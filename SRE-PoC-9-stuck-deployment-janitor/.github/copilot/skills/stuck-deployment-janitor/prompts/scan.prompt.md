---
mode: agent
agent: stuck-deployment-janitor
---

Run the **stuck-deployment-janitor** skill in `scan` mode for scope `${input:scope:prod}`.

Strict requirements:
- Read the rule pack from `skills/stuck-deployment-janitor/rules/rules.yaml` exactly. Do not invent or modify KQL.
- For every rule, call `execute_query` directly — **do NOT call `validate_query` or `generate_query`** (not in allowlist).
- Enrich each stuck deployment with `get_arm_template_deployment_status`.
- Render the report by literal substitution into `templates/output-report.md`.
- Write rendered report to `exports/stuck-<scope>-latest.md`.
- Output ONLY the rendered report and one final line confirming the file write. No commentary.
- Sort output descending by `durationHours`, ties broken by `name` ascending.
