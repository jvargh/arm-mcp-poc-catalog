---
mode: agent
agent: slo-deployment-gate
---

Run the **slo-deployment-gate** skill in `deploy` mode for scope `${input:scope:prod}`, service `${input:service}`, and template `${input:template}`.

Strict requirements:
- Run the full `gate` mode flow first (all three rules, budget evaluation, incident check).
- If `DECISION=BLOCK` or `DECISION=BLOCK (TIMEOUT)`: render `output-gate-result.md` with the BLOCK decision and STOP. Do not simulate a deployment.
- If `DECISION=ALLOW` or `DECISION=ALLOW (BYPASS)`:
  - **MUST NOT actually call `create_template_deployment` in v1.** What-if only.
  - Render `templates/output-report.md` with the ALLOW decision and the would-deploy notice.
  - The `{{would_deploy_command}}` block MUST show the exact `create_template_deployment` invocation that *would* be made.
  - Write rendered report to `exports/report-<run_id>.md`.
  - Output ONLY the rendered report. No commentary.
- Bypass: accepted only with a `CR-XXXXXX` or `INC-XXXXXX` reference. Write bypass audit line to `exports/bypass-audit.jsonl`.
- If ALLOW (BYPASS): prepend the bypass reference in `{{bypass_ref}}` section.
