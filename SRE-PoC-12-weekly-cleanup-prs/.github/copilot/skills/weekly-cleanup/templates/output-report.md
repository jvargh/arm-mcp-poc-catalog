# Weekly Azure Cleanup Report

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
| Orphaned resources found | {{orphan_count}} |
| Drift items found | {{drift_count}} |
| Compliance items found | {{compliance_count}} |
| Total estimated savings | ${{total_savings}}/mo |

## Cleanup Findings

*Sorted by category (orphaned → drift → compliance), then by estimated savings descending.*

| Category | Rule | Resource ID | Type | Resource Group | Est. Savings/mo | Status |
|---|---|---|---|---|---:|---|
{{findings_table}}

## Proposed PR

**{{pr_title}}**

See `exports/proposed-pr/{{run_id}}.md` for full PR content.

---
*Run `@weekly-cleanup drilldown <resource-id>` for per-resource detail.*
*Proposed PR content is written to `exports/proposed-pr/` — review and merge manually.*
