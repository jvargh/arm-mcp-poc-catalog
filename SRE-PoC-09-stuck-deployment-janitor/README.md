# Stuck Deployment Janitor (ARM MCP PoC — SRE-PoC-9)

A Copilot CLI / VS Code chat agent that finds ARM deployments stuck in `Running` state
past their expected duration, classifies the cause using a fixed rule pack, and offers
cancel with explicit per-deployment confirmation.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## Purpose

Stuck ARM deployments are a quiet but expensive class of incident: a
`Microsoft.Resources/deployments` row sits in `Running` for hours (sometimes days),
blocking subsequent deploys against the same scope and burning quota on any
half-provisioned resources. Operators usually find them by accident — when a
*different* deploy fails — and then manually triage each one: was a dependency
deleted, did we hit quota, or is this one of the resource types that *legitimately*
takes 4–12 hours? Different on-callers reach different cancel-vs-wait decisions
from the same evidence.

This PoC is a **deterministic Copilot agent** that turns that triage into a
reviewable artifact. It runs four pre-canned ARG queries — one to find every
deployment past a configurable threshold and three to classify *why* — dedupes
to one row per deployment, and renders a single Markdown report sorted descending
by duration. The same agent gates the `cancel` verb: each per-deployment cancel
needs an explicit `yes` from the operator, and every attempt is recorded in a
one-line `[AUDIT]` log entry.

**Audience:** SREs and platform engineers responsible for Azure deployment hygiene
who want a deterministic, diffable triage report and a confirmation-gated cancel
flow that is safe to run from chat.

## Intended end state

After you have configured `runbooks/prod.values.yaml` (your sub ID + RG include
list) and tuned `auto_cancel_threshold_hours`, `expected_duration_by_type`, and
`known_slow_types` in `prod.yaml` to match your fleet, a healthy steady state
looks like:

- Running `scan for scope prod` produces a report at `exports/stuck-<scope>-latest.md`
  with `Total stuck deployments found = 0` and an empty table block. **That is the
  desired outcome.** The agent still runs all four rules and writes the artifact
  so you have evidence the pipeline executed.
- When something *is* stuck, every row carries one of four classifications
  (`deleted-dependency`, `quota-loop`, `genuinely-slow`, `exceeded-threshold`). The
  dedup priority means each stuck deployment appears exactly once and the most
  actionable cause wins.
- The `over_expected` column shows `✅` only when the deployment's primary resource
  type appears in `expected_duration_by_type` and `durationHours` exceeds the
  per-type threshold. This is what separates a 5-hour Cosmos restore (legitimately
  slow) from a 5-hour Web App provision (something is wrong).
- The Run ID (`STUCK-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`) is reproducible.
  Identical inputs (rule pack + scope + UTC date) yield the same Run ID, so two
  reports with the same ID are byte-comparable. Edit a rule and the suffix changes
  — reviewers can see at a glance that two reports came from different rule packs.
- `cancel for scope prod` gates each deployment behind a confirmation prompt and
  emits exactly one `[AUDIT] CANCEL attempt — …` line per attempt
  (`outcome: CONFIRMED | SKIPPED | ERROR`). Pipe those lines into your audit/SIEM
  store as the system of record for who cancelled what.

## What it does

1. Loads a fixed rule pack (`skills/stuck-deployment-janitor/rules/rules.yaml`) — 4 rules
   that identify and classify stuck ARM deployments using **pre-defined literal ARG KQL**.
2. For each rule: calls `execute_query` directly (see § Determinism Deviation below).
3. Enriches each stuck deployment with a live `get_arm_template_deployment_status` call.
4. Renders a report using a **fixed markdown template** (`templates/output-report.md`).
5. On the `cancel` verb: presents a per-deployment confirmation gate before calling
   `cancel_arm_template_deployment`. Emits an `[AUDIT]` log line for every attempt.

## Why the output is deterministic

- Queries are NOT generated or modified by the LLM at run time — they are read verbatim
  from `rules.yaml`.
- Scope substitution (subscription IDs, RG filters, threshold hours) is a plain string
  replacement with no model judgment.
- The agent renders the report using a fixed template with no paraphrasing.
- Sort order is fixed: descending by `durationHours`, ties broken by `name` ascending.
- Run ID is the input scope name + UTC date + rules.yaml hash — identical inputs → identical run ID.

## Determinism Deviation

> **Ratification #7 — DOUBLE EXCEPTION (SRE-PoC-9 stricter literal-KQL discipline)**

