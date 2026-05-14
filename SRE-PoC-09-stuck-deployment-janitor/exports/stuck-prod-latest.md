# Stuck Deployment Janitor Report

**Run ID:** STUCK-20260514-prod-3ffe5114
**Scope:** prod
**Generated (UTC):** 2026-05-14T01:49:53Z
**Ruleset hash:** 3ffe5114
**Threshold:** deployments running ≥ 4 hours

## Summary

| Metric | Value |
|---|---|
| Total stuck deployments found | 0 |
| Actionable (deleted-dep + quota-loop) | 0 |
| Genuinely slow (do not cancel) | 0 |
| Unknown / exceeded threshold only | 0 |

## Stuck Deployments

| Rank | Name | Resource Group | Subscription | Duration (h) | Classification | Detail | Over Expected |
|---:|---|---|---|---:|---|---|:---:|
_(no stuck deployments — table empty)_

## Classification Key

| Reason | Meaning | Recommended action |
|---|---|---|
| `deleted-dependency` | Deployment is waiting on a resource that no longer exists | Cancel; recreate missing dependency or update template |
| `quota-loop` | Deployment is cycling against a quota-exceeded error | Cancel; request quota increase, then redeploy |
| `genuinely-slow` | Deployment includes known long-running resource types | Monitor; do NOT cancel prematurely |
| `exceeded-threshold` | Deployment has exceeded the threshold but cause is unknown | Investigate with `get_arm_template_deployment_status`; then decide |

---
*Run `@stuck-deployment-janitor cancel for scope prod` to cancel specific deployments with per-deployment confirmation.*
*Post-cancel cleanup templates are a future enhancement — see README § Out of scope.*
