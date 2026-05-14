# Runbook Execution Report

**Run ID:** RBOOK-20260514-failover-runbook-2c076ca1
**Runbook:** failover-runbook
**Scope:** subscription `sub-id`
**Generated (UTC):** 2026-05-14T01:56:05Z
**Schema hash:** 2c076ca1
**Run status:** FAILED

## Summary

| Metric | Value |
|---|---|
| Total steps | 7 |
| Steps passed | 2 |
| Steps failed | 0 |
| Steps skipped | 4 |
| Steps timed out | 1 |
| Cancelled | false |

## Step Execution Summary

| # | Step Name | Type | Status | Duration (s) | on_fail |
|---:|---|---|---|---:|---|
| 1 | Check pre-conditions — primary region health | check | PASS | 18 | halt |
| 2 | Check pre-conditions — failover region capacity | check | PASS | 12 | halt |
| 3 | Confirm failover gate | confirm | TIMED_OUT | 30 | halt |
| 4 | Deploy failover — redirect traffic to failover region | deploy | NOT_RUN | — | rollback |
| 5 | Check post-deploy health — failover region serving traffic | check | NOT_RUN | — | rollback |
| 6 | Confirm success or rollback gate | confirm | NOT_RUN | — | rollback |
| 7 | Rollback — restore primary region if needed | rollback | NOT_RUN | — | halt |

## Final State

**Run status:** FAILED
**Started (UTC):** 2026-05-14T01:54:50Z
**Completed (UTC):** 2026-05-14T01:56:00Z
**State file:** exports/prod-run-state.json

## Notes

- Evidence pack written to state file at `exports/prod-run-state.json`.
- Run `@runbook-executor status runbook=failover-runbook` to view current state.
- Run `@runbook-executor rollback runbook=failover-runbook` to trigger rollback.
- **v1 notice:** All `deploy` and `rollback` steps were SIMULATED. No ARM deployments were executed.
- Halt cause: confirm gate at step 3 received no operator response (autopilot session, no user available). Resume by re-invoking `execute` once an operator can confirm.

---

# Per-Step Statuses

## Step Status — Check pre-conditions — primary region health

**Run ID:** RBOOK-20260514-failover-runbook-2c076ca1
**Step index:** 1 / 7
**Type:** check
**Status:** PASS
**Timestamp (UTC):** 2026-05-14T01:55:10Z
**Duration (s):** 18

### Input

```
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| where location =~ 'eastus'
| where tostring(properties.provisioningState) !~ 'Succeeded'
| where subscriptionId in~ ('sub-id')
| project id, name, resourceGroup, subscriptionId, location, provisioningState=tostring(properties.provisioningState)
```

### Output

```
{"count":0,"total_records":0,"data":[]}
```

### Transition

PASS → advancing to step 2.

---

## Step Status — Check pre-conditions — failover region capacity

**Run ID:** RBOOK-20260514-failover-runbook-2c076ca1
**Step index:** 2 / 7
**Type:** check
**Status:** PASS
**Timestamp (UTC):** 2026-05-14T01:55:25Z
**Duration (s):** 12

### Input

```
Resources
| where type =~ 'microsoft.compute/virtualmachines'
| where location =~ 'westus2'
| where tostring(properties.provisioningState) =~ 'Succeeded'
| where subscriptionId in~ ('sub-id')
| project id, name, resourceGroup, subscriptionId, location
```

### Output

```
{"count":0,"total_records":0,"data":[]}
```

### Transition

PASS → advancing to step 3.

---

## Step Status — Confirm failover gate

**Run ID:** RBOOK-20260514-failover-runbook-2c076ca1
**Step index:** 3 / 7
**Type:** confirm
**Status:** TIMED_OUT
**Timestamp (UTC):** 2026-05-14T01:56:00Z
**Duration (s):** 30

### Input

```
user-confirmation
```

### Output

```
No user response received (operator unavailable). Per hard rule #4, silence is treated as FAIL/TIMED_OUT.
```

### Transition

TIMED_OUT → on_fail=`halt` → `run_status = FAILED`. Run halted at step 3. Steps 4–7 not executed.

---

# Evidence Pack — RBOOK-20260514-failover-runbook-2c076ca1

**Runbook:** failover-runbook
**Run status:** FAILED
**Generated (UTC):** 2026-05-14T01:56:05Z
**Total entries:** 3

## Evidence Pack (JSON)

```json
[
  {
    "step_name": "Check pre-conditions — primary region health",
    "type": "check",
    "input": "Resources | where type =~ 'microsoft.compute/virtualmachines' | where location =~ 'eastus' | where tostring(properties.provisioningState) !~ 'Succeeded' | where subscriptionId in~ ('sub-id') | project id, name, resourceGroup, subscriptionId, location, provisioningState=tostring(properties.provisioningState)",
    "output": "{\"count\":0,\"total_records\":0,\"data\":[]}",
    "status": "PASS",
    "timestamp_utc": "2026-05-14T01:55:10Z"
  },
  {
    "step_name": "Check pre-conditions — failover region capacity",
    "type": "check",
    "input": "Resources | where type =~ 'microsoft.compute/virtualmachines' | where location =~ 'westus2' | where tostring(properties.provisioningState) =~ 'Succeeded' | where subscriptionId in~ ('sub-id') | project id, name, resourceGroup, subscriptionId, location",
    "output": "{\"count\":0,\"total_records\":0,\"data\":[]}",
    "status": "PASS",
    "timestamp_utc": "2026-05-14T01:55:25Z"
  },
  {
    "step_name": "Confirm failover gate",
    "type": "confirm",
    "input": "user-confirmation",
    "output": "No user response received (operator unavailable). Per hard rule #4, silence is treated as FAIL/TIMED_OUT.",
    "status": "TIMED_OUT",
    "timestamp_utc": "2026-05-14T01:56:00Z"
  }
]
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
