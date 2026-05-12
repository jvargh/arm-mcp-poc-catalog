# Category Drilldown — {{category}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Rule ID:** {{rule_id}}
**Category:** {{category}}
**Category weight:** {{category_weight}}
**Affected resources:** {{affected_resource_count}}
**Category risk:** {{category_risk}}

## ARG Query (verbatim from rules.yaml)

```kql
{{verbatim_kql}}
```

## Affected Resources (first 25)

{{affected_resources_list}}

## Notes

- `Affected resources` shows the first 25 resource IDs only; re-run the ARG query to see all.
- `Category risk = category_weight × affected_resource_count` (integer).
- To view the full simulation report, run `@blast-radius-simulator simulate scope {{scope}}`.
