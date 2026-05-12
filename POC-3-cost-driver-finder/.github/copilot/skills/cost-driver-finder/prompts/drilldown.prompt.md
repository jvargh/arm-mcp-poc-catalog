---
mode: agent
agent: cost-driver-finder
---

Run the **cost-driver-finder** skill in `drilldown` mode for resource group `${input:resource_group}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/cost-driver-finder/rules/rules.yaml`.
- Re-execute only the rules that returned results for this resource group.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs per rule.
- Output ONLY the rendered drilldown. No commentary.
