---
mode: agent
agent: estate-cartographer
---

Run the **estate-cartographer** skill in `map` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/estate-cartographer/rules/rules.yaml` exactly. Do not invent rules.
- For every rule, call `execute_query` directly. Do NOT call `validate_query` (not in tool allowlist).
- Use `$skipToken` paging for any query returning >1000 rows; accumulate all pages before rendering.
- Sort: subscriptions alphabetically, RGs alphabetically within sub, resources by type then name.
- Derive Mermaid node IDs deterministically: `sha256(resourceId_lower)[:8]`.
- Render the report by literal substitution into `templates/output-report.md`.
- Write output to `exports/map-<scope>-latest.md`.
- Output ONLY the rendered report. No commentary.
