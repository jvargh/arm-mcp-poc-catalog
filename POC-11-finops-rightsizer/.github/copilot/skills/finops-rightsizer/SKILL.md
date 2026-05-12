---
name: finops-rightsizer
description: Deterministic procedure to scan Azure VMs for right-size opportunities, compute savings estimates, and (on explicit confirmation) deploy resize ARM templates.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `scan` (default), `drilldown <resource_name>`, `resize`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `target_environments[]` — environment tag values treated as right-size candidates
   - `target_sku` — default target SKU for oversized VMs (may be overridden per rule)
   - `savings_rate_per_sku` — map of SKU name → estimated monthly cost in USD (integer)
   - `freeze_active` — boolean; if `true`, no deployments are permitted
   - `freeze_windows[]` — list of ISO-8601 intervals; if the current UTC time falls
     within any window, treat `freeze_active` as `true`
3. Read `skills/finops-rightsizer/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "RSIZE-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Execute every rule (generate_query → execute_query)

> ⚠️ **No `validate_query` step.** This PoC does not include `validate_query` in its
> tool allowlist per ratification #7. Go directly to `generate_query` → `execute_query`.

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. If `rule.skip_if_unavailable == true`, be prepared to handle errors gracefully (see below).
3. Call `generate_query` with `query = rule.kql` (literal string from YAML),
   `subscriptions = runbook.subscriptions`. This returns the query ready for execution.
4. Call `execute_query` with the query returned by `generate_query`.
   - If an error or empty result occurs AND `rule.skip_if_unavailable == true` →
     record `STATUS=SKIPPED REASON=<rule.id>-data-unavailable` and continue.
   - On other errors → record `status: INVALID`, store error message, continue.
5. For each returned row, record: `{rule_id, resource_id, resource_name, resource_group,
   subscription_id, location, current_sku, weight}`.

## Step 3 — Compute savings estimates (fixed formula)

For each found resource:

1. Look up `current_sku_cost = runbook.savings_rate_per_sku[current_sku]`.
   If SKU not in map, set `current_sku_cost = 0` and mark `savings_est = UNKNOWN`.
2. Look up `target_sku_cost = runbook.savings_rate_per_sku[target_sku]`
   (use `runbook.target_sku` as default; rule may override with `rule.target_sku`).
3. Compute: `est_monthly_savings = (current_sku_cost - target_sku_cost) * 1`
   (one instance; multiply by count if query returns aggregate rows).
4. Compute total savings across all candidates.

## Step 4 — Render output (verb-specific)

### Verb = `scan`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{candidates_total}}`, `{{total_est_monthly_savings}}`, `{{ruleset_hash8}}`.
   - `{{candidates_table}}` — markdown rows sorted **descending by `est_monthly_savings`**,
     ties broken by **ascending `resource_name`**. Columns: `Rank`, `Resource`, `RG`,
     `Current SKU`, `Target SKU`, `Est. $/mo saved`, `Rule`.
   - `{{rules_summary_table}}` — one row per rule, columns: `Rule ID`, `Title`, `Weight`,
     `Candidates`, `Status`.
3. Write the rendered report to `exports/rightsizer-<scope>-latest.md`.
4. Print the rendered report and a confirmation line. Nothing else.

### Verb = `drilldown <resource_name>`

1. Read `templates/output-drilldown.md`.
2. Re-run only the rules that flagged this resource.
3. Substitute, print. No writes to exports.

### Verb = `resize`

1. From the most recent `scan` run (re-execute if not in context), retrieve the
   candidates list sorted per scan rules.
2. Present the **per-resource opt-in checklist** using this exact format for each candidate:
   ```
   [ ] resource_name (current_sku → target_sku, est. $X/mo saved)
   ```
   Sorted descending by `est_monthly_savings`, ties by ascending `resource_name`.
3. Ask the user to tick the boxes for resources they want to resize. Wait for explicit response.

## Step 5 — Confirm gate (resize verb only)

> This step is MANDATORY before any call to `create_template_deployment`.

1. **Check freeze flag:** Read `runbook.freeze_active`. Also check `freeze_windows` —
   if current UTC time falls within any listed window, treat `freeze_active` as `true`.
   If `freeze_active == true`:
   ```
   DEPLOY BLOCKED: freeze_active=true in runbook. No deployments permitted during freeze window.
   ```
   Abort.
2. **Check verb:** If the current verb is not `resize`, abort with:
   ```
   DEPLOY BLOCKED: create_template_deployment is only permitted for the resize verb.
   ```
3. **Check confirmation:** If the user has not explicitly confirmed specific resources
   (ticked checklist items), abort with:
   ```
   DEPLOY BLOCKED: no resources confirmed. Present checklist and await per-resource opt-in.
   ```
4. **Final confirmation prompt:** After checklist opt-in, present a summary of resources
   to resize and their target SKUs. Ask: `Confirm resize of N resource(s)? Type YES to proceed.`
   If response is not exactly `YES`, abort.
5. Only on `YES` response: proceed to Step 6.

## Step 6 — Deploy (resize verb only, post-confirm gate)

For each confirmed resource:

1. Load `remediation/resize-vm.json`.
2. Call `create_template_deployment` with:
   - `template`: contents of `resize-vm.json`
   - `parameters`: `{ vmName: resource_name, targetSku: target_sku, resourceGroupName: resource_group }`
   - `mode`: `Incremental`
   - `deploymentName`: `rsize-{resource_name}-{YYYYMMDD}`
3. Call `get_arm_template_deployment_status` to poll until `Succeeded` or `Failed`.
4. Render `templates/output-remediation.md` with deployment results.

## Failure handling

- ARM MCP timeouts: do not retry; record rule as `INVALID` with error and continue.
- Empty result set for a rule: rule finds no candidates; include it in rules summary as `Candidates=0`.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- If `savings_rate_per_sku` map is missing from runbook, abort with:
  `ABORT: savings_rate_per_sku missing from runbook — required for savings estimates`.

## Output contract (what callers can rely on)

- The first H1 line of every scan report is exactly: `# FinOps Right-sizer Report`.
- Section order is exactly: Header → Summary → Candidates → Rules Summary → Footer.
- Sort order: candidates descending by `est_monthly_savings`, ties by `resource_name` ascending.
- Checklist format: `[ ] resource_name (current_sku → target_sku, est. $X/mo saved)`.
- Every emitted scan run writes exactly one `exports/rightsizer-<scope>-latest.md`.
