# ARM MCP - PoC Catalog

A catalog of **25 proof-of-concept Copilot agents** built on the [Azure Resource Manager MCP Server](https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/introducing-the-azure-resource-manager-mcp-server/4517521) (public preview, May 2026). Each PoC is a self-contained VS Code workspace with its own agent persona, deterministic skill, pre-canned ARG queries, frozen output templates, and ARM template stubs where applicable.

## What is the ARM MCP Server?

The ARM MCP Server is a **remote MCP server** at `https://mcp.management.azure.com` that gives AI agents first-class access to Azure infrastructure operations through Azure Resource Manager. It exposes six tools:

| Tool | Purpose |
| --- | --- |
| `generate_query` | Turn a natural-language ask into Azure Resource Graph (KQL) |
| `validate_query` | Syntax-check an ARG query before running it |
| `execute_query` | Run an ARG query against your signed-in scope |
| `create_template_deployment` | Submit an ARM template to a resource group |
| `get_arm_template_deployment_status` | Poll deployment progress |
| `cancel_arm_template_deployment` | Stop an in-flight deployment |

All operations honor the signed-in user's RBAC and Azure Policy assignments.

*   **Announcement blog:** \<https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/introducing-the-azure-resource-manager-mcp-server/4517521\>
*   **Source repo & docs:** \<https://github.com/Azure/Azure-Resource-Manager-MCP\>

## How this catalog is organized

Two source documents define the PoC backlog:

*   [`ARM-MCP-PoC-Ideas.md`](ARM-MCP-PoC-Ideas.md) - **12 enterprise governance / FinOps / platform PoCs** (PoC 1–12).
*   [`ARM-MCP-SRE-PoCs.md`](ARM-MCP-SRE-PoCs.md) - **12 SRE / reliability PoCs** (SRE-PoC 1–12).

Every PoC has its own folder at the repo root with the same layout: agent definition, deterministic skill, literal ARG rules, frozen output templates, ARM template stubs (where the PoC deploys), and a `runbooks/` scope config split into a committed template and a gitignored values file.

## Catalog - Enterprise PoCs

| # | PoC | Folder |
| --- | --- | --- |
| 1 | Tag Hygiene Czar | [POC-01-tag-hygiene-czar/](POC-01-tag-hygiene-czar/) |
| 2 | Blast Radius Analyzer | [POC-02-blast-radius-analyzer/](POC-02-blast-radius-analyzer/) |
| 3 | Cost Driver Finder | [POC-03-cost-driver-finder/](POC-03-cost-driver-finder/) |
| 4 | Golden Path Provisioner | [POC-04-golden-path-provisioner/](POC-04-golden-path-provisioner/) |
| 5 | IaC Drift Detector | [POC-05-iac-drift-detector/](POC-05-iac-drift-detector/) |
| 6 | Incident Responder | [POC-06-incident-responder/](POC-06-incident-responder/) |
| 7 | Policy What-If | [POC-07-policy-what-if/](POC-07-policy-what-if/) |
| 8 | Estate Cartographer | [POC-08-estate-cartographer/](POC-08-estate-cartographer/) |
| 9 | ARM Template Fixer | [POC-09-arm-template-fixer/](POC-09-arm-template-fixer/) |
| 10 | Crown-Jewels Security | [POC-10-crown-jewels-security/](POC-10-crown-jewels-security/) |
| 11 | FinOps Rightsizer | [POC-11-finops-rightsizer/](POC-11-finops-rightsizer/) |
| 12 | ChatOps Bot | [POC-12-chatops-bot/](POC-12-chatops-bot/) |

## Catalog - SRE PoCs

| # | PoC | Folder |
| --- | --- | --- |
| 1 | Incident Triage | [SRE-PoC-01-incident-triage/](SRE-PoC-01-incident-triage/) |
| 2 | Change Freeze Enforcer | [SRE-PoC-02-change-freeze-enforcer/](SRE-PoC-02-change-freeze-enforcer/) |
| 3 | Pre-flight Safety | [SRE-PoC-03-preflight-safety/](SRE-PoC-03-preflight-safety/) |
| 4 | Auto Rollback | [SRE-PoC-04-auto-rollback/](SRE-PoC-04-auto-rollback/) |
| 5 | Reliability Posture Scorecard ⭐ | [SRE-PoC-05-Reliability-posture-scorecard/](SRE-PoC-05-Reliability-posture-scorecard/) |
| 6 | SLO Deployment Gate | [SRE-PoC-06-slo-deployment-gate/](SRE-PoC-06-slo-deployment-gate/) |
| 7 | Capacity / Quota Guardian | [SRE-PoC-07-capacity-quota-guardian/](SRE-PoC-07-capacity-quota-guardian/) |
| 8 | Blast Radius Simulator | [SRE-PoC-08-blast-radius-simulator/](SRE-PoC-08-blast-radius-simulator/) |
| 9 | Stuck Deployment Janitor | [SRE-PoC-09-stuck-deployment-janitor/](SRE-PoC-09-stuck-deployment-janitor/) |
| 10 | Runbook Executor | [SRE-PoC-10-runbook-executor/](SRE-PoC-10-runbook-executor/) |
| 11 | Post-Incident Reconstructor | [SRE-PoC-11-post-incident-reconstructor/](SRE-PoC-11-post-incident-reconstructor/) |
| 12 | Weekly Cleanup PRs | [SRE-PoC-12-weekly-cleanup-prs/](SRE-PoC-12-weekly-cleanup-prs/) |

