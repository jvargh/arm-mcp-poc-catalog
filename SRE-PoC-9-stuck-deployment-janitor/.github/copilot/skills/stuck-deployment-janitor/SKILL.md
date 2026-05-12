---
name: stuck-deployment-janitor
description: Deterministic procedure to scan Azure scopes for stuck ARM deployments, classify each by cause, and offer per-deployment cancel with confirmation.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `scan` (default) or `cancel`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML. If `<scope>.values.yaml`
   is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]` → build `subscription_ids_csv` (comma-separated, quoted)
   - `rg_include[]` → build `rg_include_csv` if non-empty
   - `rg_exclude[]` → applied as post-query client filter
   - `auto_cancel_threshold_hours` (default `4`)
   - `expected_duration_by_type` (map of resource type → expected hours)
   - `known_slow_types` (list of resource types)
3. Read `skills/stuck-deployment-janitor/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "STUCK-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Build scope substitution tokens

Construct the following token strings that will be injected into each rule's `kql` field:

- `${subscription_filter}` →
  `| where subscriptionId in~ ('<sub1>','<sub2>',...)`
  (one entry per subscription from runbook; omit clause if list is empty)
- `${rg_filter}` →
  `| where resourceGroup in~ ('<rg1>','<rg2>',...)`
  (one entry per rg_include; omit clause entirely if rg_include is empty)
- `${threshold_hours}` → string value of `auto_cancel_threshold_hours`

**No other substitution is performed.** Do not add, remove, or rewrite any other part of the KQL.

## Step 3 — Execute queries (no validate step)

> **Determinism Deviation in effect:** `validate_query` is not in the tool allowlist.
> Proceed directly to `execute_query` for each rule.

For each `rule` in `rules.yaml` **in file order**:

1. Take `rule.kql` verbatim.
2. Substitute the three scope tokens (Step 2) into the KQL string as plain string replacement.
3. Call `execute_query` with `query = <substituted KQL>`, `subscriptions = runbook.subscriptions`.
4. If `execute_query` returns an error, record `rule_id: FAILED, error: <message>` and continue.
5. If result is empty, record `rule_id: NO_FINDINGS` and continue.
6. Store rows as `(rule_id, classification_reason, deployment_id, name, resourceGroup,
   subscriptionId, durationHours, detail)`.
7. Apply `rg_exclude` filter client-side: drop rows where `resourceGroup` matches any
   entry in `rg_exclude[]` (case-insensitive substring).

## Step 4 — Enrich with live status

For each unique deployment `id` found in Step 3 results:

1. Call `get_arm_template_deployment_status` with the deployment resource ID.
2. Merge the returned `provisioningState`, `timestamp`, and `statusMessage` into the
   working row. If the call fails, record `statusDetail: UNAVAILABLE`.
3. Classify priority using `expected_duration_by_type` from the runbook:
   - If deployment type matches a key in `expected_duration_by_type` and
     `durationHours > expected_duration_by_type[type]`, flag `over_expected: true`.
   - Otherwise `over_expected: false`.

## Step 5 — Build stuck-deployment table

Deduplicate rows: each deployment appears once. Classification priority (if a deployment
matches multiple rules):
1. `deleted-dependency` (actionable — likely stuck forever)
2. `quota-loop` (actionable — needs quota increase)
3. `genuinely-slow` (monitor — do not cancel prematurely)
4. `exceeded-threshold` (unknown — further investigation needed)

Sort: **descending by `durationHours`** (longest stuck first). Ties broken by
`name` ascending.

## Step 6 — Render output (verb = scan)

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{threshold_hours}}`, `{{total_stuck}}`, `{{total_actionable}}`,
     `{{total_genuinely_slow}}`, `{{total_unknown}}`.
   - `{{stuck_table}}` — one markdown row per stuck deployment, sorted per Step 5.
     Columns: `Rank | Name | ResourceGroup | Subscription | Duration (h) | Classification | Detail | Over Expected`.
3. Write the rendered report to `exports/stuck-<scope>-latest.md` (overwrite).
4. Print the rendered report and one line confirming the file write. Nothing else.

## Step 7 — Cancel flow (verb = cancel)

> This step is ONLY executed when the user explicitly invokes the `cancel` verb.

1. Re-run Step 3–5 (or use in-context results if within the same session and scope is unchanged).
2. Present the stuck-deployment table to the user. Ask which deployment(s) to cancel.
3. **For each deployment the user selects:**
   a. Display the confirmation prompt from `templates/output-cancel-confirmation.md`,
      substituting `{{deployment_name}}`, `{{resource_group}}`, `{{subscription_id}}`,
      `{{duration_hours}}`, `{{classification}}`.
   b. **Wait for explicit `yes` / `confirm` reply.** Any other reply = skip (do not cancel).
   c. On confirmation: call `cancel_arm_template_deployment` with the deployment resource ID.
   d. **Emit audit log line** (regardless of outcome):
      ```
      [AUDIT] CANCEL attempt — deployment: <name> rg: <rg> sub: <sub> duration: <h>h classification: <reason> outcome: <CONFIRMED|SKIPPED|ERROR> utc: <ISO8601>
      ```
   e. If the API call errors, log `outcome: ERROR error: <message>`. Do not retry.
4. After all selected deployments are processed, print a summary of actions taken.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `FAILED` with the error and continue.
- Empty result from `execute_query`: rule has no findings; continue.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- If `get_arm_template_deployment_status` fails for a deployment, continue with `statusDetail: UNAVAILABLE`.

## Output contract (what callers can rely on)

- The first H1 line of every scan report is exactly: `# Stuck Deployment Janitor Report`.
- Section order is fixed: Header → Summary → Stuck Deployments Table → Classification Key → Footer.
- Every cancel attempt emits exactly one `[AUDIT]` line.
- Sort is always descending by `durationHours`, ties by `name` ascending.
