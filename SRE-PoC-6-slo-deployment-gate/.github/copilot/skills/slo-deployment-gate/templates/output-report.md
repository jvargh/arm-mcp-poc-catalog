# SLO Deployment Gate — Deploy Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Service:** {{service}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Gate Summary

| Field | Value |
|---|---|
| Service | {{service}} |
| SLO Error Budget | {{budget_pct}}% |
| Budget Threshold | {{budget_threshold_pct}}% |
| Window | {{window_days}} days |
| Decision | **{{decision}}** |
| Workspace Resource ID | {{workspace_resource_id}} |

> ℹ️ `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics WORKSPACE={{workspace_resource_id}}`
> Live SLO metric values are not queryable via ARG. The budget percentage above is sourced
> from the runbook `slo_targets` block (v1 simulated value). For production use, wire in
> an Azure Monitor query or Prometheus scrape targeting this workspace.

{{incident_warning}}

## Would-Deploy Notice

> ⚠️ **v1 — What-if only. No actual deployment was issued.**
> The gate decision is **{{decision}}**. The following deployment *would* be submitted
> if this PoC were wired to a live deploy pipeline:

```
create_template_deployment(
  template_path = "{{template_path}}",
  scope         = "{{scope}}",
  service       = "{{service}}",
  mode          = "Incremental"
)
```

**{{would_deploy_command}}**

{{bypass_ref}}

---
*Gate result archived at `exports/gate-{{run_id}}.md`. Run `@slo-deployment-gate status scope {{scope}} service {{service}}` to retrieve it.*
