---
name: blast-radius-analyzer
description: Deterministic procedure to inspect an ARM template, cross-reference affected resources via ARG, categorize each change, flag policy violations and dependency fan-out, and emit a fixed-format risk report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `analyze` (default) or `drilldown <resource-name>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`, `template_path`, `risk_threshold`.
3. Read `skills/blast-radius-analyzer/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "BR-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Parse target template

1. Read the ARM template file at the path given by `template_path` in the runbook.
   If the file cannot be read, abort with:
   `ABORT: template_path '<path>' unreadable — verify the path in runbooks/<scope>.values.yaml`.
2. Parse the JSON. Iterate `template.resources[]`. For each resource entry extract:
   - `resource_name`: value of `name` field (may contain `[parameters(...)]` / `[variables(...)]` — keep as-is).
   - `resource_type`: value of `type` field (normalise to lowercase).
   - `resource_api_version`: value of `apiVersion`.
   - `resource_depends_on`: value of `dependsOn[]` array (may be empty).
3. Resolve parameter and variable references where their `defaultValue` is present in
   `template.parameters` or `template.variables`. Store the resolved `resource_id_hint`
   (subscription + RG + type + name) for ARG lookup. If a parameter has no `defaultValue`,
   store the unresolved expression as-is — do not guess.
4. Store the full resource list as `template_resources[]` in working memory.
   Count: `resources_total = len(template_resources)`.

## Step 3 — Cross-reference with ARG and categorize changes (fixed loop)

For each entry in `template_resources[]`:

1. Build a scoped ARG query:
   ```
   Resources
   | where tolower(type) =~ '<resource_type>'
     and tolower(name) =~ '<resource_name_resolved>'
   | project id, name, resourceGroup, subscriptionId, location, type
   ```
2. Call `validate_query` with `subscriptions = runbook.subscriptions`.
   - On failure → mark resource `INVALID`, store error, continue.
3. Call `execute_query` with the same arguments.
4. Assign change category based on result:
   - **No rows returned** → `CREATE` (resource does not exist yet).
   - **Row returned, type matches** → `MODIFY` (exists; assume in-place update unless
     the resource type is in the replace-sensitive list from R001's `kql` types).
   - **Row returned, type matches AND resource type is replace-sensitive** → `REPLACE`.
   - **Resource present in ARG scope but absent from template** (detected in Step 5 sweep)
     → `DELETE`.
5. Assign `risk_weight` from the matching rule:
   REPLACE → 15, DELETE → 15, MODIFY → 10, CREATE → 2.
6. Apply `rg_include` / `rg_exclude` filters from runbook.

## Step 4 — Detect DELETE candidates

1. Run a single ARG query for all resources in scope:
   ```
   Resources
   | where resourceGroup in~ (<rg_include_list>)
   | project id, name, resourceGroup, subscriptionId, location, type
   ```
2. For each ARG row, if the resource `name` + `type` combination is **not** in
   `template_resources[]`, mark it as `DELETE` with `risk_weight = 15`.
   Apply `rg_exclude` filter.

## Step 5 — Evaluate supplemental rules (fixed loop)

For each `rule` in `rules.yaml` **in file order** (R001–R006):

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. If `rule.skip_if_unavailable == true` (R005), wrap execution in error-handling:
   if `execute_query` returns error or empty set, emit
   `STATUS=SKIPPED REASON=<rule_id>-unavailable` and continue.
3. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
4. Call `execute_query` with the same arguments.
5. Record per resource: `{rule_id, weight, severity, hit_count}`.

## Step 6 — Compute total risk score

```
total_risk_score = sum(risk_weight for each resource in template_resources)
                 + sum(rule.weight for each supplemental rule with hit_count > 0)
```

Compare to `risk_threshold` from runbook:
- `total_risk_score >= risk_threshold` → `threshold_status = EXCEEDED`
- `total_risk_score < risk_threshold` → `threshold_status = OK`

## Step 7 — Render output (mode-specific)

### Mode = `analyze`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{template_path}}`, `{{generated_utc}}` (ISO 8601, `Z` suffix),
     `{{ruleset_hash8}}`, `{{resources_total}}`, `{{resources_evaluated}}`,
     `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{total_risk_score}}`, `{{risk_threshold}}`, `{{threshold_status}}`.
   - `{{change_risk_table}}` — one markdown row per resource, sorted **descending by
     risk_weight**, ties broken by **resource name ascending** (case-insensitive).
   - `{{policy_violations_table}}` — rows from R005 result; if SKIPPED emit one row
     `| SKIPPED | policyresources-unavailable | — |`.
   - `{{fanout_table}}` — rows from R006 result.
   - `{{risk_breakdown_block}}` — one subsection per change category (REPLACE, DELETE,
     MODIFY, CREATE) showing count and cumulative weight. Omit empty categories.
3. Print the rendered report. Nothing else.

### Mode = `drilldown <resource-name>`

1. Read `templates/output-drilldown.md`.
2. Re-execute only the rules that flagged this resource (skip rules with no hit).
   Each rule re-rendered with: `rule_id`, `severity`, `weight`, `hit_count`,
   raw KQL, and first 25 returned `id` fields.
3. Substitute, print. No artifacts written.

## Failure handling

- ARM MCP timeouts: do not retry; record rule as `INVALID` with error and continue.
- Empty result set: resource passes for this rule; do not include in risk table.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.
- If `template_path` is missing from the runbook, abort:
  `ABORT: template_path not set in runbooks/<scope>.yaml — add it to your values file`.

## Output contract

- The first H1 line of every analyze report is exactly: `# Pre-deploy Blast Radius Report`.
- Section order is exactly: Header → Summary → Change Risk Table → Policy Violations →
  Dependency Fan-out → Risk Breakdown → Footer.
- Sort of Change Risk Table: descending risk_weight, ties by resource name ascending.
