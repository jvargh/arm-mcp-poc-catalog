# Post-Incident Change Timeline

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Incident Summary

| Field | Value |
|---|---|
| Incident window start | {{incident_start}} |
| Incident window end | {{incident_end}} |
| Incident scope | {{incident_scope}} |

## Rules Summary

| Metric | Value |
|---|---|
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Deployments found | {{deployment_count}} |
| Change events | {{change_count}} |
| RBAC changes | {{rbac_count}} |

## Change Timeline

> Timeline sorted ascending by timestamp (earliest first). Ties broken by resource name ascending.
> Entry format: `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <id>)`
> SKIPPED rows indicate a table was unavailable in this subscription — see ratification notes.

```
{{timeline_block}}
```

---
*Run `@post-incident-reconstructor drilldown <deployment-id>` for per-deployment detail.*
*This agent is READ-ONLY. No changes are made to your Azure environment.*
