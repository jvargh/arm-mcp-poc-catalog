# Golden Path Provisioner (ARM MCP PoC — POC-4)

A Copilot CLI / VS Code chat agent that provisions pre-approved ARM golden-path templates
(AKS+ACR+KV+LA, App Service+SQL+KV, or Storage+Data Factory+KV) into the right resource
group with **deterministic naming, tag enforcement, live status polling, and cancel-on-failure**.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## What it does

1. Loads the golden path catalog and runbook config from `runbooks/prod.yaml`.
2. Matches the workload description to a pre-approved template by keyword (deterministic, first-match).
3. Generates resource names following `{prefix}-{team}-{region}-{resource-type}` — no LLM naming.
4. Enforces tags (`Team`, `Environment`, `ManagedBy`, `DeployedOn`) on every resource before any deploy.
5. Runs pre-deploy compliance rules (naming, tags, public IP) via `execute_query` against ARG.
6. Renders a what-if deployment plan — **v1 does NOT call `create_template_deployment`** (see below).
7. Supports `status` polling every 10 seconds and `cancel` with mandatory user confirmation.

## Determinism Deviation

> **This PoC does not include `generate_query` or `validate_query` in its tool allowlist per source spec.**
>
> KQL correctness is assured by pre-testing during development. All KQL queries are stored
> verbatim in `rules/rules.yaml` and are NOT generated or validated by the LLM at runtime.
>
> - `generate_query` is excluded: KQL is pre-canned in `rules.yaml`; no LLM derivation is needed.
> - `validate_query` is excluded: per the source spec tool allowlist (ratification #7). The SKILL.md
>   procedure goes **directly to `execute_query`** after scope substitution — the validate step is
>   skipped entirely.
>
> Operators running this PoC live who want to verify KQL syntax should hand-verify
> `rules/rules.yaml` queries via the `validate_query` tool in a separate workspace before
> the first production run.

## Why the output is deterministic

- **Template selection**: keyword match against `golden_path_catalog` in `prod.yaml`; first match wins.
  Given the same workload description and catalog, the same template is always chosen.
- **Resource naming**: `{naming_prefix}-{team}-{region}-{resource-type-short}` assembled from
  runbook values + user inputs. No model creativity.
- **KQL queries**: read verbatim from `rules/rules.yaml`, not generated.
- **Run ID**: `GP-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}` — plain string assembly.
- **Polling interval**: fixed at 10 seconds.

## v1 Deploy Constraint (locked decision)

> **What-if only — `create_template_deployment` is NEVER called in v1.**
>
> Per the locked ratification (ratification #3): the `provision` verb produces a rendered
> would-deploy plan and stops. The `create_template_deployment` tool is listed in the agent's
> `tools:` block because the live flow requires it, but it is explicitly forbidden by the agent's
> hard rules in v1.
>
> `test-run.md` in `exports/` shows a simulated provision run with a
> "WOULD DEPLOY (NOT EXECUTED in v1)" appendix.

## Tool allowlist (exactly 4 tools)

| # | Tool | Used by |
|---|---|---|
| 1 | `create_template_deployment` | Listed for live path; MUST NOT be called in v1 |
| 2 | `get_arm_template_deployment_status` | `status` verb (10s polling) |
| 3 | `cancel_arm_template_deployment` | `cancel` verb (after user confirmation) |
| 4 | `execute_query` | Compliance rules (R001–R003 via literal KQL) |

## Agent verbs

| Verb | Description |
|---|---|
| `provision` | Keyword-match → template → name/tag plan → what-if render (NOT EXECUTED in v1) |
| `status` | Poll deployment status every 10s |
| `cancel` | Cancel in-progress deployment with mandatory `confirm` gate |

## How it works (end-to-end)

1. User types `@golden-path-provisioner provision --workload "kubernetes api backend" --team platform --region eastus2`.
2. Agent loads `runbooks/prod.yaml` + `prod.values.yaml`. Extracts `naming_prefix`, `allowed_regions`, `golden_path_catalog`.
3. Keyword scan: "kubernetes" matches `aks-baseline` → template selected.
4. Naming generated: `gp-platform-eastus2-aks`, `gp-platform-eastus2-acr`, `gp-platform-eastus2-kv`, `gp-platform-eastus2-la`.
5. Tags merged: `Team=platform`, `Environment=prod`, `ManagedBy=golden-path-provisioner`, `DeployedOn=20260512`.
6. Pre-deploy compliance: `execute_query` called for R001 (naming), R002 (tags), R003 (public IP).
7. What-if plan rendered via `templates/output-report.md`.
8. Agent emits `WOULD DEPLOY (NOT EXECUTED in v1)` and stops.
9. *(Live flow)* Agent calls `create_template_deployment`, then polls `get_arm_template_deployment_status` every 10s.
10. On failure: agent prompts for `confirm`, calls `cancel_arm_template_deployment`, writes audit line to `exports/cancel-audit.jsonl`.

## Install

1. Clone this folder and open it as a workspace in VS Code.
   The ARM MCP server is declared at workspace scope in [`.vscode/mcp.json`](.vscode/mcp.json).
   - VS Code will prompt you to start the server on first chat open.
   - Join the ARM MCP preview at <https://aka.ms/JoinARMMCP> if needed.
   - For GitHub Copilot CLI: copy the `Azure Resource Manager MCP Server` entry to `~/.copilot/mcp.json`.
2. Sign in to Azure (`az login`) with **Contributor** on the target resource groups.

> MCP server entry (`.vscode/mcp.json`):
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

### Two-file pattern

| File | Committed? | Contains |
|---|---|---|
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens. No real values. |
| `runbooks/prod.values.yaml` | ❌ gitignored | Your real subscription ID, naming prefix, cost center, allowed regions. |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference — copy this to start. |

### First-time setup

```powershell
Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
# Edit prod.values.yaml: fill in subscription_id, naming_prefix, cost_center, environment
```

## Run

VS Code chat:
```
@golden-path-provisioner provision --workload "kubernetes api backend" --team platform --region eastus2
@golden-path-provisioner status --deployment gp-platform-eastus2-20260512 --resource-group gp-platform-eastus2-rg
@golden-path-provisioner cancel --deployment gp-platform-eastus2-20260512 --resource-group gp-platform-eastus2-rg
```

GitHub Copilot CLI:
```
gh copilot -p "Provision AKS golden path for team platform in eastus2"
```

## Layout

```
POC-4-golden-path-provisioner/
  README.md
  .vscode/mcp.json
  .github/copilot/
    agents/
      golden-path-provisioner.agent.md   # agent persona + tool allowlist (4 tools)
    skills/
      golden-path-provisioner/
        SKILL.md                          # deterministic 7-step procedure
        rules/rules.yaml                  # R001 naming, R002 tags, R003 public IP
        templates/
          output-report.md               # what-if plan template
          output-status.md               # status poll template
        remediation/
          golden-path-aks-baseline.json  # AKS + ACR + KV + Log Analytics
          golden-path-webapp-baseline.json  # App Service + SQL + KV
          golden-path-data-baseline.json   # Storage + Data Factory + KV
        prompts/
          provision.prompt.md
          status.prompt.md
          cancel.prompt.md               # requires explicit "confirm" per deployment
  runbooks/
    prod.yaml                            # committed template
    prod.values.yaml.example             # committed schema reference
  exports/
    .gitkeep
    test-run.md                          # simulated provision run (NOT EXECUTED)
```

## Acceptance criteria

| Criterion | Where it lives |
|---|---|
| Catalog of ≥3 templates with param schemas | `runbooks/prod.yaml → golden_path_catalog` (3 entries) |
| Naming + tag enforcement before deploy | SKILL.md Step 3; agent hard rules 4 & 5 |
| Live progress every 10s | SKILL.md Step 6; status.prompt.md |
| Auto-cancel + rollback hook on sub-resource failure | SKILL.md Step 7; cancel.prompt.md; exports/cancel-audit.jsonl |
