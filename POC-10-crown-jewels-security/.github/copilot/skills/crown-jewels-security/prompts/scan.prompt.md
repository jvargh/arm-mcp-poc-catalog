---
mode: agent
agent: crown-jewels-security
---

Run the **crown-jewels-security** skill in `scan` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/crown-jewels-security/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- For R002 and R005: if `execute_query` errors or returns empty, emit `STATUS=SKIPPED REASON=authorizationresources-unavailable` and continue.
- Render the report by literal substitution into `templates/output-report.md`.
- Sort results descending by `severity_score`; ties broken by `resource_name` ascending.
- Write the export file to `exports/` in the format specified by `export_format` in the runbook.
- Output ONLY the rendered report and one final line confirming the export file path. No commentary.
