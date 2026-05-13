# Auto-Rollback Orchestrator Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Deployment:** {{deployment_name}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Overall status:** {{overall_status}}

## Run Summary

| Metric | Value |
|---|---|
| Deployment final state | {{deployment_final_state}} |
| Health gate overall | {{health_gate_overall}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules passed | {{rules_passed}} |
| Rules failed | {{rules_failed}} |
| Rollback attempts | {{rollback_attempts}} / {{max_rollback_attempts}} |
| LKG template ref | {{last_good_template_ref}} |

## Timeline

```
{{timeline_block}}
```

## Health Gate Results

| Rule ID | Title | Severity | Result | Failing Resources |
|---|---|---|---|---:|
{{health_gate_table}}

## Rollback Log

{{rollback_log_block}}

---
*Run `@auto-rollback cancel` to cancel an in-progress deployment with confirmation.*
*Run `@auto-rollback rollback` to manually trigger a rollback to the last-known-good template.*