This PoC does **not** include `validate_query` or `generate_query` in its tool allowlist,
per the source spec and Bishop ratification #7. Both tools are **explicitly excluded**.

The `SKILL.md` procedure skips the `validate_query → execute_query` pattern used by the
reference implementation and goes **directly to `execute_query`** with the literal KQL from
`rules.yaml` (after scope token substitution only).

**KQL correctness is assured by pre-testing during development.**
Operators running this PoC live who wish to hand-verify the KQL should copy the queries from
`rules/rules.yaml` and test them manually via the `validate_query` tool in a separate
workspace before the first production run.

The agent's `hard_rules` block explicitly forbids any LLM-side KQL derivation or rewriting
under any circumstances.

## Out of scope (future enhancements)

**Post-cancel cleanup templates are NOT implemented in this PoC.**

After calling `cancel_arm_template_deployment`, some resources may have been partially
provisioned. Cleaning them up (deleting half-created VMs, orphaned NICs, etc.) requires
deploying a cleanup template via `create_template_deployment`. However,
`create_template_deployment` is **not in the tool allowlist** for this PoC.

Operators must perform post-cancel cleanup manually using the Azure portal or Azure CLI:

```powershell
# Example: delete a partially-created resource after cancel
az resource delete --ids /subscriptions/<sub>/resourceGroups/<rg>/providers/<type>/<name>
```

A future PoC (e.g., a Golden Path variant) may implement automated post-cancel cleanup
once `create_template_deployment` is available and the cleanup template set is validated.

## How it works (end-to-end flow)

1. **Chat client routes the message.** VS Code Copilot Chat loads
   `.github/copilot/agents/stuck-deployment-janitor.agent.md` as the system prompt.
2. **Workspace MCP server starts.** Runtime reads `.vscode/mcp.json`, handshakes with
   `https://mcp.management.azure.com`. Tools `execute_query`,
   `get_arm_template_deployment_status`, and `cancel_arm_template_deployment` are available.
3. **LLM loads config.** Reads `runbooks/prod.yaml` + `prod.values.yaml`, extracts scope
   tokens and thresholds. Reads `rules.yaml`, computes `ruleset_hash8`.
4. **LLM computes `run_id`** as `STUCK-{YYYYMMDD}-{scope}-{ruleset_hash8}`.
5. **Per-rule loop.** For each of 4 rules, substitutes scope tokens into the literal KQL,
   calls `execute_query` directly (no `validate_query`), stores rows.
6. **Enrichment.** Calls `get_arm_template_deployment_status` per unique deployment ID.
7. **Deduplication + classification priority.** Each deployment gets one classification
   reason (deleted-dep > quota-loop > genuinely-slow > exceeded-threshold).
8. **Render report.** Literal substitution into `templates/output-report.md`. Write to
   `exports/stuck-prod-latest.md`.
9. **Cancel flow (if requested).** Per-deployment confirmation gate → audit log line →
   `cancel_arm_template_deployment` call.

## Install

1. Clone this folder and open it as a workspace in VS Code.
   The ARM MCP server is **already declared** at workspace scope in `.vscode/mcp.json`.
2. Sign in to Azure (`az login`) with at minimum Reader + Resource Graph Reader on target
   subscriptions. For cancel, you also need **Contributor** (or the built-in
   `Deployment Operator` role) on the target resource groups.

> The MCP server entry at workspace scope (`.vscode/mcp.json`):
>
> ```json
> {
>   "servers": {
>     "Azure Resource Manager MCP Server": {
>       "type": "http",
>       "url": "https://mcp.management.azure.com"
>     }
>   }
> }
> ```

## Configure your scope

`scope prod` maps to [`runbooks/prod.yaml`](runbooks/prod.yaml). Real values live in a
gitignored sibling `prod.values.yaml`.

| File | Committed? | Contains |
|---|---|---|
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens |
| `runbooks/prod.values.yaml` | ❌ gitignored | Your real subscription ID(s) and RG names |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference — copy this to start |

### First-time setup

1. Copy the example:
   ```powershell
   Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
   ```
2. Edit `runbooks/prod.values.yaml` with real values:
   ```yaml
   subscription_id: "11111111-2222-3333-4444-555555555555"
   rg_include:
     - "payments-prod-rg"
   rg_exclude: []
   ```
3. Verify `.gitignore` excludes it (`**/runbooks/*.values.yaml`).

### Tuning thresholds

Edit `prod.yaml` (committed) to adjust:
- `auto_cancel_threshold_hours`: default `4` — deployments running longer than this are flagged.
- `expected_duration_by_type`: per-resource-type expected duration for `over_expected` flag.
- `known_slow_types`: types matched by R004 (genuinely-slow classifier).

