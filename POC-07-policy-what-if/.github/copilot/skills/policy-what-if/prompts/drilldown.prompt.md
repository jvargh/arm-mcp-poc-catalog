---
mode: agent
agent: policy-what-if
---

Run the **policy-what-if** skill in `drilldown` mode for resource `${input:resource_id}` using scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/policy-what-if/rules/rules.yaml`. Do not invent ARG queries.
- Re-execute only the rules that flagged this resource ID. Skip rules with no hit on the last simulate run.
- For every matched rule, call `validate_query` then `execute_query`. No retries on failure.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim substituted ARG query for each matched rule.
- Output ONLY the rendered drilldown. No commentary.
