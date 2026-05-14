# SLO Deployment Gate Result

**Run ID:** SLO-20260513-prod-3dad3464
**Scope:** prod
**Service:** payments-api
**Generated (UTC):** 2026-05-13T15:00:23Z
**Ruleset hash:** 3dad3464

## SLO Budget Evaluation

| Field | Value |
|---|---|
| Service | payments-api |
| SLO Error Budget | 72.4% |
| Budget Threshold | 50.0% |
| Window | 30 days |
| Budget Source | runbook `slo_targets` (v1 simulated) |
| Workspace Resource ID | null |

> ℹ️ `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics WORKSPACE=null`
> ARG located the App Insights workspace but cannot read live metric values.
> Investigate the workspace directly for live SLO data.

## Rule Evaluation

| Rule ID | Title | Status | Result |
|---|---|---|---|
| R001 | Resolve service to App Insights component by tag | NO_MATCH | 0 resources tagged `slo_service: payments-api` in subscription sub-id |
| R002 | Check error budget status via workspace metadata (properties) | OUT_OF_SCOPE | 0 rows; `slo_budget_pct` tag not present — `REASON=arg-cannot-read-metrics` |
| R003 | Validate no active incidents on target service (resource health) | SKIPPED | `REASON=resourcechanges-unavailable` — `resourceHealthResources` table not enabled |



## Decision

**Decision:** BLOCK (fail-closed: no workspace tagged `slo_service: payments-api` — cannot evaluate SLO budget)



---
*Run `@slo-deployment-gate deploy scope prod service payments-api template <path>` to proceed with deployment on ALLOW.*
*Run `@slo-deployment-gate status scope prod service payments-api` to retrieve this result.*
