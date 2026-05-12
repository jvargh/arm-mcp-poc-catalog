# IaC Drift Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Template:** `{{template_repo_path}}`

## Summary

| Metric | Value |
|---|---|
| Template resources checked | {{resources_total}} |
| Resources with drift | {{resources_drifted}} |
| Resources missing in live | {{resources_missing}} |
| Resources in sync | {{resources_clean}} |

## Drift Summary

| Resource Name | Type | Resource Group | Rule | Drifted Fields | Status |
|---|---|---|---|---|---|
{{drift_summary_table}}

## JSON Patch (RFC 6902)

```json
{{json_patch_block}}
```

---
*Run `@iac-drift-detector drilldown <resource_id>` for per-resource property detail.*
