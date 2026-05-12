---
mode: agent
agent: runbook-executor
---

Cancel the current in-flight deployment for runbook `${input:runbook:prod}` (`cancel` verb).

⚠️ This action requires **explicit per-deployment user confirmation** before proceeding.

Strict requirements:
- Read `state_file_path` declared in `runbooks/${input:runbook:prod}.yaml`.
- Read `last_deploy_name` from the current state. If no in-flight deployment exists, emit:
  `No in-flight deployment found for runbook '${input:runbook:prod}'. Cancel not applicable.`
- Display the deployment name to the user and ask for explicit confirmation:

  ```
  ⚠️  CANCEL CONFIRMATION REQUIRED
  Deployment to cancel: <last_deploy_name>
  This will halt the current ARM deployment. This action cannot be undone.
  Type 'yes' or 'confirm' to proceed. Anything else aborts the cancel.
  ```

- Wait for user input:
  - `yes` or `confirm` (case-insensitive, trimmed) → proceed.
  - Anything else → emit `Cancel aborted by operator.` and do not cancel.
- On confirmation:
  - **In v1 (simulated):** Do NOT call `cancel_arm_template_deployment`.
    Log: `WOULD CANCEL (NOT EXECUTED in v1) — deployment: <last_deploy_name>`.
  - In a live run, call `cancel_arm_template_deployment` with `deploymentName = <last_deploy_name>`.
- Write an audit log entry to the evidence pack:
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
- Set `run_status = CANCELLED`. Persist state to `state_file_path`.
- Render `templates/output-step-status.md` for the cancel audit entry.
- Output ONLY the rendered cancel status and the audit entry. No commentary.
