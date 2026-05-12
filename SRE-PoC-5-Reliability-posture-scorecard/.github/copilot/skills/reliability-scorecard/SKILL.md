---
name: reliability-scorecard
description: Deterministic procedure to evaluate Azure workloads against a fixed reliability rule pack and emit a fixed-format markdown report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `scorecard` (default), `drilldown <workload>`, `remediate`.

## Step 0 — Preflight

1. **Auth check (non-ARG).** Either confirm the MCP server reports a healthy session,
   or run `az account show` for the CLI fallback. Do **not** synthesize a probe ARG
   query — that would violate "never invent ARG queries".
   On failure, abort with: `ABORT: Azure auth missing — sign in with az login or initialize the ARM MCP session`.
2. **Output dirs.** Ensure `exports/` and `exports/_run/` exist; create if missing.
3. **Transport selection.** If `validate_query`/`execute_query` MCP tools are present in
   the runtime, use the MCP transport. Otherwise fall back to `az graph query` per
   agent Hard Rule 11. Record the chosen transport in the run manifest (Step 2.7).

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`.
3. **`workload_key` is pinned to `resourceGroup` in v1.** If the runbook specifies any
   other value, abort with: `ABORT: workload_key '<value>' not supported in v1 — use 'resourceGroup' (tag-based grouping is deferred to v2)`.
4. **`rg_include` / `rg_exclude` semantics** (formal): both lists hold case-insensitive
   **substring** patterns matched against the row's `resourceGroup` column.
   - A row is **kept** iff: (a) `rg_include` is empty OR at least one include pattern
     is a substring of the row's `resourceGroup` (case-insensitive), AND
     (b) no `rg_exclude` pattern is a substring of the row's `resourceGroup`.
   - `rg_exclude` always wins.
   - Rows whose `resourceGroup` is empty are dropped (counted as `dropped_rows` per rule).
5. Read `skills/reliability-scorecard/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`. If the file cannot be read,
   abort with: `ABORT: rules.yaml unreadable`.
6. Compute `run_id = "RPS-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
7. Compute `runbook_value_hash` = SHA-256 of the post-substitution runbook YAML
   (used in the run manifest, not the run_id).

## Step 2 — Evaluate every rule (fixed loop)

For each `rule` in `rules.yaml` **in file order**:

1. **Skip-on-missing.** If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. **Transport-collapse the KQL.** Replace runs of newlines/tabs with single spaces to
   produce `kql_t` (transported form). Pre-condition: the kql block contains no
   multi-line string literals and no `//` or `/* */` comments (the v1 rule pack
   satisfies this). Both validate and execute MUST use `kql_t` (never validate one
   form and execute another).
3. **Derive `expected_columns`** by parsing the final `| project ...` segment of
   `kql_t`: split each comma-separated term on `=` and take the left side as the
   column name (or the whole term if no `=`), trimming whitespace. Example:
   `project id, name, resourceGroup, sku=sku.name` → `{id, name, resourceGroup, sku}`.
4. **Validate.** Submit `kql_t` to `validate_query` (or to the CLI validate equivalent).
   On parse error → `status: INVALID`, `reason: parse-error`, continue.
5. **Execute, paginated.** Submit `kql_t` to `execute_query` with page size 1000.
   While the response carries a non-null `skip_token`, repeat with that token. Union
   all pages. On transport error or timeout → `status: INVALID`,
   `reason: transport-error`, continue (no retries).
6. **Result schema-shape sanity check.** For every returned row:
   - Row keys MUST equal `expected_columns` (no extras like `tags`, `properties`,
     `kind` — those signal a transport-mangled query that silently returned the full
     ARG resource shape). Mismatch → `status: INVALID`, `reason: result-schema-mismatch`,
     continue. **This is the strongest defense against the silent-wrong-data class of bug.**
   - `id` MUST be non-empty and start with `/subscriptions/`. Mismatch →
     `status: INVALID`, `reason: result-id-malformed`, continue.
7. **Cache raw rows.** Persist the **unfiltered, pre-grouping** result rows to
   `exports/_run/{run_id}/{rule_id}.json`. Append a manifest entry to
   `exports/_run/{run_id}/manifest.json` recording: `run_id`, `scope`,
   `ruleset_hash8`, `runbook_value_hash`, `subscriptions` (sorted),
   `workload_key`, `transport` (`mcp` or `cli`), and per-rule `{status, row_count,
   page_count, dropped_rows}`. Cached rows are pre-filter so downstream `rg_include`
   changes do not invalidate the cache.
8. **Apply `rg_include` / `rg_exclude`** per Step 1.4 against the `resourceGroup` column.
9. **Group by `resourceGroup`.** Record per workload: `{rule_id, weight, severity,
   failing_resource_count}` where `failing_resource_count` is the count of **distinct
   `id` values** in the workload's bucket (not the row count — multi-row finds like
   R009/R010/R012 must not double-count a single resource).

## Step 3 — Score every workload

For each workload that appears in any rule's results:
```
score = max(0, 100 - sum(rule.weight for each rule where failing_resource_count > 0))
```
Round to integer. Track `failed_rules` list and `top_gap` = highest-weight failed
rule_id (ties broken by ascending `rule_id`).

