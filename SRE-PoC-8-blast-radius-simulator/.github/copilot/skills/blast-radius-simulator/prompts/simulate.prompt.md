---
mode: agent
agent: blast-radius-simulator
---

Simulate the blast radius for ARM template deployment using scope `${input:scope:prod}`.

Strict requirements:
- Load `runbooks/<scope>.yaml` and resolve `template_path`, `risk_score_weights`, and `deploy_strategy_recommendations`.
- Read `skills/blast-radius-simulator/rules/rules.yaml` verbatim. Do not invent rules or KQL.
- For every rule (R001–R005): call `validate_query` then `execute_query`. No retries on failure.
- R004 uses `AuthorizationResources` table — emit `STATUS=SKIPPED REASON=authorizationresources-unavailable` if unavailable and continue.
- Compute `risk_score = sum(category_weight × affected_resource_count)`. Integer.
- Look up `recommended_strategy` from `deploy_strategy_recommendations` thresholds. Pure lookup.
- Render the report by literal substitution into `templates/output-report.md`.
- Write rendered report to `exports/blast-radius-<scope>-latest.md`.
- MUST NOT call `create_template_deployment`. MUST NOT call `get_arm_template_deployment_status`.
- Output ONLY the rendered report. No commentary.
