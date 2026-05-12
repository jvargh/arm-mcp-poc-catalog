---
name: incident-responder
description: Deterministic procedure to answer blast-radius questions during incidents using ARG change feed, in-flight deployments, and RBAC audit — with a cancel path for running deployments.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `triage` (default) or `cancel`.

---

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If `<scope>.values.yaml`
   is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `rg_include[]`, `rg_exclude[]`,
   `default_time_window_hours` (default `2`), `incident_scopes[]`.
3. Read `skills/incident-responder/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "INC-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. Substitute `${time_window_hours}` in every rule's `kql` field with the value of
   `default_time_window_hours` from the runbook. This is the **only** KQL substitution.

---

## Step 2 — Evaluate rules (fixed loop, triage verb only)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED REASON=no-kql` and continue.
2. Call `generate_query` with:
   - `query_template = rule.kql` (after `${time_window_hours}` substitution from Step 1)
   - `subscriptions = runbook.subscriptions`
   - `scope_filter = runbook.rg_include` (if non-empty)
3. Call `execute_query` with the generated query and `subscriptions = runbook.subscriptions`.
   **Do NOT call `validate_query` — it is not in the tool allowlist.**
4. On `execute_query` error or empty result:
   - If `rule.skip_if_unavailable == true` → record
     `STATUS=SKIPPED REASON=<rule_table>-unavailable` and continue with next rule.
   - Otherwise → record `STATUS=INVALID` with the error message and continue.
5. Apply `rg_include` / `rg_exclude` filters from runbook to the returned rows
   (case-insensitive substring match on `resourceGroup` column).
6. Store result rows: `{rule_id, rows[], row_count}`.

### Handling skip_if_unavailable rules

- **R001 (`resourcechanges`)**: If unavailable, emit:
  `STATUS=SKIPPED REASON=resourcechanges-unavailable`
  Continue to R002. Do NOT abort the run.
- **R003 (`authorizationresources`)**: If unavailable, emit:
  `STATUS=SKIPPED REASON=authorizationresources-unavailable`
  Continue. Do NOT abort the run.
- R002 (`Resources` table) is always available; no skip logic.

---

## Step 3 — Fetch in-flight deployment statuses

For each deployment returned by R002:

1. Call `get_arm_template_deployment_status` with the deployment `id` from the R002 row.
2. Capture: `provisioningState`, `timestamp`, `duration`, `correlationId`.
3. Attach enriched status to the R002 row for template rendering.

If R002 returned no rows (no in-flight deployments), record `in_flight_count = 0` and
skip this step.

---

## Step 4 — Render triage report

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{time_window_hours}}`.
   - `{{r001_status}}` — `OK` (rows returned) | `SKIPPED` | `INVALID`.
   - `{{r002_status}}` — `OK` | `INVALID`.
   - `{{r003_status}}` — `OK` (rows returned) | `SKIPPED` | `INVALID`.
   - `{{change_feed_table}}` — markdown rows from R001, sorted descending by `changeTime`.
     If R001 was skipped: single row `| SKIPPED | resourcechanges-unavailable | — | — | — |`.
   - `{{in_flight_table}}` — markdown rows from R002 (enriched with status), sorted
     descending by `startTime`. If no in-flight deployments: `*(none)*`.
   - `{{rbac_changes_table}}` — markdown rows from R003, sorted descending by `createdOn`.
     If R003 was skipped: single row `| SKIPPED | authorizationresources-unavailable | — | — | — |`.
   - `{{in_flight_count}}` — integer count of R002 rows.
   - `{{change_count}}` — integer count of R001 rows (0 if skipped).
   - `{{rbac_count}}` — integer count of R003 rows (0 if skipped).
3. Append one JSON-line to `exports/incident-audit.jsonl` (create if missing):
   ```json
   {"run_id":"<run_id>","verb":"triage","generated_utc":"<utc>","scope":"<scope>","r001_status":"<>","r002_status":"<>","r003_status":"<>","in_flight_count":<n>,"change_count":<n>,"rbac_count":<n>}
   ```
4. Print the rendered report and the audit-line confirmation. Nothing else.

---

## Step 5 — Cancel flow

**Triggered when:** user invokes the `cancel` verb, e.g.
`@incident-responder cancel deployment <deployment-id> scope prod`.

This step requires a prior `triage` run in context (or re-runs Steps 1–3 automatically).

### Step 5a — Identify target deployment

1. Resolve the deployment ID from the user's message. If ambiguous (no explicit ID given),
   list the current R002 in-flight deployments and ask the user to specify one by ID.
   Do not proceed without an explicit deployment ID.

### Step 5b — Check current status

1. Call `get_arm_template_deployment_status` with the target deployment ID.
2. If `provisioningState` is NOT `Running`, report:
   `Deployment <id> is in state <state> — cancel not applicable. Aborting.`
   Append an ABORTED audit line and stop.

### Step 5c — Confirmation gate (MANDATORY — do not skip)

Present the following confirmation block verbatim and wait for user input:

```
⚠️  CANCEL CONFIRMATION REQUIRED
Deployment ID : <deployment-id>
Deployment name: <name>
Resource group : <resourceGroup>
Subscription   : <subscriptionId>
Current state  : Running
Started at     : <startTime>

Type "yes" or "y" to confirm cancellation. Any other input aborts.
```

- If user responds "yes" or "y" (case-insensitive, stripped): proceed to Step 5d.
- Any other response → append ABORTED audit line and stop:
  `ABORTED: user did not confirm cancellation of <deployment-id>.`

### Step 5d — Execute cancel

1. Call `cancel_arm_template_deployment` with the deployment `id`.
2. Read the tool response.
3. Render `templates/output-cancel-confirmation.md` with:
   - `{{deployment_id}}`, `{{deployment_name}}`, `{{resource_group}}`,
     `{{subscription_id}}`, `{{cancel_result}}`, `{{cancel_utc}}`.
4. Append one JSON-line to `exports/incident-audit.jsonl`:
   ```json
   {"run_id":"<run_id>","verb":"cancel","generated_utc":"<utc>","scope":"<scope>","deployment_id":"<id>","deployment_name":"<name>","cancel_result":"<Succeeded|Failed>","confirmed_by_user":true}
   ```
5. Print the rendered cancel-confirmation template and the audit-line confirmation.

### Step 5e — Aborted cancel audit

If the user did not confirm (Step 5c fallback) or the deployment was not Running (Step 5b
fallback), always append to `exports/incident-audit.jsonl`:
```json
{"run_id":"<run_id>","verb":"cancel","generated_utc":"<utc>","scope":"<scope>","deployment_id":"<id>","cancel_result":"ABORTED","confirmed_by_user":false,"reason":"<reason>"}
```

---

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result set for R001 or R003 (no changes, not an error): record `STATUS=OK` with
  `row_count=0`. Do not treat an empty change feed as unavailable.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.
- If `exports/incident-audit.jsonl` cannot be written, warn but do not abort the run.

---

## Output contract (what callers can rely on)

- The first H1 line of every triage report is exactly: `# Incident Triage Report`.
- Section order: Header → Summary → Change Feed → In-Flight Deployments → RBAC Changes → Footer.
- Every triage run appends exactly one JSON-line to `exports/incident-audit.jsonl`.
- Every cancel attempt (success or aborted) appends exactly one JSON-line.
- Sort orders: change feed descending by `changeTime`; deployments descending by `startTime`;
  RBAC descending by `createdOn`.
