# Tag Hygiene Drilldown — {{resource_group}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Non-compliant resource count (this RG):** {{noncompliant_count}}
**Failed rule count:** {{failed_rule_count}}

## Failed Tag Checks (descending by weight)

{{failed_checks_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- `Resources listed` shows the first 25 IDs only; re-run the ARG query to see all.
- To remediate, run `@tag-hygiene-czar apply` and confirm at the confirm gate when prompted.
