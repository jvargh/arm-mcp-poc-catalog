---
mode: agent
agent: post-incident-reconstructor
---

Run the **post-incident-reconstructor** skill in `reconstruct` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/post-incident-reconstructor/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- If R002 (`resourcechanges`) or R003 (`authorizationresources`) returns empty or table-not-found, emit `STATUS=SKIPPED REASON=<table>-unavailable` inline in the timeline and continue — do not abort.
- Build the change timeline sorted ascending by timestamp; ties broken by resource name ascending.
- Each timeline entry MUST match exactly: `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <id>)`
- Render the report by literal substitution into `templates/output-report.md`.
- Output ONLY the rendered report. No commentary.
