# Capacity & Quota Guardian — Pre-Deploy Quota Check

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Template:** {{template_path}}

## Quota Gate Result

| Metric | Value |
|---|---|
| Headroom threshold | {{headroom_threshold_pct}}% |
| Quota breaches | {{breach_count}} |
| **Gate decision** | **{{deploy_gate_decision}}** |

## Quota Usage (descending by usage_pct)

| Region | Resource Type | SKU | Current | Limit | Usage % | Status |
|---|---|---|---:|---:|---:|---|
{{quota_usage_table}}

## Alternate Region Suggestions

{{alternate_region_block}}

## Next Steps

{{#if_fail}}
> ⛔ **DEPLOY BLOCKED.** Resolve quota breaches before deploying.
> Options:
> 1. Deploy to an alternate region (see suggestions above).
> 2. File a quota increase request with Azure Support (`az support tickets create`).
> 3. Delete unused resources in the target region to free quota.
> 4. Update `quota_limits` in `runbooks/prod.yaml` if limits have already been increased.
{{/if_fail}}
{{#if_pass}}
> ✅ **QUOTA PASS.** All resource types are within headroom threshold.
> Re-run with `deploy` verb to proceed (v1 will simulate — no actual deployment made).
{{/if_pass}}
