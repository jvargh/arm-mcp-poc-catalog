---
mode: agent
agent: preflight-safety
---

Run the **preflight-safety** skill in `deploy` mode for scope `${input:scope:prod}`.

Template file: `${input:template_file}`
Parameters file: `${input:parameters_file}`

Strict requirements:
- Re-run the full preflight battery first (or confirm it passed earlier this session).
- **BLOCK the deployment** if any preflight rule returned FAIL and `force_deploy_flag` is false.
  Print: `DEPLOY BLOCKED — ${checks_fail} check(s) failed. Resolve the issues above and retry.`
- If `force_deploy_flag` is true: require the user to supply a written justification for
  overriding the failure(s). Do not proceed without it. Emit:
  `⚠️ AUDIT WARNING: force_deploy_flag=true overrides ${checks_fail} FAIL(s). Justification: <user text>`
  Write audit entry to `exports/audit-<run_id>.md`.
- **Do NOT call `create_template_deployment` in v1.** Instead, render a
  "Would deploy (NOT EXECUTED in v1)" section in `templates/output-report.md`.
- Output ONLY the rendered deploy report. No commentary.
