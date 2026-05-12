---
mode: agent
agent: incident-triage
---

Run the **incident-triage** skill in `triage` mode for scope
`${input:scope:prod}`.

Strict requirements:
- Load `runbooks/<scope>.yaml` (with values file substitution).
- Execute all three rules in order: R001 → R002 → R003.
- For R001 and R003: use `generate_query` → `execute_query`.
  If the table is unavailable, emit `STATUS=SKIPPED REASON=<table>-unavailable`
  and continue — do NOT abort.
- For R002: use `generate_query` → `execute_query` to find running deployments,
  then call `get_arm_template_deployment_status` per deployment for live state.
- Do NOT call `validate_query` (not in allowlist — ratification #7).
- Render the report by literal substitution into `templates/output-report.md`.
  Every output line MUST be ≤ 80 characters. Truncate resource IDs with `…`.
- Sort: R001 by changedAt desc, R002 by startTime desc, R003 by createdOn desc.
- Append exactly one JSON-Lines audit record to `exports/`.
- Output ONLY the rendered report and one final line confirming the audit write.
  No commentary.
