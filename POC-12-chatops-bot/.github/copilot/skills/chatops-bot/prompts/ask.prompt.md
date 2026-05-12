---
mode: agent
agent: chatops-bot
---

Answer the user's Azure question using the **chatops-bot** skill in `ask` mode for scope `${input:scope:prod}`.

Strict requirements:
- Map the question to a pre-canned category in `skills/chatops-bot/rules/rules.yaml`. Do not invent queries.
- Call `generate_query` once (discard output), then `execute_query` with the verbatim kql from rules.yaml. No retries.
- Check `runbook.allowed_question_categories` before executing — block if the category is not listed.
- Write one JSON audit log line to `runbook.audit_log_path` (success or failure).
- Render the response by literal substitution into `templates/output-report.md`. No commentary outside the template.
- NEVER call any write or deploy tool. `read_only_mode: true` is absolute.
