# ChatOps Audit Log

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}

## Summary

| Metric | Value |
|---|---|
| Total queries logged | {{total_queries}} |
| Successful queries | {{successful_queries}} |
| Failed queries | {{failed_queries}} |

## Audit Table

*(Sorted by timestamp descending — most recent first)*

| Timestamp (UTC) | User | Question | Rule Matched | Row Count | Run ID |
|---|---|---|---|---:|---|
{{audit_table}}

---
*Audit log is append-only. One line per query attempt (success or failure).*
*Log path: `{{audit_log_path}}`*
