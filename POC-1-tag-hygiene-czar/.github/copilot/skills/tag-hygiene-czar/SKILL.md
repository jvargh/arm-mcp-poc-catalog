---
name: tag-hygiene-czar
description: Deterministic procedure to find tag-non-compliant Azure resources, emit a fixed-format report, and (on explicit authorisation) deploy ARM patches to apply missing tags.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `scan` (default), `drilldown <resource-group>`, `apply`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `rg_include[]`, `rg_exclude[]`,
   `required_tags[]`, `default_tag_values{}`, `freeze_active` (boolean), `freeze_windows[]`.
3. Read `skills/tag-hygiene-czar/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "TAG-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. For each tag name in `required_tags` that has no matching `tag_key` entry in
   `rules.yaml`, emit a warning row `STATUS=NO_RULE_DEFINED TAG=<name>` and continue.
   Do not attempt to generate KQL for undefined tags.

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order** whose `tag_key` appears in
`runbook.required_tags` (skip rules for tags not in the required set):

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue. Do not retry.
3. Call `execute_query` with the same arguments.
4. From returned rows, apply `rg_include` / `rg_exclude` filters (case-insensitive
   substring match on `resourceGroup`).
5. Record per row: `{rule_id, tag_key, weight, severity, id, name, type, resourceGroup, location}`.

## Step 3 — Aggregate findings

1. Deduplicate: for each `(id, rule_id)` pair keep one row (no double-counting).
2. Count `noncompliant_count` per `(rule_id, resourceGroup, type)`.
3. Sort all result rows: `resourceGroup` ascending → `type` ascending → `name` ascending.
   This sort order is fixed and must not be altered.

## Step 4 — Render output (verb-specific)

### Verb = `scan`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{resources_scanned}}` (distinct resource IDs across all executed rules),
     `{{resources_noncompliant}}` (distinct resource IDs with at least one tag violation),
     `{{ruleset_hash8}}`.
   - `{{noncompliant_table}}` — one markdown row per non-compliant resource-tag pair,
     sorted: `resourceGroup` ascending, `type` ascending, `name` ascending.
   - `{{failing_checks_table}}` — one row per rule with `noncompliant_count > 0`,
     sorted descending by `weight`, ties by `rule_id` ascending.
3. Write the rendered report to `exports/tag-report-<scope>-latest.md`.
4. Print the rendered report and one final confirmation line. Nothing else.

### Verb = `drilldown <resource-group>`

1. Read `templates/output-drilldown.md`.
2. Re-run only the rules that flagged this RG (skip rules with no hit on the last scan).
   Each rule re-rendered with: `rule_id`, `tag_key`, `severity`, `weight`,
   `noncompliant_count`, raw KQL (verbatim from `rules.yaml`), and the first 25 `id` values.
3. Substitute and print. No file write.

### Verb = `apply`

1. Check `freeze_active` in the loaded runbook. If `true`, abort with the literal message:
   `ABORT: freeze_active is set in runbooks/<scope>.yaml — no deployments permitted during freeze window.`
2. From the last `scan` result (re-execute Step 2 if not in current context), collect all
   non-compliant `(resource_id, tag_key)` pairs. For each pair, look up the default tag
   value from `runbook.default_tag_values[tag_key]` (use `"UNKNOWN"` if the key is absent).
3. For each rule with a `remediation_template` entry, construct a deployments table:
   template file, target resource ID, tag name, proposed tag value.
4. Present the planned deployments table to the user.

## Step 5 — Confirm gate (apply verb only)

> **Do not proceed past this step without explicit confirmation. This is a hard requirement.**

5. Output the following literal message and await the user's next response:
   ```
   CONFIRM GATE: About to deploy ARM tag patches for {{noncompliant_count}} resource-tag pair(s) across {{rg_count}} resource group(s).
   Reply "yes, apply tags" to proceed. Any other reply cancels all deployments.
   ```
6. If the user replies with exactly `yes, apply tags` (case-insensitive, whitespace-trimmed):
   - For each (resource_id, tag_key) pair call `create_template_deployment` with:
     - template: `remediation/apply-missing-tags.json`
     - parameters: `targetResourceId = resource_id`, `tagName = tag_key`,
       `tagValue = default_tag_values[tag_key]`
     - mode: `Incremental`
     - deployment name: `tag-patch-<rule_id>-<sha256(resource_id)[:8]>`
   - After all deployments are submitted, poll `get_arm_template_deployment_status` for
     each deployment name until every deployment reaches a terminal state
     (`Succeeded`, `Failed`, or `Canceled`).
   - Render `templates/output-remediation.md` with the deployment results.
7. If the user replies with anything else — output `CANCELLED: no deployments submitted.` and stop.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set: rule passes for all resources; do not include it in the failing checks table.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- `validate_query` failure: mark rule `INVALID`, do not retry, continue to next rule.

## Output contract (what callers can rely on)

- The first H1 line of every scan report is exactly: `# Tag Hygiene Report`.
- Section order is fixed: Header → Summary → Non-Compliant Resources → Failing Checks → Footer.
- Sort order for the non-compliant table: `resourceGroup` ascending, `type` ascending,
  `name` ascending. This order is frozen and must not be changed.
- Numeric output is integer unless source data is a percentage (1 decimal place).
- Tag compliance is **binary per resource per tag**: a resource either has the tag (with a
  non-empty value) or it does not. Partial matches are not considered compliant.
