# Workload Drilldown — mc_aks02day2-rg_aks02day2_eastus2

**Run ID:** RPS-20260512-prod-dbef14c0
**Scope:** prod
**Generated (UTC):** 2026-05-12T04:14:18Z
**Score:** 76 / 100
**Failed rule count:** 3

## Failed Checks (descending by weight)

### R010 — NSG rules allowing inbound from Internet/Any

- Severity: **critical** | Weight: **14** | Failing resources in this workload: **1**

ARG query (verbatim from `rules.yaml`):

```kusto
Resources
| where type =~ 'microsoft.network/networksecuritygroups'
| mv-expand rule = properties.securityRules
| where tostring(rule.properties.direction) =~ 'Inbound'
      and tostring(rule.properties.access) =~ 'Allow'
      and tostring(rule.properties.sourceAddressPrefix) in ('*','0.0.0.0/0','Internet')
| project id, name, resourceGroup, subscriptionId, location, ruleName=tostring(rule.name)
```

Resources listed (first 25 of 1):

- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-agentpool-73197682-nsg`

### R004 — Public IPs assigned (potential exposure)

- Severity: **medium** | Weight: **6** | Failing resources in this workload: **2**

ARG query (verbatim from `rules.yaml`):

```kusto
Resources
| where type =~ 'microsoft.network/publicipaddresses'
| where isnotempty(tostring(properties.ipAddress))
| project id, name, resourceGroup, subscriptionId, location, ip=tostring(properties.ipAddress)
```

Resources listed (first 25 of 2):

- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/publicIPAddresses/bb8ad3d9-6bea-4d6d-aedd-f5340b3c7f07`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/publicIPAddresses/kubernetes-a95a544970a56496b8148bc88ee07f99`

### R012 — Resources without owner / cost-center tags (operational hygiene)

- Severity: **low** | Weight: **4** | Failing resources in this workload: **12**

ARG query (verbatim from `rules.yaml`):

```kusto
Resources
| where type !startswith 'microsoft.insights/'
| where isnull(tags.Owner) or isnull(tags.CostCenter)
| project id, name, resourceGroup, subscriptionId, location, type
```

Resources listed (first 25 of 12):

- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-syspool-27568677-vmss`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-userpool-32075967-vmss`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks02day2-agentpool`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/loadBalancers/kubernetes`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-agentpool-73197682-nsg`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-appgateway-73197682-nsg`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-virtualkubelet-73197682-nsg`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-vnet-73197682-aks-appgateway-nsg-eastus2`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/networkSecurityGroups/aks-vnet-73197682-aks-virtualkubelet-nsg-eastus2`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/publicIPAddresses/bb8ad3d9-6bea-4d6d-aedd-f5340b3c7f07`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/mc_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/publicIPAddresses/kubernetes-a95a544970a56496b8148bc88ee07f99`
- `/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/MC_aks02day2-rg_aks02day2_eastus2/providers/Microsoft.Network/virtualNetworks/aks-vnet-73197682`

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query to see all.
- To remediate, run `@scorecard remediate` and confirm per rule_id when prompted.

