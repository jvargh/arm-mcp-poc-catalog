---
mode: agent
agent: change-freeze-enforcer
---

Run the **change-freeze-enforcer** skill with verb `override` for scope `${input:scope:prod}`.

> ⚠️ **Break-glass override.** Use only when a deployment is urgent and cannot wait for
> the freeze window to end. All override events are permanently audited.

Required inputs — ALL fields are mandatory for override:
- `template_name`: name of the ARM template you intend to deploy
- `target_scope`: target Azure resource group
- `cr_id`: change-request ID from your ITSM system (e.g. `CHG0012345`)
- `justification`: written justification for overriding the freeze window

Strict requirements:
- Load freeze schedule from `runbooks/<scope>.yaml` + values file.
- Evaluate all 4 rules from `skills/change-freeze-enforcer/rules/rules.yaml` in order.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Verify ALL `break_glass_required_fields` from runbook are present and non-empty. If any
  field is missing, abort immediately with the literal message:
  `ABORT: break-glass field '<field>' is required for override but was not supplied`.
- Perform the freeze check (R001–R004). Decision must be OVERRIDE_ALLOW.
- Render `templates/output-override.md` with audit log JSON line.
- Append audit log JSON line to `exports/override-audit.log` (create if missing).
- Write rendered report to `exports/override-<run_id>.md`.
- Do NOT call `create_template_deployment` in v1 under any circumstances.
- Output ONLY the rendered override report. No commentary.
