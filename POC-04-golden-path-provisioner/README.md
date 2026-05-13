# Golden Path Provisioner (ARM MCP PoC - POC-4)

A Copilot CLI / VS Code chat agent that provisions pre-approved ARM golden-path templates  
(AKS+ACR+KV+LA, App Service+SQL+KV, or Storage+Data Factory+KV) into the right resource  
group with **deterministic naming, tag enforcement, live status polling, and cancel-on-failure**.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## Why "Golden Path"?

"Golden path" is a platform-engineering term (popularized by Spotify, now standard in the  
Backstage / IDP / CNCF community) for **the opinionated, pre-approved, well-supported way**  
**to build and deploy something in your org**. Teams can go off-path, but the golden path is  
the one that "just works", is secure by default, and is owned by the platform team.

This agent is the _provisioner_ side of that idea: it doesn't define the golden path  
(that lives in [runbooks/prod.yaml](runbooks/prod.yaml) and the ARM templates under  
`remediation/`, owned by the platform team), it puts workloads onto it. Concretely:

| Golden-path property | How this PoC enforces it |
| --- | --- |
| Pre-approved, opinionated templates | Fixed catalog of 3 ARM templates (`aks-baseline`, `webapp-baseline`, `data-baseline`). No free-form ARM. |
| Secure by default | Hardening baked into each template (Key Vault soft-delete + RBAC + private, ACR Premium + private + zone-redundant, AKS Entra + Azure RBAC + zones). Operator cannot override. |
| Consistent identity | Deterministic naming (`{prefix}-{team}-{region}-{type}`) and a fixed 5-tag set (`Team`, `Environment`, `ManagedBy`, `CostCenter`, `DeployedOn`). |
| Compliance gate | Pre-deploy KQL rules (R001 naming, R002 tags, R003 public IP) every workload must pass. |
| Safe operations | What-if-only in v1, mandatory `confirm` gate for cancel, audit trail in `exports/`. |

If you're new to the term, think of it as "the paved road for Azure deployments in this org".

## What it does

