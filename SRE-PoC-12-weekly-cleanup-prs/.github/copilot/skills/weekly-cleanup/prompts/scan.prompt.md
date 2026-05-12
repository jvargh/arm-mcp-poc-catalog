---
mode: agent
agent: weekly-cleanup
---

Run the **weekly-cleanup** skill in `scan` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/weekly-cleanup/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `execute_query` directly (no `validate_query` step). No retries on failure.
- R002 uses the `resourcechanges` table — if unavailable, emit `STATUS=SKIPPED REASON=resourcechanges-unavailable` and continue.
- The agent will NEVER deploy. `create_template_deployment` MUST NOT be called.
- Sort findings: category group order (orphaned → drift → compliance), then estimated savings descending; ties by resource_id ascending.
- Render the scan report by literal substitution into `templates/output-report.md`.
- Compose proposed PR content by literal substitution into `templates/output-pr-content.md`.
- Write the rendered PR markdown to `exports/proposed-pr/{{run_id}}.md`. Do NOT call `create_template_deployment`.
- Output ONLY the rendered scan report and one final line confirming the PR markdown path. No commentary.
