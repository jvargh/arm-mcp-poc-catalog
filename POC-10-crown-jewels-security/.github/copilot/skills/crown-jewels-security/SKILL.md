---
name: crown-jewels-security
description: Deterministic procedure to evaluate Azure resources against a fixed security rule pack and emit a severity-scored crown jewels report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `scan` (default), `drilldown <resource_id>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default
   `resourceGroup`), `rg_include[]`, `rg_exclude[]`, `severity_weights` (map of
   category → weight multiplier, default all 1.0), `export_format` (sarif | csv,
   default sarif), `crown_jewel_tags` (optional tag key=value filter; if present,
   only resources bearing at least one matching tag are eligible for the crown-jewels
   table).
3. Read `skills/crown-jewels-security/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "SEC-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. If `rule.skip_if_unavailable == true` (R002, R005):
   - Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On validation failure → record `status: INVALID`, store error message, continue.
   - Call `execute_query` with the same arguments.
   - If `execute_query` returns an empty result set **or** any error mentioning
     `authorizationresources` (table not found, insufficient permission) →
     emit output row `STATUS=SKIPPED REASON=authorizationresources-unavailable`
     and **continue** with the next rule. Do not abort.
   - Otherwise proceed to sub-step 4.
3. (Normal rules — no `skip_if_unavailable`) Call `validate_query` with
   `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
4. Call `execute_query` with the same arguments.
5. Apply `rg_include` / `rg_exclude` filters from runbook to returned rows.
   If `crown_jewel_tags` is set, additionally filter rows to only those whose
   resource `tags` contain at least one of the specified key=value pairs.
6. Record per resource: `{rule_id, weight, severity, resource_id, resource_name, resourceGroup}`.

## Step 3 — Score every resource

For each resource that appears in at least one rule's results:
```
severity_score = sum(rule.weight * severity_weights[rule.category]
                     for each rule where the resource appears in results)
```
`severity_weights[category]` defaults to `1.0` if the category is not listed in the
runbook's `severity_weights` map. Round final score to integer.

Sort order: **descending by `severity_score`**; ties broken by **ascending
`resource_name`** (case-insensitive).

## Step 4 — Render output (mode-specific)

### Mode = `scan`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{resources_scored}}`, `{{ruleset_hash8}}`.
   - `{{top_crown_jewels_table}}` — top 10 rows sorted **descending by `severity_score`**,
     ties by `resource_name` ascending. Columns: `Rank`, `Resource`, `Resource Group`,
     `Severity Score`, `Matched Rules`.
   - `{{rule_findings_table}}` — one row per rule with at least one hit, sorted
     **descending by `weight`**, ties by `rule_id` ascending. Columns: `Rule ID`,
     `Title`, `Severity`, `Weight`, `Matched Resources`.
   - `{{skipped_rules_block}}` — list of rules with `STATUS=SKIPPED` or `STATUS=INVALID`,
     each on its own line. Include `REASON` where applicable.
3. Write a SARIF or CSV export to `exports/` according to `export_format`:
   - **sarif**: emit a SARIF 2.1.0 JSON document.
   - **csv**: emit a header row + one data row per crown-jewel resource.
4. Print the rendered report and a single confirmation line naming the export file.
   Nothing else.

### Mode = `drilldown <resource_id>`

1. Read `templates/output-drilldown.md`.
2. Re-run only the rules that flagged this resource (skip rules with no hit for it).
   Each rule re-rendered with: `rule_id`, `severity`, `weight`, and the verbatim `kql`.
3. Substitute, print. No export write.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set (non-`authorizationresources` rules): rule has no hits; do not include
  it in the findings table.
- `authorizationresources` errors on R002/R005: emit
  `STATUS=SKIPPED REASON=authorizationresources-unavailable` and continue.
- If `rules.yaml` cannot be read, abort with: `ABORT: rules.yaml unreadable`.

## Output contract (what callers can rely on)

- The first H1 line of every scan report is exactly: `# Crown Jewels Security Posture`.
- The order of sections is exactly: Header → Summary → Top Crown Jewels → Rule Findings
  → Skipped/Invalid Rules → Footer.
- Severity score is always a non-negative integer.
- Sort is always descending by severity_score, ties by resource_name ascending.
