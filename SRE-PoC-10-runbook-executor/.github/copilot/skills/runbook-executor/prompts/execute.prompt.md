---
mode: agent
agent: runbook-executor
---

Execute the **runbook-executor** skill (`execute` verb) for runbook `${input:runbook:prod}`.

Strict requirements:
- Load `runbooks/${input:runbook:prod}.yaml` and its sibling `.values.yaml`. Abort with the
  standard message if the values file is missing.
- Validate all `runbook_steps` entries against the step type schemas in
  `skills/runbook-executor/rules/rules.yaml`. Abort on schema validation failure.
- Check `state_file_path` for an in-progress run before starting. If an IN_PROGRESS state
  exists, announce the resume and continue from the last completed step.
- Walk each step in `runbook_steps` in file order. Dispatch by `type`:
  - `check`: call `validate_query` then `execute_query`. Zero rows = PASS.
  - `deploy`: SIMULATE — do NOT call `create_template_deployment`. Log "WOULD DEPLOY (NOT EXECUTED in v1)".
  - `confirm`: pause and require explicit user confirmation (`yes`/`confirm`) before advancing.
  - `rollback`: SIMULATE — do NOT call `create_template_deployment`. Log "WOULD ROLLBACK (NOT EXECUTED in v1)".
- After every step: render `templates/output-step-status.md` and persist state to `state_file_path`.
- Append an evidence pack entry after every step.
- On run completion (COMPLETED, FAILED, or CANCELLED), render `templates/output-report.md`
  and `templates/output-evidence-pack.md`.
- Output ONLY the rendered step statuses, the final report, and the evidence pack. No commentary.
