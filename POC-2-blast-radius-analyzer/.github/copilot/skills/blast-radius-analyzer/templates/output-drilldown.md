# Blast Radius Drilldown — {{resource_name}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Change Category:** {{change_category}}
**Risk Weight:** {{risk_weight}}

## Resource Details

| Field | Value |
|---|---|
| Resource ID | {{resource_id}} |
| Resource Type | {{resource_type}} |
| Resource Group | {{resource_group}} |
| Location | {{location}} |
| API Version | {{api_version}} |

## Triggered Rules (descending by weight)

{{triggered_rules_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query to see all.
- To understand cross-resource impact, inspect the `dependsOn` graph from the parsed template.
