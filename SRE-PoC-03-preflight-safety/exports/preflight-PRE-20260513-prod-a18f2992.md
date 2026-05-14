# Pre-flight Deployment Safety Check

**Run ID:** PRE-20260513-prod-a18f2992
**Scope:** prod
**Generated (UTC):** 2026-05-13T14:18:09Z
**Ruleset hash:** a18f2992
**Timeout budget:** 30s

## Preflight Summary

| Metric | Value |
|---|---|
| Checks passed | 5 |
| Checks failed | 2 |
| Checks skipped / invalid | 2 |
| Decision | **FAIL — DEPLOY BLOCKED** |

## Preflight Results

| Rule ID | Title | Severity | Status | Failing Resources | Remediation Hint |
|---|---|---|---|---:|---|
| R001 | Active resource health incidents in scope | critical | PASS | 0 | Investigate impaired resources in the Azure portal Health blade before deploying. |
| R002 | Overlapping deployments already Running in target scope | high | PASS | 0 | Wait for in-flight deployments to complete or cancel them before proceeding. |
| R003 | Dependency resources not in Succeeded provisioning state | high | PASS | 0 | Repair or re-provision the failed dependency resources listed above before deploying. |
| R004 | Recent throttling or failed operations in the last 15 minutes (resourcechanges) | high | PASS | 0 | Review Activity Log for throttling/errors and resolve before retrying the deployment. |
| R005 | Quota headroom — current resource counts vs configured limits | medium | PASS | 0 | Request a quota increase via the Azure portal or reduce resource count. Compare vm_count/ip_count/nic_count/sa_count against quota_limits in prod.yaml. |
| R006 | Resources lacking the iac-managed tag (possible drift from IaC source) | medium | FAIL | ≥200 (ARG page cap) | Add the 'iac-managed=true' tag to resources managed by IaC, or re-apply your IaC pipeline to reconcile state. |
| R007 | Resources missing required deployment tags (Environment, Owner, deployment-scope) | medium | FAIL | ≥200 (ARG page cap) | Apply required tags (Environment, Owner, deployment-scope) to all resources before deploying. |
| R008 | Failed deployments in the last 1 hour in target scope | high | TIMEOUT | 0 | Investigate and resolve the failed deployments listed above before re-deploying. |
| R009 | Region capacity signal — VM count in target location | low | TIMEOUT | 0 | If region appears near capacity, consider an alternate region or open a support ticket for capacity reservation. |

---
*Run `@preflight-safety deploy scope <scope> template <file> params <file>` to proceed if all checks pass.*
*Run `@preflight-safety status` to check last deployment status.*

> ⚠️ **Budget warning:** preflight wall-clock budget of 30s was exhausted after R007. Rules R008 and R009 were not executed and are recorded as TIMEOUT.

