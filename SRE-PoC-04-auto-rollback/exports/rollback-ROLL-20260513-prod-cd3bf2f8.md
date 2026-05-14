# Auto-Rollback Orchestrator Report

**Run ID:** ROLL-20260513-prod-cd3bf2f8
**Scope:** prod
**Deployment:** payments-deploy-20260512
**Generated (UTC):** 2026-05-13T14:26:50Z
**Ruleset hash:** cd3bf2f8
**Overall status:** HALTED

## Run Summary

| Metric | Value |
|---|---|
| Deployment final state | NotFound |
| Health gate overall | SKIPPED |
| Rules evaluated | 0 |
| Rules passed | 0 |
| Rules failed | 0 |
| Rollback attempts | 0 / 2 |
| LKG template ref | git:refs/heads/main:infra/main.json |

## Timeline

```
[2026-05-13T14:26:45Z] ACTION: run-start run_id=ROLL-20260513-prod-cd3bf2f8 verb=watch (IN_PROGRESS)
[2026-05-13T14:26:46Z] ACTION: poll-error error="DeploymentNotFound: Deployment 'payments-deploy-20260512' could not be found in resource group 'aks01day2-rg'." (FAIL)
[2026-05-13T14:26:47Z] ACTION: cancel-requested deployment=payments-deploy-20260512 (PENDING_CONFIRM)
[2026-05-13T14:26:48Z] ACTION: confirmation-prompted prompt="Cancel deployment payments-deploy-20260512? This will stop all in-progress operations. Reply YES to confirm." (PENDING_CONFIRM)
[2026-05-13T14:26:49Z] ACTION: cancel-aborted deployment=payments-deploy-20260512 reason=user-declined (HALTED)
[2026-05-13T14:26:50Z] ACTION: run-end overall_status=HALTED (HALTED)
```

## Health Gate Results

| Rule ID | Title | Severity | Result | Failing Resources |
|---|---|---|---|---:|
| R001 | All deployed resources in Succeeded provisioningState | critical | SKIPPED | 0 |
| R002 | No new public IP exposure | high | SKIPPED | 0 |
| R003 | Required tags present on new resources | medium | SKIPPED | 0 |
| R004 | No error-state resources in target RG post-deploy | critical | SKIPPED | 0 |

## Rollback Log

- No rollback attempted. Deployment poll failed (DeploymentNotFound) and the operator did not confirm cancel within the session, so the orchestrator halted before reaching Step 6.
- **STATUS=HALTED REASON=user-declined-cancel - operator intervention required**

---
*Run `@auto-rollback cancel` to cancel an in-progress deployment with confirmation.*
*Run `@auto-rollback rollback` to manually trigger a rollback to the last-known-good template.*
