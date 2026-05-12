---
mode: agent
agent: weekly-cleanup
---

Run the **weekly-cleanup** skill in `drilldown` mode for resource `${input:resource_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/weekly-cleanup/rules/rules.yaml`.
- Re-execute only the rules that would flag this resource. Apply a resource-level filter (`| where id =~ '<resource-id>'`) to each KQL before calling `execute_query`.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and the finding reason per matched rule.
- Output ONLY the rendered drilldown. No PR write. No commentary.