## Step 4 — Render output (mode-specific)

### Mode = `scorecard`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{rules_total}}`, `{{rules_evaluated}}`, `{{rules_skipped}}`, `{{rules_invalid}}`,
     `{{workloads_total}}`, `{{ruleset_hash8}}`.
   - `{{bottom10_table}}` — markdown rows sorted ascending by `score`, ties by `workload` ascending. Limit to 10 rows. If fewer than 10 workloads, list all.
   - `{{failing_checks_table}}` — one row per rule with `failing_resource_count > 0`,
     sorted descending by `weight`, ties by `rule_id`.
   - `{{top3_gaps_block}}` — three subsections for the three rule_ids with highest
     `(weight × failing_resource_count)`. Ties broken by `rule_id` ascending. If fewer than three
     gap rule_ids exist, list as many as exist.
3. **Persist outputs:**
   - Overwrite `exports/scorecard-{scope}-latest.md` with the rendered report.
   - Overwrite `exports/{run_id}.md` with the same content.
4. **Trend CSV upsert.** File: `exports/scorecard-trend.csv`. Header (create if missing):
   `run_id,generated_utc,scope,ruleset_hash8,workloads_total,avg_score,min_score,rules_failing`.
   If a row with the current `run_id` exists, **replace it in-place** (do not append a
   duplicate). Otherwise append. Output contract: exactly one row per `run_id`.
5. Print the rendered report and one final line confirming the CSV upsert. Nothing else.

### Mode = `drilldown <workload>`

**Snapshot semantics:** drilldown explains the **most recent scorecard snapshot** for the
current `(scope, ruleset_hash8)`. It does not re-query live Azure unless the cache is
missing or stale.

1. Locate the cache: `exports/_run/{run_id}/manifest.json` for the latest scorecard run
   matching the current `(scope, ruleset_hash8, runbook_value_hash post-filter)` — note
   that cache rows are pre-filter, so a `rg_include`/`rg_exclude` change since the
   scorecard run is safe.
2. If no usable cache exists for the current `(scope, ruleset_hash8)`, abort with:
   `ABORT: no scorecard snapshot available for this scope+ruleset — run @scorecard run for scope <scope> first`.
3. Read `templates/output-drilldown.md`.
4. From the cached per-rule rows, identify rules whose post-filter, post-grouping
   results include the requested workload. For each such rule, render: `rule_id`,
   `severity`, `weight`, `failing_resource_count` (distinct `id` count for this
   workload), the **verbatim multi-line KQL** from `rules.yaml` (NOT the transport-collapsed
   form — drilldown shows what's in the rule pack), and the first 25 distinct `id`
   values for this workload.
5. Persist to `exports/drilldown-{scope}-{workload}.md` (overwrite). Print. No CSV write.

### Mode = `remediate`

1. From the last `scorecard` run (locate via `exports/_run/<run_id>/manifest.json`;
   re-run a scorecard pass if no snapshot is found), pick the three rule_ids with the
   highest `(weight × failing_resource_count)`, ties by `rule_id` ascending.
2. For each pick, look up `rule.remediation_template`. If null, report
   "no template available for {{rule_id}}" and continue.
3. **Stop and ask the user to confirm each remediation by rule_id.** Do not deploy
   without explicit confirmation per rule.
4. On confirmation, call `create_template_deployment` with the template file at
   `remediation/<remediation_template>` and parameters drawn from the failing
   resource list. Use mode = `Incremental`.
5. Render `templates/output-remediation.md` with the deployment names + statuses.
   Persist to `exports/remediation-{run_id}.md` (overwrite). Print.

## Failure handling

INVALID reasons (rule is excluded from scoring, recorded in the manifest, and counted
in `rules_invalid`):
- `parse-error` — `validate_query` failed.
- `transport-error` — `execute_query` HTTP/timeout/auth failure.
- `result-schema-mismatch` — returned columns ≠ `expected_columns` (Step 2.6).
- `result-id-malformed` — at least one row's `id` is empty or not `/subscriptions/`-prefixed.
- `truncated` — pagination cap reached without draining `skip_token` (only if a hard
  cap is configured; default = no cap).

Other rules:
- Empty result set is **not** an INVALID — the rule passes for all workloads and is
  omitted from the failing-checks table.
- Do not retry on any failure mode.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.

## Output contract (what callers can rely on)

- The first H1 line of every scorecard report is exactly: `# Reliability Posture Scorecard`.
- The order of sections is exactly: Header → Summary → Bottom 10 → Failing Checks → Top 3 Gaps → Footer.
- The trend CSV has **exactly one row per `run_id`** (upsert semantics — re-runs replace
  the prior row in place).
- `exports/scorecard-{scope}-latest.md` always reflects the most recent run for that scope.
- `exports/{run_id}.md` is the immutable name-stamped copy of the same content.
- `exports/_run/{run_id}/` is the per-run cache: `{rule_id}.json` per rule (pre-filter
  raw rows) plus `manifest.json`. Drilldown reuses this; remediate reads from it.
- `failing_resource_count` is a **distinct `id` count** in every context (per-rule,
  per-workload, in the failing-checks table, and in the top-3 gaps math).
