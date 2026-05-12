---
mode: agent
agent: chatops-bot
---

Show the audit log using the **chatops-bot** skill in `audit` mode for scope `${input:scope:prod}`.

Strict requirements:
- Read all lines from `runbook.audit_log_path`. Parse each as a JSON object.
- Sort entries descending by `timestamp_utc` (most recent first).
- Render the audit report by literal substitution into `templates/output-audit.md`. No commentary outside the template.
- Do NOT execute any ARG queries in audit mode. This is a log-display operation only.
- Do NOT write a new audit log line for the audit command itself.
- NEVER call any write or deploy tool. `read_only_mode: true` is absolute.
