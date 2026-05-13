---
mode: agent
agent: tag-hygiene-czar
---

Run the **tag-hygiene-czar** skill with verb `scan` for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/tag-hygiene-czar/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Render the report by literal substitution into `templates/output-report.md`.
- Write the **full** rendered report to `exports/tag-report-<scope>-latest.md` (always complete).
- Chat output follows the deterministic preview rule in SKILL.md Step 4 item 4
  (truncate `noncompliant_table` to 50 rows in chat when total > 50; on-disk file is unaffected).
- End chat output with the literal line `SCAN COMPLETE: full report written to exports/tag-report-<scope>-latest.md`. No commentary.
- Do NOT call `create_template_deployment` — this verb is strictly read-only.
