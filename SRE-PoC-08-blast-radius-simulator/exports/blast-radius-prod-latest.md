# Blast-Radius Simulation Report

**Run ID:** BLAST-20260514-prod-d916b5fb  
**Scope:** prod  
**Template:** templates/sample-webapp.json  
**Generated (UTC):** 2026-05-14T01:40:29Z  
**Ruleset hash:** d916b5fb

## Template Summary

| Metric | Value |
| --- | --- |
| Resources in template | 6 |
| Resource types | Microsoft.ManagedIdentity/userAssignedIdentities, Microsoft.Network/virtualNetworks, Microsoft.KeyVault/vaults, Microsoft.Web/serverfarms, Microsoft.Web/sites, Microsoft.Authorization/roleAssignments |
| Estimated change type | add-only |

## Impact by Category (descending by category risk)

| Rule ID | Category | Weight | Affected Resources | Category Risk | Status |
| --- | --- | --- | --- | --- | --- |
| R004 | rbac | 9 | 167 | 1503 | OK |
| R005 | dependency\_edge | 8 | 35 | 280 | OK |
| R002 | identity\_rotation | 10 | 18 | 180 | OK |
| R001 | dns\_endpoint | 15 | 4 | 60 | OK |
| R003 | cert\_regen | 12 | 2 | 24 | OK |

## Dependency Edges

*   aks-agentpool-26158496-nsg → microsoft.network/networksecuritygroups
*   aks-agentpool-73197682-nsg → microsoft.network/networksecuritygroups
*   aks-agentpool-96834568-nsg → microsoft.network/networksecuritygroups
*   aks-appgateway-73197682-nsg → microsoft.network/networksecuritygroups
*   aks-virtualkubelet-73197682-nsg → microsoft.network/networksecuritygroups
*   aks-vnet-26158496-aks-appgateway-nsg-eastus2 → microsoft.network/networksecuritygroups
*   aks-vnet-26158496-aks-virtualkubelet-nsg-eastus2 → microsoft.network/networksecuritygroups
*   aks-vnet-73197682-aks-appgateway-nsg-eastus2 → microsoft.network/networksecuritygroups
*   aks-vnet-73197682-aks-virtualkubelet-nsg-eastus2 → microsoft.network/networksecuritygroups
*   aks-vnet-96834568-aks-appgateway-nsg-centralus → microsoft.network/networksecuritygroups
*   aks-vnet-96834568-aks-virtualkubelet-nsg-centralus → microsoft.network/networksecuritygroups
*   rhelvm01-nsg → microsoft.network/networksecuritygroups
*   rhelvm01-vnet-default-nsg-eastus → microsoft.network/networksecuritygroups
*   rhelvm01nsg241 → microsoft.network/networksecuritygroups
*   rhelvm02-nsg → microsoft.network/networksecuritygroups
*   rhelvm02-vnet-default-nsg-eastus2 → microsoft.network/networksecuritygroups
*   susevm01-nsg → microsoft.network/networksecuritygroups
*   vm01-nsg → microsoft.network/networksecuritygroups
*   vnet-centralus-snet-centralus-1-nsg-centralus → microsoft.network/networksecuritygroups
*   vnet-y7njcffivri2q-snet-appservice-nsg-eastus2 → microsoft.network/networksecuritygroups
*   vnet-y7njcffivri2q-snet-sql-pe-nsg-eastus2 → microsoft.network/networksecuritygroups
*   winvm01-nsg → microsoft.network/networksecuritygroups
*   workers-sg → microsoft.network/networksecuritygroups
*   privatelink.database.windows.net → microsoft.network/privatednszones
*   privatelink.datafactory.azure.net → microsoft.network/privatednszones
*   pe-sql-y7njcffivri2q → microsoft.network/privateendpoints
*   pe-to-shir → microsoft.network/privateendpoints
*   aks-vnet-26158496 → microsoft.network/virtualnetworks
*   aks-vnet-73197682 → microsoft.network/virtualnetworks
*   aks-vnet-96834568 → microsoft.network/virtualnetworks
*   rhelvm01-vnet → microsoft.network/virtualnetworks
*   rhelvm02-vnet → microsoft.network/virtualnetworks
*   vnet-centralus → microsoft.network/virtualnetworks
*   vnet-y7njcffivri2q → microsoft.network/virtualnetworks
*   workers-vnet → microsoft.network/virtualnetworks


## Risk Assessment

| Metric | Value |
| --- | --- |
| Total risk score | 2047 |
| Risk level | high |
| Recommended strategy | staggered |

---

_Run_ `_@blast-radius-simulator drilldown <category>_` _for per-category detail (e.g._ `_drilldown dns_endpoint_`_)._
