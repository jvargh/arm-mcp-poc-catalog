# SRE-PoC-10 — On-Call Runbook Executor (ARM MCP PoC)

An on-call runbook executor that converts structured YAML runbooks into MCP-driven state
machines. Each step is an ARG health check, ARM deployment (what-if in v1), human
confirmation gate, or rollback. Captures a full evidence pack per run.

This is the **most complex PoC in the fleet** — the only one using all 6 ARM MCP tools
and introducing a novel runbook DSL.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

**Purpose in one line:** Walk a YAML failover runbook as a deterministic, resume-safe
state machine, gate destructive actions on human confirmation, simulate every ARM deploy
in v1, and drop a complete evidence pack to `exports/` so an SRE can audit exactly what
the agent did (and didn't do) during an incident.

**End state of any run:** A `run_status` of `COMPLETED`, `FAILED`, or `CANCELLED` plus
two artifacts in `exports/` — the JSON state file (machine-readable, used for resume) and
a rendered markdown report (human-readable). See [Outputs](#outputs),
[Expected outcomes](#expected-outcomes), and
[Example run](#example-run-failed-at-confirm-gate).

---

## Quickstart (5 minutes)

For an SRE who wants to go from clone to first audit-trail in five minutes:

1. **Clone & open** the folder. From VS Code, open this folder as a workspace; from
   GitHub Copilot CLI, just `cd` into it.
2. **Sign in to Azure.** `az login` with at least **Reader + Resource Graph Reader** on
   the target subscription. (Live deploys would need Contributor — but v1 simulates.)
3. **Create your values file** from the example and fill in real names:
   ```powershell
   Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
   # then edit runbooks/prod.values.yaml — see "Configure your runbook" below
   ```
4. **(VS Code only) Start the ARM MCP server** from `.vscode/mcp.json` — the chat panel
   prompts you. Skip this step on Copilot CLI; the agent falls back to `az graph query`.
5. **Run the runbook:**
   - VS Code chat: `@runbook-executor execute runbook=prod`
   - Copilot CLI: `@.github/copilot/agents/runbook-executor.agent.md execute runbook=prod`

After every step you'll see a per-step status card in chat. When the run finishes
(or halts), look in `exports/` for `prod-run-state.json` and `report-<run_id>.md`.

> ⚠️ **Heads-up:** The runbook contains two `confirm` gates (steps 3 and 6). Each one
> **pauses the agent** until you type `yes` or `confirm`. If no operator is present
> (e.g., autopilot mode), the gate times out, the run halts, and **no deploy ever
> executes**. This is by design — see [Lessons learned](#lessons-learned-from-the-latest-run).

---

## What it does

1. Loads a structured runbook (`runbooks/<name>.yaml`) containing an ordered list of steps
   in the **runbook DSL** (check / deploy / confirm / rollback).
2. Validates each step against the step type schemas in
   `skills/runbook-executor/rules/rules.yaml`.
3. Walks the runbook as a **deterministic state machine**:
   - `check` steps: `validate_query` → `execute_query` (ARM MCP). Zero rows = PASS.
   - `deploy` steps: `create_template_deployment` → `get_arm_template_deployment_status`
     (SIMULATED in v1 — not actually called).
   - `confirm` steps: pause and require explicit human input before advancing.
   - `rollback` steps: `create_template_deployment` → `get_arm_template_deployment_status`
     (SIMULATED in v1 — not actually called).
4. Persists run state to `state_file_path` after every step transition (resume-safe).
5. Captures a full **evidence pack** per run: ordered JSON array of step outcomes.
6. Supports **cancel mid-run** via `cancel_arm_template_deployment` (with mandatory
   per-deployment user confirmation).
7. Renders a report, per-step status, and evidence pack using fixed markdown templates.

---

## Determinism Deviation

> ⚠️ **`rules.yaml` in this PoC is NON-STANDARD.** Read this section before comparing
> with other PoCs in the fleet.

In every other PoC, `rules.yaml` contains a **list of rules** (individual KQL queries
with weights and metadata). In SRE-PoC-10, `rules.yaml` defines **step type SCHEMAS** —
one schema per DSL step type (`check`, `deploy`, `confirm`, `rollback`). These schemas are
the validation rules the agent uses to validate each step in a runbook's `runbook_steps`
list before execution.

Individual runbook instances define their own `runbook_steps` ordered list inside their
runbook YAML file (e.g., `runbooks/prod.yaml`). The `rules.yaml` schema file is
type-level metadata, not instance-level step definitions.

**Rationale (ratification #1):** The runbook DSL requires type-level validation rather
than a fixed rule list. Defining schemas in `rules.yaml` keeps the schema authority
centralized (and still hashes cleanly for the run_id) while allowing each runbook to
declare its own execution plan. This is a deliberate architectural choice, not a bug.

**Downstream note:** The SHA-256 of `rules.yaml` (first 8 hex chars as `schema_hash8`)
is still used in the `run_id` exactly as specified:
`RBOOK-{YYYYMMDD}-{runbook_name}-{sha256(rules.yaml)[:8]}`

---

## Why the output is deterministic

- Runbook steps are executed **in file order** with no reordering.
- Each step results in exactly **PASS or FAIL** — no partial states.
- State transitions are driven by `on_fail` values, not LLM judgment.
- `run_id` is computed from UTC date + runbook name + rules.yaml hash — no model judgment.
- Evidence pack entries are **ordered by execution sequence**, never sorted.
- Output is rendered by literal `{{placeholder}}` substitution into fixed templates.
- Resume behavior is deterministic: always resumes from `last_completed_step_index + 1`.

---

## How it works (end-to-end flow)

What happens after you type `@runbook-executor execute runbook=prod`:

1. **Chat client routes the message.** VS Code Copilot Chat sees the `@runbook-executor`
   mention, loads `.github/copilot/agents/runbook-executor.agent.md` as the system prompt,
   and reads its `tools:` block to know which tools to expose (all 6).
2. **Workspace MCP server starts.** The runtime reads `.vscode/mcp.json`, sees the
   `Azure Resource Manager MCP Server` entry, performs the MCP initialize handshake.
3. **LLM loads inputs.** Reads `runbooks/prod.yaml` (substituting `.values.yaml`),
   reads `rules/rules.yaml`, validates step schemas, computes `run_id`.
4. **Resume check.** LLM checks `state_file_path` for an in-progress run. If found,
   resumes from the last completed step.
5. **Step loop.** For each step in `runbook_steps`:
   - **check**: `validate_query` → `execute_query`. Zero rows = PASS.
   - **deploy**: simulated in v1 — no actual ARM call. Evidence entry written.
   - **confirm**: operator asked for `yes`/`confirm`. Blocks until input or timeout.
   - **rollback**: simulated in v1 — no actual ARM call. Evidence entry written.
6. **State persisted after every step.** Full state JSON written to `state_file_path`.
7. **Evidence pack appended** after every step: `{step_name, type, input, output, status, timestamp_utc}`.
8. **Cancel available at any time.** Operator types `cancel` or uses the `cancel` verb.
   Per-deployment confirmation required. Audit entry written to evidence pack.
9. **Final render.** On run completion, renders `output-report.md`, `output-step-status.md`
   per step, and `output-evidence-pack.md`.

---

## Tool allowlist (EXACTLY 6 tools, in this order)

| # | Tool | Used by |
|---|---|---|
| 1 | `generate_query` | check steps (KQL generation fallback only) |
| 2 | `validate_query` | check steps — validate KQL before execute |
| 3 | `execute_query` | check steps — run ARG health query |
| 4 | `create_template_deployment` | deploy/rollback steps (SIMULATED in v1) |
| 5 | `get_arm_template_deployment_status` | deploy/rollback steps (SIMULATED in v1) |
| 6 | `cancel_arm_template_deployment` | cancel flow (requires user confirmation) |

---

## Install

1. Clone this folder anywhere and open it as a workspace in VS Code.
   The ARM MCP server is **already declared** at workspace scope in `.vscode/mcp.json` —
   VS Code will prompt you to start it the first time you open the chat.
   - If your VS Code account isn't yet authorized for the ARM MCP preview, click
     <https://aka.ms/JoinARMMCP>.
   - For GitHub Copilot CLI users: copy the `Azure Resource Manager MCP Server` entry
     from `.vscode/mcp.json` into `~/.copilot/mcp.json`.
2. Sign in to Azure (`az login`) with **Reader + Resource Graph Reader** on the target
   scope. For live deploy steps you also need **Contributor** on the target RGs.

MCP server entry (workspace scope):
```json
{
  "servers": {
    "Azure Resource Manager MCP Server": {
      "type": "http",
      "url": "https://mcp.management.azure.com"
    }
  }
}
```

---

## Configure your runbook (do this before first run)

`runbook=prod` maps to `runbooks/prod.yaml`. Use the two-file pattern:

| File | Committed? | Contains |
|---|---|---|
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens. No real values. |
| `runbooks/prod.values.yaml` | ❌ **gitignored** | Your real sub ID, region names, TM profile. |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference — copy this to start. |

### First-time setup

```powershell
Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
```

Edit `runbooks/prod.values.yaml`:
```yaml
subscription_id: "11111111-2222-3333-4444-555555555555"
primary_region: "eastus"
failover_region: "westus2"
traffic_manager_profile: "my-tm-profile"
traffic_manager_rg: "my-tm-rg"
primary_endpoint_name: "primary-ep"
failover_endpoint_name: "failover-ep"
```

Verify `.gitignore` excludes it (root `.gitignore` has `**/runbooks/*.values.yaml`).

---

## Run

VS Code chat:
```
@runbook-executor execute runbook=prod
```

Check current run state:
```
@runbook-executor status runbook=prod
```

Trigger rollback:
```
@runbook-executor rollback runbook=prod
```

Cancel in-flight deployment:
```
@runbook-executor cancel runbook=prod
```

> **Environment note (CLI vs VS Code):** When run from VS Code Copilot Chat with the ARM
> MCP server in `.vscode/mcp.json` started, the agent calls all 6 ARM MCP tools directly.
> When run from GitHub Copilot CLI or any environment without the ARM MCP server attached,
> the agent falls back to `az graph query` for `check` steps; `deploy`/`rollback` steps
> are SIMULATED in v1 regardless of environment, so this fallback does not change deploy
> behavior.

---

## Outputs

After every run, `exports/` contains:

| File | Purpose | Lifecycle |
|---|---|---|
| `prod-run-state.json` | Run state + ordered evidence pack JSON. Validated as JSON after every step. Used for resume detection. | Rewritten after every step transition. On a fresh run started while a final (COMPLETED/FAILED) state file already exists, the prior file is renamed to `prod-run-state.json.prev-<previous_run_id>` per SKILL.md Step 3.4. |
| `report-<run_id>.md` | Rendered markdown bundle: run report, all per-step statuses, full evidence pack. Mirrors what the chat client shows. | Written once on run completion (COMPLETED, FAILED, or CANCELLED). One file per `run_id`. |

The state file is the source of truth — the markdown report is regenerated from it.
Both files are committed-friendly (no secrets) but are typically left untracked so the
git working tree stays clean across re-runs.

---

## Expected outcomes

Every run ends in exactly one of three terminal states. Use this table to interpret
what happened and decide what to do next.

| `run_status` | What it means | Typical trigger | Recommended next action |
|---|---|---|---|
| `COMPLETED` | All steps in `runbook_steps` ran and the last step PASSed (or `continue`-on-fail). For the `prod` runbook this is steps 1–6 PASS + step 7 NOT_RUN (rollback fires only on prior FAIL). | Operator confirmed both gates; failover region was healthy after the simulated deploy. | Review `report-<run_id>.md`. Archive it with the incident ticket. |
| `FAILED` | A step returned FAIL or TIMED_OUT and its `on_fail` was `halt` (or `rollback`, in which case the rollback step also ran). Remaining steps are NOT_RUN. | A `check` returned rows (resources violating the check), an operator declined a `confirm` gate, or a confirm gate timed out (e.g., autopilot). | Read the last evidence-pack entry to see which step failed and why. Fix the underlying condition, then re-invoke `execute` (the prior state file is auto-renamed). |
| `CANCELLED` | Operator invoked the `cancel` verb or typed `cancel` at a confirm gate, then confirmed the per-deployment cancel prompt. The audit log entry is the last evidence entry. | Mid-run abort — usually because conditions changed or a different remediation was chosen. | Review the cancel audit entry. If a deploy had already been simulated/executed, decide whether to invoke `rollback` separately. |

**Per-step statuses you will see along the way:** `PASS`, `FAIL`, `TIMED_OUT`,
`SKIPPED` (missing `kql_or_template` on a non-confirm step), `AWAITING_CONFIRMATION`
(transient, only while a confirm gate is open), and `NOT_RUN` (used in the rendered
report for steps after a halt — they have no evidence-pack entry).

---

## Example run (FAILED at confirm gate)

A representative run executed against subscription
`sub-id` from GitHub Copilot CLI in autopilot:

```
Run ID:  RBOOK-20260514-failover-runbook-2c076ca1
Status:  FAILED
Halted:  step 3 (Confirm failover gate) — TIMED_OUT
```

| # | Step | Type | Status | on_fail |
|---:|---|---|---|---|
| 1 | Check pre-conditions — primary region health | check | PASS (0 rows) | halt |
| 2 | Check pre-conditions — failover region capacity | check | PASS (0 rows) | halt |
| 3 | Confirm failover gate | confirm | TIMED_OUT → halt | halt |
| 4 | Deploy failover — redirect traffic to failover region | deploy | NOT_RUN | rollback |
| 5 | Check post-deploy health — failover region serving traffic | check | NOT_RUN | rollback |
| 6 | Confirm success or rollback gate | confirm | NOT_RUN | rollback |
| 7 | Rollback — restore primary region if needed | rollback | NOT_RUN | halt |

This is the **deterministic, expected behavior** when no operator is present to answer a
`confirm` gate — per hard rule #4 in `agents/runbook-executor.agent.md`, silence at a
`confirm` step is treated as FAIL/TIMED_OUT and the step's `on_fail` action runs (here:
`halt`). The runbook is therefore safe by default in autopilot environments: it stops
**before** any deploy step rather than executing destructive actions unattended.

Full output for the example run lives at:
- `exports/prod-run-state.json` — state + 3-entry evidence pack JSON
- `exports/report-RBOOK-20260514-failover-runbook-2c076ca1.md` — rendered markdown

### What a successful (COMPLETED) run would look like

Same runbook, this time with an operator typing `yes` at both gates and a healthy
Traffic Manager profile:

| # | Step | Type | Status | Notes |
|---:|---|---|---|---|
| 1 | Check pre-conditions — primary region health | check | PASS | 0 unhealthy VMs in primary |
| 2 | Check pre-conditions — failover region capacity | check | PASS | (see Lesson #2 below — this query passes on 0 rows even when there is no capacity) |
| 3 | Confirm failover gate | confirm | PASS | operator typed `yes` |
| 4 | Deploy failover — redirect traffic | deploy | PASS (simulated) | `WOULD DEPLOY (NOT EXECUTED in v1)` written to evidence |
| 5 | Check post-deploy health | check | PASS | failover endpoint enabled in TM profile |
| 6 | Confirm success or rollback gate | confirm | PASS | operator typed `yes` (else `rollback` fires) |
| 7 | Rollback — restore primary | rollback | NOT_RUN | rollback only fires on prior FAIL |

Final `run_status = COMPLETED`. Evidence pack contains 6 entries (rollback never wrote
one). The report file is named `report-RBOOK-<YYYYMMDD>-failover-runbook-<hash>.md`.

### Lessons learned from the latest run

1. **Confirm gates block in autopilot / unattended runs.** This is intentional — the
   runbook DSL treats human confirmation as a hard gate (hard rule #4). If you want a
   fully unattended run for testing, replace the `confirm` step's `on_fail: halt` with
   `on_fail: continue`, or remove the gate from a non-prod runbook. **Do not silently
   auto-confirm** in production — that defeats the audit purpose of the gate.

2. **The `check` pass condition is "zero violations found", not "expected state
   present".** Step 2 in the bundled `prod.yaml` filters for *Succeeded* VMs in the
   failover region: zero rows mechanically = PASS, but semantically that means "no
   capacity". This is a runbook-author gotcha: a `check` query should look for the
   *bad* condition (resources you don't want to find) so that "no rows" maps to "no
   problem". For "verify desired state present" semantics, prefer a `deploy` step
   whose template fails when the resource isn't found, or invert the predicate
   (e.g., `where provisioningState !~ 'Succeeded'`).

3. **Resume just works on re-run.** After a FAILED run, the state file at
   `state_file_path` is final. Re-invoking `execute` renames it to
   `prod-run-state.json.prev-<previous_run_id>` (per SKILL.md Step 3.4) and starts a
   fresh run with a new `run_id`. To resume from the *middle* of a run that crashed
   while still `IN_PROGRESS`, just re-invoke — the agent announces
   `RESUMING run {{run_id}} from step index N`.

4. **CLI-mode runs use `az graph query` for `check` steps.** When the ARM MCP server
   isn't attached (e.g., GitHub Copilot CLI), `validate_query` and `execute_query`
   are substituted by `az graph query`. Behavior is identical from the runbook's
   perspective — same KQL, same row counts, same PASS/FAIL semantics — but you must
   have `az login` completed and the right subscription selected.

---

## Runbook DSL

Each runbook YAML defines an ordered list of steps. Supported types:

```yaml
runbook_steps:
  - name: <human-readable step name>
    type: check | deploy | confirm | rollback
    kql_or_template: <KQL string for check; template path for deploy/rollback; null for confirm>
    params: {}        # parameters for deploy/rollback templates
    on_fail: halt | rollback | continue
    max_timeout_seconds: <int, optional, defaults to runbook-level max_step_timeout_seconds>
```

Step types:

| Type | Tool calls | Pass condition | Fail condition |
|---|---|---|---|
| `check` | `validate_query` → `execute_query` | Zero rows returned | Validation error OR non-empty rows |
| `deploy` | `create_template_deployment` → `get_arm_template_deployment_status` (simulated in v1) | Succeeded | Failed or timeout |
| `confirm` | none (human gate) | User types `yes`/`confirm` | Any other input or timeout |
| `rollback` | `create_template_deployment` → `get_arm_template_deployment_status` (simulated in v1) | Succeeded | Failed or timeout |

---

## Layout

```
SRE-PoC-10-runbook-executor/
  README.md
  .vscode/mcp.json                               # ARM MCP server config
  .github/copilot/
    agents/runbook-executor.agent.md             # agent persona + tool allowlist (all 6)
    skills/runbook-executor/
      SKILL.md                                   # deterministic state machine procedure
      rules/rules.yaml                           # DSL step type SCHEMAS (not a rules list — see Determinism Deviation)
      templates/
        output-report.md                         # fixed run summary report format
        output-step-status.md                    # fixed per-step status format
        output-evidence-pack.md                  # fixed evidence pack format
      remediation/
        example-failover-deploy.json             # ARM template: redirect traffic to failover region
        example-failover-rollback.json           # ARM template: restore primary region
      prompts/
        execute.prompt.md                        # execute verb
        status.prompt.md                         # status verb
        rollback.prompt.md                       # rollback verb
        cancel.prompt.md                         # cancel verb (requires per-deploy confirmation)
  runbooks/
    prod.yaml                                    # committed template (placeholders only)
    prod.values.yaml.example                     # committed schema reference
  exports/
    .gitkeep                                     # keeps the folder in git
    prod-run-state.json                          # run state + evidence pack JSON (rewritten per step)
    report-<run_id>.md                           # rendered markdown report (one per completed run)
    test-run.md                                  # bundled simulated test run output (committed reference)
```

---

## Acceptance criteria

| Criterion | Where it lives |
|---|---|
| Runbook DSL with check/deploy/confirm/rollback step types | `runbooks/prod.yaml` + `rules/rules.yaml` (schema) + `SKILL.md` |
| State machine that resumes from interruption | `SKILL.md` Step 3 (Resume detection) + Step 4 (Initialize) |
| Evidence pack per run | `SKILL.md` Step 7 + `templates/output-evidence-pack.md` |
| Cancel path with per-deployment confirmation | `SKILL.md` Step 8 + `prompts/cancel.prompt.md` |
| All 6 ARM MCP tools used | `agents/runbook-executor.agent.md` tools block |
| v1 what-if only (no actual deploys) | Hard rule #1 in agent.md; v1_behavior in rules.yaml |

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Run halts immediately at step 3 with `TIMED_OUT` | A `confirm` gate received no operator response (typical in autopilot / unattended CLI runs). | Re-invoke from an interactive session and type `yes` or `confirm` when prompted. See Lesson #1 above. |
| `ABORT: runbooks/prod.values.yaml missing — copy prod.values.yaml.example and fill in real values` | First-time setup not done. | `Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml` and edit. |
| `ABORT: step '<name>' failed schema validation for type '<type>'` | A step in your runbook is missing a required field for its `type`, or `on_fail` is not one of `halt` / `rollback` / `continue`. | Compare the step against `skills/runbook-executor/rules/rules.yaml` — each schema lists `required_fields` and allowed `on_fail_values`. |
| Run announces `RESUMING run <run_id> from step index N` when you wanted a fresh start | A previous run's state file is still `IN_PROGRESS` (the agent was killed before persisting a final status). | Either let it resume (recommended — that's the design), or delete `exports/prod-run-state.json` to force a new `run_id`. |
| `check` step returns PASS but you know the cluster is unhealthy | The KQL is filtering for the *desired* state (e.g., `=~ 'Succeeded'`) instead of the *violation* state. Zero rows mechanically PASSes regardless of meaning. | Invert the predicate so the query returns rows when something is wrong (Lesson #2). |
| Copilot CLI run errors with "Resource Graph not enrolled" or `az graph` not found | You haven't run `az login`, or the `resource-graph` extension isn't installed. | `az login` and (if needed) `az extension add --name resource-graph`. |
| `run_id` differs across runs even when nothing changed | Expected — the date component (`YYYYMMDD`) rolls over at UTC midnight. The `schema_hash8` portion is stable while `rules.yaml` is unchanged. | No fix needed; `run_id` uniqueness across days is intentional. |
| State file shows non-final `run_status` after a crash | Agent died between writes. The next `execute` call will resume from `last_completed_step_index + 1`. | Re-invoke `execute`. To force restart, delete the state file. |
