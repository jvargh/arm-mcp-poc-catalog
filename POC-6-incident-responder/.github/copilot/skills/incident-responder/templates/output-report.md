# Incident Triage Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Time window:** {{time_window_hours}}h

## Summary

| Rule | Title | Status | Count |
|---|---|---|---:|
| R001 | Resources changed in time window | {{r001_status}} | {{change_count}} |
| R002 | In-flight ARM deployments (Running) | {{r002_status}} | {{in_flight_count}} |
| R003 | Recent RBAC changes | {{r003_status}} | {{rbac_count}} |

## Change Feed (R001 — last {{time_window_hours}}h)

| Change Time | Resource ID | Change Type | Resource Group | Subscription |
|---|---|---|---|---|
{{change_feed_table}}

## In-Flight ARM Deployments (R002)

| Deployment ID | Name | Resource Group | Subscription | Start Time | State |
|---|---|---|---|---|---|
{{in_flight_table}}

> ℹ️  To cancel a running deployment, run:
> `@incident-responder cancel deployment <deployment-id> scope {{scope}}`

## Recent RBAC Changes (R003)

| Created On | Resource Group | Principal ID | Role Definition ID | Subscription |
|---|---|---|---|---|
{{rbac_changes_table}}

---

*Run `@incident-responder cancel deployment <id> scope {{scope}}` to cancel a running deployment.*
*Audit trail appended to `exports/incident-audit.jsonl`.*
