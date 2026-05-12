---
name: post-incident-reconstructor
description: Deterministic procedure to reconstruct a full change timeline (deployments + property changes + RBAC) from Azure Resource Graph over an incident time window and render a postmortem-ready report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `reconstruct` (default) or `drilldown <deployment-id>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `incident_time_window.start_utc` and `incident_time_window.end_utc`
   - `incident_scope` (subscription, resource group, or tag filter)
   - `postmortem_template_format` (e.g. `"standard"`)
3. Read `skills/post-incident-reconstructor/rules/rules.yaml`. Compute SHA-256 of the
   file contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "POST-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Inject `start_utc` and `end_utc` from the runbook's `incident_time_window` into the
   KQL using `${start_utc}` / `${end_utc}` substitution. Inject scope filter tokens
   (`${subscription_id}`, `${rg_filter}`) likewise.
3. Call `validate_query` with `query = injected_kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
4. Call `execute_query` with the same arguments.
5. If `rule.skip_if_unavailable == true` AND the result is an empty set OR the error
   indicates the table is unavailable:
   - Record `status: SKIPPED`, `reason: <table>-unavailable`.
   - Emit one timeline sentinel row: `STATUS=SKIPPED REASON=<table>-unavailable`.
   - Continue to next rule.
6. Store returned rows as `(rule_id, rows[])`.

## Step 3 — Enrich deployments with status

For each deployment ID in R001 results, call `get_arm_template_deployment_status` to
retrieve final `provisioningState`. Attach the state to the deployment record.

## Step 4 — Build the change timeline

1. Merge rows from R001, R002 (if available), R003 (if available), and R004.
2. For each row extract:
   - `timestamp` (ISO 8601 UTC)
   - `principal` (identity that made the change; use deployment `principalId` or
     `changedBy` field; fall back to `"unknown"`)
   - `action` (change type: `deployed`, `modified`, `role-assigned`, `role-removed`,
     `correlated-change`)
   - `resource` (resource name or ID short-form — last segment of the ARM resource ID)
   - `deployment_id` (correlated deployment name; `n/a` if none)
3. Sort the merged list **ascending by `timestamp`** (earliest event first).
   Ties broken by `resource` ascending (case-insensitive).
4. Format each row exactly as:
   `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <deployment_id>)`
   where `HH:MM:SS UTC` is extracted from the ISO 8601 timestamp.

## Step 5 — Render output (mode-specific)

### Mode = `reconstruct`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`.
   - `{{incident_start}}`, `{{incident_end}}` from runbook `incident_time_window`.
   - `{{incident_scope}}` from runbook.
   - `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`.
   - `{{deployment_count}}` — count of distinct deployment IDs from R001.
   - `{{change_count}}` — total timeline entries (excluding SKIPPED sentinels).
   - `{{rbac_count}}` — count of RBAC rows from R003 (0 if SKIPPED).
   - `{{timeline_block}}` — the formatted timeline lines, one per row, in ascending
     timestamp order.
3. Print the rendered report. Nothing else.

### Mode = `drilldown <deployment-id>`

1. Read `templates/output-drilldown.md`.
2. Filter timeline to rows where `deployment_id` matches the given deployment ID, OR
   where the resource ID appears in the deployment's resource list.
3. Call `get_arm_template_deployment_status` for the deployment ID to get full status.
4. Substitute placeholders and print. No CSV write.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set on a non-skippable rule: rule returns zero rows; note it in summary.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- If `incident_time_window` is missing from the runbook, abort with:
  `ABORT: incident_time_window missing from runbook — set start_utc and end_utc`.

## Output contract (what callers can rely on)

- The first H1 line of every reconstruct report is exactly:
  `# Post-Incident Change Timeline`
- The order of sections is exactly:
  Header → Incident Summary → Rules Summary → Change Timeline → Footer.
- Timeline entries appear in ascending timestamp order with no gaps or re-ordering.
- Each timeline entry matches the canonical format exactly:
  `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <id>)`
- SKIPPED sentinels appear inline in the timeline at the position they were emitted,
  not grouped at the end.
