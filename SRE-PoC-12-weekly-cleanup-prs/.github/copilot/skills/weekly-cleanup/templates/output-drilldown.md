# Resource Drilldown — {{resource_id}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Resource Type:** {{resource_type}}
**Resource Group:** {{resource_group}}

## Rule Hits (descending by severity)

{{rule_hits_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- To remediate, propose a template via the `scan` verb and review the output in `exports/proposed-pr/`.
- The agent NEVER deploys — review proposed templates and apply manually.
