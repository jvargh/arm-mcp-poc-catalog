# Cost Driver Finder Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Time window:** {{time_window_days}} days
**Target region:** {{target_region}}

## Summary

| Metric | Value |
|---|---|
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Resources found | {{resources_total}} |

## New Resources (R001)

Resources created within the time window in the target region.

| Resource ID | Name | Type | Resource Group | Created At | Owner |
|---|---|---|---|---|---|
{{new_resources_table}}

## Modified Resources (R002)

Resources updated (resized, reconfigured) within the time window in the target region.

| Resource ID | Resource Group | Location | Changed At | Change Type |
|---|---|---|---|---|
{{modified_resources_table}}

## Untagged Resources in Region (R003)

Resources in the target region missing an `Owner` tag — cost attribution may be impossible.

| Resource ID | Name | Type | Resource Group | RG Owner |
|---|---|---|---|---|
{{untagged_resources_table}}

## Cost Management Handoff

{{cost_management_block}}

---
*Run `@cost-driver-finder drilldown <resource-group>` for per-resource-group detail.*
