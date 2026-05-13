---
mode: agent
agent: golden-path-provisioner
---

Run the **golden-path-provisioner** skill in `status` mode for scope `${input:scope:prod}`.

Deployment name: `${input:deployment_name}`
Resource group: `${input:resource_group}`

Strict requirements:
- Call `get_arm_template_deployment_status` with the deployment name and resource group.
- Render the result via `templates/output-status.md` by literal `{{placeholder}}` substitution.
- If `provisioningState` is not terminal (`Succeeded`, `Failed`, `Canceled`), poll again after **exactly 10 seconds**.
- If `provisioningState == "Failed"`, emit: `⚠ DEPLOYMENT FAILED — run cancel verb to trigger rollback hook`.
- Output ONLY the rendered status block. No commentary.
