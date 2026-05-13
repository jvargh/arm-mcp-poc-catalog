---
name: preflight-safety
description: Deterministic procedure to evaluate ARG health preconditions before an ARM deployment and emit a fixed-format preflight-results report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `preflight` (default), `deploy`, `status`.
- `template_file`: path to the ARM template file to deploy (required for `deploy` verb).
- `parameters_file`: path to the ARM parameters file (required for `deploy` verb).

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If
   `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `rg_include[]`, `rg_exclude[]`
   - `deployment_target_rg` (resource group for the deploy)
   - `preflight_rules_per_env` (map of env name → list of rule_ids to run; defaults to all rules)
   - `force_deploy_flag` (boolean; default false)
   - `preflight_timeout_seconds` (integer; default 30)
   - `quota_limits` (map for R005 comparison; see ratification #6)
3. Read `skills/preflight-safety/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "PRE-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. Determine the active rule list: if `preflight_rules_per_env[scope]` is set, use that
   list; otherwise use all rules in file order. Sort the active list by rule_id
   ascending (R001, R002, … R009).
6. Record `start_time` in UTC.

## Step 2 — Preflight battery (rule_id order)

For each `rule` in the active rule list **in rule_id order**:

1. **Time-budget check:** if `(now - start_time) >= preflight_timeout_seconds`, record
   all remaining rules as `STATUS=TIMEOUT` and break out of the loop.
2. If `rule.kql` is missing → record `STATUS=SKIPPED REASON=no-kql` and continue.
3. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `STATUS=INVALID`, store error message, continue to next rule.
4. Call `execute_query` with the same arguments.
   - If `skip_if_unavailable: true` AND the response is an error containing
     "table not found" / "table unavailable" OR the result set is empty with an
     error indicator → record `STATUS=SKIPPED REASON=<error>` and continue.
5. Evaluate the result:
   - **0 rows returned** → `STATUS=PASS`
   - **≥ 1 rows returned** → `STATUS=FAIL`, store `failing_resource_count` and
     up to the first 25 `id` values.
   - For R005 (quota): compare `currentCount` per `(subscriptionId, location, resourceType)`
     against the matching entry in `runbook.quota_limits`. If `currentCount >=
     quota_limit * 0.9` (90 % threshold) → FAIL. If `quota_limits` not configured →
     SKIPPED.
6. Record `(rule_id, title, severity, status, failing_resource_count, remediation_hint)`.

## Step 3 — Decision (PASS / FAIL / FORCE+AUDIT)

1. Aggregate results:
   - `checks_pass` = count of PASS
   - `checks_fail` = count of FAIL
   - `checks_skip` = count of SKIPPED + INVALID + TIMEOUT
2. **Decision logic:**
   - If `checks_fail == 0` → decision = `PASS — DEPLOY ALLOWED`
   - If `checks_fail > 0` AND `runbook.force_deploy_flag == false` →
     decision = `FAIL — DEPLOY BLOCKED`
   - If `checks_fail > 0` AND `runbook.force_deploy_flag == true` →
     decision = `FORCE — DEPLOY WITH AUDIT WARNING`
     Emit: `⚠️ AUDIT WARNING: force_deploy_flag=true overrides ${checks_fail} FAIL(s).`
     Write a timestamped audit entry to `exports/audit-<run_id>.md` (see Step 4 c).

## Step 4 — Render output (verb-specific)

### (a) Verb = `preflight`

1. Read `templates/output-preflight-results.md`.
2. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`,
     `{{preflight_timeout_seconds}}`, `{{checks_pass}}`, `{{checks_fail}}`,
     `{{checks_skip}}`, `{{decision}}`
   - `{{preflight_results_table}}` — one row per rule in rule_id order with columns:
     `Rule ID | Title | Severity | Status | Failing Resources | Remediation Hint`
3. Print the rendered report. Nothing else.

### (b) Verb = `deploy`

1. Require that the `preflight` step has already been run this session, or re-run it.
2. If decision is `FAIL — DEPLOY BLOCKED` → print the block message and stop.
   Do not proceed with deployment.
3. If decision is `PASS` or `FORCE`:
   - Read `templates/output-report.md`.
   - Substitute placeholders: `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`,
     `{{decision}}`, `{{template_file}}`, `{{parameters_file}}`,
     `{{deployment_target_rg}}`, `{{preflight_results_table}}`.
   - Append a "Would deploy (NOT EXECUTED in v1)" section showing the template file
     path, parameters file path, target resource group, and scope.
   - **Do NOT call `create_template_deployment`** — render the outcome locally.
   - Print the rendered report.

### (c) Audit entry (force-deploy path only)

Write `exports/audit-<run_id>.md`:

```
# Audit Entry — Force Deploy
run_id: <run_id>
timestamp_utc: <generated_utc>
scope: <scope>
force_deploy_flag: true
checks_fail_count: <checks_fail>
justification: <user-supplied justification from prompt>
failed_rules: <comma-separated list of FAIL rule_ids>
```

### (d) Verb = `status`

1. Call `get_arm_template_deployment_status` with the deployment name from the last
   `deploy` run (stored in context or passed as input).
2. Print status rows: `deployment_name`, `status`, `timestamp`, `error` (if any).

## Failure handling

- ARM MCP timeouts: record the rule as `INVALID` with the timeout error and continue.
- Empty result set (no error): rule PASSES — return 0 rows means no violations found.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.
- If `preflight_timeout_seconds` budget is exhausted, mark remaining rules `TIMEOUT`
  and emit a budget-exceeded warning in the report.

## Output contract (what callers can rely on)

- The first H1 line of every preflight-results report is exactly:
  `# Pre-flight Deployment Safety Check`.
- Check rows are always in rule_id ascending order (R001 first).
- Decision line is always the last non-footer line before the separator.
- Every force-deploy run writes exactly one audit entry to `exports/`.
