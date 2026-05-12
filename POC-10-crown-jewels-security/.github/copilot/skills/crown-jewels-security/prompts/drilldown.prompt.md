---
mode: agent
agent: crown-jewels-security
---

Run the **crown-jewels-security** skill in `drilldown` mode for resource `${input:resource_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/crown-jewels-security/rules/rules.yaml`.
- Re-execute only the rules that flagged this resource. Do not run rules that produced no hit.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query for each matched rule.
- Output ONLY the rendered drilldown. No commentary.
