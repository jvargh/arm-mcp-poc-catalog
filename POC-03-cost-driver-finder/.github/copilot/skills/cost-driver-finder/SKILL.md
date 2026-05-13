---
name: cost-driver-finder
description: Deterministic procedure to surface top cost-driving resources by querying ARG for new/resized resources in a time window, joined with owner tags, and emit a fixed-format markdown report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `run` (default), `drilldown <resource-group>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted text
   as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`, `time_window_days` (default `30`), `target_region`,
   `cost_threshold_usd` (optional).
3. Read `skills/cost-driver-finder/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "COST-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate every rule (fixed loop, no validate_query)

> **Determinism Deviation:** `validate_query` is NOT in the tool allowlist for this PoC.
> Each rule proceeds directly from `generate_query` to `execute_query`.

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Call `generate_query` with the **literal** `kql` from `rules.yaml`, substituting:
   - `${time_window_days}` → the integer value from the runbook (e.g. `30`)
   - `${target_region}` → the string value from the runbook (e.g. `eastus2`)
   This substitution is pure string replacement. The KQL is never invented by the LLM.
3. Call `execute_query` with the generated query and `subscriptions = runbook.subscriptions`.
   - **If rule has `skip_if_unavailable: true`** (currently R002 only):
     - If `execute_query` returns an empty result set OR returns a table-not-found /
       ResourceChanges-unavailable error → record `status: SKIPPED`,
       emit output row `STATUS=SKIPPED REASON=resourcechanges-unavailable`, and continue
       to the next rule. Do not retry.
   - On any other error → record `status: INVALID` with the error message and continue.
4. Apply `rg_include` / `rg_exclude` filters to the returned rows (case-insensitive
   substring match on `resourceGroup`).
5. Store the filtered rows keyed by `rule.id`.

## Step 3 — Summarise findings

1. Count distinct `id` values returned per rule → `resource_count[rule_id]`.
2. Count distinct `resourceGroup` values across all rules → `resource_groups_affected`.
3. Compute `resources_total` = sum of all rule resource counts (deduplicated by `id`).

## Step 4 — Render output (mode-specific)

### Mode = `run`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally** (no paraphrasing):
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{time_window_days}}`, `{{target_region}}`, `{{resources_total}}`,
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`.
   - `{{new_resources_table}}` — markdown rows from R001 results, sorted descending by
     `createdAt`, ties by `name` ascending. Columns: Resource ID, Name, Type, Resource Group,
     Created At, Owner. If R001 has no rows, substitute `*(no new resources found in window)*`.
   - `{{modified_resources_table}}` — markdown rows from R002 results, sorted descending by
     `changedAt`, ties by `id` ascending. Columns: Resource ID, Resource Group, Location,
     Changed At, Change Type. If R002 was SKIPPED, substitute
     `*(STATUS=SKIPPED REASON=resourcechanges-unavailable)*`.
     If R002 has no rows, substitute `*(no modified resources found in window)*`.
   - `{{untagged_resources_table}}` — markdown rows from R003 results, sorted ascending by
     `name`. Columns: Resource ID, Name, Type, Resource Group, RG Owner. If no rows,
     substitute `*(no untagged resources found in region)*`.
   - `{{cost_management_block}}` — if `cost_threshold_usd` is set in the runbook, emit:
     `*Cost threshold set to ${{cost_threshold_usd}} USD. Actual cost figures require Azure Cost Management — query the resources listed above by resource ID in the Azure Cost Management portal or API.*`
     Otherwise emit: `*Set `cost_threshold_usd` in your values file to enable future Azure Cost Management handoff.*`
3. Print the rendered report. Nothing else.

### Mode = `drilldown <resource-group>`

1. Read `templates/output-drilldown.md`.
2. Filter all rule result rows to those where `resourceGroup` matches the argument
   (case-insensitive exact match).
3. For each rule that has rows for this resource group, render a findings sub-block:
   - Rule ID, title, severity, verbatim KQL, resource count, first 25 `id` values.
4. Substitute placeholders and print. No exports write.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set (non-R002): rule has no cost drivers; render as "no rows found" per template.
- R002 empty or table-not-found: emit `STATUS=SKIPPED REASON=resourcechanges-unavailable` and continue.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.

## Output contract (what callers can rely on)

- The first H1 line of every run report is exactly: `# Cost Driver Finder Report`.
- Section order is exactly: Header → Summary → New Resources (R001) → Modified Resources (R002) → Untagged Resources (R003) → Cost Management Handoff → Footer.
- Sort order for R001/R002 results: descending by timestamp, ties by name/id ascending.
- Sort order for R003 results: ascending by name.
- Timestamps are emitted verbatim from ARG (ISO 8601 strings). No reformatting by the LLM.
