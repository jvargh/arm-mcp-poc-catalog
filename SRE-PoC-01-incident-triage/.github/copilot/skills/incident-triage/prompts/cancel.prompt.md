---
mode: agent
agent: incident-triage
---

Run the **incident-triage** skill in `cancel` mode for deployment
`${input:deployment_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Resolve deployment to `{ deploymentName, resourceGroup, subscriptionId }`
  from context or ask the user to confirm the triple.
- Call `get_arm_template_deployment_status` to verify the deployment is still
  `Running`. If not Running, abort immediately — do NOT call cancel.
- Render `templates/output-cancel-confirmation.md` (pre-cancel section) and
  STOP. Wait for the user to type exactly `YES`.
- **Per-deployment confirmation is MANDATORY.** Any response other than `YES`
  (case-sensitive) → print `Cancel aborted. No action taken.` and stop.
- On `YES`: call `cancel_arm_template_deployment` with the exact parameters.
- Call `get_arm_template_deployment_status` again to confirm final state.
- Append one JSON-Lines audit record to `exports/` regardless of outcome.
- Render `templates/output-cancel-confirmation.md` (post-cancel section).
- Output ONLY the rendered cancel result and audit confirmation. No commentary.

> ⚠️  Never call `cancel_arm_template_deployment` without explicit YES
> confirmation for EACH deployment. One confirmation per deployment.
