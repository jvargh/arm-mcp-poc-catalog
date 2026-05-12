# SRE-PoC-10 — On-Call Runbook Executor (ARM MCP PoC)

An on-call runbook executor that converts structured YAML runbooks into MCP-driven state
machines. Each step is an ARG health check, ARM deployment (what-if in v1), human
confirmation gate, or rollback. Captures a full evidence pack per run.

This is the **most complex PoC in the fleet** — the only one using all 6 ARM MCP tools
and introducing a novel runbook DSL.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

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
    .gitkeep                                     # state files and test run land here
    test-run.md                                  # simulated test run output
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
