---
mode: agent
agent: finops-rightsizer
---

Run the **finops-rightsizer** skill in `scan` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/finops-rightsizer/rules/rules.yaml` exactly. Do not invent rules or queries.
- For every rule: call `generate_query` with the literal KQL, then `execute_query`. Do NOT call `validate_query`.
- Compute savings estimates using the `savings_rate_per_sku` map from the runbook.
- Render the report by literal substitution into `templates/output-report.md`.
- Write the rendered report to `exports/rightsizer-${input:scope:prod}-latest.md`.
- Output ONLY the rendered report and one final confirmation line. No commentary.
