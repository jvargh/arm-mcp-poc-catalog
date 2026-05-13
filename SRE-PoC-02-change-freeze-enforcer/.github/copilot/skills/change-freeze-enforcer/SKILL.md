---
name: change-freeze-enforcer
description: >
  Deterministic procedure to check whether a proposed ARM deployment is permitted under the
  current freeze schedule and emit a fixed-format decision report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `deploy` (default), `override`, `status`.
- `template_name`: name of the ARM template the user intends to deploy.
- `target_scope`: target resource group (or subscription-level scope) of the deployment.
- `cr_id` (override verb only): change-request ID from the user.
- `justification` (override verb only): break-glass justification text from the user.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `freeze_windows[]` — each entry: `{start_utc, end_utc, scopes[], severity}`
   - `break_glass_required_fields[]`
   - `exempt_tags` — `{key, value}`
3. Read `skills/change-freeze-enforcer/rules/rules.yaml`.
   Compute SHA-256 of the file contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "FREEZE-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. Record `current_utc` = current UTC timestamp (ISO 8601 to seconds, `Z` suffix).

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
3. Call `execute_query` with the same arguments.
4. Store the returned rows keyed by `rule.id`.

## Step 3 — Freeze check

1. **R001 scope resolution:** Using the rows returned by R001, confirm the `target_scope`
   (resource group) is present in the subscription. If absent, abort with:
   `ABORT: target scope <target_scope> not found in subscription results`.
2. **R002 time comparison:** For each entry in `runbook.freeze_windows`:
   - Parse `start_utc` and `end_utc` as UTC timestamps.
   - If `current_utc >= start_utc` AND `current_utc < end_utc` → mark window as **ACTIVE**.
   - Collect all ACTIVE windows into `active_windows[]`.
3. **R003 scope overlap:** For each ACTIVE window, check whether `target_scope` matches any
   entry in `window.scopes[]` (case-insensitive substring match). If any match is found,
   record `scope_frozen = true` with the matching window details.
4. **R004 exemption tag check:** From R004 rows, check whether any resource in `target_scope`
   carries the `exempt_tags.key` with the value `exempt_tags.value`. If found, record
   `scope_exempt = true`.

## Step 4 — Override gate (override verb only, requires break-glass fields)

*Skip this step entirely for `deploy` and `status` verbs.*

1. Verify that **all** fields listed in `runbook.break_glass_required_fields` are present and
   non-empty in the user input. If any field is missing or empty, abort with:
   `ABORT: break-glass field '<field>' is required for override but was not supplied`.
2. The override is permitted to proceed only after this verification passes.

## Step 5 — Decision

| Condition | Decision |
|-----------|----------|
| No ACTIVE freeze window, OR `scope_frozen = false`, OR `scope_exempt = true` | **PASS** |
| `scope_frozen = true` AND verb = `deploy` | **BLOCK** |
| `scope_frozen = true` AND verb = `override` AND all break-glass fields supplied | **OVERRIDE_ALLOW** |
| `scope_frozen = true` AND verb = `override` AND missing break-glass field | **ABORT** (see Step 4) |

Decision is recorded as one of the three literal strings above. No other values are valid.

## Step 6 — Render output (verb-specific)

### Verb = `deploy` → Decision = PASS

1. Read `templates/output-report.md`.
2. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`
   - `{{template_name}}`, `{{target_scope}}`
   - `{{freeze_windows_checked}}` — integer count of freeze windows evaluated
   - `{{exemption_status}}` — `present` if `scope_exempt = true`, otherwise `absent`
   - `{{simulated_deploy_mode}}` — `Incremental`
   - `{{simulated_deploy_status}}` — `Would-deploy (simulated — create_template_deployment not called in v1)`
3. Write rendered report to `exports/deploy-<run_id>.md`.
4. Return the rendered report. No other output.

### Verb = `deploy` → Decision = BLOCK

1. Read `templates/output-blocked.md`.
2. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`
   - `{{template_name}}`, `{{target_scope}}`
   - `{{freeze_window_start}}`, `{{freeze_window_end}}`, `{{freeze_severity}}` — from first matching ACTIVE window
   - `{{freeze_scopes_matched}}` — comma-separated list of matched scopes
3. Write rendered report to `exports/blocked-<run_id>.md`.
4. Return the rendered report. No other output.

### Verb = `override` → Decision = OVERRIDE_ALLOW

1. Read `templates/output-override.md`.
2. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`
   - `{{template_name}}`, `{{target_scope}}`
   - `{{freeze_window_start}}`, `{{freeze_window_end}}`, `{{freeze_severity}}`
   - `{{cr_id}}`, `{{justification}}`, `{{principal}}`
   - `{{simulated_deploy_status}}` — `Would-deploy (simulated — create_template_deployment not called in v1)`
   - `{{audit_log_json}}` — the JSON audit entry (see agent hard rule #8)
3. Append the audit log JSON line to `exports/override-audit.log` (create if missing).
4. Write rendered report to `exports/override-<run_id>.md`.
5. Return the rendered report. No other output.

### Verb = `status`

1. If a `deployment_name` was supplied, call `get_arm_template_deployment_status` with that
   deployment name and the subscription from the runbook.
2. Report current freeze window status:
   - List all `freeze_windows` from the runbook (sorted by `start_utc` ascending).
   - For each window, indicate whether it is ACTIVE, UPCOMING, or PAST relative to `current_utc`.
3. Return a plain markdown status block. No template file required. No exports written.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error and continue.
- Empty result from R001: abort with `ABORT: target scope not resolvable — R001 returned no rows`.
- If `rules.yaml` cannot be read: abort with `ABORT: rules.yaml unreadable`.

## Output contract

- The first H1 line of every deploy report is exactly:
  `# Change-Freeze Enforcer — Deployment Cleared` (PASS) or
  `# Change-Freeze Enforcer — Deployment Blocked` (BLOCK) or
  `# Change-Freeze Enforcer — Override Approved` (OVERRIDE_ALLOW).
- Section order is frozen per each template.
- Every PASS and BLOCK run writes exactly one file to `exports/`.
- Every OVERRIDE_ALLOW run writes one report file and appends one line to `exports/override-audit.log`.
