---
mode: agent
agent: finops-rightsizer
---

Run the **finops-rightsizer** skill in `resize` mode for scope `${input:scope:prod}`.

Strict requirements:
- Load candidates from the most recent `scan` run (re-execute scan if not in context).
- Present the per-resource opt-in checklist in this **exact** format for each candidate,
  sorted descending by `est_monthly_savings`, ties by ascending `resource_name`:
  ```
  [ ] resource_name (current_sku → target_sku, est. $X/mo saved)
  ```
- **Stop and wait for the user to tick boxes.** Do NOT proceed without explicit per-resource opt-in.
- After the user provides their selection, perform the Confirm Gate (SKILL.md Step 5):
  1. Check `freeze_active` and `freeze_windows` in the runbook. Abort if freeze is active.
  2. Present a final summary of selected resources and ask: `Confirm resize of N resource(s)? Type YES to proceed.`
  3. Only on exact `YES` response: proceed to deployments.
- For each confirmed resource: call `create_template_deployment` with `remediation/resize-vm.json`,
  mode `Incremental`, deployment name `rsize-{resource_name}-{YYYYMMDD}`.
- Poll `get_arm_template_deployment_status` after each deployment.
- Render via `templates/output-remediation.md`. No commentary.
