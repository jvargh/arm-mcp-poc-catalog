# Pre-deploy Blast Radius Analyzer (ARM MCP PoC - POC-2)

A Copilot CLI / VS Code chat agent that inspects an ARM template **before deployment**,  
queries Azure Resource Graph (ARG) for affected resources, categorizes every change as  
REPLACE / DELETE / MODIFY / CREATE, and produces a **byte-near-identical risk report**  
**every time** it is run with the same template and scope.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## Why "blast radius"?

In SRE / ops terminology, **blast radius** = the scope of impact if a change goes wrong.  
Before you run `az deployment ... create` against a production subscription, you want to  
know: _which existing resources will this touch, what gets replaced vs. modified vs._  
_deleted, and how far does the damage spread if something breaks?_ This agent measures  
that radius **before** the deployment happens. It is a pre-deploy what-if + risk scorer,  
not a post-mortem tool. It never deploys (see [Known limitations](#known-limitations)).

## Checks performed via the ARM MCP

The agent uses two ARM MCP tools, `validate_query` (KQL syntax check) and `execute_query`  
(run KQL against Azure Resource Graph), driven by literal queries in  
`.github/copilot/skills/blast-radius-analyzer/rules/rules.yaml`. Queries are never  
LLM-generated at runtime; that is how the report stays byte-near-identical across runs.

| Rule | Check | Risk weight |
| --- | --- | --- |
| R001 | **CREATE**: resource in template, not in ARG (new addition) | 2 |
| R002 | **MODIFY**: exists in ARG, mutable type (in-place config update) | 10 |
| R003 | **REPLACE**: exists in ARG, replace-sensitive type (immutable properties would change) | 15 |
| R004 | **DELETE**: exists in ARG within scope, absent from template | 15 |
| R005 | **Policy violations** on in-scope resources (`policyresources` table). Skipped if table unavailable. | varies |
| R006 | **Dependency fan-out**: downstream consumers of shared platform resources (e.g., VNets) to surface high-impact blast zones | varies |

Per-resource flow: parse `template.resources[]` → `validate_query` → `execute_query`  
against ARG scoped to your `subscriptions` + `rg_include` → categorize → sum weighted  
risk → compare to `risk_threshold` → render fixed-format report.

## How the template, rules, and ARG fit together

```
template JSON                  rules.yaml                       Azure Resource Graph
(what you WANT to deploy)      (which TYPES are risky)          (what EXISTS today)
        │                             │                                 │
        └──── resource type ──────────┴──── KQL `type in~ (...)` ───────┘
                                              ↓
                                     categorize per resource
                                       (CREATE / MODIFY / REPLACE / DELETE)
                                              ↓
                                          sum weighted risk
```

`rules.yaml` is a **type classifier**. Each rule lists Azure resource types known to be  
risky in a specific way, plus the weight to assign. The template JSON tells the agent  
_which types you are about to deploy_. ARG tells it _what already exists_. The agent  
intersects all three.

Worked example for the shipped `runbooks/azuredeploy.test.json` (storage + NSG + VNet):

| Resource in template | Type | Matches in `rules.yaml` | Outcome (depends on ARG) |
| --- | --- | --- | --- |
| `storageAccountName` | `Microsoft.Storage/storageAccounts` | R002 (modify, w=10), R003 (create, w=2), R004 (delete, w=15) | Exists in scope → **MODIFY** (10). Otherwise → **CREATE** (2). |
| `nsgName` | `Microsoft.Network/networkSecurityGroups` | R004 only | Not in R001/R002/R003, so a new NSG is **CREATE** with no weighted hit. NSGs only contribute to DELETE risk. |
| `vnetName` | `Microsoft.Network/virtualNetworks` | R001 (replace, w=15), R003 (create, w=2), R004 (delete, w=15), R006 (fan-out, w=8) | Exists → **REPLACE** (15), and **R006** if it has ≥3 subnets+peerings. Otherwise → **CREATE** (2). |

Two sweeps run independently of the template:

*   **R004 DELETE sweep:** any resource ARG returns inside your `rg_include` whose name is  
    not in the template is flagged as a DELETE candidate at weight 15. Pointing a sparse  
    template at a populated RG list is what makes the DELETE risk spike.
*   **R005 / R006:** scope-wide cross-cuts (policy compliance, fan-out), not driven by  
    the template at all.

Why this design: the KQL in `rules.yaml` filters by `type` only, never by name. Names  
come from the template parse. That separation is what keeps the report deterministic.  
The rules pack is hashed into `run_id`, so the same template + same ARG state always  
produces the same categorization.

## Reading the output report

Every run drops a markdown file into `exports/` named  
`BR-{YYYYMMDD}-{scope}-{rules_hash}.md`. The sections, in order:

1.  **Header** with `Run ID`, `Scope`, `Template`, `Generated (UTC)`, and `Ruleset hash`.  
    Identical inputs produce an identical `Run ID`, which is the determinism contract.
2.  **Summary table.** Counts of resources in the template, resources evaluated, rules  
    evaluated / skipped / invalid, `Total risk score`, `Risk threshold`, and `Threshold status` (`OK` or `EXCEEDED`). Status is the gate you would wire into CI.
3.  **Change Risk Table.** One row per categorized resource with category, name, type,  
    weight, and severity. Sorted by category then name for stable diffs.
4.  **Policy Violations** (R005). May show `SKIPPED — policyresources-unavailable` when  
    the `PolicyResources` ARG table is not enabled in the subscription. That is expected  
    behavior, not an error.
5.  **Dependency Fan-out Warnings** (R006). VNets where `subnets + peerings >= 3`.  
    Independent of the template; flags existing shared infra you should avoid touching.
6.  **Risk Breakdown by Category.** Per-category resource lists with cumulative weight.  
    DELETE includes a warning banner because removal is the most consequential category.

### Worked example: a high-score run

A real run of the shipped test template against six populated production-style RGs  
produced:

| Metric | Value |
| --- | --- |
| Resources in template | 3 |
| Total risk score | 911 |
| Risk threshold | 50 |
| Threshold status | **EXCEEDED** |

Breakdown: 57 DELETE candidates × 15 = **855**, 3 CREATEs × 2 = **6**, plus three R006  
fan-out hits on existing VNets making up the rest. Reading the report:

*   **The CREATE section is what the template actually does.** Only 3 net-new resources:  
    `stgtest*` storage, `nsg-test`, `vnet-test`.
*   **The DELETE section is what the template would destroy if treated as desired state.**  
    Because the test template names only 3 resources but `rg_include` covers RGs with 57  
    real resources (AKS clusters, ACR, Log Analytics workspaces, App Insights, dashboards,  
    Foundry storage, ...), the R004 sweep flags every one of them at weight 15. This is  
    the agent doing its job: a sparse template pointed at populated RGs is the canonical  
    "do not deploy" scenario.
*   **Unresolved ARM expressions stay literal.** The storage row shows  
    `[concat('stgtest', uniqueString(resourceGroup().id))]` because the parser does not  
    evaluate ARM functions. Expected.
*   **Fan-out warnings are advisory.** Three `aks-vnet-*` VNets each scored 3; they are  
    not in the template but are flagged so you know touching them later carries reach.

### What to do when status = EXCEEDED

The agent never auto-resolves. Options:

1.  **Verify scope is correct.** If `rg_include` is broader than the template's intended  
    target, narrow it. A test template should not be pointed at production RGs.
2.  **Verify the template is correct.** If real production resources are showing up as  
    DELETE candidates, the template is missing resources it should declare.
3.  **Raise** `**risk_threshold**` only with sign-off. The threshold is the gate; do not  
    silence the gate to make the report green.

## What it does

1.  Reads a user-supplied ARM template path from the runbook (`template_path`).
2.  Parses `template.resources[]` to extract resource names, types, and dependencies.
3.  For each resource: calls `validate_query` → `execute_query` against ARG to determine  
    whether the resource exists, then categorizes the change:
    *   **REPLACE** - resource exists and its type is replace-sensitive (immutable properties would change; risk weight 15).
    *   **DELETE** - resource exists in the scoped ARG result but is absent from the template (risk weight 15).
    *   **MODIFY** - resource exists and is a mutable type (in-place config update; risk weight 10).
    *   **CREATE** - resource does not yet exist in ARG (new addition; risk weight 2).
4.  Runs two supplemental rules: R005 (policy violations on in-scope resources) and R006  
    (dependency fan-out on shared platform resources).
5.  Computes a total risk score and compares it against the `risk_threshold` from the runbook.
6.  Renders a deterministic markdown risk report using a fixed template.

## Why the output is deterministic

*   Queries are NOT generated by the LLM at run time - they are read verbatim from `rules.yaml`.
*   The skill instructs the agent to emit the report using a fixed template with no paraphrasing.
*   Change categorization logic is rule-driven: lookup in ARG → compare → assign category.
*   Sort order, column headers, decimal precision, and section order are all pinned in `SKILL.md`.
*   Run ID is the scope name + UTC date + SHA-256 of `rules.yaml` - identical inputs → identical run ID.

## How it works (end-to-end flow)

What happens after you type `@blast-radius-analyzer analyze for scope prod`:

1.  **Chat client routes the message.** VS Code Copilot Chat sees the `@blast-radius-analyzer`  
    mention, loads [`.github/copilot/agents/blast-radius-analyzer.agent.md`](.github/copilot/agents/blast-radius-analyzer.agent.md)  
    as the system prompt, and reads its `tools:` / `mcp:` declarations.
2.  **Workspace MCP servers start.** The runtime reads [`.vscode/mcp.json`](.vscode/mcp.json),  
    starts the ARM MCP server (`https://mcp.management.azure.com`), and obtains the tool list.
3.  **LLM follows SKILL.md Step 1 - load config.** Reads `runbooks/prod.yaml` (after  
    substituting `prod.values.yaml`), extracts `subscriptions`, `template_path`, `risk_threshold`,  
    `rg_include`, `rg_exclude`.
4.  **LLM follows SKILL.md Step 2 - parse template.** Reads and parses the JSON at  
    `template_path`. Extracts `resource_name`, `resource_type`, `resource_depends_on` for  
    every entry in `resources[]`.
5.  **LLM computes** `**run_id**` **deterministically.** `BR-{YYYYMMDD}-prod-{sha256(rules.yaml)[:8]}`.
6.  **LLM follows SKILL.md Step 3 - ARG cross-reference loop.** For each parsed resource,  
    calls `validate_query` → `execute_query` to check existence. Assigns change category.
7.  **LLM follows SKILL.md Step 4 - detect DELETE candidates.** Sweeps ARG for resources  
    in scope that are NOT in the template.
8.  **LLM follows SKILL.md Step 5 - supplemental rules loop.** Runs R001–R006 literal KQL  
    from `rules.yaml` via `validate_query` → `execute_query`. R005 uses `skip_if_unavailable: true`.
9.  **LLM computes total risk score and threshold status.**
10.  **LLM renders the report** by literal `{{placeholder}}` substitution into  
    `templates/output-report.md`. No paraphrasing.
11.  **LLM streams the result back to chat.** The rendered report appears inline.

## Install

1.  Clone this folder anywhere and open it as a workspace in VS Code.  
    The ARM MCP server is **already declared** at workspace scope in [`.vscode/mcp.json`](.vscode/mcp.json).
    *   If your VS Code account isn't yet authorized for the ARM MCP preview, click through  
        \<https://aka.ms/JoinARMMCP\> once.
    *   For GitHub Copilot CLI users: copy the `Azure Resource Manager MCP Server` entry from  
        `.vscode/mcp.json` into `~/.copilot/mcp.json`.
2.  Sign in to Azure (`az login`) with Reader + Resource Graph Reader on the target scope.

> The MCP server entry at workspace scope (`.vscode/mcp.json`):
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

## Configure your scope (do this before first run)

`scope prod` maps to [`runbooks/prod.yaml`](runbooks/prod.yaml).

### Two-file pattern: template + values

| File | Committed? | Contains |
| --- | --- | --- |
| [`runbooks/prod.yaml`](runbooks/prod.yaml) | ✅ yes | Template with `${placeholder}` tokens. No real values. |
| `runbooks/prod.values.yaml` | ❌ **gitignored** | Your real subscription ID, template path, RG names. |
| [`runbooks/prod.values.yaml.example`](runbooks/prod.values.yaml.example) | ✅ yes | Schema reference - copy this to start. |

### First-time setup

1.  **Copy the example to a real values file:**
2.  **Edit** `**runbooks/prod.values.yaml**` and fill in real values:
3.  **Verify** `**.gitignore**` **excludes it** (root `.gitignore` has `**/runbooks/*.values.yaml`).
4.  **Point** `**template_path**` at the ARM template you want to analyze.

## Run

VS Code chat:

```
@blast-radius-analyzer analyze for scope prod
```

GitHub Copilot CLI:

```
gh copilot -p "Analyze blast radius for scope prod"
```

Drill-down on one resource:

```
@blast-radius-analyzer drilldown aks-prod-cluster
```

## Layout

```
POC-02-blast-radius-analyzer/
  README.md
  .github/copilot/
    agents/
      blast-radius-analyzer.agent.md   # agent persona + tool allowlist + hard rules
    skills/
      blast-radius-analyzer/
        SKILL.md                        # deterministic procedure (7 steps)
        rules/rules.yaml                # 6 rules: R001–R006 with literal KQL
        templates/
          output-report.md              # fixed analyze report format
          output-drilldown.md           # fixed drilldown format
        prompts/
          analyze.prompt.md
          drilldown.prompt.md
  runbooks/
    prod.yaml                           # committed template (placeholders only)
    prod.values.yaml                    # GITIGNORED - your real sub ID / template path
    prod.values.yaml.example            # committed schema reference
  exports/
    .gitkeep                            # analysis outputs land here
    test-run.md                         # simulated test run output
```

## Acceptance criteria mapping

| Criterion | Where it lives |
| --- | --- |
| Parses ARM template, extracts resource IDs/scopes | `SKILL.md` Step 2 - Parse target template |
| Cross-refs existing resources via ARG | `SKILL.md` Step 3 - Cross-reference with ARG |
| Categorizes change as create/no-op/modify/replace/delete | `SKILL.md` Steps 3–4; R001, R002, R003, R004 rule types |
| Flags policy violations | R005 (`policyresources`), `skip_if_unavailable: true` |
| Flags dependency fan-out | R006 (VNet fan-out score) |

## Known limitations

### What-if mode - v1 renders the report locally; `create_template_deployment` is NOT called

The ARM MCP `create_template_deployment` tool does not expose a native what-if flag in  
this PoC's scope. As a result:

*   The agent's `analyze` verb produces a **what-if REPORT only** - it does not invoke the  
    deploy tool. Change categorization and risk scoring are derived from ARG queries against  
    the parsed template, not from a live ARM what-if call.
*   `create_template_deployment` is listed in the agent's `tools:` allowlist **for future**  
    **use only** - when ARM MCP exposes a native what-if mode it can be wired in a future `apply`  
    verb with an explicit confirm gate (per ratification #3).
*   **Hard rule (binding):** The agent MUST NOT call `create_template_deployment` in v1.  
    This is enforced in `agents/blast-radius-analyzer.agent.md` hard rule #7.

To perform an actual what-if deployment, use the Azure CLI outside this agent:

```
az deployment group create `
  --resource-group <rg> `
  --template-file <template_path> `
  --what-if
```

### R005 - `policyresources` table availability

R005 queries the `PolicyResources` table in ARG (`microsoft.policyinsights/policystates/latest`).  
This table may not be enabled in all subscriptions. If `execute_query` returns an error or  
empty result due to table unavailability, the agent emits:

```
STATUS=SKIPPED REASON=policyresources-unavailable
```

and continues. Live validation in VS Code will confirm availability in your subscription.  
This is controlled by `skip_if_unavailable: true` in `rules.yaml` R005.

```
subscription_id: "11111111-2222-3333-4444-555555555555"
template_path:   "infra/azuredeploy.json"
risk_threshold:  30
rg_include:
  - "payments-prod-rg"
rg_exclude: []
```

```
Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
```