---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `scorecard` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/reliability-scorecard/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Render the report by literal substitution into `templates/output-report.md`.
- Append one row to `exports/scorecard-trend.csv`.
- Output ONLY the rendered report and one final line confirming the CSV append. No commentary.
