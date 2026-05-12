# Reliability Posture Scorecard

**Run ID:** RPS-20260512-prod-dbef14c0
**Scope:** prod
**Generated (UTC):** 2026-05-12T03:43:39Z
**Ruleset hash:** dbef14c0

## Summary

| Metric | Value |
|---|---|
| Rules total | 12 |
| Rules evaluated | 12 |
| Rules skipped | 0 |
| Rules invalid | 0 |
| Workloads scored | 8 |

## Bottom 10 Workloads by Score

| Rank | Workload | Score | Failed Rules | Top Gap |
|---:|---|---:|---:|---|
| 1 | mc_aks02day2-rg_aks02day2_eastus2 | 76 | 3 | R010 |
| 2 | aks01day2-rg | 77 | 3 | R009 |
| 3 | aks02day2-rg | 77 | 3 | R009 |
| 4 | aksnapday2-rg | 77 | 3 | R009 |
| 5 | az-foundry-rg | 78 | 3 | R002 |
| 6 | mc_aksnapday2-rg_aksnapday2_eastus2 | 90 | 2 | R004 |
| 7 | apicenter-rg | 96 | 1 | R012 |
| 8 | apptesting-rg | 96 | 1 | R012 |

## Failing Checks

| Rule ID | Title | Severity | Weight | Failing Resources |
|---|---|---|---:|---:|
| R010 | NSG rules allowing inbound from Internet/Any | critical | 14 | 1 |
| R009 | AKS node pools without availability zones | high | 11 | 5 |
| R002 | Storage accounts on LRS (no zone or geo redundancy) | high | 10 | 1 |
| R003 | Resources missing diagnostic settings | medium | 8 | 4 |
| R004 | Public IPs assigned (potential exposure) | medium | 6 | 3 |
| R012 | Resources without owner / cost-center tags (operational hygiene) | low | 4 | 61 |

## Top 3 Gaps

### 1. R012 — Resources without owner / cost-center tags (operational hygiene)

- Severity: **low** | Weight: **4** | Failing resources: **61** | Affected workloads: **8**
- Gap score (weight × failing): **244**
- Remediation template: `_(no template)_`
- Affected workloads: aks01day2-rg, aks02day2-rg, aksnapday2-rg, apicenter-rg, apptesting-rg, az-foundry-rg, mc_aks02day2-rg_aks02day2_eastus2, mc_aksnapday2-rg_aksnapday2_eastus2

### 2. R009 — AKS node pools without availability zones

- Severity: **high** | Weight: **11** | Failing resources: **5** | Affected workloads: **3**
- Gap score (weight × failing): **55**
- Remediation template: `_(no template)_`
- Affected workloads: aks01day2-rg, aks02day2-rg, aksnapday2-rg

### 3. R003 — Resources missing diagnostic settings

- Severity: **medium** | Weight: **8** | Failing resources: **4** | Affected workloads: **4**
- Gap score (weight × failing): **32**
- Remediation template: `enable-diagnostic-settings.json`
- Affected workloads: aks01day2-rg, aks02day2-rg, aksnapday2-rg, az-foundry-rg

---
*Run `@scorecard drilldown <workload>` for per-workload detail. Run `@scorecard remediate` to generate ARM patch templates for the top 3 gap types.*

