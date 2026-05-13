# IaC Drift Report

**Run ID:** DRIFT-20260513-prod-66fb84d2
**Scope:** prod
**Generated (UTC):** 2026-05-13T04:45:40Z
**Ruleset hash:** 66fb84d2
**Template:** `infra/main.json`

## Summary

| Metric | Value |
|---|---|
| Template resources checked | 7 |
| Resources with drift | 0 |
| Resources missing in live | 7 |
| Resources in sync | 0 |

## Drift Summary

| Resource Name | Type | Resource Group | Rule | Drifted Fields | Status |
|---|---|---|---|---|---|
| aks01day2-nsg | microsoft.network/networksecuritygroups | (template-only) | R001 | — | MISSING_IN_LIVE |
| apptesting-nsg | microsoft.network/networksecuritygroups | (template-only) | R001 | — | MISSING_IN_LIVE |
| apptest-vm01 | microsoft.compute/virtualmachines | (template-only) | R002 | — | MISSING_IN_LIVE |
| apptestingsa01 | microsoft.storage/storageaccounts | (template-only) | R003 | — | MISSING_IN_LIVE |
| aks01day2sa01 | microsoft.storage/storageaccounts | (template-only) | R003 | — | MISSING_IN_LIVE |
| apptesting-kv01 | microsoft.keyvault/vaults | (template-only) | R004 | — | MISSING_IN_LIVE |
| az-foundry-kv01 | microsoft.keyvault/vaults | (template-only) | R004 | — | MISSING_IN_LIVE |

## JSON Patch (RFC 6902)

```json
[]
```

---
*Run `@iac-drift-detector drilldown <resource_id>` for per-resource property detail.*
