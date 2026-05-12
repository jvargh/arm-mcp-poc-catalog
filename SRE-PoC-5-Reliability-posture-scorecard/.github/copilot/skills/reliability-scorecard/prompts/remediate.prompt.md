---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `remediate` mode for scope `${input:scope:prod}`.

Strict requirements:
- Identify the top 3 gap rule_ids by `(weight * failing_resource_count)` from the most recent scorecard run.
- For each pick that has a `remediation_template` in `rules.yaml`, propose a deployment using the template at `remediation/<remediation_template>`.
- **Stop and ask the user to confirm each rule_id before deploying.** No auto-deploy.
- On confirmation, call `create_template_deployment` (mode `Incremental`) per failing resource, parameterizing from the resource list.
- Render via `templates/output-remediation.md`. No commentary.
