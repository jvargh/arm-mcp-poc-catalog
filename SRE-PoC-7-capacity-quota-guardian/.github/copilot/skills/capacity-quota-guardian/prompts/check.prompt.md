---
mode: agent
agent: capacity-quota-guardian
---

Run the **capacity-quota-guardian** skill in `check` mode for scope `${input:scope:prod}`.

Strict requirements:
- Load `runbooks/${input:scope:prod}.yaml` (substituting from the sibling `.values.yaml`).
- Load `skills/capacity-quota-guardian/rules/rules.yaml` and compute `run_id`.
- For every rule: call `generate_query` with the rule KQL + scope context, then `execute_query`. No retries.
- Compute `usage_pct = (current_count / limit) * 100` using limits from `quota_limits` in the runbook.
- Sort all rows **descending by `usage_pct`**.
- For every row with `usage_pct > headroom_threshold_pct`, include an alternate region suggestion from the runbook.
- Render the report by literal substitution into `templates/output-report.md`.
- Output ONLY the rendered report. No commentary.
