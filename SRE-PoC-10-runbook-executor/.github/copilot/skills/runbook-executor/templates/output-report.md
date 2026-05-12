# Runbook Execution Report

**Run ID:** {{run_id}}
**Runbook:** {{runbook_name}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Schema hash:** {{schema_hash8}}
**Run status:** {{run_status}}

## Summary

| Metric | Value |
|---|---|
| Total steps | {{steps_total}} |
| Steps passed | {{steps_passed}} |
| Steps failed | {{steps_failed}} |
| Steps skipped | {{steps_skipped}} |
| Steps timed out | {{steps_timed_out}} |
| Cancelled | {{cancelled}} |

## Step Execution Summary

| # | Step Name | Type | Status | Duration (s) | on_fail |
|---:|---|---|---|---:|---|
{{step_summary_table}}

## Final State

**Run status:** {{run_status}}
**Started (UTC):** {{started_utc}}
**Completed (UTC):** {{completed_utc}}
**State file:** {{state_file_path}}

## Notes

- Evidence pack written to state file at `{{state_file_path}}`.
- Run `@runbook-executor status runbook={{runbook_name}}` to view current state.
- Run `@runbook-executor rollback runbook={{runbook_name}}` to trigger rollback.
- **v1 notice:** All `deploy` and `rollback` steps were SIMULATED. No ARM deployments were executed.
