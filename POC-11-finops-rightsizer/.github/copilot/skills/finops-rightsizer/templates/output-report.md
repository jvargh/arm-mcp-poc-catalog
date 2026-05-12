# FinOps Right-sizer Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Right-size candidates | {{candidates_total}} |
| Est. total monthly savings | ${{total_est_monthly_savings}} |

## Right-size Candidates

Sorted descending by estimated monthly savings; ties by resource name ascending.

| Rank | Resource | RG | Current SKU | Target SKU | Est. $/mo saved | Rule |
|---:|---|---|---|---|---:|---|
{{candidates_table}}

## Rules Summary

| Rule ID | Title | Weight | Candidates | Status |
|---|---|---:|---:|---|
{{rules_summary_table}}

## Opt-in Checklist (for `resize` verb)

To resize, issue `@finops-rightsizer resize scope <scope>` and confirm from this list:

{{checklist_block}}

---
*Run `@finops-rightsizer drilldown <resource>` for per-resource detail.*
*Run `@finops-rightsizer resize scope <scope>` and confirm each resource to deploy.*
