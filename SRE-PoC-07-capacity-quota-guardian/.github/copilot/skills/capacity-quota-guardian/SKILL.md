---
name: capacity-quota-guardian
description: >
  Deterministic procedure to query Azure resource counts via ARG, compare against runbook quota
  limits, gate deploys, and suggest alternate regions. Uses generate_query → execute_query
  (no validate_query — see Determinism Deviation).
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `check` (default), `deploy <template-path>`, `status <deployment-name>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml` exists,
   parse it and substitute every `${key}` token with the corresponding value. Parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `quota_limits` map (resource_type → region → integer limit; or flat per-sub for storage_accounts)
   - `alternate_regions` map (primary_region → ordered fallback list, latency-tier order)
   - `headroom_threshold_pct` (default `80` if absent)
3. Read `skills/capacity-quota-guardian/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep the first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "QUOTA-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Query resource counts (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. Take the literal `kql` from the rule. Combine it with `subscriptions` from the runbook as
   scope context and call `generate_query` to produce the scope-injected final KQL string.
2. Call `execute_query` with the generated KQL and `subscriptions` list.
   - On ARM MCP error → record `status: QUERY_ERROR`, store error message, continue.
   - On empty result → record zero count for all regions; continue.
3. Store returned rows as `(rule_id, resource_type, sku, region, subscriptionId, current_count)`.

> **KEY LIMITATION:** Quota LIMITS are **not** available in ARG. Current *counts* come from
> ARG; *limits* are read from the runbook `quota_limits` map. Operators must keep
> `quota_limits` in sync with actual Azure subscription limits (use `az vm list-usage --location <region>`).

## Step 3 — Quota check (current vs limit from runbook)

For each row from Step 2:

1. Look up `limit = quota_limits[rule.resource_type][region]`. If absent → `LIMIT_UNKNOWN`.
2. Compute `usage_pct = round((current_count / limit) * 100, 1)`.
3. Determine `status`:
   - `usage_pct > headroom_threshold_pct` → `FAIL`
   - `LIMIT_UNKNOWN` → `LIMIT_UNKNOWN`
   - otherwise → `PASS`
4. Collect all rows into a single list.
5. **Sort the list descending by `usage_pct`** (rows with `LIMIT_UNKNOWN` sort last; ties broken
   by `resource_type` asc then `region` asc).

## Step 4 — Alternate region suggestion

For each row with `status = FAIL`:

1. Look up `alternate_regions[row.region]` in the runbook. If absent → no suggestion.
2. The fallback list is already sorted by latency tier (nearest first) — preserve that order.
3. Emit an alternate-region block:
   ```
   Resource: <resource_type> (<sku if applicable>) | Region: <region> | Usage: <usage_pct>%
   Suggested alternates (latency-tier order): <alt1>, <alt2>, ...
   ```
4. If no alternates are configured, emit: `No alternate regions configured for <region>.`

## Step 5 — Render output (verb-specific)

### Verb = `check`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{headroom_threshold_pct}}`.
   - `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_errored}}`.
   - `{{regions_checked}}`, `{{resource_types_checked}}`, `{{breach_count}}`.
   - `{{overall_result}}` → `FAIL` if any row is `FAIL`; `PASS` otherwise.
   - `{{quota_usage_table}}` — one row per (resource_type, region) sorted descending by
     `usage_pct`. Integer counts; percentages to 1 decimal.
   - `{{alternate_region_block}}` — one sub-block per FAIL row per Step 4.
   - `{{deploy_gate_decision}}` — `DEPLOY BLOCKED — resolve quota breaches before deploying.`
     if `FAIL`; `QUOTA PASS — deploy is permitted.` if all `PASS`.
3. Print the rendered report. Nothing else.

### Verb = `deploy <template-path>`

1. **Run the full `check` procedure (Steps 1–4) first.**
2. If any row has `status = FAIL`:
   - Read `templates/output-quota-check.md`.
   - Substitute `{{deploy_gate_decision}}` → `DEPLOY BLOCKED`.
   - Populate `{{quota_usage_table}}` and `{{alternate_region_block}}` from Step 3/4 results.
   - Print the rendered quota-check output and stop. **Do not proceed to deployment.**
3. If all rows are `PASS` (or `LIMIT_UNKNOWN`):
   - **MUST NOT call `create_template_deployment` in v1.**
   - Read the template file at `<template-path>` and print a `WOULD DEPLOY (NOT EXECUTED — v1 what-if)` block:
     ```
     Template: <template-path>
     Subscriptions: <subscriptions[]>
     Mode: Incremental
     Status: NOT EXECUTED — v1 is what-if only.
     ```
   - Print the quota-check summary showing all PASS rows.

### Verb = `status <deployment-name>`

1. Call `get_arm_template_deployment_status` with `deployment_name` and `subscriptions[0]`.
2. Print the raw status response as-is (no template).

## Failure handling

- ARM MCP errors: do not retry; record the rule as `QUERY_ERROR` and continue.
- Missing `quota_limits` entry: emit `LIMIT_UNKNOWN` for that row; do not block on it.
- If `rules.yaml` cannot be read: abort with `ABORT: rules.yaml unreadable`.
- If `prod.values.yaml` is missing: abort with the message in Step 1.

## Output contract

- First H1 of every check report is exactly: `# Capacity & Quota Guardian — Run Report`.
- Section order: Header → Summary → Quota Usage Table → Alternate Region Suggestions → Deploy Gate Decision → Footer.
- Every FAIL row has a corresponding alternate-region sub-block (even if empty).
