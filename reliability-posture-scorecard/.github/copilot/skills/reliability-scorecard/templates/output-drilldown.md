# Workload Drilldown — {{workload}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Score:** {{score}} / 100
**Failed rule count:** {{failed_rule_count}}

## Failed Checks (descending by weight)

{{failed_checks_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query to see all.
- To remediate, run `@scorecard remediate` and confirm per rule_id when prompted.
