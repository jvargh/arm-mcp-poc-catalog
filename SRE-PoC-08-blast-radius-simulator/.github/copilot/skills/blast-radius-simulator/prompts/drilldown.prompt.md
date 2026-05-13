---
mode: agent
agent: blast-radius-simulator
---

Run the **blast-radius-simulator** skill in `drilldown` mode for category `${input:category}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/blast-radius-simulator/rules/rules.yaml`.
- Re-execute only the rule matching `<category>`. Do not run other rules.
- Call `validate_query` then `execute_query` for the matched rule.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs.
- Output ONLY the rendered drilldown. No commentary.
