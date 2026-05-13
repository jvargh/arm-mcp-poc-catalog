# FinOps Right-sizer Report

**Run ID:** RSIZE-20260513-prod-8900fdf8
**Scope:** prod
**Generated (UTC):** 2026-05-13T05:48:26Z
**Ruleset hash:** 8900fdf8

## Summary

| Metric | Value |
|---|---|
| Rules total | 4 |
| Rules evaluated | 3 |
| Rules skipped | 1 |
| Rules invalid | 0 |
| Right-size candidates | 4 |
| Est. total monthly savings | $0 |

## Right-size Candidates

Sorted descending by estimated monthly savings; ties by resource name ascending.

| Rank | Resource | RG | Current SKU | Target SKU | Est. $/mo saved | Rule |
|---:|---|---|---|---|---:|---|
| 1 | rhelvm01 | vm-rg | Standard_DC2s_v3 | Standard_D4s_v5 | UNKNOWN | R003 |
| 2 | susevm01 | vm-rg | Standard_DC2s_v3 | Standard_D4s_v5 | UNKNOWN | R003 |
| 3 | vm01 | servicegroups-rg | Standard_E2s_v3 | Standard_D4s_v5 | UNKNOWN | R003 |
| 4 | winvm01 | vm-rg | Standard_E2s_v3 | Standard_D4s_v5 | UNKNOWN | R003 |

## Rules Summary

| Rule ID | Title | Weight | Candidates | Status |
|---|---|---:|---:|---|
| R001 | Oversized VMs in dev/test environments | 10 | 0 | OK |
| R002 | VMs running Standard_D8s_v5 in non-production environments | 8 | 0 | OK |
| R003 | Idle VMs in deallocated or stopped state | 12 | 4 | OK |
| R004 | VMs with active Advisor right-size recommendations | 6 | 0 | SKIPPED (R004-data-unavailable) |

## Opt-in Checklist (for `resize` verb)

To resize, issue `@finops-rightsizer resize scope <scope>` and confirm from this list:

```
[ ] rhelvm01 (Standard_DC2s_v3 → Standard_D4s_v5, est. UNKNOWN/mo saved)
[ ] susevm01 (Standard_DC2s_v3 → Standard_D4s_v5, est. UNKNOWN/mo saved)
[ ] vm01 (Standard_E2s_v3 → Standard_D4s_v5, est. UNKNOWN/mo saved)
[ ] winvm01 (Standard_E2s_v3 → Standard_D4s_v5, est. UNKNOWN/mo saved)
```

---
*Run `@finops-rightsizer drilldown <resource>` for per-resource detail.*
*Run `@finops-rightsizer resize scope <scope>` and confirm each resource to deploy.*
