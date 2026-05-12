---
mode: agent
agent: capacity-quota-guardian
---

Get status for deployment `${input:deployment_name}` in scope `${input:scope:prod}`.

Strict requirements:
- Load `runbooks/${input:scope:prod}.yaml` to get `subscriptions[0]`.
- Call `get_arm_template_deployment_status` with `deployment_name = "${input:deployment_name}"` and the first subscription ID from the runbook.
- Output the raw status response exactly as returned by the tool. No reformatting or commentary.
- If the tool returns an error (e.g., deployment not found), print the error message verbatim.