⭐ = reference implementation. Read `SRE-PoC-5` first to understand the determinism contract (literal KQL in YAML, `validate_query` → `execute_query`,  
fixed sort orders, frozen markdown templates with `{{placeholder}}` slots only, run IDs derived from input hashes).

## Getting started with any PoC

1.  **Install the ARM MCP Server** once: open \<https://aka.ms/JoinARMMCP\> in VS Code.
2.  **Sign in to Azure** (`az login`) with at least Reader + Resource Graph Reader on the target scope. Deploy-capable PoCs also need Contributor on the target RGs.
3.  **Open one PoC folder** in VS Code as a workspace. The `.vscode/mcp.json` declares the ARM MCP server at workspace scope; VS Code will start it on first chat use.
4.  **Configure scope** - copy `runbooks/<scope>.values.yaml.example` to `runbooks/<scope>.values.yaml` and fill in your subscription ID + resource groups. The values file is gitignored.
5.  **Invoke the agent** - see each PoC's `README.md` for the verbs it accepts (typically `run`, `drilldown`, `remediate`).

## Determinism contract (every PoC)

*   ARG queries are **read literally from YAML**, never authored by the LLM at run time. Scope filters are string-substituted in.
*   Each ARG call is `validate_query` → `execute_query`. If `validate_query` fails, the rule is marked `INVALID` and the agent does not retry.
*   Run IDs follow `<POC-PREFIX>-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}` so re-running with the same inputs produces the same ID.
*   Output templates are frozen markdown with `{{placeholder}}` substitution only - no paraphrasing by the model.
*   Deploy-capable PoCs require an explicit user verb (e.g. `apply`, `remediate`) **and** a confirm gate. They honor a global freeze flag from `runbooks/<scope>.yaml`.

## Repo conventions

*   **Scope config split** - `runbooks/<scope>.yaml` is the committed template with `${placeholder}` tokens; `runbooks/<scope>.values.yaml` holds your real subscription/RG values and is gitignored.
*   **No secrets in YAML, agents, or templates.** Use Azure Key Vault references or environment variables in deployable templates.

## Copilot CLI usage notes

Each PoC README shows two ways to invoke the agent: a VS Code Copilot Chat form (`@agent-name verb ...`) and a GitHub Copilot CLI form. A few cross-cutting things to know about the CLI form:

*   **Use the standalone `copilot` binary, not `gh copilot`.** The `gh copilot` wrapper re-execs `copilot` through cmd without quoting, so it fails when the resolved `copilot` lives on a path containing spaces (e.g. the VS Code Insiders shim under `...\AppData\Roaming\Code - Insiders\...`). If your `copilot` binary is on a space-free path, `gh copilot -p "..."` is equivalent.
*   **`@agent-name` mentions are VS Code Chat-only.** The CLI does not parse `@` mentions to route to a specific agent, so the CLI prompts in each README are written in plain English instead. The agent's skill files in `.github/copilot/skills/` still get pulled in as workspace context when you run `copilot` from the PoC folder.
*   **First runs are slow.** Expect 3–5 minutes on a busy subscription: each rule typically does one `validate_query` + one `execute_query` ARG round-trip (gated by a model turn), and large result sets get serialized back into context.
*   **Run from the PoC folder.** `cd` into the PoC directory before invoking `copilot` so the workspace `.vscode/mcp.json` and `.github/copilot/` agent + skill files are picked up.
*   **Auth.** `az login` once with Reader + Resource Graph Reader on your target scope; deploy-capable PoCs also need Contributor on the target RGs.

Common flags worth knowing: `--allow-all-tools` (skip per-tool approval prompts), `--no-ask-user` (fail rather than block on ambiguity), `-C <dir>` (run as if from another directory), `--additional-mcp-config <json>` (inject extra MCP servers without editing `~/.copilot/mcp-config.json`).

## Feedback / issues

For ARM MCP Server bugs and feature requests: \<https://github.com/Azure/Azure-Resource-Manager-MCP/issues\>