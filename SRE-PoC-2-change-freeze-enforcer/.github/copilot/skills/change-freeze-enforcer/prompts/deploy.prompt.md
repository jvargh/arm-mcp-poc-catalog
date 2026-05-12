---
mode: agent
agent: change-freeze-enforcer
---

Run the **change-freeze-enforcer** skill with verb `deploy` for scope `${input:scope:prod}`.

Required inputs:
- `template_name`: name of the ARM template you intend to deploy (e.g. `my-app-infra.json`)
- `target_scope`: target Azure resource group (e.g. `payments-prod-rg`)

Strict requirements:
- Load freeze schedule from `runbooks/<scope>.yaml` + values file.
- Evaluate all 4 rules from `skills/change-freeze-enforcer/rules/rules.yaml` in order.
- For every rule, call `validate_query` then `execute_query`. No retries on failure.
- Perform the freeze check: resolve scope (R001), time comparison (R002), scope overlap (R003), exemption tag (R004).
- If PASS: render `templates/output-report.md` with simulated deploy outcome. Write to `exports/`.
- If BLOCK: render `templates/output-blocked.md`. Write to `exports/`. Do NOT proceed.
- Do NOT call `create_template_deployment` in v1 under any circumstances.
- Output ONLY the rendered decision report. No commentary.
