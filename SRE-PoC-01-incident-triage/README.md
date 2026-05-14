# "First 60 Seconds" Incident Triage Agent (SRE-PoC-1)

An on-call Copilot agent that returns **what changed** in an affected Azure
scope in the last N hours, **who changed it**, **in-flight deployments**, with
a one-key cancel path — all in ≤ 1 screen, copy-paste-ready output.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## Purpose

When an alert fires at 03:00, the on-call engineer wastes the first few
minutes flipping between the Azure Portal Activity Log, Resource Graph
Explorer, the Deployments blade, and an IAM audit query just to answer the
three questions every page starts with:

1. What changed in the last couple of hours?
2. Is anything still being deployed right now?
3. Did anyone get new permissions just before this fired?

This PoC collapses that hunt into a single chat verb. The agent runs three
fixed Azure Resource Graph rules against the affected scope, calls the live
ARM deployments API for any in-flight deployments, and renders a fixed
≤80-char-wide markdown report you can drop straight into an incident
channel. Every run is deterministic (same inputs → same `run_id`), and
every run leaves a JSON-Lines audit trail in `exports/`.

## Intended end state

When this PoC is installed and configured against a real subscription, the
day-2 experience is:

- An on-call engineer types `@incident-triage triage scope prod` (VS Code
  Chat) or `copilot -p "Run incident triage for scope prod"` (CLI).
- Within a few model turns, they get a one-screen report listing recent
  resource changes, in-flight deployments (with live `provisioningState`),
  and recent role-assignment changes — sorted, truncated, and width-capped
  to fit a chat pane.
- If the report shows an in-flight deployment that needs to stop, the
  engineer types `@incident-triage cancel <name>`, types `YES`, and the
  deployment is cancelled via the ARM MCP `cancel_arm_template_deployment`
  tool. The cancel attempt is audited regardless of outcome.
- An auditor can later replay any incident: the `run_id`
  (`TRIAGE-{date}-{scope}-{ruleset_hash}`) plus the JSONL record in
  `exports/` together pin down exactly which rules ran, against which
  subscription, and what the rendered report contained.

