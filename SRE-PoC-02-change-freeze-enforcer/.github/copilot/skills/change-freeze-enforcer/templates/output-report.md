# Change-Freeze Enforcer — Deployment Cleared

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Decision: ✅ PASS

| Field | Value |
|---|---|
| Template | {{template_name}} |
| Target scope | {{target_scope}} |
| Freeze windows checked | {{freeze_windows_checked}} |
| Active freeze match | None |
| Exemption tag | {{exemption_status}} |

## Simulated Deploy Outcome

> ⚠️ v1 does **not** invoke `create_template_deployment`. This is a simulated outcome.
> Live deployment must be triggered by the operator after this gate passes.

| Parameter | Value |
|---|---|
| Template | {{template_name}} |
| Target scope | {{target_scope}} |
| Deploy mode | {{simulated_deploy_mode}} |
| Status | {{simulated_deploy_status}} |

---
*No active freeze window matched this scope. Deployment is permitted.*
*Run `@change-freeze-enforcer status` to review current freeze schedule.*
