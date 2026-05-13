---
mode: agent
agent: slo-deployment-gate
---

Run the **slo-deployment-gate** skill in `gate` mode for scope `${input:scope:prod}` and service `${input:service}`.

Strict requirements:
- Load `runbooks/<scope>.yaml` (with `.values.yaml` substitution). Abort if missing.
- Evaluate all three rules from `skills/slo-deployment-gate/rules/rules.yaml` in order.
- Do NOT call `validate_query`. Use `generate_query` → `execute_query` directly.
- Read `budget_pct` from `slo_targets.<service>.simulated_budget_pct` in the runbook (v1).
- Gate decision: ALLOW if `budget_pct > budget_threshold_pct`, BLOCK if `budget_pct ≤ budget_threshold_pct`.
- Timeout (no response within `approval_timeout_minutes`) → auto-deny (BLOCK).
- Render the result by literal substitution into `templates/output-gate-result.md`.
- Write the rendered gate result to `exports/gate-<run_id>.md`.
- Output ONLY the rendered gate result. No commentary.
- If BLOCK: emit the decision and stop. Do not proceed with any deployment step.
- Bypass: accepted only with a `CR-XXXXXX` or `INC-XXXXXX` reference. Write bypass audit line to `exports/bypass-audit.jsonl`.
