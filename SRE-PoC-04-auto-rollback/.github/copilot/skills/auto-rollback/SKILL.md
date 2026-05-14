---
name: auto-rollback
description: >
  Deterministic procedure to watch an ARM deployment, evaluate a health gate,
  and automatically cancel + redeploy the last-known-good template on breach.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `watch` (default), `rollback`, `cancel`.

## Step 1 - Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing - copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscription_id`, `resource_group`
   - `deployment_name`
   - `template_file`, `parameters_file`
   - `last_good_template_ref` (Git ref or file path to the last-known-good template)
   - `health_gate_timeout_seconds` (default `120`)
   - `max_rollback_attempts` (default `2`)
3. Read `skills/auto-rollback/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "ROLL-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. Initialise timeline buffer and `rollback_attempts_remaining = max_rollback_attempts`.

## Step 2 - Compute run_id and open timeline

1. Emit the opening timeline line:
   ```
   [<utc_now>] ACTION: run-start (IN_PROGRESS)
   ```
   Format: `[YYYY-MM-DDTHH:MM:SSZ] ACTION: description (status)`.
   Status values: `IN_PROGRESS`, `OK`, `FAIL`, `SKIPPED`, `HALTED`, `PENDING_CONFIRM`.

## Step 3 - Watch deployment progress

1. Call `get_arm_template_deployment_status` with:
   - `deployment_name` from runbook
   - `resource_group` from runbook
   - `subscription_id` from runbook
2. Emit timeline line for each poll:
   ```
   [<utc_now>] ACTION: deployment-status-check (IN_PROGRESS) provisioningState=<state>
   ```
3. Repeat polling until one of:
   - Deployment reaches terminal state (`Succeeded`, `Failed`, `Canceled`).
   - `health_gate_timeout_seconds` has elapsed since step 2 started.
4. Emit terminal status line:
   ```
   [<utc_now>] ACTION: deployment-settled provisioningState=<state> (OK|FAIL)
   ```
   Use `OK` if `Succeeded`, `FAIL` otherwise.
5. If the deployment is still `Running` when the timeout fires:
   - Emit `[<utc_now>] ACTION: health-gate-timeout elapsed=<seconds>s (FAIL)`.
   - Proceed to Step 5 (Trigger rollback).
6. If the deployment reached `Failed` or `Canceled`, proceed directly to Step 5.

## Step 4 - Health gate evaluation (rule_id order)

Run **only when** the deployment settled with `Succeeded`. If already heading to
rollback (Step 5), skip this step.

For each rule in `rules.yaml` **in rule_id order** (R001 → R002 → R003 → R004):

1. Take the literal `kql` from the rule. Substitute `${resource_group}` and
   `${subscription_id}` from the runbook values. **Do not call `generate_query`
   or `validate_query`** - go directly to `execute_query`.
2. Call `execute_query` with the substituted KQL and `subscriptions=[subscription_id]`.
3. Emit timeline line:
   ```
   [<utc_now>] ACTION: health-check rule_id=<id> title="<title>" result=<PASS|FAIL> failing_resources=<n>
   ```
   `PASS` = zero rows returned. `FAIL` = one or more rows.
4. If any rule returns one or more rows → record the rule as `FAIL` and note the
   failing resource IDs (first 25). Continue evaluating remaining rules even on FAIL.
5. After all rules evaluated, emit aggregate:
   ```
   [<utc_now>] ACTION: health-gate-result overall=<PASS|FAIL> failed_rules=<count> (OK|FAIL)
   ```
6. If overall `PASS` → go to Step 7 (Render output, status = `SUCCEEDED`).
7. If overall `FAIL` → emit:
   ```
   [<utc_now>] ACTION: health-gate-breach triggering=auto-rollback (FAIL)
   ```
   Proceed to Step 5.

## Step 5 - Cancel flow

Triggered automatically by the orchestrator on:
- Deployment `Failed` / `Canceled` state (Step 3).
- Health gate timeout (Step 3).
- Health gate breach (Step 4).

Also triggered manually by the user invoking the `cancel` verb.

1. Emit:
   ```
   [<utc_now>] ACTION: cancel-requested deployment=<name> (PENDING_CONFIRM)
   ```
2. **Pause and ask the user:**
   ```
   Cancel deployment <deployment_name>? This will stop all in-progress operations.
   Reply YES to confirm.
   ```
3. On `YES`:
   - Call `cancel_arm_template_deployment` with `deployment_name`, `resource_group`,
     `subscription_id`.
   - Emit:
     ```
     [<utc_now>] ACTION: cancel-invoked deployment=<name> (OK)
     ```
   - Write audit log entry: `AUDIT: cancel deployment=<name> actor=<user|orchestrator> ts=<utc_now>`.
4. On any other response, or if the user does not confirm within the session:
   - Emit:
     ```
     [<utc_now>] ACTION: cancel-aborted deployment=<name> reason=user-declined (HALTED)
     ```
   - Stop. Do not proceed to rollback.
5. If verb is `cancel` (manual invocation), go to Step 7 after cancel completes.
6. Otherwise (auto-cancel path), proceed to Step 6.

## Step 6 - Trigger rollback

Runs only after a successful cancel (auto path). Attempts to redeploy `last_good_template_ref`.

1. Emit:
   ```
   [<utc_now>] ACTION: rollback-start attempt=<n>/<max> lkg_ref=<last_good_template_ref> (IN_PROGRESS)
   ```
2. **v1 SIMULATED ONLY.** Write the would-deploy details to the timeline:
   ```
   [<utc_now>] ACTION: deploy-lkg [SIMULATED - NOT EXECUTED in v1] template=<ref> params=<params_file> mode=Complete (IN_PROGRESS)
   ```
   Do **not** call `create_template_deployment` in v1.
3. Simulate the LKG deployment completing. Emit:
   ```
   [<utc_now>] ACTION: rollback-deploy-settled [SIMULATED] provisioningState=Succeeded (OK)
   ```
4. Re-run the full health gate (Step 4) against the LKG deployment result.
5. If health gate passes → emit:
   ```
   [<utc_now>] ACTION: rollback-success attempt=<n>/<max> (OK)
   ```
   Proceed to Step 7 (status = `ROLLED_BACK`).
6. If health gate fails:
   - Decrement `rollback_attempts_remaining`.
   - Emit:
     ```
     [<utc_now>] ACTION: rollback-failed attempt=<n>/<max> remaining=<r> (FAIL)
     ```
   - If `rollback_attempts_remaining > 0` → loop back to step 6.1.
   - If `rollback_attempts_remaining == 0` → emit:
     ```
     [<utc_now>] ACTION: rollback-halted reason=max-rollback-attempts-reached (HALTED)
     ```
     Proceed to Step 7 (status = `HALTED`).

## Step 7 - Render output

1. Read `templates/output-timeline.md`. Substitute `{{placeholders}}` with run values.
   Write the full timeline buffer into `{{timeline_block}}`.
2. Read `templates/output-report.md`. Substitute all `{{placeholders}}`.
3. Write rendered report to `exports/rollback-<run_id>.md` (create file; append `_N` if
   a file with the same name already exists).
4. Print both rendered templates to chat. Output ONLY the rendered content.
   No commentary, no paraphrase.

## Failure handling

- `get_arm_template_deployment_status` timeout / error: emit
  `[<utc_now>] ACTION: poll-error error="<msg>" (FAIL)` and proceed to Step 5.
- `execute_query` error for a health-gate rule: emit rule result as `FAIL` with
  `reason=query-error` and continue.
- `cancel_arm_template_deployment` error: emit
  `[<utc_now>] ACTION: cancel-error error="<msg>" (FAIL)` - do not retry cancel;
  escalate to operator.
- `rules.yaml` unreadable: abort with literal message `ABORT: rules.yaml unreadable`.

## Output contract

- Every timeline line is exactly: `[YYYY-MM-DDTHH:MM:SSZ] ACTION: description (status)`.
- The first H1 of every report is exactly: `# Auto-Rollback Orchestrator Report`.
- Section order: Header → Run Summary → Timeline → Health Gate Results → Rollback Log → Footer.
- Numeric values are integers. No decimals.
