# Blast-Radius Simulation Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Template:** {{template_path}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Template Summary

| Metric | Value |
|---|---|
| Resources in template | {{template_resource_count}} |
| Resource types | {{template_resource_types}} |
| Estimated change type | {{change_type}} |

## Impact by Category (descending by category risk)

| Rule ID | Category | Weight | Affected Resources | Category Risk | Status |
|---|---|---:|---:|---:|---|
{{impact_table}}

## Dependency Edges

{{dependency_edges_block}}

## Risk Assessment

| Metric | Value |
|---|---|
| Total risk score | {{total_risk_score}} |
| Risk level | {{risk_level}} |
| Recommended strategy | {{recommended_strategy}} |

---
*Run `@blast-radius-simulator drilldown <category>` for per-category detail (e.g. `drilldown dns_endpoint`).*
