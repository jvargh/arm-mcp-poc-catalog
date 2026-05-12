---
name: runbook-executor
description: >
  Deterministic procedure to walk a runbook DSL state machine, dispatch MCP tool calls per
  step type, persist state after every transition, and emit a full evidence pack.
---

# Procedure

Inputs:
- `verb`: one of `execute`, `status`, `rollback`, `cancel`. Defaults to `execute`.
- `runbook`: name of a runbook file under `runbooks/<runbook>.yaml`. Defaults to `prod`.
- `step_index` (optional): override step to start/resume from (integer, 0-based).

---

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<runbook>.yaml` as raw text. If a sibling
   `runbooks/<runbook>.values.yaml` exists, parse it and substitute every `${key}` token
   in the runbook text with the corresponding value. Then parse the substituted text as YAML.
   If `<runbook>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<runbook>.values.yaml missing — copy <runbook>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `runbook_name` (string)
   - `subscriptions[]`
   - `state_file_path` (string path)
   - `max_step_timeout_seconds` (integer, default 300)
   - `runbook_steps[]` (ordered list of step objects; see DSL schema below)
3. Read `skills/runbook-executor/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep the first 8 hex chars as `schema_hash8`.
4. Validate each step in `runbook_steps[]` against the step type schema in `rules.yaml`
   for its declared `type`. If a step fails schema validation, abort with:
   `ABORT: step '<name>' failed schema validation for type '<type>': <reason>`.

---

## Runbook DSL Schema (verbatim — do not alter this block)

```yaml
runbook_steps:
  - name: <human-readable step name>
    type: check | deploy | confirm | rollback
    kql_or_template: <KQL string for check; template path for deploy/rollback; null for confirm>
    params: {}        # parameters for deploy/rollback templates
    on_fail: halt | rollback | continue
    max_timeout_seconds: <int, optional, defaults to runbook-level max_step_timeout_seconds>
