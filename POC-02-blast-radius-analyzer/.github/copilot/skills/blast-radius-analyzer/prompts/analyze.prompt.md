---
mode: agent
agent: blast-radius-analyzer
---

Run the **blast-radius-analyzer** skill in `analyze` mode for scope `${input:scope:prod}`.

Strict requirements:
- Read `template_path` from `runbooks/<scope>.yaml` (resolved via values file). Abort if missing.
- Parse the ARM template at that path and extract all `resources[]` entries before calling any MCP tool.
- Cross-reference every extracted resource against ARG using the per-resource queries in SKILL.md Step 3.
- For every supplemental rule (R001–R006), call `validate_query` then `execute_query`. No retries on failure.
- Render the report by literal substitution into `templates/output-report.md`.
- Sort the Change Risk Table: **descending by risk weight**, ties by resource name ascending.
- If R005 (`policyresources`) is unavailable, emit `STATUS=SKIPPED REASON=policyresources-unavailable` and continue.
- MUST NOT call `create_template_deployment` — what-if is rendered from ARG data only (v1 constraint).
- Output ONLY the rendered report. No commentary.
