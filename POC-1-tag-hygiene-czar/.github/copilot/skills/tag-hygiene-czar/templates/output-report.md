# Tag Hygiene Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Resources scanned | {{resources_scanned}} |
| Resources non-compliant | {{resources_noncompliant}} |

## Non-Compliant Resources

*Sorted by resource group (ascending), resource type (ascending), resource name (ascending).*

| Resource Group | Resource Type | Resource Name | Resource ID | Missing Tag |
|---|---|---|---|---|
{{noncompliant_table}}

## Failing Checks

| Rule ID | Tag Key | Severity | Weight | Non-Compliant Count |
|---|---|---|---:|---:|
{{failing_checks_table}}

---
*Run `@tag-hygiene-czar drilldown <resource-group>` for per-RG detail.*
*Run `@tag-hygiene-czar apply` to deploy ARM tag patches (explicit confirmation required).*
