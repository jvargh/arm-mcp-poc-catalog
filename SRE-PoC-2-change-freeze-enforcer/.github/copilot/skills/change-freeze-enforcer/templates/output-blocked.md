# Change-Freeze Enforcer — Deployment Blocked

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Decision: 🚫 BLOCK

| Field | Value |
|---|---|
| Template | {{template_name}} |
| Target scope | {{target_scope}} |
| Freeze window start (UTC) | {{freeze_window_start}} |
| Freeze window end (UTC) | {{freeze_window_end}} |
| Freeze severity | {{freeze_severity}} |
| Scopes matched | {{freeze_scopes_matched}} |
| Exemption tag | absent |

## Why this deployment was blocked

The target scope **{{target_scope}}** falls within an active freeze window
(`{{freeze_window_start}}` → `{{freeze_window_end}}`). No `freeze-exempt` tag was found on
resources in this scope.

## How to proceed

- **Wait** until the freeze window ends (`{{freeze_window_end}}`), then re-run `deploy`.
- **Apply a break-glass override** by re-running with the `override` verb and supplying
  a change-request ID (`cr_id`) and `justification`. Both fields are required and will be
  written to `exports/override-audit.log`.

```
@change-freeze-enforcer override
  template: {{template_name}}
  target_scope: {{target_scope}}
  cr_id: <your-CR-ID>
  justification: <your-justification>
```

---
*Deployment blocked by change-freeze policy. Contact your SRE on-call if you believe this is incorrect.*
