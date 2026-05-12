---
mode: agent
agent: tag-hygiene-czar
---

Run the **tag-hygiene-czar** skill with verb `apply` for scope `${input:scope:prod}`.

Strict requirements:
- Check `freeze_active` in `runbooks/<scope>.yaml` before any action. Abort if `true`.
- Identify all non-compliant `(resource_id, tag_key)` pairs from the most recent `scan` result (re-execute if not in context).
- Present the planned ARM tag patch deployments to the user as a table before doing anything.
- **STOP and display the CONFIRM GATE message (verbatim from SKILL.md Step 5) before calling `create_template_deployment`.** This is mandatory.
- Only call `create_template_deployment` if the user explicitly replies "yes, apply tags" (case-insensitive). Any other reply → output `CANCELLED: no deployments submitted.` and stop immediately.
- After confirmed deployments are submitted, poll `get_arm_template_deployment_status` for each deployment name until terminal state.
- Render via `templates/output-remediation.md`. No commentary.
- **Never call `create_template_deployment` without explicit user confirmation at the confirm gate.**
