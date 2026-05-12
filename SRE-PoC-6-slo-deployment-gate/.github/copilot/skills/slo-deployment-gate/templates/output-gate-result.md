# SLO Deployment Gate Result

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Service:** {{service}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## SLO Budget Evaluation

| Field | Value |
|---|---|
| Service | {{service}} |
| SLO Error Budget | {{budget_pct}}% |
| Budget Threshold | {{budget_threshold_pct}}% |
| Window | {{window_days}} days |
| Budget Source | runbook `slo_targets` (v1 simulated) |
| Workspace Resource ID | {{workspace_resource_id}} |

> ℹ️ `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics WORKSPACE={{workspace_resource_id}}`
> ARG located the App Insights workspace but cannot read live metric values.
> Investigate the workspace directly for live SLO data.

## Rule Evaluation

| Rule ID | Title | Status | Result |
|---|---|---|---|
{{slo_status_row}}

{{incident_warning}}

## Decision

**Decision:** {{decision}}

{{bypass_ref}}

---
*Run `@slo-deployment-gate deploy scope {{scope}} service {{service}} template <path>` to proceed with deployment on ALLOW.*
*Run `@slo-deployment-gate status scope {{scope}} service {{service}}` to retrieve this result.*
