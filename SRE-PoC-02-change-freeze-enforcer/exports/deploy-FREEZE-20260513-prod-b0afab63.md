# Change-Freeze Enforcer — Deployment Cleared

**Run ID:** FREEZE-20260513-prod-b0afab63
**Scope:** prod
**Generated (UTC):** 2026-05-13T14:00:01Z
**Ruleset hash:** b0afab63

## Decision: ✅ PASS

| Field | Value |
|---|---|
| Template | runbooks/my-app.json |
| Target scope | aks01day2-rg |
| Freeze windows checked | 1 |
| Active freeze match | None |
| Exemption tag | absent |

## Simulated Deploy Outcome

> ⚠️ v1 does **not** invoke `create_template_deployment`. This is a simulated outcome.
> Live deployment must be triggered by the operator after this gate passes.

| Parameter | Value |
|---|---|
| Template | runbooks/my-app.json |
| Target scope | aks01day2-rg |
| Deploy mode | Incremental |
| Status | Would-deploy (simulated — create_template_deployment not called in v1) |

---
*No active freeze window matched this scope. Deployment is permitted.*
*Run `@change-freeze-enforcer status` to review current freeze schedule.*
