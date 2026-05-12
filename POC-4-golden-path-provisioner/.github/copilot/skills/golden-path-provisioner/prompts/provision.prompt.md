---
mode: agent
agent: golden-path-provisioner
---

Run the **golden-path-provisioner** skill in `provision` mode for scope `${input:scope:prod}`.

Workload description: `${input:workload}`
Team: `${input:team}`
Region: `${input:region}`

Strict requirements:
- Load `runbooks/<scope>.yaml` and values file. Abort if values file missing.
- Select template from `golden_path_catalog` by keyword match — first match wins. No manual override.
- Generate all resource names using `{naming_prefix}-{team}-{region}-{resource-type}` pattern. No deviation.
- Run pre-deploy compliance check: call `execute_query` (NOT `validate_query`) for each rule in `rules/rules.yaml`.
- Render the what-if plan via `templates/output-report.md` by literal `{{placeholder}}` substitution only.
- **Do NOT call `create_template_deployment`.** Emit the rendered plan and stop with:
  `WOULD DEPLOY (NOT EXECUTED in v1 — what-if only per locked decision)`.
- Output ONLY the rendered report and the NOT-EXECUTED notice. No commentary.
