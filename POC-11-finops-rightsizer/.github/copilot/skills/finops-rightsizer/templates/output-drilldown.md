# Resource Drilldown — {{resource_name}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Current SKU:** {{current_sku}}
**Target SKU:** {{target_sku}}
**Est. monthly savings:** ${{est_monthly_savings}}

## Matching Rules (descending by weight)

{{matched_rules_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query in Azure Resource Graph Explorer to see all.
- To resize, run `@finops-rightsizer resize scope <scope>` and confirm this resource in the opt-in checklist.
