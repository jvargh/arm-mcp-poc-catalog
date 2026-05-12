---
mode: agent
agent: iac-drift-detector
---

Run the **iac-drift-detector** skill in `drilldown` mode for resource `${input:resource_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Identify the drift entries for the given `resource_id` from the last `detect` run (re-execute if not in context).
- Use the rule pack at `skills/iac-drift-detector/rules/rules.yaml`.
- Re-execute only the rules that match the resource type of the given `resource_id`. Do NOT call `validate_query`.
- Sort drifted properties alphabetically in the table.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the RFC 6902 JSON patch with operations sorted by `/path` ascending.
- Output ONLY the rendered drilldown. No commentary.
