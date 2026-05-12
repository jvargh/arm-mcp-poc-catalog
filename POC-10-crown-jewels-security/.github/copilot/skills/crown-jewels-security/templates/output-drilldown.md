# Resource Drilldown — {{resource_id}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Resource Group:** {{resource_group}}
**Severity Score:** {{severity_score}}
**Matched rule count:** {{matched_rule_count}}

## Matched Rules (descending by weight)

{{matched_rules_block}}

## Notes

- Each block above contains the **exact** ARG query that produced the finding (verbatim from `rules.yaml`).
- To investigate further, paste the KQL into the Azure Resource Graph Explorer.
- This PoC is read-only — no remediation actions are available from this agent.
