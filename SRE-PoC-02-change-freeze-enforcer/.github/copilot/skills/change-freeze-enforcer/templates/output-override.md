# Change-Freeze Enforcer — Override Approved

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Decision: ⚠️ OVERRIDE_ALLOW

| Field | Value |
|---|---|
| Template | {{template_name}} |
| Target scope | {{target_scope}} |
| Freeze window start (UTC) | {{freeze_window_start}} |
| Freeze window end (UTC) | {{freeze_window_end}} |
| Freeze severity | {{freeze_severity}} |
| CR ID | {{cr_id}} |
| Principal | {{principal}} |
| Justification | {{justification}} |

## Audit Log Entry

The following JSON line has been appended to `exports/override-audit.log`:

```json
{{audit_log_json}}
```

## Simulated Deploy Outcome

> ⚠️ v1 does **not** invoke `create_template_deployment`. This is a simulated outcome.
> The override is approved; the operator must trigger the actual deployment manually.

| Parameter | Value |
|---|---|
| Template | {{template_name}} |
| Target scope | {{target_scope}} |
| Deploy mode | Incremental |
| Status | {{simulated_deploy_status}} |

---
*Break-glass override recorded. Deployment is permitted for this run only.*
*All override events are audited in `exports/override-audit.log`.*
