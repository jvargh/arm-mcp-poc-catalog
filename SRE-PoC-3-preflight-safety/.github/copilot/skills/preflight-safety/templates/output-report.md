# Pre-flight Deployment Safety Check — Deploy Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Decision:** **{{decision}}**

## Preflight Results (summary)

| Rule ID | Title | Severity | Status | Failing Resources | Remediation Hint |
|---|---|---|---|---:|---|
{{preflight_results_table}}

## Would Deploy (NOT EXECUTED in v1)

> ⚠️ `create_template_deployment` is **not invoked** in v1. This section shows what
> **would** be deployed if this PoC were upgraded to v2 with live deploys enabled.

| Field | Value |
|---|---|
| Template file | `{{template_file}}` |
| Parameters file | `{{parameters_file}}` |
| Target resource group | `{{deployment_target_rg}}` |
| Scope | `{{scope}}` |
| Deploy mode | Incremental |

To perform the actual deployment, run the ARM template manually:

```powershell
az deployment group create \
  --resource-group {{deployment_target_rg}} \
  --template-file {{template_file}} \
  --parameters @{{parameters_file}} \
  --mode Incremental
```

---
*Force-deploy audit entry written to `exports/audit-{{run_id}}.md` (if force path was taken).*
