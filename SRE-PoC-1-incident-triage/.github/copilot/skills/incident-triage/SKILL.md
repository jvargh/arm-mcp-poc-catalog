---
name: incident-triage
description: >
  Deterministic procedure for the "First 60 Seconds" incident triage agent.
  Runs three fixed rules (change feed, in-flight deployments, RBAC changes),
  renders a ≤1-screen 80-char-wide report, and writes an audit trail.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `triage` (default) or `cancel <deployment-id>`.

---

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling
   `runbooks/<scope>.values.yaml` exists, parse it and substitute every
   `${key}` token in the runbook text. Then parse the substituted text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy
   <scope>.values.yaml.example and fill in real values`.
2. Extract: `subscription_id`, `triage_scopes[]`, `default_time_window_hours`
   (default `2`).
3. Read `skills/incident-triage/rules/rules.yaml`. Compute SHA-256 of the raw
   file bytes; keep the first 8 hex chars as `ruleset_hash8`.
4. Compute:
   ```
   run_id = "TRIAGE-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8
   ```
5. Set `time_window_hours` = `default_time_window_hours` from runbook.

---

## Step 2 — R001: Resource changes (skip_if_unavailable)

> Table: `resourcechanges` — carries `skip_if_unavailable: true`.

1. Take the literal `kql` from R001 in `rules.yaml`.
2. Substitute `{subscription_id}` → the subscription_id string from the runbook.
   Substitute `{time_window_hours}` → `time_window_hours` integer.
3. Call `generate_query` with the substituted KQL string.
4. Call `execute_query` with the query returned by `generate_query`,
   `subscriptions = [subscription_id]`.
5. **On table-not-found error OR empty result with provider error:**
   - Emit one output row: `STATUS=SKIPPED REASON=resourcechanges-unavailable`.
   - Continue to Step 3. Do NOT abort.
6. **On success:** store rows as `r001_rows`, sorted descending by `changedAt`.
   Cap at 20 rows.

---

## Step 3 — R002: In-flight ARM deployments

> Table: `resources` (microsoft.resources/deployments).

1. Take the literal `kql` from R002 in `rules.yaml`.
2. Substitute `{subscription_id}` and `{time_window_hours}` as above.
3. Call `generate_query` → `execute_query`.
4. For each deployment row returned, call `get_arm_template_deployment_status`
   with `deploymentName = row.name`, `resourceGroup = row.resourceGroup`,
   `subscriptionId = subscription_id`.
5. Merge live `provisioningState` into the row. Keep only rows where
   `provisioningState =~ 'Running'` after the live check.
6. Store as `r002_rows`, sorted descending by `startTime`. Cap at 10 rows.

---

## Step 4 — R003: RBAC / role assignment changes (skip_if_unavailable)

> Table: `authorizationresources` — carries `skip_if_unavailable: true`.

1. Take the literal `kql` from R003 in `rules.yaml`.
2. Substitute `{subscription_id}` and `{time_window_hours}`.
3. Call `generate_query` → `execute_query`.
4. **On table-not-found error OR provider error:**
   - Emit one output row: `STATUS=SKIPPED REASON=authorizationresources-unavailable`.
   - Continue to Step 5.
5. **On success:** store rows as `r003_rows`, sorted descending by `createdOn`.
   Cap at 10 rows.

---

## Step 5 — Render output

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally** (no paraphrasing):
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601, UTC, `Z` suffix),
     `{{time_window_hours}}`, `{{subscription_id}}`, `{{ruleset_hash8}}`.
   - `{{r001_table}}` — markdown rows from `r001_rows` (or single SKIPPED row).
     Columns: `changedAt | changeType | resourceId (truncated) | principal`.
     All lines ≤ 80 chars; truncate `resourceId` with `…` at char 35 if needed.
   - `{{r002_table}}` — rows from `r002_rows`. If empty, write `(none)`.
     Columns: `name | resourceGroup | startTime | state`.
   - `{{r003_table}}` — rows from `r003_rows` (or single SKIPPED row).
     Columns: `principalId (short) | roleDefId (short) | scope (truncated)`.
3. Emit the rendered report to chat. Nothing else.

---

## Step 6 — Write audit trail

Append exactly one JSON-Lines record to
`exports/triage-audit-<scope>-<YYYYMMDD>.jsonl` (create if missing):

```json
{"event":"triage","run_id":"<run_id>","scope":"<scope>",
 "generated_utc":"<iso8601>","r001_status":"ok|skipped",
 "r002_rows":<int>,"r003_status":"ok|skipped"}
```

Print one confirmation line: `✓ Audit record written to exports/`.

---

## Step 7 — Cancel flow

> **Cancel verb only.** This step does NOT run during a normal `triage`.

Trigger: user types `@incident-triage cancel <deployment-id>` or follows the
prompt in `prompts/cancel.prompt.md`.

1. Resolve `deployment-id` to `{ deploymentName, resourceGroup, subscriptionId }`
   from `r002_rows` in context (or ask the user to confirm the triple).
2. Call `get_arm_template_deployment_status` with those parameters to confirm the
   deployment is still `Running`. If not Running, abort with:
   `ABORT: deployment <name> is no longer Running (state=<state>). Nothing cancelled.`
3. **Display the cancel confirmation template** by substituting into
   `templates/output-cancel-confirmation.md`. STOP and wait.
4. **Gate:** require the user to type exactly `YES` (case-sensitive) in reply.
   Any other reply → print `Cancel aborted. No action taken.` and stop.
5. On `YES` → call `cancel_arm_template_deployment` with the same parameters.
6. Call `get_arm_template_deployment_status` again to confirm state is
   `Canceling` or `Canceled`.
7. Append audit record:
   ```json
   {"event":"cancel","run_id":"<run_id>","scope":"<scope>",
    "generated_utc":"<iso8601>","deployment":"<name>",
    "rg":"<rg>","result":"cancelled|aborted","user_confirmed":true}
   ```
8. Print the result using `templates/output-cancel-confirmation.md` (post-cancel
   section) with the final state. Line width ≤ 80 chars.

---

## Failure handling

- ARM MCP timeouts: do not retry. Record the rule as `SKIPPED` with error and
  continue.
- `generate_query` error: mark rule `SKIPPED REASON=generate-query-error` and
  continue.
- `rules.yaml` unreadable: abort with `ABORT: rules.yaml unreadable`.
- Cancel on non-Running deployment: abort with clear message (see Step 7.2).

---

## Output contract

- First H1 of every triage report is exactly:
  `# Incident Triage Report`
- Section order: Header → Changes (R001) → In-Flight Deployments (R002) →
  RBAC Changes (R003) → Footer.
- Every line in the rendered report is ≤ 80 characters.
- Every run appends exactly one record to the audit JSONL.
