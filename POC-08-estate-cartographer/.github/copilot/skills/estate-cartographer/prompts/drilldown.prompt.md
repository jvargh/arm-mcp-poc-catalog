---
mode: agent
agent: estate-cartographer
---

Run the **estate-cartographer** skill in `drilldown` mode for resource `${input:resource_id}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/estate-cartographer/rules/rules.yaml` (R004 and R005 only).
- Call `execute_query` directly. Do NOT call `validate_query` (not in tool allowlist).
- Re-execute only R004 and R005 scoped to the target resource ID.
- Use `$skipToken` paging if results exceed 1000 rows.
- Render via literal substitution into `templates/output-drilldown.md`.
- Output ONLY the rendered drilldown. No commentary.
