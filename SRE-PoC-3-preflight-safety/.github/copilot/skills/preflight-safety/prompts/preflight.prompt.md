---
mode: agent
agent: preflight-safety
---

Run the **preflight-safety** skill in `preflight` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/preflight-safety/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Evaluate checks in rule_id ascending order (R001 first). Do not reorder.
- Handle SKIPPED state for rules marked `skip_if_unavailable: true` — SKIP is non-fatal.
- Render the report by literal substitution into `templates/output-preflight-results.md`.
- Output ONLY the rendered report. No commentary.
