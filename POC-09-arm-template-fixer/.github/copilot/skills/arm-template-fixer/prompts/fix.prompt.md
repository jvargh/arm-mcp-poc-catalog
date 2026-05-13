---
mode: agent
agent: arm-template-fixer
---

Run the **arm-template-fixer** skill in `fix` mode for template `${input:template}` using scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/arm-template-fixer/rules/rules.yaml` exactly. Do not invent fix patterns.
- **DO NOT call `create_template_deployment` in v1.** Simulate the deploy → error → fix loop using fabricated error responses. Document each call that *would* be made.
- Compute `run_id` as `FIX-{YYYYMMDD}-{template_filename}-{sha256(rules.yaml)[:8]}`. No model judgment.
- Apply fixes in deterministic order: R001 (dependency) → R002 (SKU) → R003 (quota) → R004 (conflict). R005 is a pre-check guard.
- Emit a unified diff after every fix attempt.
- Halt immediately if a destructive change pattern is detected (see `runbooks/prod.yaml → destructive_change_types`).
- Do not exceed `max_retries` (from runbook, default 3).
- Render the fix report by literal substitution into `templates/output-report.md` on success, or `templates/output-status.md` on halt/exhaustion.
- Append one row to `exports/fix-run-log.csv`. Output ONLY the rendered report and one final line confirming the CSV append. No commentary.