## Run

VS Code chat — scan:
```
@stuck-deployment-janitor scan for scope prod
```

VS Code chat — cancel:
```
@stuck-deployment-janitor cancel for scope prod
```

GitHub Copilot CLI:
```
copilot -p "Scan for stuck deployments in scope prod"
```

> **CLI users:** see [Copilot CLI usage notes](../README.md#copilot-cli-usage-notes) — `gh copilot` has a quoting bug on Windows when `copilot` lives on a path with spaces, `@agent` mentions don't work in the CLI, and first runs take a few minutes.

## Sample run — what to expect end-to-end

Two artifacts under `exports/` show what the agent emits in practice. Read these
before your first invocation so you know what a healthy report looks like and
what a "something stuck" report looks like.

### Live run on a real subscription (2026-05-14)

[`exports/stuck-prod-latest.md`](exports/stuck-prod-latest.md) was produced by
`@stuck-deployment-janitor scan for scope prod` against the configured production
subscription. Top observations (use these to calibrate expectations on your own
first run):

- **All 4 rules executed cleanly** end-to-end via the `execute_query` ARM MCP
  path. No `validate_query` calls were made (per the determinism deviation), no
  rules failed, and `get_arm_template_deployment_status` was not invoked because
  there was nothing to enrich.
- **Total stuck deployments found: 0** — every rule returned an empty result. This
  is the desired outcome on a healthy production scope and proves the pipeline
  works end-to-end (rule loop → enrich → dedup → sort → render → write). The
  Stuck Deployments table renders the `_(no stuck deployments — table empty)_`
  placeholder rather than being omitted, so reviewers can tell "agent ran and
  found nothing" apart from "agent did not run".
- **Reproducible Run ID:** `STUCK-20260514-prod-3ffe5114`. Anyone re-running the
  shipped rule pack against any `prod` scope on the same UTC date will produce a
  Run ID with the same `3ffe5114` suffix. The suffix is `sha256(rules.yaml)[:8]`
  — change a rule and the suffix changes, and the next run's diff will tell you
  why.
- **Threshold reflected in the header:** `Threshold: deployments running ≥ 4 hours`
  matches `auto_cancel_threshold_hours: 4` in `runbooks/prod.yaml`. Lower it for
  a stricter scan, raise it for less noise — the value flows into the report so
  reviewers always see what threshold the run was generated against.
- **Header summary counts are all zero**, so the four classification buckets line
  up cleanly: 0 actionable, 0 genuinely-slow, 0 unknown. On a non-empty run the
  same four metrics let you see at a glance whether the work to do is "cancel
  these two deletes" or "investigate this one mystery row".

### Simulated "something stuck" report + cancel flow

[`exports/test-run.md`](exports/test-run.md) (built during development) shows what
you can't see in the live empty run: a populated stuck-deployment table with one
row per classification, the per-deployment cancel-confirmation prompt rendered
from `templates/output-cancel-confirmation.md`, and an example
`[AUDIT] CANCEL attempt …` log line. Use it as the contract reference when you
review real reports — the live run won't show you what the cancel gate looks like
until your environment actually has a stuck deployment.

### What to do after your first run

1. **If the table is empty: you're done.** Re-run on your usual cadence (e.g.,
   daily, or post-deploy as a smoke test). The exported file is overwritten on
   every run, so commit it under `exports/` only if you want a longitudinal
   record of "we scanned and nothing was stuck on date X".
2. **If you see `exceeded-threshold` rows with no specific classifier:** R001
   matched but R002–R004 didn't recognise the failure mode. The `Detail` column
   will be empty. Investigate manually with `get_arm_template_deployment_status`
   against the deployment ID, and consider extending `rules.yaml` with a new
   classifier rule for the pattern you find — that's how the rule pack gets
   smarter over time.
3. **If a `genuinely-slow` row looks suspicious:** check the `Detail` column for
   the matched resource type and compare against `expected_duration_by_type` in
   `runbooks/prod.yaml`. If the per-type expected duration is too generous for
   your environment, lower it; the next scan will surface the same deployment
   with `over_expected: ✅` so reviewers know to look harder.
4. **Tune `known_slow_types` carefully.** Adding a type there means R004 will
   *protect* deployments referencing it from being flagged as actionable. Remove
   it (or pair it with a tighter `expected_duration_by_type` ceiling) if your
   environment provisions that type quickly.
