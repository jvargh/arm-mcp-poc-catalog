# Reliability Posture Scorecard

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
| Workloads scored | {{workloads_total}} |

## Bottom 10 Workloads by Score

| Rank | Workload | Score | Failed Rules | Top Gap |
|---:|---|---:|---:|---|
{{bottom10_table}}

## Failing Checks

| Rule ID | Title | Severity | Weight | Failing Resources |
|---|---|---|---:|---:|
{{failing_checks_table}}

## Top 3 Gaps

{{top3_gaps_block}}

---
*Run `@scorecard drilldown <workload>` for per-workload detail. Run `@scorecard remediate` to generate ARM patch templates for the top 3 gap types.*
