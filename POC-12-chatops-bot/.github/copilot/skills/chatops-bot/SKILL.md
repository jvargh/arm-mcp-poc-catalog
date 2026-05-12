---
name: chatops-bot
description: Deterministic procedure to answer Azure resource questions via pre-canned ARG query categories, in read-only mode, with audit logging.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `ask` (default) or `audit`.
- `question`: free-text question from the user (for `ask` verb only).

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If `<scope>.values.yaml`
   is missing, abort with:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `read_only_mode` (MUST be `true` — if
   not, abort with `ABORT: read_only_mode must be true for chatops-bot`),
   `audit_log_path`, `allowed_question_categories[]`.
3. Read `skills/chatops-bot/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "CHAT-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Match question to category (ask verb only)

1. Map the user's free-text question to the best-matching rule `id` from `rules.yaml`
   using keyword matching (do NOT use LLM reasoning beyond simple keyword lookup against
   `id`, `title`, and `category` fields):
   - "storage account" / "storage accounts" → R001 (if counting by type) or R003 (if filtering by tag)
   - "region" / "location" / "by region" → R002
   - "tag" / "tagged" → R003
   - "sql" / "database" / "databases" / "tier" → R004
   - "subscription" / "by subscription" / "count by sub" → R005
   - "vm" / "virtual machine" / "compute" → R001 or R002 depending on question
   - Default fallback: R001 (count by type)
2. Check that the matched `id` is in `runbook.allowed_question_categories`. If not,
   output `STATUS=BLOCKED REASON=category-not-in-allowed-list CATEGORY=<id>` and stop.
3. Load the matched rule's `kql` verbatim.

## Step 3 — Execute query (NO validate step — ratification #7)

> ⚠️ `validate_query` is intentionally skipped per ratification #7. See README.md
> `## Determinism Deviation` for rationale.

1. Call `generate_query` with:
   - `intent`: the matched rule's `title`
   - `subscriptions`: from runbook
   - The tool returns a KQL string. **Discard this output entirely.** Use the verbatim
     `kql` from `rules.yaml` instead (the tool call is for budget/audit compliance only).
2. Call `execute_query` with:
   - `query`: the **verbatim** `kql` from `rules.yaml`
   - `subscriptions`: from runbook
3. Collect result rows. If the query errors, record `row_count = -1` and `error = <message>`.

## Step 4 — Write audit log line

Append **one** JSON line to `runbook.audit_log_path`:

```json
{"timestamp_utc":"<ISO8601>","user":"<upn-from-az-login>","question":"<raw question>","kql_generated":"<verbatim kql used>","row_count":<int>,"run_id":"<run_id>"}
```

On error add `"error":"<message>"` and set `row_count` to `-1`.
The file is append-only. Never truncate.

## Step 5 — Render output

### Verb = `ask`

1. Read `templates/output-report.md`.
2. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix)
   - `{{question}}` — the user's raw question
   - `{{rule_id}}`, `{{rule_title}}`, `{{rule_category}}`
   - `{{results_table}}` — markdown table of result rows, sorted descending by `count`
     (for aggregation queries) or ascending by `id` (for list queries)
   - `{{row_count}}` — integer
3. Print the rendered report. Nothing else.

### Verb = `audit`

1. Read `templates/output-audit.md`.
2. Read `runbook.audit_log_path` (all lines), parse each as JSON.
3. Substitute placeholders literally:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`
   - `{{audit_table}}` — markdown table rows sorted descending by `timestamp_utc`.
     Columns: `timestamp_utc`, `user`, `question`, `rule_matched`, `row_count`, `run_id`.
4. Print the rendered report. Nothing else.

## Failure handling

- ARM MCP timeouts: do not retry; write audit log line with `row_count: -1`, report error inline.
- Empty result set: query executed successfully; `row_count = 0`; render an empty results table.
- If `rules.yaml` cannot be read, abort with: `ABORT: rules.yaml unreadable`.
- If `audit_log_path` is not writable, abort with: `ABORT: audit_log_path not writable — check runbook.audit_log_path`.

## Output contract (what callers can rely on)

- The first H1 line of every `ask` response is exactly: `# ChatOps Bot Response`.
- The first H1 line of every `audit` response is exactly: `# ChatOps Audit Log`.
- Section order for `ask`: Header → Question → Rule Matched → Results → Footer.
- Section order for `audit`: Header → Summary → Audit Table → Footer.
- Every query appends exactly one line to the audit log.