5. **For `cancel` runs, archive the audit lines.** Every `[AUDIT] CANCEL attempt …`
   line is the audit trail for a chat-driven cancel decision. Pipe them into your
   SIEM, or at minimum paste them into the change ticket. The line is emitted
   regardless of outcome (`CONFIRMED`, `SKIPPED`, `ERROR`) so a "skipped" attempt
   is just as recoverable as a confirmed one.

## Troubleshooting first runs

| Symptom | Likely cause | Action |
|---|---|---|
| `Total stuck deployments found = 0` and the table is empty | Healthy state — no deployments past the threshold | None. Re-run on cadence; commit the report only if you track reliability evidence |
| You expected stuck deployments but see `0` | Threshold too high, `rg_include` too narrow, or wrong subscription | Lower `auto_cancel_threshold_hours` in `runbooks/prod.yaml`; widen `rg_include` (or empty it to scan all RGs); verify `subscription_id` in `prod.values.yaml` |
| `ABORT: runbooks/prod.values.yaml missing — copy …` | First-time setup not done | `Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml` and fill in real values |
| `ABORT: rules.yaml unreadable` | File missing or permission issue | Verify `.github/copilot/skills/stuck-deployment-janitor/rules/rules.yaml` exists and is readable |
| Run ID changes between two runs you expected to match | Either `rules/rules.yaml` was edited (new `ruleset_hash8`) or the UTC date rolled over between runs | Diff `rules/rules.yaml` against the last commit; confirm both runs occurred on the same UTC day |
| A rule is recorded as `FAILED` in the agent log (the rendered table is unaffected) | `execute_query` errored — typically auth, RBAC, or a transient ARM MCP problem | Re-run `az login` with Reader + Resource Graph Reader on the target sub; confirm the ARM MCP server entry is loaded (workspace `.vscode/mcp.json` for VS Code chat, `~/.copilot/mcp.json` for the CLI). The agent does **not** retry on its own |
| `cancel` invocation skipped your selected deployment | Your reply was not exactly `yes` or `confirm` (case-insensitive) | Re-invoke `cancel` and respond `yes` at the per-deployment prompt. The audit line for the prior attempt will read `outcome: SKIPPED` |
| Cancel succeeded but partially-provisioned resources remain | Expected — post-cancel cleanup is **out of scope** in v1 (see § Out of scope) | Clean up manually with `az resource delete --ids <id>` or via the portal |

## Layout

```
SRE-PoC-09-stuck-deployment-janitor/
  README.md
  .vscode/mcp.json
  .github/copilot/
    agents/
      stuck-deployment-janitor.agent.md   # agent persona + tool allowlist (3 tools)
    skills/stuck-deployment-janitor/
      SKILL.md                            # deterministic procedure
      rules/rules.yaml                    # 4 rules: literal KQL, classification reasons
      templates/
        output-report.md                  # fixed scan report format
        output-cancel-confirmation.md     # per-deployment cancel gate
      prompts/
        scan.prompt.md
        cancel.prompt.md
  runbooks/
    prod.yaml                             # committed template (placeholders only)
    prod.values.yaml                      # GITIGNORED — your real sub IDs / RG names
    prod.values.yaml.example              # committed schema reference
  exports/
    .gitkeep
    test-run.md                           # simulated stuck-table + cancel-flow contract reference
    stuck-<scope>-latest.md               # rendered output from the most recent live `scan` run (overwritten each run)
```

## Tool allowlist

Exactly 3 tools — no additions permitted:

| Tool | Purpose |
|---|---|
| `execute_query` | Run literal KQL from rules.yaml against ARG |
| `get_arm_template_deployment_status` | Enrich stuck deployments with live status |
| `cancel_arm_template_deployment` | Cancel a specific stuck deployment (cancel verb only, requires confirmation) |

`generate_query`, `validate_query`, and `create_template_deployment` are explicitly **NOT** in
the allowlist and must not be called.

## Acceptance criteria mapping

| Criterion | Where it lives |
|---|---|
| Configurable per-resource-type expected duration | `runbooks/prod.yaml` → `expected_duration_by_type` map |
| Classifier produces reason string per stuck deploy | R002/R003/R004 in `rules.yaml`, dedup logic in `SKILL.md` Step 5 |
| Cancel with post-cancel cleanup template | Cancel: `cancel_arm_template_deployment` (implemented). Cleanup template: FUTURE — see § Out of scope |
| Sort descending by duration | SKILL.md Step 5, pinned in `output-report.md` column order |
| Cancel requires per-deployment confirmation | `cancel.prompt.md`, SKILL.md Step 7, `output-cancel-confirmation.md` |
