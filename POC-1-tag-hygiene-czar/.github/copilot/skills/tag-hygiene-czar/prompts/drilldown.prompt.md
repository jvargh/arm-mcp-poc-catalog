---
mode: agent
agent: tag-hygiene-czar
---

Run the **tag-hygiene-czar** skill with verb `drilldown` for resource group `${input:resource_group}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/tag-hygiene-czar/rules/rules.yaml`.
- Re-execute only the rules that flagged this resource group. Do not run rules with no previous hits on this RG.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs per failed rule.
- Output ONLY the rendered drilldown. No commentary.
- Do NOT call `create_template_deployment` — this verb is strictly read-only.
