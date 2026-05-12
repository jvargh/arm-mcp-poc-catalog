---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `remediate` mode for scope `${input:scope:prod}`.

Strict requirements:
- Source the top 3 gaps from the most recent scorecard snapshot at
  `exports/_run/{run_id}/manifest.json` (re-run a scorecard pass if no snapshot exists
  for the current `(scope, ruleset_hash8)`).
- Rank rule_ids by `(weight * failing_resource_count)` where `failing_resource_count`
  is a **distinct `id` count**. Ties broken by ascending `rule_id`.
- For each pick that has a `remediation_template` in `rules.yaml`, propose a deployment
  using the template at `remediation/<remediation_template>`. If null, surface
  "no template available for <rule_id>" and skip.
- **Stop and ask the user to confirm each rule_id before deploying.** No auto-deploy.
- On confirmation, call `create_template_deployment` (mode `Incremental`) per failing
  resource, parameterizing from the cached resource list.
- Render via `templates/output-remediation.md`.
- Persist to `exports/remediation-{run_id}.md`.
- Output ONLY the rendered summary. No commentary.
