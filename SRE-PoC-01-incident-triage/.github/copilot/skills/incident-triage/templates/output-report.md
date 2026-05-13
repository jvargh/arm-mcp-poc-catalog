# Incident Triage Report

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Time window:** last {{time_window_hours}}h
**Subscription:** {{subscription_id}}
**Ruleset hash:** {{ruleset_hash8}}

---

## Resource Changes (R001)

| changedAt (UTC)      | type    | resourceId                          | principal  |
|----------------------|---------|-------------------------------------|------------|
{{r001_table}}

---

## In-Flight ARM Deployments (R002)

| name                 | resourceGroup        | startTime (UTC)      | state   |
|----------------------|----------------------|----------------------|---------|
{{r002_table}}

---

## RBAC Changes (R003)

| principalId (short)  | roleDefId (short)    | scope (truncated)    | createdOn  |
|----------------------|----------------------|----------------------|------------|
{{r003_table}}

---

*Run `@incident-triage cancel <name>` to cancel an in-flight deployment.*
*Audit record written to `exports/`.*
