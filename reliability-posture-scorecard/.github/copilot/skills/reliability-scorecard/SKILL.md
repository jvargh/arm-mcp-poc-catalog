---
name: reliability-scorecard
description: Deterministic procedure to evaluate Azure workloads against a fixed reliability rule pack and emit a fixed-format markdown report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `scorecard` (default), `drilldown <workload>`, `remediate`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`.
3. Read `skills/reliability-scorecard/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "RPS-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
3. Call `execute_query` with the same arguments.
4. Group returned rows by `workload_key` (default the `resourceGroup` column).
   Apply `rg_include` / `rg_exclude` filters from runbook.
5. Record per workload: `{rule_id, weight, severity, failing_resource_count}`.

## Step 3 — Score every workload

For each workload that appears in any rule's results:
```
score = max(0, 100 - sum(rule.weight for each rule where failing_resource_count > 0))
```
Round to integer. Track `failed_rules` list and `top_gap` = highest-weight failed rule_id.

## Step 4 — Render output (mode-specific)

### Mode = `scorecard`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{workloads_total}}`, `{{ruleset_hash8}}`.
   - `{{bottom10_table}}` — markdown rows sorted ascending by `score`, ties by `workload` ascending. Limit to 10 rows. If fewer than 10 workloads, list all.
   - `{{failing_checks_table}}` — one row per rule with `failing_resource_count > 0`,
     sorted descending by `weight`, ties by `rule_id`.
   - `{{top3_gaps_block}}` — three subsections for the three rule_ids with highest
     `(weight × failing_resource_count)`. Ties broken by `rule_id` ascending. If fewer than three
     gap rule_ids exist, list as many as exist.
3. Append one row to `exports/scorecard-trend.csv` (create with header if missing):
   `run_id,generated_utc,scope,ruleset_hash8,workloads_total,avg_score,min_score,rules_failing`
4. Print the rendered report and the CSV append confirmation. Nothing else.

### Mode = `drilldown <workload>`

1. Read `templates/output-drilldown.md`.
2. Re-run only the rules that flagged this workload (skip rules with no hit).
   Each rule re-rendered with: `rule_id`, `severity`, `weight`, `failing_resource_count`,
   raw KQL, and the first 25 returned `id` fields.
3. Substitute, print. No CSV write.

### Mode = `remediate`

1. From the last `scorecard` run (re-execute if not in context), pick the three rule_ids
   with the highest `(weight × failing_resource_count)`.
2. For each pick, look up `rule.remediation_template`. If null, report
   "no template available for {{rule_id}}" and continue.
3. **Stop and ask the user to confirm each remediation by rule_id.** Do not deploy
   without explicit confirmation per rule.
4. On confirmation, call `create_template_deployment` with the template file at
   `remediation/<remediation_template>` and parameters drawn from the failing
   resource list. Use mode = `Incremental`.
5. Render `templates/output-remediation.md` with the deployment names + statuses.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set: rule passes for all workloads; do not include it in the failing checks table.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.

## Output contract (what callers can rely on)

- The first H1 line of every scorecard report is exactly: `# Reliability Posture Scorecard`.
- The order of sections is exactly: Header → Summary → Bottom 10 → Failing Checks → Top 3 Gaps → Footer.
- Every emitted run appends exactly one row to the trend CSV.
