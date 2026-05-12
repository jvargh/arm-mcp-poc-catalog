# ARM MCP Server — Enterprise PoC Catalog

Reference: [Introducing the Azure Resource Manager MCP Server](https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/introducing-the-azure-resource-manager-mcp-server/4517521)

## About the ARM MCP Server (context for implementers)

A remote MCP server giving AI agents first-class access to ARM. Six tools currently exposed:

| Tool | Purpose |
| --- | --- |
| `generate_query` | Natural-language → Azure Resource Graph (ARG / KQL) query |
| `validate_query` | Static-validate ARG query before execution |
| `execute_query` | Run ARG query across the user's tenant/subscription scope |
| `create_template_deployment` | Deploy an ARM template to a target resource group |
| `get_arm_template_deployment_status` | Poll deployment progress / outputs / errors |
| `cancel_arm_template_deployment` | Abort an in-flight deployment |

Install: \<https://aka.ms/JoinARMMCP\>. All operations honor the signed-in user's RBAC + Azure Policy.

---

## How to use this document (instructions for the Copilot CLI fleet)

Each PoC below is a self-contained build assignment. For every PoC:

1.  Spin up a Copilot CLI agent in its own working directory (`pocs/<poc-id>/`).
2.  The agent must:
    *   Read the **Goal**, **Wow moment**, and **Acceptance criteria**.
    *   Use **only** the ARM MCP tools listed under **Tools used** (plus standard file/git tools).
    *   Produce: `README.md`, runnable script(s) or agent definition, sample prompts, and a recorded transcript (`demo.md`) showing the wow moment end-to-end against a real subscription.
3.  Tag deliverables with the PoC ID so they can be demoed independently.

Subscription assumptions: use a non-prod sub with at least one resource group the user owns, plus reader access at the subscription scope. Each PoC notes any extra prerequisite.

---

## PoC 1 — "Tag Hygiene Czar" agent

**Goal:** A standing agent that finds non-compliant resources by tag policy and produces a remediation plan + ARM deployment to fix them.

**Wow moment:** Customer asks _"Which prod resources are missing_ `_CostCenter_` _or_ `_DataClassification_` _and what would it cost me to fix them today?"_ — agent returns a categorized list, generates a patch ARM template, deploys it on approval, and reports back delta in \<60 seconds.

**Tools used:** `generate_query`, `validate_query`, `execute_query`, `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Configurable required-tag set via YAML.
*   Outputs a CSV/markdown report grouped by RG and resource type.
*   Generates an ARM template that applies missing tags via `Microsoft.Resources/tags`.
*   Dry-run mode (no deployment) and apply mode (with confirmation gate).

---

## PoC 2 — Pre-deploy "Blast Radius" analyzer

**Goal:** Before any ARM template deployment, the agent inspects the template, queries ARG for what would be touched/replaced, and produces a human-readable risk report.

**Wow moment:** Drop a 600-line ARM template into chat → agent answers _"This will replace 3 SQL servers in_ `_prod-east_` _(downtime ~12 min), modify NSG rules affecting 47 VMs, and breach your_ `_no-public-IP_` _policy on resource X."_

**Tools used:** `generate_query`, `execute_query`, `validate_query`, `create_template_deployment` (what-if mode), `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Parses ARM template, extracts resource IDs / scopes.
*   Cross-references existing resources via ARG.
*   Categorizes change as: create / no-op / modify / replace / delete.
*   Flags policy violations and dependency fan-out.

---

## PoC 3 — "Where did my money go?" cost-driver finder

**Goal:** Combine ARG topology with a natural-language question to surface the top cost-driving resources and their owners.

**Wow moment:** _"Why did East US 2 spend jump 22% last month?"_ → agent enumerates new/resized resources in that region in the last 30 days, joins with tags for owner + workload, and ranks them.

**Tools used:** `generate_query`, `execute_query`.

**Acceptance criteria:**

*   ARG query covering `resources` + `resourcecontainers` tables.
*   Filter by region, time window, and resource type.
*   Output sorted by created/changed timestamp with owner tag column.
*   Optional handoff to Azure Cost Management for actual $ figures.

---

## PoC 4 — Self-service "Golden Path" provisioner

**Goal:** Internal-developer-platform agent that takes a one-line workload description and deploys a pre-approved ARM golden-path template (e.g., AKS + ACR + Key Vault + Log Analytics) into the right RG with policy guardrails.

**Wow moment:** _"Spin up a sandbox for the payments team in westus3 with the standard secure baseline."_ — agent picks template, parameterizes it from the request, deploys, streams live status, and posts the connection details when done.

**Tools used:** `create_template_deployment`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`, `execute_query` (post-deploy verification).

**Acceptance criteria:**

*   Catalog of ≥3 golden-path templates with parameter schemas.
*   Naming convention + tag enforcement before deploy.
*   Live progress updates every 10s.
*   Auto-cancel + rollback hook if any sub-resource fails.

---

## PoC 5 — Drift detector for Infrastructure-as-Code

**Goal:** Compare a checked-in ARM template (Git source of truth) with live state in Azure and report drift in plain English.

**Wow moment:** _"Is_ `_infra/prod/network.json_` _still what's actually running?"_ — agent queries every resource the template should own, diffs properties, reports _"NSG_ `_prod-web-nsg_` _has rule_ `_AllowSSH_` _that is not in source — added by alice@contoso 4 days ago."_

**Tools used:** `generate_query`, `execute_query`.

**Acceptance criteria:**

*   Walks ARM template resource list.
*   Per-resource ARG query for current props.
*   Diff renderer (markdown table + JSON patch).
*   Optional: open a GitHub issue/PR with the drift.

---

## PoC 6 — Incident-time "Who/what/when" responder

**Goal:** During incidents, an on-call agent answers blast-radius questions instantly without humans writing KQL.

**Wow moment:** _"What changed in the last 2 hours in subscription X, who deployed it, and which deployments are still in-flight?"_ — agent runs ARG against `resourcechanges` + checks deployment statuses for currently-running ARM jobs, with a one-click cancel for any deployment correlating with the incident timeframe.

**Tools used:** `generate_query`, `execute_query`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`.

