---
mode: agent
agent: blast-radius-analyzer
---

Run the **blast-radius-analyzer** skill in `drilldown` mode for resource `${input:resource}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/blast-radius-analyzer/rules/rules.yaml`.
- Re-execute only the rules that flagged this resource. Do not run rules that produced no hit in the last analyze run.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs per triggered rule.
- MUST NOT call `create_template_deployment` (v1 constraint).
- Output ONLY the rendered drilldown. No commentary.