1.  Loads the golden path catalog and runbook config from [runbooks/prod.yaml](runbooks/prod.yaml), substituting `${...}` tokens from the gitignored [runbooks/prod.values.yaml](runbooks/prod.values.yaml).
2.  Computes a deterministic `Run ID` of the form `GP-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}` (e.g. `GP-20260513-prod-4b86d445`).
3.  Matches the workload description to a pre-approved template by keyword scan against `golden_path_catalog`, in file order, first match wins. Logs `TEMPLATE SELECTED: <name> (matched keyword: <kw>)` and the template path.
4.  Validates that `--region` is in `allowed_regions`. Aborts otherwise.
5.  Generates resource names following `{naming_prefix}-{team}-{region}-{resource-type-short}` (see ACR exception below). No LLM naming.
6.  Builds the tag set by merging `default_tags` from the runbook (`Environment`, `ManagedBy`, `CostCenter`) with runtime tags (`Team`, `DeployedOn`).
7.  Emits a Template Parameter Summary (the values bound to the ARM template's `parameters{}`) and an Estimated Resource Count.
8.  Runs pre-deploy compliance rules (R001 naming, R002 tags, R003 public IP) via `execute_query` against Azure Resource Graph. KQL is read verbatim from [rules/rules.yaml](.github/copilot/skills/golden-path-provisioner/rules/rules.yaml).
9.  Renders a What-If Plan Summary listing each resource (name, type, API version), the hardening defaults baked into the template, and the ARM-resolved dependency order. **v1 does NOT call** `**create_template_deployment**`**.**
10.  Writes the rendered plan to `exports/{run_id}-provision-report.md` with a `WOULD DEPLOY (NOT EXECUTED in v1)` footer.
11.  Supports `status` polling every 10 seconds and `cancel` with mandatory user `confirm` gate.

## Determinism Deviation

> **This PoC does not include** `**generate_query**` **or** `**validate_query**` **in its tool allowlist per source spec.**
> 
> KQL correctness is assured by pre-testing during development. All KQL queries are stored  
> verbatim in `rules/rules.yaml` and are NOT generated or validated by the LLM at runtime.
> 
> *   `generate_query` is excluded: KQL is pre-canned in `rules.yaml`; no LLM derivation is needed.
> *   `validate_query` is excluded: per the source spec tool allowlist (ratification #7). The SKILL.md  
>     procedure goes **directly to** `**execute_query**` after scope substitution - the validate step is  
>     skipped entirely.
> 
> Operators running this PoC live who want to verify KQL syntax should hand-verify  
> `rules/rules.yaml` queries via the `validate_query` tool in a separate workspace before  
> the first production run.

## Why the output is deterministic

*   **Template selection**: keyword match against `golden_path_catalog` in `prod.yaml`; first match wins.  
    Given the same workload description and catalog, the same template is always chosen.
*   **Resource naming**: `{naming_prefix}-{team}-{region}-{resource-type-short}` assembled from  
    runbook values + user inputs. No model creativity. The `resource-type-short` suffixes are fixed in  
    [SKILL.md](.github/copilot/skills/golden-path-provisioner/SKILL.md) Step 3 (`managedclusters`→`aks`,  
    `registries`→`acr`, `vaults`→`kv`, `workspaces`→`la`, `sites`→`app`, `servers`→`sql`,  
    `storageaccounts`→`st`, `factories`→`adf`).
*   **ACR naming exception**: Azure Container Registry forbids hyphens, so the AKS template assembles  
    the ACR name as `concat(namingPrefix, team, replace(location,'-',''), 'acr')` →  
    e.g. `gpplatformeastus2acr`. All other resources keep the hyphenated pattern.
*   **Tags**: merged set is fixed: `{Environment, ManagedBy, CostCenter}` from `default_tags` in  
    the runbook, plus `{Team, DeployedOn}` from CLI args + UTC date.
*   **KQL queries**: read verbatim from `rules/rules.yaml`, not generated.
*   **Run ID**: `GP-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}` - plain string assembly. The hash  
    depends only on `rules.yaml` content, not on values.yaml or CLI args.
*   **Polling interval**: fixed at 10 seconds.

## v1 Deploy Constraint (locked decision)

> **What-if only -** `**create_template_deployment**` **is NEVER called in v1.**
> 
> Per the locked ratification (ratification #3): the `provision` verb produces a rendered  
> would-deploy plan and stops. The `create_template_deployment` tool is listed in the agent's  
> `tools:` block because the live flow requires it, but it is explicitly forbidden by the agent's  
> hard rules in v1.
> 
> See [exports/GP-20260513-prod-4b86d445-provision-report.md](exports/GP-20260513-prod-4b86d445-provision-report.md)  
> for a real provision run, ending with the `WOULD DEPLOY (NOT EXECUTED in v1)` footer.

## Tool allowlist (exactly 4 tools)

| # | Tool | Used by |
| --- | --- | --- |
| 1 | `create_template_deployment` | Listed for live path; MUST NOT be called in v1 |
| 2 | `get_arm_template_deployment_status` | `status` verb (10s polling) |
| 3 | `cancel_arm_template_deployment` | `cancel` verb (after user confirmation) |
| 4 | `execute_query` | Compliance rules (R001–R003 via literal KQL) |

## Agent verbs

| Verb | Description |
| --- | --- |
| `provision` | Keyword-match → template → name/tag plan → what-if render (NOT EXECUTED in v1) |
| `status` | Poll deployment status every 10s |
| `cancel` | Cancel in-progress deployment with mandatory `confirm` gate |

## How it works (end-to-end)

1.  User types `@golden-path-provisioner provision --workload "kubernetes api backend" --team platform --region eastus2 --resource-group aks01day2-rg`.
2.  Agent loads `runbooks/prod.yaml` + `prod.values.yaml`. Extracts `subscriptions`, `naming_prefix`, `default_tags`, `allowed_regions`, `golden_path_catalog`.
3.  Computes `run_id = GP-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}` (e.g. `GP-20260513-prod-4b86d445`).
4.  Keyword scan: `kubernetes` matches `aks-baseline` → template selected; logs `TEMPLATE SELECTED: aks-baseline (matched keyword: aks)` and the template path.
5.  Region check: confirms `eastus2 ∈ allowed_regions`.
6.  Naming generated: `gp-platform-eastus2-aks`, `gpplatformeastus2acr` (no-hyphen ACR exception), `gp-platform-eastus2-kv`, `gp-platform-eastus2-la`.
7.  Tags merged: `Team=platform`, `Environment=prod`, `ManagedBy=golden-path-provisioner`, `CostCenter=C001`, `DeployedOn=<UTC YYYYMMDD>`.
8.  Template parameters bound: `namingPrefix`, `team`, `location`, `environment`, plus template-specific params (e.g. `aksNodeCount=3`, `aksNodeVmSize=Standard_D4s_v5`, `logAnalyticsRetentionDays=30`).
9.  Pre-deploy compliance: `execute_query` called for R001 (naming), R002 (tags), R003 (public IP), in file order. KQL passed verbatim from `rules.yaml`.
10.  What-if plan rendered via `templates/output-report.md`. Includes per-resource hardening defaults and ARM-resolved dependency order.
11.  Agent writes `exports/{run_id}-provision-report.md` with the `WOULD DEPLOY (NOT EXECUTED in v1)` footer and stops.
12.  _(Live flow, future version)_ Agent calls `create_template_deployment`, then polls `get_arm_template_deployment_status` every 10s.
13.  On failure: agent prompts for `confirm`, calls `cancel_arm_template_deployment`, writes audit line to `exports/cancel-audit.jsonl`.

## Export anatomy

Each section of the rendered report (see [exports/GP-20260513-prod-4b86d445-provision-report.md](exports/GP-20260513-prod-4b86d445-provision-report.md)) maps to a deterministic source:

| Report section | Source | Notes |
| --- | --- | --- |
| `Run ID`, `Scope`, `Ruleset hash` | SKILL.md Step 1 | `scope` from `--scope` (default `prod`); hash from `rules.yaml`. |
| `Workload`, `Selected Template`, template path | SKILL.md Step 2 | Keyword-match log line; first match wins. |
| `Region ✅ in allowed_regions` | SKILL.md Step 3.1 | Halts the run if the region is not allowed. |
| **Naming table** | SKILL.md Step 3.2 + AKS template variable | All names from `{prefix}-{team}-{region}-{type-short}` except ACR (no hyphens). |
| **Tags table** | `default_tags` in `prod.yaml` + runtime `Team`/`DeployedOn` | 5 tags total when CostCenter is set in values.yaml. |
| **Template Parameter Summary** | `golden_path_catalog.<entry>.param_schema.required_parameters` | Values come from CLI args + runbook + template defaults. |
| **Estimated Resource Count** | Count of `resources[]` in the selected ARM template | 4 for `aks-baseline`. |
| **Pre-Deploy Compliance Check** | `execute_query` results for each rule in `rules.yaml` | `validate_query` is intentionally skipped (see Determinism Deviation). |
| **What-If Plan Summary** | Selected template + `--resource-group` + subscription from runbook | Includes per-resource hardening defaults (Key Vault soft-delete, ACR Premium/private, AKS Entra+RBAC+zones) and ARM-resolved `dependsOn` order. |
| `WOULD DEPLOY (NOT EXECUTED in v1)` footer | `templates/output-report.md` | Always present in v1; gates real deploys behind a future `apply` verb. |

## Install

1.  Clone this folder and open it as a workspace in VS Code.  
    The ARM MCP server is declared at workspace scope in [`.vscode/mcp.json`](.vscode/mcp.json).
    *   VS Code will prompt you to start the server on first chat open.
    *   Join the ARM MCP preview at \<https://aka.ms/JoinARMMCP\> if needed.
    *   For GitHub Copilot CLI: copy the `Azure Resource Manager MCP Server` entry to `~/.copilot/mcp.json`.
2.  Sign in to Azure (`az login`) with **Contributor** on the target resource groups.

> MCP server entry (`.vscode/mcp.json`):
> 
> ```
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
| --- | --- | --- |
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens. No real values. |
| `runbooks/prod.values.yaml` | ❌ gitignored | Your real subscription ID, naming prefix, cost center, allowed regions. |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference - copy this to start. |

### First-time setup

```
Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
# Edit prod.values.yaml: fill in subscription_id, naming_prefix, cost_center, environment
```

## Run

VS Code chat:

```
@golden-path-provisioner provision --workload "kubernetes api backend" --team platform --region eastus2 --resource-group aks01day2-rg
@golden-path-provisioner status  --deployment gp-platform-eastus2-20260513 --resource-group aks01day2-rg
@golden-path-provisioner cancel  --deployment gp-platform-eastus2-20260513 --resource-group aks01day2-rg
```

### CLI args reference

| Arg | Verbs | Source / used for |
| --- | --- | --- |
| `--scope` | all | Selects `runbooks/<scope>.yaml`. Defaults to `prod`. |
| `--workload` | `provision` | Free-text; tokenised and keyword-matched against `golden_path_catalog`. |
| `--team` | `provision` | Injected into resource names and the `Team` tag. |
| `--region` | `provision` | Must be in `allowed_regions` (from runbook). Used in resource names and as the ARM `location`. |
| `--resource-group` | `provision`, `status`, `cancel` | Operator-supplied target RG. The agent does NOT create the RG; it must already exist. |
| `--deployment` | `status`, `cancel` | ARM deployment name. |

GitHub Copilot CLI:

```
gh copilot -p "Provision AKS golden path for team platform in eastus2 into resource group aks01day2-rg"
```

## Layout

```
POC-04-golden-path-provisioner/
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
    prod.values.yaml                     # gitignored — your real values
  exports/
    GP-{YYYYMMDD}-{scope}-{hash8}-provision-report.md   # one per provision run
    cancel-audit.jsonl                                  # appended on every cancel attempt
```

## Acceptance criteria

| Criterion | Where it lives |
| --- | --- |
| Catalog of ≥3 templates with param schemas | `runbooks/prod.yaml → golden_path_catalog` (3 entries) |
| Naming + tag enforcement before deploy | SKILL.md Step 3; agent hard rules 4 & 5 |
| Live progress every 10s | SKILL.md Step 6; status.prompt.md |
| Auto-cancel + rollback hook on sub-resource failure | SKILL.md Step 7; cancel.prompt.md; exports/cancel-audit.jsonl |