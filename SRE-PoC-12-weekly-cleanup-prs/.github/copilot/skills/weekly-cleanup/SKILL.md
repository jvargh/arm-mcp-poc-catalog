---
name: weekly-cleanup
description: Deterministic procedure to find drift + orphaned resources in an Azure scope and compose a proposed PR with corrective ARM patches and savings estimates.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `scan` (default), `drilldown <resource-id>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml` exists,
   parse it and substitute every `${key}` token in the runbook text with the corresponding value
   (lists/maps inlined as YAML). Then parse the substituted text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `rg_include[]`, `rg_exclude[]`,
   `iac_repo_path`, `orphan_threshold_days` (default `30`), `savings_rate_map`.
3. Read `skills/weekly-cleanup/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "CLEAN-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. If `rule.skip_if_unavailable == true` (i.e. R002): wrap the `execute_query` call defensively.
   If `execute_query` returns a table-not-found error or an error indicating `resourcechanges` is
   unavailable, emit `STATUS=SKIPPED REASON=<rule.skip_reason>` and continue.
3. If `rule.generate_hint` is set → call `generate_query` with the hint to build the KQL.
   Otherwise use the **literal** KQL from `rules.yaml` verbatim (no LLM rewriting).
4. Call `execute_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
5. Apply `rg_include` / `rg_exclude` filters from runbook to the returned rows
   (case-insensitive substring match on `resourceGroup` column).
6. Record per rule: `{rule_id, category, findings[], failing_resource_count}`.

**No `validate_query` step.** See `## Determinism Deviation` in README.

## Step 3 — Categorize and sort findings

1. Group findings by `rule.category`: `orphaned`, `drift`, `compliance`.
2. For each finding row, compute `estimated_savings`:
   - If `rule.estimated_savings_resource_type == "use_map"`:
     look up `savings_rate_map[resource_type]` (from runbook); default to `0`.
   - If `rule.estimated_savings_resource_type == null`: `estimated_savings = 0`.
3. Apply fixed sort: **category group order** (orphaned → drift → compliance),
   then **estimated_savings descending** within each group,
   then **resource_id ascending** as deterministic tie-break.
4. Compute summary counts: `orphan_count`, `drift_count`, `compliance_count`,
   `total_savings` (sum of all `estimated_savings`, rounded to integer, no decimals).

## Step 4 — Render scan output (verb = `scan`)

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally** (no paraphrasing):
   `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601, UTC, `Z` suffix),
   `{{ruleset_hash8}}`, `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`,
   `{{orphan_count}}`, `{{drift_count}}`, `{{compliance_count}}`, `{{total_savings}}`,
   `{{findings_table}}` (markdown rows in fixed sort order), `{{pr_title}}`.
3. Print the rendered report. Nothing else.

## Step 5 — Compute savings estimates

For each finding, `estimated_savings = savings_rate_map.get(resource_type, 0)`.
Round each value to integer. Sum per category and overall for `total_savings`.

## Step 6 — Compose proposed PR content

1. Read `templates/output-pr-content.md`.
2. Compute `orphan_savings`, `drift_savings`, `compliance_savings`, `total_count`, `total_savings`.
3. Build `{{proposed_changes_block}}`: one sub-section per remediation template referenced.
   Each sub-section includes: template file path, list of affected resource IDs (up to 10),
   and a code-block showing the apply command referencing the JSON template filename.
4. Substitute all placeholders in `output-pr-content.md` **literally**.

**GitHub PR creation is out of scope for v1.** The agent composes the PR content markdown only.
A human (or a future GitHub Actions integration) opens the actual PR.

## Step 7 — Write PR markdown to exports/

1. Create directory `exports/proposed-pr/` if it does not exist.
2. Write the rendered PR content to `exports/proposed-pr/{{run_id}}.md`.
3. Reference ARM patch templates by file path only (`remediation/*.json`) — do NOT call
   `create_template_deployment`. Do NOT issue any deployment.
4. Print: `Proposed PR content written to exports/proposed-pr/{{run_id}}.md`.

## Step 8 — Drilldown (verb = `drilldown <resource-id>`)

1. Read `templates/output-drilldown.md`.
2. Re-execute only the rules that would flag this specific resource
   (apply a resource-level filter `| where id =~ '<resource-id>'` to the KQL).
3. Render via literal substitution: `{{resource_id}}`, `{{resource_type}}`,
   `{{resource_group}}`, `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{rule_hits_block}}`.
4. Print the rendered drilldown. No PR write.

## Failure handling

- ARM MCP timeouts: record the rule as `SKIPPED` with the error message and continue.
- R002 `resourcechanges` table unavailable: emit `STATUS=SKIPPED REASON=resourcechanges-unavailable`.
- Empty result set from `execute_query`: rule finds no issues — do not include in findings table.
- If `rules.yaml` cannot be read, abort with: `ABORT: rules.yaml unreadable`.

## Output contract (what callers can rely on)

- The first H1 line of every scan report is exactly: `# Weekly Azure Cleanup Report`.
- Section order: Header → Summary → Cleanup Findings → Proposed PR → Footer.
- Sort order: orphaned → drift → compliance, then savings descending, then resource_id ascending.
- `run_id` format is always `CLEAN-{YYYYMMDD}-{scope}-{sha256[:8]}`.
- PR title is always: `Weekly Azure cleanup: {orphan_count} orphaned, {drift_count} drifts,
  {compliance_count} compliance — $X/mo savings`.
