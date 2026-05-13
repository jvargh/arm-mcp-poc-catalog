---
name: blast-radius-simulator
description: Deterministic procedure to parse an ARM template, project user-facing blast radius via ARG queries, and emit a fixed-format simulation report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `simulate` (default), `drilldown <category>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `template_path`,
   `impact_categories[]`, `risk_score_weights{}`, `deploy_strategy_recommendations{}`.
3. Read `skills/blast-radius-simulator/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "BLAST-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Parse target template

1. Read the ARM template file at `template_path` (relative to workspace root).
   If the file cannot be read, abort with the literal message:
   `ABORT: template_path not set in runbook or file not found at <path>`.
2. Extract from `resources[]`: resource types (`type`), resource names (`name`), and
   API version (`apiVersion`). Build a deduplicated `change_set` list of
   `{type, count}` entries.
3. Record `template_resource_count` (total resources in template) and
   `template_resource_types` (comma-separated list of distinct types).
4. Determine `change_type`: `add-only` if no existing resources in ARG match template
   resource names; `update` if ARG returns matching resources; `mixed` otherwise.
   Use ARG `execute_query` results from Step 3 to resolve — do not guess.

## Step 3 — Run ARG impact queries (fixed loop)

For each `rule` in `rules.yaml` **in file order** (R001 → R005):

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Call `validate_query` with `query = rule.kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
3. Call `execute_query` with the same arguments.
4. For R004 specifically: if `execute_query` returns an empty result set OR returns an
   error containing "table not found" / "AuthorizationResources" → record
   `status: SKIPPED`, `reason: authorizationresources-unavailable`, and continue.
5. Record per rule: `{rule_id, category, category_weight, affected_resource_count,
   affected_resource_ids[], status}`.

## Step 4 — Impact classification (R001–R005 in rule_id order)

For each rule result (in R001 → R005 order), map to impact category:

| Rule ID | Category | Impact type |
|---|---|---|
| R001 | dns_endpoint | DNS / endpoint disruption (Front Door, App Gateway, custom domains) |
| R002 | identity_rotation | Managed identity rotation (identities referenced elsewhere) |
| R003 | cert_regen | Certificate regeneration (Key Vault certs referenced by services) |
| R004 | rbac | RBAC disruption (role assignments affected) — skip_if_unavailable |
| R005 | dependency_edge | Dependency edge disruption (shared VNet, NSG, private DNS dependencies) |

`category_weight` for each category is read from `risk_score_weights` in the runbook.
`category_risk = category_weight × affected_resource_count`.

## Step 5 — Risk score + strategy recommendation

1. `risk_score = sum(category_weight × affected_resource_count)` for all non-SKIPPED rules.
   Integer. No decimals.
2. Determine `risk_level`:
   - `risk_score < deploy_strategy_recommendations.low_threshold` → `low`
   - `risk_score < deploy_strategy_recommendations.medium_threshold` → `medium`
   - Otherwise → `high`
3. Look up `recommended_strategy = deploy_strategy_recommendations.strategies[risk_level]`
   from the runbook. Pure map lookup — do not interpret or override.

## Step 6 — Render output (mode-specific)

### Mode = `simulate`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{template_path}}`, `{{template_resource_count}}`,
     `{{template_resource_types}}`, `{{change_type}}`.
   - `{{impact_table}}` — one markdown row per rule, sorted **descending by `category_risk`**,
     ties broken by `rule_id` ascending. Include `STATUS=SKIPPED` rows at the bottom.
   - `{{dependency_edges_block}}` — bulleted list of R005 resource dependency pairs
     (resource name → dependency type). If R005 was SKIPPED or returned zero rows,
     emit `_No dependency data available._`.
   - `{{total_risk_score}}`, `{{risk_level}}`, `{{recommended_strategy}}`.
3. Write rendered report to `exports/blast-radius-<scope>-latest.md`.
4. Print the rendered report. Nothing else.

### Mode = `drilldown <category>`

1. Read `templates/output-drilldown.md`.
2. Re-render only the rule matching `<category>`. Include verbatim KQL, affected resource
   IDs (first 25), and `category_risk` sub-total.
3. Substitute, print. No file write.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with error and continue.
- Empty result set: `affected_resource_count = 0`; still include the row in the impact table.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.
- If `template_path` is missing or file not found, abort:
  `ABORT: template_path not set in runbook or file not found at <path>`.

## Output contract

- The first H1 line of every simulation report is exactly: `# Blast-Radius Simulation Report`.
- Section order is exactly: Header → Template Summary → Impact by Category → Dependency Edges → Risk Assessment → Footer.
- `risk_score` is always an integer (no decimals).
- Sort of impact table: descending by `category_risk`, ties by `rule_id` ascending.
