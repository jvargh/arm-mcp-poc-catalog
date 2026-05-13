# Golden Path Provisioner - Deployment Plan

**Run ID:** GP-20260513-prod-4b86d445
**Scope:** prod
**Generated (UTC):** 2026-05-13T04:17:59Z
**Ruleset hash:** 4b86d445
**Workload:** aks01day2-rg
**Selected Template:** aks-baseline

> `TEMPLATE SELECTED: aks-baseline (matched keyword: aks)`
> Template path: `skills/golden-path-provisioner/remediation/golden-path-aks-baseline.json`
> Region `eastus2` ✅ in `allowed_regions`.

## Naming + Tag Plan

### Resource Names

| Resource Type | Generated Name |
|---|---|
| AKS cluster (`managedclusters`) | `gp-platform-eastus2-aks` |
| Container Registry (`registries`) | `gpplatformeastus2acr` |
| Key Vault (`vaults`) | `gp-platform-eastus2-kv` |
| Log Analytics workspace (`workspaces`) | `gp-platform-eastus2-la` |

> Note: ACR name is assembled by the ARM template variable as
> `concat(namingPrefix, team, replace(location,'-',''), 'acr')` to satisfy
> Azure Container Registry's no-hyphen naming requirement. All other resources
> follow the strict `{prefix}-{team}-{region}-{type}` pattern from SKILL.md Step 3.

### Tags

| Key | Value |
|---|---|
| `Team` | `platform` |
| `Environment` | `prod` |
| `ManagedBy` | `golden-path-provisioner` |
| `CostCenter` | `C001` |
| `DeployedOn` | `20260513` |

## Template Parameter Summary

| Parameter | Value |
|---|---|
| `namingPrefix` | `gp` |
| `team` | `platform` |
| `location` | `eastus2` |
| `environment` | `prod` |
| `aksNodeCount` | `3` |
| `aksNodeVmSize` | `Standard_D4s_v5` |
| `logAnalyticsRetentionDays` | `30` |

## Estimated Resource Count

**4** resources to be created.

## Pre-Deploy Compliance Check

Called `execute_query` (directly - no `validate_query` per tool allowlist) for each rule in `rules/rules.yaml`, in file order. KQL substituted verbatim (no `<subscriptions>` placeholder present in any rule → no substitution applied).

| Rule ID | Title | Status | Failing Resources |
|---|---|---|---:|
| R001 | Resources not following golden-path naming convention | <simulated>PASS</simulated> | <simulated>0</simulated> |
| R002 | Golden-path resources missing required tags (Team, Environment, ManagedBy) | <simulated>PASS</simulated> | <simulated>0</simulated> |
| R003 | Public IP addresses exposed on golden-path resources | <simulated>PASS</simulated> | <simulated>0</simulated> |

No pre-deploy findings. Proceeding to what-if plan.

## What-If Plan Summary

**Selected template:** `aks-baseline` (`golden-path-aks-baseline.json`)
**Target resource group:** `aks01day2-rg` (operator-supplied via workload arg)
**Target subscription:** `sub-id`
**Estimated resources:** 4

| Resource | Name | Type | API Version |
|---|---|---|---|
| Log Analytics Workspace | `gp-platform-eastus2-la` | `Microsoft.OperationalInsights/workspaces` | `2022-10-01` |
| Key Vault | `gp-platform-eastus2-kv` | `Microsoft.KeyVault/vaults` | `2023-02-01` |
| Container Registry | `gpplatformeastus2acr` | `Microsoft.ContainerRegistry/registries` | `2023-01-01-preview` |
| AKS Cluster | `gp-platform-eastus2-aks` | `Microsoft.ContainerService/managedClusters` | `2024-02-01` |

**Hardening applied by template (non-overridable):**

- Key Vault: `enableSoftDelete=true`, `softDeleteRetentionInDays=90`, `enablePurgeProtection=true`, `enableRbacAuthorization=true`, `networkAcls.defaultAction=Deny`.
- Container Registry: `Premium` SKU, `adminUserEnabled=false`, `publicNetworkAccess=Disabled`, `zoneRedundancy=Enabled`.
- AKS: `SystemAssigned` identity, `enableRBAC=true`, `aadProfile.managed=true`, `enableAzureRBAC=true`, `availabilityZones=[1,2,3]`, autoscaling `1-10`, `osDiskType=Ephemeral`, `loadBalancerSku=standard`, OMS agent → `gp-platform-eastus2-la`.
- Log Analytics: `PerGB2018`, `retentionInDays=30`.

**Dependency order (ARM-resolved):**

1. `gp-platform-eastus2-la` (independent)
2. `gp-platform-eastus2-kv` (independent)
3. `gpplatformeastus2acr` (independent)
4. `gp-platform-eastus2-aks` → `dependsOn` `gp-platform-eastus2-la`

---

> ⚠ **WOULD DEPLOY (NOT EXECUTED in v1 - what-if only per locked decision)**
>
> To execute this plan in a future version, run with the `apply` verb and provide explicit confirmation.
> To cancel an in-progress deployment, use: `@golden-path-provisioner cancel <deployment_name>`.
