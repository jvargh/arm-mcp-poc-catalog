---
name: estate-cartographer
description: Deterministic procedure to map an Azure estate across subscriptions, render a hierarchical Mermaid/Markdown diagram with a high-risk overlay, and emit a fixed-format report.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `map` (default), `drilldown <resource-id>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If `<scope>.values.yaml`
   is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `management_group` (optional), `subscriptions[]`,
   `max_subscriptions` (default 10), `mermaid_max_nodes` (default 200).
3. Read `skills/estate-cartographer/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "MAP-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Discover estate (fixed rule loop with paging)

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Inject the scope filter into the KQL via string substitution:
   - `{{subscriptions_filter}}` → a KQL `| where subscriptionId in ({csv-of-sub-ids})` clause.
     If `management_group` is set and `subscriptions[]` is empty, discover subscriptions
     under the MG first using R001 before injecting.
   - `{{management_group}}` → the MG ID string, if present.
3. **Paging loop** — repeat until `$skipToken` is absent:
   a. Call `execute_query` with the current KQL and `$skipToken` (omit on first call).
   b. Accumulate returned rows into `rule.rows[]`.
   c. If the response carries a `$skipToken`, loop back with that token.
   d. If row count already reached `max_subscriptions * 1000`, stop and record
      `status: PAGED_TRUNCATED`.
4. If `execute_query` returns an error, record `status: INVALID` and continue.
5. Record per rule: `{rule_id, row_count, rows[], status}`.

> **Paging note (R003 in particular):** Large estates may return >1000 resources.
> The `$skipToken` loop in step 3 handles this transparently. Do not truncate silently.

## Step 3 — Build the estate model (in-memory, no LLM judgement)

From the accumulated rows:

1. **Subscriptions list** (from R001 rows): sort alphabetically by `displayName`.
   Apply `max_subscriptions` cap — take first N alphabetically; record cap if applied.
2. **Resource groups** (from R002 rows): bucket by `subscriptionId`, sort each bucket
   alphabetically by `name`.
3. **Resources** (from R003 rows): bucket by `resourceGroup`, sort each bucket by
   `type` ascending then `name` ascending.
4. **Relationships** (from R004 + R005 rows): build an edge list
   `{source_id, target_id, rel_type}` where `rel_type ∈ {NSG_PROTECTS_SUBNET, MI_ACCESSES_KV}`.
5. **High-risk overlay** (from R006 + R007 rows): tag each affected resource
   with `risk: high` and a `risk_reason` string.
6. **Mermaid node IDs:** derive each node ID as `sha256(resourceId_lower)[:8]` — deterministic,
   no random suffixes. If two resources collide (extremely unlikely), append `_1`, `_2`.

## Step 4 — Render output (mode-specific)

### Mode = `map`

1. Read `templates/output-report.md`.
2. Build the Mermaid `flowchart TD` block:
   - Emit subscription nodes first (sorted as per Step 3.1).
   - Under each sub, emit RG nodes (sorted as per Step 3.2).
   - Under each RG, emit resource nodes (sorted as per Step 3.3), labelled with
     `type/name`.
   - Emit relationship edges from the edge list.
   - Annotate high-risk nodes with a `:::highRisk` class tag.
   - Stop adding nodes when `mermaid_max_nodes` is reached; emit the notice.
3. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{subscriptions_total}}`, `{{rg_total}}`,
     `{{resources_total}}`, `{{relationships_total}}`, `{{high_risk_total}}`.
   - `{{mermaid_diagram}}` — the Mermaid block from step 2.
   - `{{high_risk_table}}` — one row per high-risk resource, sorted by `subscriptionId`
     then `resourceGroup` then `name` ascending.
   - `{{relationships_table}}` — one row per edge, sorted by `rel_type` then `source_id`.
4. Write rendered report to `exports/map-<scope>-latest.md`.
5. Print the rendered report. Nothing else.

### Mode = `drilldown <resource-id>`

1. Read `templates/output-drilldown.md`.
2. Re-execute only R004 and R005 scoped to the target resource ID to refresh relationship data.
   Use the same paging pattern.
3. Substitute placeholders and print. No export write.

## Failure handling

- ARG timeouts: record `status: INVALID`; continue with next rule.
- Empty result set from R001: abort with `ABORT: no subscriptions found in scope`.
- If `rules.yaml` cannot be read, abort with `ABORT: rules.yaml unreadable`.
- If `mermaid_max_nodes` cap is hit, emit the warning inline; do not abort.

## Output contract (what callers can rely on)

- The first H1 line of every map report is exactly: `# Azure Estate Map`.
- Section order is fixed: Header → Summary → Mermaid Diagram → High-Risk Overlay → Relationships → Footer.
- Mermaid node IDs are deterministic: same inputs → same IDs → same diagram.
- Sort orders are pinned (Step 3). Same inputs → byte-near-identical output.
