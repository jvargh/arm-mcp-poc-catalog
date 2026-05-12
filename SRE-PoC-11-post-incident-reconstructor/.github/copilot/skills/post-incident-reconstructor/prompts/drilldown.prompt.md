---
mode: agent
agent: post-incident-reconstructor
---

Run the **post-incident-reconstructor** skill in `drilldown` mode for deployment `${input:deployment_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/post-incident-reconstructor/rules/rules.yaml`.
- Filter the full change timeline to events correlated with the specified deployment ID.
- Call `get_arm_template_deployment_status` for the deployment ID to obtain provisioning state.
- Timeline entries MUST match exactly: `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <id>)`
- Render via literal substitution into `templates/output-drilldown.md`.
- Include all correlated resource change events found in the incident window.
- Output ONLY the rendered drilldown. No commentary.
