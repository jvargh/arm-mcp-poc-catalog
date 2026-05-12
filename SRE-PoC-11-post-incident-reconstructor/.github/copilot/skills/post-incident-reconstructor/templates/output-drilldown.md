# Deployment Drilldown — {{deployment_id}}

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Provisioning state:** {{provisioning_state}}
**Deployment started:** {{deployment_timestamp}}

## Correlated Change Events

> All timeline entries correlated to this deployment ID, ascending by timestamp.
> Entry format: `[HH:MM:SS UTC] <principal> <action> <resource> (deployment: <id>)`

```
{{deployment_timeline_block}}
```

## Deployment Detail

| Field | Value |
|---|---|
| Deployment ID | {{deployment_id}} |
| Resource group | {{deployment_rg}} |
| Subscription | {{deployment_subscription}} |
| Provisioning state | {{provisioning_state}} |
| Correlated resource changes | {{correlated_change_count}} |

## Notes

- Each timeline entry above reflects an event correlated to this deployment via ARM correlation ID.
- `Resources listed` shows all events found within the incident window for this deployment.
- To investigate further, use `@post-incident-reconstructor reconstruct` for the full incident timeline.
- This agent is READ-ONLY. No changes are made to your Azure environment.
