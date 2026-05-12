---
mode: agent
agent: preflight-safety
---

Run the **preflight-safety** skill in `status` mode.

Deployment name: `${input:deployment_name}`

Strict requirements:
- Call `get_arm_template_deployment_status` with the deployment name provided.
- Print status rows: `deployment_name`, `status`, `timestamp`, `error` (if any).
- Output ONLY the status rows. No commentary.
