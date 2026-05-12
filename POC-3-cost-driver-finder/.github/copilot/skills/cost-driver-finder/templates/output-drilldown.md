# Cost Driver Drilldown — {{resource_group}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Time window:** {{time_window_days}} days
**Target region:** {{target_region}}

## Resources Found

{{drilldown_findings_block}}

## Notes

- Results are filtered to resource group `{{resource_group}}`.
- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query directly to see all.
- Sort order: descending by created/changed timestamp, ties broken by resource name ascending.
