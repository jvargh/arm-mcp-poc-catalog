# Auto-Rollback Timeline - {{run_id}}

**Deployment:** {{deployment_name}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Overall status:** {{overall_status}}

## Timeline

Each line: `[timestamp_utc] ACTION: description (status)`

```
{{timeline_block}}
```

---
*Timeline is append-only. Lines are never edited once written.*
*Status values: IN_PROGRESS | OK | FAIL | SKIPPED | HALTED | PENDING_CONFIRM*
