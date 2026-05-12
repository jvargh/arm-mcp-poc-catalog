---
mode: agent
agent: finops-rightsizer
---

Run the **finops-rightsizer** skill in `drilldown` mode for resource `${input:resource}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/finops-rightsizer/rules/rules.yaml`.
- Re-execute only the rules that flagged this resource. Do not run rules that produced no hit.
- For each matching rule: call `generate_query` with the literal KQL, then `execute_query`. Do NOT call `validate_query`.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs per matched rule.
- Output ONLY the rendered drilldown. No commentary.
