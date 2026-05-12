---
mode: agent
agent: incident-responder
---

Run the **incident-responder** skill in `cancel` mode for deployment `${input:deployment_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Call `get_arm_template_deployment_status` to verify the deployment is in `Running` state before proceeding.
- If not Running, report the current state and abort — do not call `cancel_arm_template_deployment`.
- **MANDATORY CONFIRMATION GATE:** Before calling `cancel_arm_template_deployment`, present the deployment ID, name, resource group, subscription, and start time to the user and require explicit "yes" or "y" confirmation.
  - One confirmation is required per deployment ID. Do not batch-cancel multiple deployments in a single confirmation.
  - If the user does not respond "yes" or "y", abort immediately and record the cancellation as ABORTED in the audit log.
- Only after confirmed "yes": call `cancel_arm_template_deployment` with the deployment ID.
- Render the result by literal substitution into `templates/output-cancel-confirmation.md`.
- Append one JSON-line to `exports/incident-audit.jsonl` regardless of outcome (success or aborted).
- Output ONLY the rendered cancel-confirmation template and one final line confirming the audit append. No commentary.
