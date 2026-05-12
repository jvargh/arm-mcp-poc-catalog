---
mode: agent
agent: arm-template-fixer
---

Run the **arm-template-fixer** skill in `cancel` mode for deployment `${input:deployment_name}` in scope `${input:scope:prod}`.

Strict requirements:
- Call `get_arm_template_deployment_status` first to confirm the deployment is in a cancellable state (`Running` or `Accepted`).
- **MANDATORY confirmation gate:** Display exactly this message to the user before calling `cancel_arm_template_deployment`:

  ```
  Deployment ${input:deployment_name} is currently {status}.
  To cancel, type exactly: confirm cancel ${input:deployment_name}
  Any other input will abort the cancel flow.
  ```

- Wait for user input. Only proceed with cancellation if the user types `confirm cancel ${input:deployment_name}` verbatim (exact match, case-sensitive).
- On confirmed input: call `cancel_arm_template_deployment` with `deploymentName = ${input:deployment_name}`.
- On any other input: log `[Cancel] Cancel aborted by user.` and stop.
- If the deployment is already `Succeeded`, `Failed`, or `Canceled`: report the current status and do NOT call `cancel_arm_template_deployment`.
- Output ONLY the cancel outcome and deployment status. No commentary.