**Acceptance criteria:**

*   Time-windowed change feed.
*   List of in-flight deployments with `cancel` action.
*   Audit log of which agent action the responder approved.

---

## PoC 7 — Policy compliance "what-if" agent

**Goal:** Given a draft Azure Policy definition, the agent simulates impact: _"If I enforce this today, how many resources break?"_

**Wow moment:** Paste a new Policy definition → agent translates the `if` block into an ARG query, runs it, and returns the count + drill-down list of would-be non-compliant resources, grouped by owner.

**Tools used:** `generate_query`, `validate_query`, `execute_query`.

**Acceptance criteria:**

*   Accepts policy JSON as input.
*   Maps common policy aliases to ARG fields.
*   Outputs both summary chart data and per-resource list.
*   Exports to CSV for governance review.

---

## PoC 8 — Multi-subscription "Estate Cartographer"

**Goal:** Generate an interactive Mermaid/Markdown map of an entire Azure estate (subscriptions → RGs → resources → key relationships like NSG↔Subnet, MI↔KeyVault).

**Wow moment:** _"Map our entire_ `_contoso-prod_` _MG."_ — agent fans out ARG queries across all subs, builds a hierarchical diagram, and clicking any node prints the resource's properties and recent changes.

**Tools used:** `generate_query`, `execute_query`.

**Acceptance criteria:**

*   Handles ≥10 subscriptions in one run with paging.
*   Mermaid output renderable in VS Code.
*   Includes a "high-risk" overlay (public IPs, unencrypted disks, etc.).

---

## PoC 9 — ARM template "fixer" loop

**Goal:** Author-time helper that deploys, watches, captures errors, edits the template, and redeploys — autonomously, until green or a max-retry hit.

**Wow moment:** Hand the agent a broken ARM template; it deploys, sees the failure, reads the error, edits the template (e.g., adds missing dependency, fixes SKU), redeploys, and reports the diff that fixed it.

**Tools used:** `create_template_deployment`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`.

**Acceptance criteria:**

*   Bounded retry loop (default 3) with diff log per attempt.
*   Halt-on-destructive-change safeguard.
*   Final summary: working template + changelog.

---

## PoC 10 — "Show me my crown jewels" security posture agent

**Goal:** Surface highest-blast-radius resources (public-facing, holding identities/keys, with broad RBAC) across the tenant in one query.

**Wow moment:** _"List internet-exposed resources with managed identities that have Owner role anywhere."_ — agent composes a multi-join ARG query (`resources` + `authorizationresources`), validates, executes, and ranks.

**Tools used:** `generate_query`, `validate_query`, `execute_query`.

**Acceptance criteria:**

*   Joins resources + role assignments + network exposure facets.
*   Severity scoring (configurable weights).
*   Export to SARIF or CSV for SecOps intake.

---

## PoC 11 — Conversational FinOps "right-sizer" deployer

**Goal:** Combine ARG-based right-sizing recommendations with auto-generated ARM templates that resize/SKU-down resources on approval.

**Wow moment:** _"Find all idle Standard\_D8s\_v5 VMs in dev/test and downsize them to D2s\_v5."_ — agent identifies candidates, generates an ARM patch template, shows projected monthly savings, and (on confirm) deploys + monitors.

**Tools used:** `generate_query`, `execute_query`, `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   ARG query keyed on resource utilization tags / Advisor data.
*   Generated ARM template uses `properties.hardwareProfile.vmSize` patch pattern.
*   Per-resource opt-in checklist before bulk deploy.

---

## PoC 12 — ChatOps Slack/Teams bot backed by ARM MCP

**Goal:** Wire ARM MCP behind a Teams bot so non-engineers (PMs, finance, security) can self-serve Azure questions in chat.

**Wow moment:** Finance PM types in Teams _"how many SQL DBs do we have in production by tier?"_ — bot answers with a chart, no Azure portal training needed.

**Tools used:** `generate_query`, `execute_query` (read-only profile; deploy tools disabled).

**Acceptance criteria:**

*   RBAC pass-through via on-behalf-of token.
*   Read-only mode toggle that disables `create_template_deployment` / `cancel_*`.
*   Audit log of every question + ARG query produced.

---

## Suggested fleet rollout order

1.  **Quick demos (1–2 days each):** PoC 3, PoC 6, PoC 10 — pure ARG, no deployments, immediate visual wow.
2.  **Mid-tier (3–5 days):** PoC 1, PoC 5, PoC 7, PoC 8, PoC 12.
3.  **Flagship demos (1–2 weeks):** PoC 2, PoC 4, PoC 9, PoC 11 — these are the boardroom moments.

## Cross-cutting build standards

*   All agents must log every MCP tool call + arguments to `runs/<timestamp>.jsonl` for audit.
*   Every PoC must demonstrate a **failure / cancel** path (use `cancel_arm_template_deployment` where relevant).
*   Templates that deploy resources must be parameterized for region, tags, and naming prefix.
*   Read-only PoCs must run cleanly under a Reader-only principal; write PoCs document the minimum RBAC role.
*   Each PoC ships a 90-second screen-recorded demo showing the wow moment.