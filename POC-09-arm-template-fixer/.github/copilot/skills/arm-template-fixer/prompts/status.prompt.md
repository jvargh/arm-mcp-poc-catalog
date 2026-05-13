---
mode: agent
agent: arm-template-fixer
---

Run the **arm-template-fixer** skill in `status` mode for deployment `${input:deployment_name}` in scope `${input:scope:prod}`.

Strict requirements:
- Call `get_arm_template_deployment_status` with `deploymentName = ${input:deployment_name}`.
- Render the status using literal substitution into `templates/output-status.md`.
- Populate `{{final_status}}` from the ARM response status field (`Running`, `Succeeded`, `Failed`, `Canceled`).
- Populate `{{reason}}` from the ARM error detail if status is `Failed`, otherwise `N/A`.
- If status is `Running` or `Accepted`, append to `{{next_steps_block}}`:
  `Run @arm-template-fixer cancel deployment_name={{deployment_name}} to cancel (requires confirmation).`
- Output ONLY the rendered status report. No commentary.
