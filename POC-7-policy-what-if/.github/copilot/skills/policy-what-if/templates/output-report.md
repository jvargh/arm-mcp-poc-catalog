# Policy What-If Report

**Run ID:** {{run_id}}
**Policy:** {{policy_name}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Alias map version:** {{alias_map_version}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Rules evaluated | {{rules_evaluated}} |
| Rules invalid | {{rules_invalid}} |
| Unsupported aliases | {{aliases_unsupported}} |
| Would-be non-compliant resources | {{total_noncompliant}} |

## Would-Be Non-Compliant Resources

Sorted by Owner tag (ascending), then by resource type (ascending). Unsupported alias rows appear last.

| Owner Tag | Resource Type | Resource Group | Resource ID |
|---|---|---|---|
{{noncompliant_table}}

## Alias Mapping Summary

| Policy Alias | ARG Field | Status |
|---|---|---|
{{alias_map_table}}

---
*Run `@policy-what-if drilldown <resource-id>` for per-resource detail.*
*Output format: {{output_format}}. Exports written to `exports/` when format is `detailed` or `csv`.*
