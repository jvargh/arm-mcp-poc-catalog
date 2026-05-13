# Pre-deploy Blast Radius Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Template:** {{template_path}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Resources in template | {{resources_total}} |
| Resources evaluated | {{resources_evaluated}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Total risk score | {{total_risk_score}} |
| Risk threshold | {{risk_threshold}} |
| Threshold status | {{threshold_status}} |

## Change Risk Table

| Change Category | Resource Name | Resource Type | Risk Weight | Severity |
|---|---|---|---:|---|
{{change_risk_table}}

## Policy Violations

| Resource | Policy Name | Compliance State |
|---|---|---|
{{policy_violations_table}}

## Dependency Fan-out Warnings

| Resource | Resource Type | Fan-out Score |
|---|---|---:|
{{fanout_table}}

## Risk Breakdown by Category

{{risk_breakdown_block}}

---
*Run `@blast-radius-analyzer drilldown <resource-name>` for per-resource detail.*
