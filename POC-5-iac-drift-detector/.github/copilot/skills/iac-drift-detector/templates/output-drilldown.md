# Resource Drilldown — {{resource_name}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Resource ID:** `{{resource_id}}`
**Resource Type:** {{resource_type}}
**Resource Group:** {{resource_group}}

## Drifted Properties (alphabetical)

| Property | Template Value | Live Value |
|---|---|---|
{{drift_properties_table}}

## JSON Patch (RFC 6902)

```json
{{json_patch_entry}}
```

## Notes

- Property paths follow ARM REST API JSON structure (`properties.*`, `sku.*`, etc.).
- Template values are read verbatim from the checked-in ARM template at `{{template_repo_path}}`.
- Live values are retrieved from Azure Resource Graph at report generation time.
- To remediate manually, apply the JSON patch above to the live resource via `az resource update` or an ARM template re-deployment.
