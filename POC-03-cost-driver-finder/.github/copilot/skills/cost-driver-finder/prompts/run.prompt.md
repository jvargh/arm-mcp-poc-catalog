---
mode: agent
agent: cost-driver-finder
---

Run the **cost-driver-finder** skill in `run` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/cost-driver-finder/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `generate_query` then `execute_query`. Do not call `validate_query`. No retries on failure.
- Substitute `${time_window_days}` and `${target_region}` from the runbook values file into the KQL before calling `generate_query`.
- Render the report by literal substitution into `templates/output-report.md`.
- Output ONLY the rendered report. No commentary.
