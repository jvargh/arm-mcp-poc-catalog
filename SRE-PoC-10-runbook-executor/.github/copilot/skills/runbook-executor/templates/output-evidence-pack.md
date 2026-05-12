# Evidence Pack — {{run_id}}

**Runbook:** {{runbook_name}}
**Run status:** {{run_status}}
**Generated (UTC):** {{generated_utc}}
**Total entries:** {{entry_count}}

## Evidence Pack (JSON)

```json
{{evidence_pack_json}}
```

## Entry Legend

| Field | Description |
|---|---|
| `step_name` | Human-readable step name from the runbook DSL |
| `type` | Step type: `check`, `deploy`, `confirm`, `rollback`, `cancel` |
| `input` | KQL string, template path, `'user-confirmation'`, or `null` |
| `output` | MCP response JSON, simulated outcome string, or user input |
| `status` | One of: `PASS`, `FAIL`, `TIMED_OUT`, `SKIPPED`, `AWAITING_CONFIRMATION` |
| `timestamp_utc` | ISO 8601 UTC timestamp of step completion |

---
*Entries are ordered by execution sequence. Never re-sorted.*
*v1 notice: `deploy` and `rollback` entries contain simulated outcomes.*
