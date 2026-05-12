---
mode: agent
agent: tag-hygiene-czar
---

Run the **tag-hygiene-czar** skill with verb `scan` for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/tag-hygiene-czar/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Render the report by literal substitution into `templates/output-report.md`.
- Write the rendered report to `exports/tag-report-<scope>-latest.md`.
- Output ONLY the rendered report and one final confirmation line. No commentary.
- Do NOT call `create_template_deployment` — this verb is strictly read-only.
