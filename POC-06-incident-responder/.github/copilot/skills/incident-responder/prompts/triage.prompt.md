---
mode: agent
agent: incident-responder
---

Run the **incident-responder** skill in `triage` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/incident-responder/rules/rules.yaml` exactly. Do not invent queries.
- For every rule, call `generate_query` then `execute_query`. Do NOT call `validate_query`.
- For R001 and R003, if execute_query errors or the table is unavailable, emit STATUS=SKIPPED and continue — do not abort.
- After R002, call `get_arm_template_deployment_status` for each in-flight deployment found.
- Render the report by literal substitution into `templates/output-report.md`.
- Append one JSON-line to `exports/incident-audit.jsonl`.
- Output ONLY the rendered report and one final line confirming the audit append. No commentary.
