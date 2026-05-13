---
name: slo-deployment-gate
description: Deterministic procedure to evaluate SLO error budget for a target service and emit an ALLOW or BLOCK deployment gate decision.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `service`: name of the target service to gate (matches `slo_service` tag in ARG).
- `template`: path to the ARM template the user wants to deploy (relative to workspace root).
- `mode`: one of `gate` (default), `deploy` (gate + would-deploy on ALLOW), `status` (check last gate result).

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If `<scope>.values.yaml`
   is missing, abort with:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `slo_targets` (map of service →
   `{budget_threshold_pct, window_days, approval_required_below_pct}`),
   `budget_source`, `approval_timeout_minutes` (default 30),
   `block_on_active_incident` (default true).
3. Locate the `slo_targets` entry for `${service}`. If not found, abort with:
   `ABORT: service '${service}' not in runbook slo_targets — add it to prod.yaml`.
4. Read `skills/slo-deployment-gate/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
5. Compute `run_id = "SLO-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Evaluate rules (fixed loop, generate_query → execute_query)

> **NOTE (ratification #7):** `validate_query` is NOT in the tool allowlist.
> Go directly: `generate_query` → `execute_query`. Do not call `validate_query`.

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Substitute `${service}` placeholder in `rule.kql` with the input `service` name,
   and `${subscriptions}` with the subscription list from the runbook.
3. Call `generate_query` with `query_text = rule.kql`, `subscriptions = runbook.subscriptions`.
   - If `generate_query` returns an error → record `status: INVALID`, store the error, continue.
4. Call `execute_query` with the query returned by `generate_query` (or the raw KQL if
   `generate_query` returns the input unchanged).
   - If `execute_query` errors → record `status: INVALID`, store error.
   - If `execute_query` returns empty result AND `rule.skip_if_unavailable == true`
     → record `status: SKIPPED REASON=resourcechanges-unavailable` and continue.
5. Store the result rows keyed by `rule_id`.

## Step 3 — SLO budget evaluation (external dependency)

> **KEY LIMITATION:** SLO error budget percentage is **NOT directly queryable via ARG**.
> ARG can locate the App Insights / Log Analytics workspace resource (R001) and read
> tags/properties (R002), but **cannot read metric values** such as error rate or
> availability percentage. The actual budget % must come from an external source.
>
> **v1 behaviour:** read the budget value from `slo_targets.<service>.simulated_budget_pct`
> in the runbook. This is a hardcoded test value for PoC purposes.
> **Production wiring:** replace with an Azure Monitor query, Prometheus scrape, or
> external SLO platform API call — outside the scope of this ARM MCP PoC.

1. If R001 returned zero rows → `workspace_resource_id = null`.
   Gate emits `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics WORKSPACE=null`.
   Decision = BLOCK (fail-closed: cannot evaluate budget without workspace).
2. If R001 returned rows → record `workspace_resource_id` = first row's `id`.
3. If R002 `budget_tag_pct` column is non-empty → use that value as `budget_pct`.
   Else → read `budget_pct` from `slo_targets.<service>.simulated_budget_pct`.
   Emit `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics WORKSPACE=<id>` to
   indicate that live metric value is not available via ARG.
4. `budget_threshold_pct` = `slo_targets.<service>.budget_threshold_pct`.
5. Gate decision (deterministic):
   - `budget_pct > budget_threshold_pct` → `DECISION=ALLOW`
   - `budget_pct ≤ budget_threshold_pct` → `DECISION=BLOCK`
   - Timeout (no response within `approval_timeout_minutes`) → `DECISION=BLOCK (TIMEOUT)`

## Step 4 — Active incident check (R003)

1. If R003 returned any rows AND `block_on_active_incident == true`:
   - Downgrade decision to BLOCK (active incident), regardless of budget.
   - Populate `incident_warning` in the output template.
2. If R003 `skip_if_unavailable` triggered → record `STATUS=SKIPPED REASON=resourcechanges-unavailable`.

## Step 5 — Bypass path

1. If `DECISION=BLOCK` and the user provides a bypass command with a valid
   `CR-XXXXXX` or `INC-XXXXXX` reference:
   - Validate that the reference string matches pattern `^(CR|INC)-[0-9]{6}$`.
   - If valid: override decision to `ALLOW (BYPASS)`.
   - Write one JSON line to `exports/bypass-audit.jsonl`:
     ```json
     {"timestamp_utc":"<ISO8601>","service":"<service>","budget_pct":<n>,"cr_or_incident_ref":"<ref>","approver":"<copilot-user>","run_id":"<run_id>"}
     ```
   - If invalid → reject bypass, keep DECISION=BLOCK.

## Step 6 — Render output (mode-specific)

### Mode = `gate`

1. Read `templates/output-gate-result.md`.
2. Substitute placeholders literally:
   `{{run_id}}`, `{{scope}}`, `{{service}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`,
   `{{budget_pct}}`, `{{budget_threshold_pct}}`, `{{window_days}}`,
   `{{decision}}`, `{{workspace_resource_id}}`, `{{slo_status_row}}`,
   `{{incident_warning}}` (empty string if no active incidents),
   `{{bypass_ref}}` (empty string if not a bypass).
3. Write rendered gate result to `exports/gate-<run_id>.md`.
4. Print the rendered gate result. Nothing else.

### Mode = `deploy` (gate + would-deploy simulation)

1. Run the full `gate` mode flow first.
2. If `DECISION=BLOCK` or `DECISION=BLOCK (TIMEOUT)`:
   - Print the gate result with BLOCK notice. Stop. Do not simulate deploy.
3. If `DECISION=ALLOW` or `DECISION=ALLOW (BYPASS)`:
   - Read `templates/output-report.md`.
   - Substitute: `{{run_id}}`, `{{scope}}`, `{{service}}`, `{{generated_utc}}`,
     `{{template_path}}`, `{{decision}}`, `{{budget_pct}}`.
   - **MUST NOT actually call `create_template_deployment` in v1.**
     Write a `## Would-Deploy Notice` section confirming what would have been deployed.
   - Append `{{would_deploy_command}}` = the `create_template_deployment` call that
     *would* be made (template path + parameters), formatted as a code block.
   - Write rendered report to `exports/report-<run_id>.md`.
   - Print the rendered report.

### Mode = `status`

1. Read `templates/output-gate-result.md`.
2. Look for the most recent `exports/gate-<run_id>*.md` for this scope + service.
3. Print it. If none found, emit `STATUS=NO_PRIOR_GATE_RUN`.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` and continue.
- Empty result set on non-skip rule: rule passes — record zero failing resources.
- If `rules.yaml` cannot be read: abort with `ABORT: rules.yaml unreadable`.
- If `slo_targets` entry missing: abort (see Step 1).

## Output contract

- The first H1 line of every gate result is exactly: `# SLO Deployment Gate Result`.
- The first H1 line of every deploy report is exactly: `# SLO Deployment Gate — Deploy Report`.
- Decision line format: `**Decision:** ALLOW` or `**Decision:** BLOCK` (or with suffix).
- Every run writes exactly one file to `exports/`.
