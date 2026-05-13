# Resource Drilldown — {{resource_id}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Resource Type:** {{resource_type}}
**Resource Group:** {{resource_group}}
**Subscription:** {{subscription_id}}
**High-risk:** {{is_high_risk}}

## Relationships

| Relationship Type | Source | Target |
|---|---|---|
{{drilldown_relationships_table}}

## Notes

- Relationship data is re-queried live from ARG rules R004 and R005.
- `Source` and `Target` columns contain full Azure resource IDs.
- To view the full estate context, run `@estate-cartographer map for scope {{scope}}`.
