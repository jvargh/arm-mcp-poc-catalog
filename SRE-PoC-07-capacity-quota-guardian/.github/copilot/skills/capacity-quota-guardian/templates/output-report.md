# Capacity & Quota Guardian — Run Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Headroom threshold | {{headroom_threshold_pct}}% |
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules errored | {{rules_errored}} |
| Regions checked | {{regions_checked}} |
| Resource types checked | {{resource_types_checked}} |
| Quota breaches (above threshold) | {{breach_count}} |
| **Overall result** | **{{overall_result}}** |

## Quota Usage (descending by usage_pct)

| Region | Resource Type | SKU | Current | Limit | Usage % | Status |
|---|---|---|---:|---:|---:|---|
{{quota_usage_table}}

> Rows with `LIMIT_UNKNOWN` indicate the limit is not configured in `runbooks/prod.yaml`.
> Update the `quota_limits` map and re-run.

## Alternate Region Suggestions

{{alternate_region_block}}

## Deploy Gate Decision

{{deploy_gate_decision}}

---
*Run `@quota-guardian deploy scope prod --template <path>` to attempt a gated deploy.
On quota PASS the deploy is simulated (v1 is what-if only — no ARM deployment is made).*
