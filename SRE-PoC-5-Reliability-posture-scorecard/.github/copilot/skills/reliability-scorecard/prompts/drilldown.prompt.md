---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `drilldown` mode for workload `${input:workload}` in scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/reliability-scorecard/rules/rules.yaml`.
- Re-execute only the rules that flag this workload. Do not run rules that produced no hit on the last scorecard run.
- Render via literal substitution into `templates/output-drilldown.md`.
- Include the verbatim ARG query and up to 25 resource IDs per failed rule.
- Output ONLY the rendered drilldown. No commentary.