The 2026-05-13 live run (see [Live validation log](#live-validation-log))
is the canonical reference for what a healthy end-to-end execution looks
like.

## What it does

1. Reads a fixed three-rule pack
   (`skills/incident-triage/rules/rules.yaml`) — literal ARG KQL per rule.
2. **R001** — queries `resourcechanges` for every resource changed in the
   triage window (who, what, correlationId).
3. **R002** — queries `resources` for ARM deployments in `Running` state;
   confirms live status via `get_arm_template_deployment_status`.
4. **R003** — queries `authorizationresources` for new role assignments in
   the window (potential privilege escalation during incident).
5. Renders a ≤ 1-screen 80-char-wide report using a fixed markdown template.
6. Writes a JSON-Lines audit record to `exports/`.
7. Offers a `cancel` verb with a mandatory YES gate per deployment.

## Expected outcomes

| Rule | Healthy result | Skipped result | What to do when populated |
|------|----------------|----------------|---------------------------|
| R001 — Resource changes | Up to 20 rows of resources changed in the last `time_window_hours`, sorted desc by `changedAt`. Empty ⇒ `(none)` row. | `STATUS=SKIPPED REASON=resourcechanges-unavailable` if Resource Graph isn't enabled in the sub. | Cross-reference `correlationId` against your CI/CD or change-management logs to find the originating change. |
| R002 — In-flight deployments | Up to 10 deployments whose live `provisioningState` is `Running`, sorted desc by `startTime`. Empty ⇒ `(none)` row. | `skip_if_unavailable: false` — hard failure if the core `resources` table is unreachable (would indicate an Azure-wide outage). | If a deployment looks like the cause, run `@incident-triage cancel <name>` (YES gate required). |
| R003 — RBAC changes | Up to 10 role assignments created in the window, sorted desc by `createdOn`. Empty ⇒ `(none)` row. | `STATUS=SKIPPED REASON=authorizationresources-unavailable` if the table isn't enabled. | Verify the principal had a change ticket; otherwise treat as a privilege-escalation lead. |

In a quiet production subscription, all three sections will commonly
render as empty (`(none)`) — that itself is a signal: the incident is
unlikely to be a recent control-plane change. The 2026-05-13 live run
produced exactly this shape.

A run is **successful** when:

- The rendered report has the canonical `# Incident Triage Report` H1.
- Each section has either real rows, `(none)`, or a `STATUS=SKIPPED` row.
- One JSON-Lines record was appended to
  `exports/triage-audit-<scope>-<YYYYMMDD>.jsonl`.
- The `run_id` matches `TRIAGE-{YYYYMMDD}-{scope}-{ruleset_hash[:8]}` and
  reproduces byte-for-byte for the same inputs.

## Why the output is deterministic

- Queries are NOT generated by the LLM at run time — they are read verbatim
  from `rules.yaml`.
- The skill instructs the agent to emit the report using a fixed template with
  no paraphrasing.
- Sort orders, column headers, and line-width cap (80 chars) are pinned in
  `SKILL.md`.
- Run ID is the scope + UTC date + rules.yaml hash — identical inputs →
  identical run ID.
- Numeric convention: all counts and durations as integers.

## Determinism Deviation

> **This PoC does not include `validate_query` in its tool allowlist**
> per source spec and ratification #7 (2026-05-12). KQL correctness is
> assured by pre-testing during development.
>
> The SKILL.md procedure uses `generate_query` → `execute_query` (skipping
> the validate step entirely). Operators running this PoC live should
> hand-verify `rules.yaml` KQL via the `validate_query` tool in another
> workspace if uncertain about query correctness.

## Skip-if-unavailable tables

| Rule | Table                  | Behaviour when unavailable                          |
|------|------------------------|-----------------------------------------------------|
| R001 | `resourcechanges`      | Emit `STATUS=SKIPPED REASON=resourcechanges-unavailable`; continue |
| R003 | `authorizationresources` | Emit `STATUS=SKIPPED REASON=authorizationresources-unavailable`; continue |

**Live validation status (2026-05-13):** both tables are present and queryable
in the configured `prod` subscription. The first live run (`run_id`
`TRIAGE-20260513-prod-7cfcd968`) returned `r001_status=ok`, `r002_rows=0`,
`r003_status=ok` — no rules were SKIPPED. Sanity-checked: 1 `resourcechanges`
row in the last 24h and 167 `authorizationresources` role assignments
visible. See [Live validation log](#live-validation-log) for the rendered
report and audit record.

## How it works (end-to-end flow)

1. **You type** `@incident-triage triage scope prod`.
2. **VS Code** loads `agents/incident-triage.agent.md` as the system prompt,
   reads `.vscode/mcp.json`, starts the ARM MCP server, and calls `tools/list`.
3. **LLM gets its toolbox** — 4 tools: `generate_query`, `execute_query`,
   `get_arm_template_deployment_status`, `cancel_arm_template_deployment`.
4. **SKILL Step 1** — loads `runbooks/prod.yaml` + values file; computes
   `run_id = TRIAGE-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`.
5. **SKILL Step 2 (R001)** — substitutes scope into the `resourcechanges` KQL,
   calls `generate_query` → `execute_query`. On table error → SKIPPED.
6. **SKILL Step 3 (R002)** — runs `resources` KQL to find Running deployments,
   then calls `get_arm_template_deployment_status` per row for live state.
7. **SKILL Step 4 (R003)** — runs `authorizationresources` KQL (time-windowed
   by `properties.createdOn`). On table error → SKIPPED.
8. **SKILL Step 5** — renders `templates/output-report.md` by literal
   placeholder substitution. All lines ≤ 80 chars.
9. **SKILL Step 6** — appends one JSON-Lines audit record to `exports/`.
10. **Report streamed to chat.** Total MCP round-trips: 5–8 (2 per KQL rule +
    1 per Running deployment).

### Cancel flow

```
@incident-triage cancel deploy-payments-v42
```

1. Agent fetches live deployment status — confirms still `Running`.
2. Renders confirmation screen with deployment details.
3. **Waits for user to type `YES` (case-sensitive).**
4. On `YES` → calls `cancel_arm_template_deployment`.
5. Re-fetches status → confirms `Canceling` or `Canceled`.
6. Appends cancel audit record to `exports/`.

## Install

1. Clone this folder and open it as a workspace in VS Code.  
   The ARM MCP server is already declared in [`.vscode/mcp.json`](.vscode/mcp.json).
   - If your account isn't authorized for the ARM MCP preview:
     <https://aka.ms/JoinARMMCP>
   - **For GitHub Copilot CLI users:** the entry in `.vscode/mcp.json` is NOT
     auto-loaded. Copy the `Azure Resource Manager MCP Server` block into
     `~/.copilot/mcp.json` and restart the CLI. Confirm the four tools
     (`generate_query`, `execute_query`, `get_arm_template_deployment_status`,
     `cancel_arm_template_deployment`) appear in the agent's toolbox before
     running. **Without the MCP server loaded the deterministic flow cannot
     run** — the agent will be missing every tool in its allowlist.
2. Sign in: `az login` with Reader + Resource Graph Reader on the target scope.

> **Emergency fallback (non-contract).** If the MCP server is unavailable, the
> same literal KQL from `rules.yaml` can be replayed against the Resource
> Graph REST API directly: `POST
> https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01`
> with body `{"subscriptions":["<sub>"],"query":"<kql>","options":{"resultFormat":"objectArray"}}`.
> This was used to produce the 2026-05-13 validation run when the MCP server
> wasn't loaded in the CLI. Note: this bypasses Hard Rule 2 in
> `agents/incident-triage.agent.md` and is **not** the supported transport —
> use only when a live MCP session genuinely cannot be established.
> Operational gotcha: `az graph query` from PowerShell silently drops the
> KQL projection when arguments contain `|`; pass the body as a JSON file to
> `az rest --body @body.json` to avoid this.

## Configure

Copy the example values file and fill in your subscription ID:

```powershell
Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
```

Edit `runbooks/prod.values.yaml`:

```yaml
subscription_id: "11111111-2222-3333-4444-555555555555"

triage_scopes:
  - "payments-prod"
  - "checkout-prod"
```

`prod.values.yaml` is gitignored (`**/runbooks/*.values.yaml` in root
`.gitignore`). Confirm with `git status` before committing.

## Run

VS Code chat:

```
@incident-triage triage scope prod
```

GitHub Copilot CLI:

```
copilot -p "Run incident triage for scope prod"
```

> **CLI users:** see [Copilot CLI usage notes](../README.md#copilot-cli-usage-notes) — `gh copilot` has a quoting bug on Windows when `copilot` lives on a path with spaces, `@agent` mentions don't work in the CLI, and first runs take a few minutes.

Cancel an in-flight deployment:

```
@incident-triage cancel deploy-payments-v42
```

## Layout

```
SRE-PoC-01-incident-triage/
  README.md
  .vscode/mcp.json                      # ARM MCP server declaration
  .github/copilot/
    agents/
      incident-triage.agent.md          # agent persona + tool allowlist (4)
    skills/
      incident-triage/
        SKILL.md                        # deterministic procedure
        rules/rules.yaml                # 3 rules: literal ARG KQL
        templates/
          output-report.md              # triage report template
          output-cancel-confirmation.md # cancel confirmation template
        prompts/
          triage.prompt.md
          cancel.prompt.md
  runbooks/
    prod.yaml                           # committed template (placeholders)
    prod.values.yaml.example            # committed schema reference
  exports/
    .gitkeep                            # audit JSONL + test-run land here
    test-run.md                         # simulated test run (pre-validation)
    triage-audit-prod-20260513.jsonl    # first live audit record (real)
```

## Lessons from the 2026-05-13 live run

The first end-to-end live run against subscription `463a82d4-…aa93`
surfaced three issues operators should know about before running this PoC
themselves. The verbatim report and audit record are preserved below in
[Live validation log](#live-validation-log).

1. **Copilot CLI does not auto-load `.vscode/mcp.json`.** The CLI looks
   at `~/.copilot/mcp.json` only. Without the ARM MCP server registered
   there, the agent's four prescribed tools are all absent and the
   deterministic flow cannot run — the run silently degrades or aborts.
   **Fix:** copy the `Azure Resource Manager MCP Server` block from
   `.vscode/mcp.json` into `~/.copilot/mcp.json`, restart the CLI, and
   verify the four tools (`generate_query`, `execute_query`,
   `get_arm_template_deployment_status`,
   `cancel_arm_template_deployment`) are present in the toolbox before
   invoking any verb. VS Code Chat is unaffected.
2. **`az graph query` mangles KQL with pipes when invoked from
   PowerShell.** Multi-line KQL strings get their `project` clauses
   silently dropped and the raw row schema is returned instead. Use
   `az rest --body @body.json` or, preferably, the MCP `execute_query`
   tool — both are unaffected. This bit the REST fallback path on the
   first attempt and is the reason the [Install](#install) emergency
   fallback ships with the JSON-body recipe rather than a one-liner.
3. **Empty-set rendering is consistent across all three rules.** SKILL.md
   Step 5 only specified `(none)` rendering for R002. The live run
   rendered R001 and R003 the same way (a single `(none)` row) when
   their result sets were empty-but-not-skipped. Treat this as the
   pinned behaviour: empty `ok` ⇒ `(none)` row; table-unavailable ⇒
   `STATUS=SKIPPED` row.

The run also confirmed both `resourcechanges` and `authorizationresources`
are present and queryable in the configured subscription, so neither R001
nor R003 will SKIP on this sub today.

## Live validation log

First live run, 2026-05-13. Subscription `463a82d4-…aa93`. Tables
`resourcechanges` and `authorizationresources` confirmed available. No rules
SKIPPED. Output below is the verbatim rendered report:

```text
# Incident Triage Report

**Run ID:** TRIAGE-20260513-prod-7cfcd968
**Scope:** prod
**Generated (UTC):** 2026-05-13T13:53:49Z
**Time window:** last 2h
**Subscription:** sub-id
**Ruleset hash:** 7cfcd968

---

## Resource Changes (R001)

| changedAt (UTC)      | type    | resourceId                          | principal  |
|----------------------|---------|-------------------------------------|------------|
| (none)               |         |                                     |            |

---

## In-Flight ARM Deployments (R002)

| name                 | resourceGroup        | startTime (UTC)      | state   |
|----------------------|----------------------|----------------------|---------|
| (none)               |                      |                      |         |

---

## RBAC Changes (R003)

| principalId (short)  | roleDefId (short)    | scope (truncated)    | createdOn  |
|----------------------|----------------------|----------------------|------------|
| (none)               |                      |                      |            |

---

*Run `@incident-triage cancel <name>` to cancel an in-flight deployment.*
*Audit record written to `exports/`.*

✓ Audit record written to exports/triage-audit-prod-20260513.jsonl
```

Audit record (`exports/triage-audit-prod-20260513.jsonl`):

```jsonl
{"r002_rows":0,"generated_utc":"2026-05-13T13:53:49Z","r001_status":"ok","run_id":"TRIAGE-20260513-prod-7cfcd968","scope":"prod","r003_status":"ok","event":"triage"}
```

See [Lessons from the 2026-05-13 live run](#lessons-from-the-2026-05-13-live-run)
for the three operator-facing takeaways from this run (CLI transport gap,
`az graph query` pipe bug, empty-set rendering convention).

---

## Acceptance criteria mapping

| Criterion | Where it lives |
|---|---|
| ARG against resourcechanges + resourcecontainers, scoped by RG/sub/tag | `rules/rules.yaml` R001 KQL |
| In-flight deployments list with confirm-to-cancel gate | `SKILL.md` Steps 3 + 7; `prompts/cancel.prompt.md` |
| Output ≤ 1 screen, copy-paste ready, 80-char width | `SKILL.md` Step 5; `agent.md` hard rule 8 |
| Audit trail (JSON-Lines in exports/) | `SKILL.md` Step 6; `agent.md` hard rule 10 |
| R001 skip_if_unavailable | `rules.yaml` R001; `SKILL.md` Step 2 |
| R003 skip_if_unavailable | `rules.yaml` R003; `SKILL.md` Step 4 |
| Cancel path with YES gate | `SKILL.md` Step 7; `cancel.prompt.md` |
