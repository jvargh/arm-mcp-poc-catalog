# Capacity & Quota Guardian (ARM MCP PoC)

A Copilot CLI / VS Code chat agent that queries subscription and region resource counts via ARG,
compares them against quota limits, **warns before deploys would breach quota**, and suggests
alternate regions. The `deploy` verb is **gated** — it is blocked until all quota checks pass.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## What it does

1.  Loads a fixed rule pack (`skills/capacity-quota-guardian/rules/rules.yaml`) — 4 ARG query
    rules counting VMs by SKU, vCPUs, storage accounts, and public IPs per region/subscription.
2.  For every rule: `generate_query` → `execute_query` (ARM MCP) to retrieve current resource counts.
3.  Compares current counts against quota **limits from `runbooks/prod.yaml`** (`quota_limits` map).
4.  Computes `usage_pct = (current_count / limit) * 100` per resource type per region.
5.  Sorts results **descending by `usage_pct`** (highest pressure first).
6.  Emits a `FAIL` status on any row where `usage_pct > headroom_threshold_pct` (default 80).
7.  Suggests alternate regions (from `alternate_regions` map, sorted by latency tier) for every FAIL row.
8.  **Gates the `deploy` verb:** blocks on any FAIL; on PASS, simulates the would-deploy outcome
    (v1 is what-if only — see [Hard rules](#known-limitations)).

## Why the output is deterministic

*   ARG queries are read verbatim from `rules/rules.yaml` — the LLM is a query runner, not an author.
*   `usage_pct` formula is fixed: `(current_count / limit) * 100`, rounded to 1 decimal place.
*   Sort order is fixed: **descending by `usage_pct`**, ties by `resource_type` asc then `region` asc.
*   Alternate region suggestions follow the runbook `alternate_regions` map order (latency tier).
*   Run ID is deterministic: `QUOTA-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`.
*   Numeric formatting is pinned: integer counts; percentages to 1 decimal place.

## How it works (end-to-end flow)

1.  **Chat client routes the message.** VS Code Copilot Chat sees the `@quota-guardian` mention,
    loads `.github/copilot/agents/capacity-quota-guardian.agent.md` as the system prompt, and
    reads its `tools:` / `mcp:` declarations.
2.  **Workspace MCP server starts.** The runtime reads `.vscode/mcp.json`, starts the
    `Azure Resource Manager MCP Server`, and gets its tool list.
3.  **LLM gets its toolbox.** The model sees the agent hard rules, SKILL.md procedure, user
    prompt, and JSON schemas for the 4 allowed tools. No Azure call yet.
4.  **LLM follows SKILL step 1 — load inputs.** Reads `runbooks/prod.yaml` (substituting
    from `prod.values.yaml`): subscriptions, `quota_limits`, `alternate_regions`,
    `headroom_threshold_pct`.
5.  **LLM computes `run_id` deterministically.** `QUOTA-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`.
6.  **LLM enters the per-rule loop (SKILL step 2).** For each rule, calls `generate_query` with
    the literal KQL from `rules.yaml` plus scope context, then calls `execute_query` to get counts.
7.  **LLM runs SKILL step 3 — quota check.** For each row, looks up the limit in `quota_limits`,
    computes `usage_pct`, and assigns PASS / FAIL / LIMIT_UNKNOWN.
8.  **LLM sorts all rows descending by `usage_pct`** (SKILL step 3).
9.  **LLM runs SKILL step 4 — alternate region suggestions.** For each FAIL row, reads
    `alternate_regions[region]` from the runbook (latency-tier ordered).
10. **LLM renders the output** (SKILL step 5). Loads `templates/output-report.md`, does literal
    `{{placeholder}}` substitution, and streams the report back to chat.
11. **Deploy gate.** If the verb is `deploy`, the LLM runs the full check first. On FAIL it
    renders `templates/output-quota-check.md` and stops. On PASS it outputs a
    `WOULD DEPLOY (NOT EXECUTED — v1 what-if)` block — no actual ARM deployment is made.
12. **Status check.** If the verb is `status`, the LLM calls `get_arm_template_deployment_status`
    and prints the raw result.

**Where the LLM ≠ the oracle:** load, compute, sort, suggest, render — all rule-driven.  
**Where MCP does the heavy lifting:** `execute_query` running KQL against ARG with your Azure identity.

## Install

1.  Clone this folder and open it as a workspace in VS Code.  
    ARM MCP server is already declared in [`.vscode/mcp.json`](.vscode/mcp.json) — VS Code will
    prompt you to start it the first time you open chat.
    *   If not yet authorized for the ARM MCP preview: <https://aka.ms/JoinARMMCP>
    *   For GitHub Copilot CLI users: copy the `Azure Resource Manager MCP Server` entry from
        `.vscode/mcp.json` into `~/.copilot/mcp.json`.
2.  Sign in to Azure (`az login`) with **Reader + Resource Graph Reader** on the target scope.

> MCP server entry in `.vscode/mcp.json`:
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

## Configure your scope (do this before first run)

`scope prod` maps to `runbooks/prod.yaml`. Fill in real values in `runbooks/prod.values.yaml`.

### Two-file pattern: template + values

| File | Committed? | Contains |
| --- | --- | --- |
| [`runbooks/prod.yaml`](runbooks/prod.yaml) | ✅ yes | Template with `${placeholder}` tokens, `quota_limits`, `alternate_regions`. |
| `runbooks/prod.values.yaml` | ❌ **gitignored** | Your real subscription ID. |
| [`runbooks/prod.values.yaml.example`](runbooks/prod.values.yaml.example) | ✅ yes | Schema reference — copy this to start. |

### First-time setup

1.  **Copy the example:**

    ```powershell
    Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
    ```

2.  **Fill in your subscription ID** in `prod.values.yaml`.

3.  **Update `quota_limits` in `prod.yaml`** to match your actual Azure subscription limits:

    ```powershell
    az vm list-usage --location eastus -o table
    az network list-usages --location eastus -o table
    az storage account list --query "length(@)" -o tsv
    ```

4.  **Verify `.gitignore`** excludes `prod.values.yaml` (the root `.gitignore` has
    `**/runbooks/*.values.yaml`).

### Adding more scopes

```
runbooks/
  prod.yaml             ← committed template
  prod.values.yaml      ← gitignored, your values
  staging.yaml          ← committed template
  staging.values.yaml   ← gitignored, your values
```

Then run `@quota-guardian check scope staging`.

## Run

VS Code chat:

```
@quota-guardian check scope prod
@quota-guardian deploy scope prod --template <path-to-arm-template>
@quota-guardian status scope prod <deployment-name>
```

GitHub Copilot CLI:

```
gh copilot -p "Check capacity quotas for scope prod"
```

## Layout

```
SRE-PoC-7-capacity-quota-guardian/
  README.md
  .vscode/mcp.json                      # ARM MCP server declaration
  .github/copilot/
    agents/
      capacity-quota-guardian.agent.md  # agent persona + tool allowlist (4 tools)
    skills/
      capacity-quota-guardian/
        SKILL.md                        # deterministic 5-step procedure
        rules/rules.yaml                # 4 rules: R001–R004 with literal ARG KQL
        templates/
          output-report.md              # check verb report template
          output-quota-check.md         # pre-deploy quota gate template
        prompts/
          check.prompt.md
          deploy.prompt.md
          status.prompt.md
  runbooks/
    prod.yaml                           # committed template (quota_limits, alternate_regions)
    prod.values.yaml                    # GITIGNORED — your real sub ID
    prod.values.yaml.example            # schema reference
  exports/
    .gitkeep
    test-run.md                         # simulated test outcome
```

## Acceptance criteria mapping

| Criterion | Where it lives |
| --- | --- |
| ARG queries enumerate by SKU + region | `rules/rules.yaml` R001 (VMs by SKU/region), R002 (vCPUs via vcpu_per_sku map) |
| Suggests alternate regions | SKILL.md Step 4; `runbook prod.yaml` `alternate_regions` map |
| Optional auto-file quota request | Out of scope for v1 — see below |

## Known limitations

*   **Quota LIMITS are not available in ARG.** Current *counts* come from ARG via `execute_query`.
    *Limits* are read from the `quota_limits` map in `runbooks/prod.yaml`, which operators must
    keep in sync manually. Use `az vm list-usage --location <region>` to get current limits.
*   Quota limits change after increase requests — update `quota_limits` in `prod.yaml` whenever
    limits are raised.
*   The `vcpu_per_sku` map in `rules.yaml` (R002) must be kept in sync with Azure SKU definitions
    as new SKUs are introduced.

## Out of scope (future enhancements)

*   **Auto-file quota increase request** via Azure Quota API — not implemented in v1.
    Future versions may call `az support tickets create` or the ARM Quota API automatically.
*   Reading quota limits directly from Azure (ARM `usages` API) — future enhancement to replace
    the manual `quota_limits` map.

## Determinism Deviation

This PoC does **not** include `validate_query` in its tool allowlist per source spec
(ratification #7 from `.squad/decisions/inbox/copilot-bishop-ratifications-2026-05-12.md`).
The SKILL.md procedure uses `generate_query` → `execute_query` instead of
`validate_query` → `execute_query`.

KQL correctness is assured by pre-testing during development. Operators running this PoC live
should hand-verify `rules.yaml` KQL via the `validate_query` tool in another workspace if uncertain.