```

Field rules:
- `name`: required, non-empty string. Must be unique within the runbook.
- `type`: required. One of `check`, `deploy`, `confirm`, `rollback`.
- `kql_or_template`:
  - `check`: required literal KQL string (verbatim ARG query).
  - `deploy`/`rollback`: required path string under `remediation/`.
  - `confirm`: must be `null` or omitted.
- `params`: optional map. Used by `deploy`/`rollback` to parameterize the ARM template.
- `on_fail`: required. One of `halt` | `rollback` | `continue`.
  - `halt`: stop the runbook, mark run as `FAILED`, do not attempt further steps.
  - `rollback`: immediately trigger rollback step for the most recent `deploy` step.
  - `continue`: log FAIL in evidence pack, advance to the next step.
- `max_timeout_seconds`: optional integer. If omitted, inherits `max_step_timeout_seconds`
  from the runbook YAML level (default 300).

---

## Step 2 — Compute run_id (deterministic, no LLM judgement)

```
run_id = "RBOOK-" + UTC date YYYYMMDD + "-" + runbook_name + "-" + schema_hash8
```

Example: `RBOOK-20260512-failover-runbook-a1b2c3d4`

---

## Step 3 — Resume detection

1. Check whether the file at `state_file_path` exists.
2. If it exists, parse it as JSON and read `run_status`.
3. If `run_status` is `IN_PROGRESS` (not `COMPLETED` or `FAILED`):
   - Announce to the user: `RESUMING run {{run_id}} from step index {{last_completed_step_index + 1}}.`
   - Load `evidence_pack` array from the state file.
   - Set `current_step_index = last_completed_step_index + 1`.
   - Continue to Step 5 (skip Step 4 initialization of evidence pack and run_id).
4. If `run_status` is `COMPLETED` or `FAILED`, the previous run is final. Start a fresh run
   (proceed to Step 4). Rename the old state file to
   `<state_file_path>.prev-<run_id>` before overwriting.
5. If the file does not exist, start a fresh run (proceed to Step 4).

---

## Step 4 — Initialize run state

Write the initial state JSON to `state_file_path`:

```json
{
  "run_id": "<run_id>",
  "runbook_name": "<runbook_name>",
  "run_status": "IN_PROGRESS",
  "current_step_index": 0,
  "last_completed_step_index": -1,
  "total_steps": <N>,
  "evidence_pack": [],
  "started_utc": "<ISO 8601 UTC>",
  "schema_hash8": "<schema_hash8>"
}
```

---

## Step 5 — Execute step (dispatch by type: check / deploy / confirm / rollback)

For each step in `runbook_steps[]` starting at `current_step_index`, in file order:

### Pre-step

1. Note the step's effective `max_timeout_seconds` (step-level if set, else runbook-level,
   else 300).
2. Record `step_start_utc` (ISO 8601 UTC).

### Dispatch by `type`

#### type = `check`

1. Take `kql_or_template` as the literal KQL string. Inject scope filter from
   `subscriptions[]` if not already present:
   `| where subscriptionId in~ (<subscriptions list>)` appended before `| project`.
2. Call `validate_query` with `query = kql_or_template`, `subscriptions = runbook.subscriptions`.
   - On validation failure → record `status: FAIL`, store error in `output`, apply `on_fail`.
3. Call `execute_query` with the same arguments.
   - On empty result set → step **PASSES** (no failing resources).
   - On non-empty result set → step **FAILS** (resources found that violate the check).
   - On MCP error → record `status: FAIL`, store error, apply `on_fail`.
4. Timeout: if elapsed time exceeds `max_timeout_seconds`, stop waiting, record
   `status: TIMED_OUT`, apply `on_fail`.

#### type = `deploy`

> **v1 hard rule: do NOT call `create_template_deployment`. Simulate the outcome.**

1. Log to evidence pack: `WOULD DEPLOY (NOT EXECUTED in v1) — template: <kql_or_template>, params: <params>`.
2. Fabricate a simulated deployment name: `rbook-deploy-<step.name>-<yyyymmdd>`.
3. Fabricate a simulated `get_arm_template_deployment_status` response:
   `{"deploymentName": "<name>", "status": "Succeeded", "simulated": true}`.
4. Record step `status: PASS` (simulated success).
5. Store the fabricated deployment name in run state as `last_deploy_name` (needed for cancel).

#### type = `confirm`

> **Hard rule: pause and require explicit user input before continuing.**

1. Emit the confirmation prompt (render `templates/output-step-status.md` with status
   `AWAITING_CONFIRMATION`) to the user.
2. Wait for user input.
   - `yes` or `confirm` (case-insensitive, trimmed) → step **PASSES**.
   - `no`, `abort`, or any other value → step **FAILS**, apply `on_fail`.
   - Timeout → step **FAILS** (`status: TIMED_OUT`), apply `on_fail`.

#### type = `rollback`

> **v1 hard rule: do NOT call `create_template_deployment`. Simulate the outcome.**

1. Log to evidence pack: `WOULD ROLLBACK (NOT EXECUTED in v1) — template: <kql_or_template>, params: <params>`.
2. Fabricate a simulated rollback deployment name: `rbook-rollback-<step.name>-<yyyymmdd>`.
3. Fabricate a simulated `get_arm_template_deployment_status` response:
   `{"deploymentName": "<name>", "status": "Succeeded", "simulated": true}`.
4. Record step `status: PASS` (simulated success).

### on_fail action (when step status = FAIL or TIMED_OUT)

| `on_fail` value | Action |
|---|---|
| `halt` | Set `run_status = FAILED`. Persist state. Stop executing steps. |
| `rollback` | Find the most recent `deploy` step in the evidence pack. Run its corresponding rollback template (simulate in v1). Then set `run_status = FAILED`. Persist state. Stop. |
| `continue` | Record FAIL in evidence pack. Advance to next step. |

---

## Step 6 — Persist state after each step

After every step completes (PASS, FAIL, or TIMED_OUT):

1. Update `state_file_path` JSON:
   - `last_completed_step_index = current_step_index`
   - `current_step_index = current_step_index + 1`
   - `run_status = IN_PROGRESS` (unless halted — then `FAILED`)
   - Append the new evidence pack entry (see Step 7)
2. If all steps are complete and no halt occurred:
   - Set `run_status = COMPLETED`, `completed_utc = <ISO 8601 UTC>`.
3. Write updated JSON to `state_file_path`.

---

## Step 7 — Append evidence-pack entry

After each step, append one entry to the `evidence_pack` array in state JSON.
**Entries are ordered by execution sequence — never re-sorted.**

Entry schema (all fields required):

```json
{
  "step_name": "<step.name>",
  "type": "<step.type>",
  "input": "<kql string OR template path OR 'user-confirmation' OR null>",
  "output": "<MCP response JSON string OR simulated outcome string OR user input>",
  "status": "PASS | FAIL | TIMED_OUT | SKIPPED | AWAITING_CONFIRMATION",
  "timestamp_utc": "<ISO 8601 UTC timestamp of step completion>"
}
```

---

## Step 8 — Cancel flow

The cancel flow is triggered by the `cancel` verb or by the user typing `cancel` at any
`confirm` gate.

**Every cancel call requires per-deployment user confirmation.**

1. Read `state_file_path` to find `last_deploy_name`.
2. Emit the cancel confirmation prompt (render `prompts/cancel.prompt.md`) to the user,
   showing the deployment name.
3. Wait for user input:
   - `yes` or `confirm` → proceed with cancel.
   - Anything else → abort cancel, resume normal flow.
4. **In v1 (simulated):** Do NOT call `cancel_arm_template_deployment`. Log:
   `WOULD CANCEL (NOT EXECUTED in v1) — deployment: <last_deploy_name>`.
   In a live run, call `cancel_arm_template_deployment` with the deployment name.
5. Write an audit log entry to the evidence pack:

```json
{
  "step_name": "CANCEL",
  "type": "cancel",
  "input": "<last_deploy_name>",
  "output": "Cancel confirmed by user. cancel_arm_template_deployment called (or simulated in v1).",
  "status": "PASS",
  "timestamp_utc": "<ISO 8601 UTC>"
}
```

6. Set `run_status = CANCELLED`. Persist state.

---

## Step 9 — Render output

After each step (or on `status` / `rollback` / `cancel` verb):

1. **Per-step status:** Render `templates/output-step-status.md` with the step's evidence
   pack entry. Emit to chat after every step so the operator can track progress.
2. **Final report:** On run completion (COMPLETED, FAILED, or CANCELLED), render
   `templates/output-report.md` with the full run summary.
3. **Evidence pack:** On request or run completion, render `templates/output-evidence-pack.md`
   with the full `evidence_pack` JSON array.

---

## Failure handling

- MCP timeouts: do not retry; record `status: TIMED_OUT`, apply `on_fail`.
- Missing `kql_or_template` on a non-confirm step: record `status: SKIPPED`, continue.
- If `rules.yaml` cannot be read: abort with `ABORT: rules.yaml unreadable`.
- If `state_file_path` is not writable: abort with `ABORT: state_file_path not writable — cannot persist state`.

---

## Output contract

- The first H1 line of every run report is exactly: `# Runbook Execution Report`.
- Evidence pack is a JSON array, no trailing comma, entries in execution order.
- State file is valid JSON after every write.
- Cancel audit entry is always the last entry in the evidence pack if cancel was invoked.
