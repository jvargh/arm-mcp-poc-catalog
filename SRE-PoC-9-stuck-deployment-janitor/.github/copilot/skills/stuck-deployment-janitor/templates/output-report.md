# Stuck Deployment Janitor Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Threshold:** deployments running ≥ {{threshold_hours}} hours

## Summary

| Metric | Value |
|---|---|
| Total stuck deployments found | {{total_stuck}} |
| Actionable (deleted-dep + quota-loop) | {{total_actionable}} |
| Genuinely slow (do not cancel) | {{total_genuinely_slow}} |
| Unknown / exceeded threshold only | {{total_unknown}} |

## Stuck Deployments

| Rank | Name | Resource Group | Subscription | Duration (h) | Classification | Detail | Over Expected |
|---:|---|---|---|---:|---|---|:---:|
{{stuck_table}}

## Classification Key

| Reason | Meaning | Recommended action |
|---|---|---|
| `deleted-dependency` | Deployment is waiting on a resource that no longer exists | Cancel; recreate missing dependency or update template |
| `quota-loop` | Deployment is cycling against a quota-exceeded error | Cancel; request quota increase, then redeploy |
| `genuinely-slow` | Deployment includes known long-running resource types | Monitor; do NOT cancel prematurely |
| `exceeded-threshold` | Deployment has exceeded the threshold but cause is unknown | Investigate with `get_arm_template_deployment_status`; then decide |

---
*Run `@stuck-deployment-janitor cancel for scope {{scope}}` to cancel specific deployments with per-deployment confirmation.*
*Post-cancel cleanup templates are a future enhancement — see README § Out of scope.*
