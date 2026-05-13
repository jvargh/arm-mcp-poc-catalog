# Policy What-If Drilldown — {{resource_id}}

**Run ID:** {{run_id}}
**Policy:** {{policy_name}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}

## Resource Details

| Field | Value |
|---|---|
| Resource ID | {{resource_id}} |
| Resource Type | {{resource_type}} |
| Resource Group | {{resource_group}} |
| Owner Tag | {{owner_tag}} |
| Location | {{location}} |

## Matched Rules

{{matched_rules_block}}

## Notes

- Each rule block above contains the **exact** ARG query (verbatim from `rules.yaml` after alias substitution) that produced the finding.
- Re-run with `@policy-what-if simulate` and full scope to see all would-be non-compliant resources.
- This resource would be **denied** by the simulated policy if it were enforced.
