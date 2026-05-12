---
mode: agent
agent: runbook-executor
---

Trigger a rollback for runbook `${input:runbook:prod}` (`rollback` verb).

Strict requirements:
- Read `state_file_path` declared in `runbooks/${input:runbook:prod}.yaml`.
- Find the most recent `deploy` step in the evidence pack (the last entry with `type = deploy`).
- If no deploy step is found, emit: `No deploy step found in evidence pack — rollback not applicable.`
- Load the rollback template: use the `kql_or_template` of a corresponding `rollback` step if
  defined in `runbook_steps`, otherwise use `remediation/example-failover-rollback.json`.
- **Stop and ask the user to confirm the rollback** before proceeding. Show the deploy step name
  and template path. Do not proceed without explicit `yes` or `confirm`.
- On confirmation: SIMULATE rollback (do NOT call `create_template_deployment` in v1).
  Log "WOULD ROLLBACK (NOT EXECUTED in v1)".
- Append a rollback evidence pack entry. Set `run_status = FAILED` (rollback implies failure recovery).
- Persist state to `state_file_path`.
- Render `templates/output-step-status.md` for the rollback step.
- Output ONLY the rendered rollback status. No commentary.
