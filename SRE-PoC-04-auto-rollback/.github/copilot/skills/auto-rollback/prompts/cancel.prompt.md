---
mode: agent
agent: auto-rollback
---

Cancel the in-progress ARM deployment `${input:deployment_name}` for scope `${input:scope:prod}`.

Run the **auto-rollback** skill in `cancel` mode (SKILL.md Step 5):

Strict requirements:
- Load `runbooks/<scope>.yaml` + `<scope>.values.yaml`. Extract `deployment_name`,
  `subscription_id`, `resource_group`.
- **MANDATORY per-deployment confirmation gate.** Before calling `cancel_arm_template_deployment`,
  display the exact prompt:
  ```
  Cancel deployment <deployment_name>? This will stop all in-progress operations.
  Reply YES to confirm.
  ```
  Do NOT proceed without the user typing an explicit "YES". Any other response aborts the cancel.
- On YES:
  - Call `cancel_arm_template_deployment` with `deployment_name`, `resource_group`, `subscription_id`.
  - Emit timeline line: `[<utc_now>] ACTION: cancel-invoked deployment=<name> (OK)`
  - Write audit entry: `AUDIT: cancel deployment=<name> actor=user ts=<utc_now>`
- On any other response:
  - Emit: `[<utc_now>] ACTION: cancel-aborted deployment=<name> reason=user-declined (HALTED)`
  - Stop. Do not trigger rollback.
- After cancel: render via `templates/output-timeline.md`. No rollback unless user then invokes `rollback` verb.
