---
mode: agent
agent: auto-rollback
---

Watch the ARM deployment `${input:deployment_name}` for scope `${input:scope:prod}`.

Run the full **auto-rollback** skill in `watch` mode:

Strict requirements:
- Load `runbooks/<scope>.yaml` + `<scope>.values.yaml`. Abort if values file is missing.
- Poll `get_arm_template_deployment_status` until terminal state or `health_gate_timeout_seconds` elapses.
- Write one timeline line per poll in canonical format: `[timestamp_utc] ACTION: description (status)`.
- On `Succeeded`: run health gate (R001 → R002 → R003 → R004) via `execute_query` (literal KQL from rules.yaml - no `generate_query`, no `validate_query`).
- On health gate PASS: emit `overall_status=SUCCEEDED`. Render and stop.
- On health gate FAIL, deployment FAIL, or timeout: trigger cancel flow (Step 5 in SKILL.md) with user confirmation, then rollback (Step 6).
- Cap rollback attempts at `max_rollback_attempts`. Halt with `STATUS=HALTED` on exhaustion.
- v1: `create_template_deployment` is NOT invoked - mark simulated steps with `[SIMULATED]`.
- Render output via `templates/output-report.md` and `templates/output-timeline.md`.
- Write report to `exports/rollback-<run_id>.md`. Output ONLY rendered content.
