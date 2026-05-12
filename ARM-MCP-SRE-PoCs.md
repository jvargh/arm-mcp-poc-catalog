# ARM MCP Server — SRE-Focused PoC Catalog

Reference: [Introducing the Azure Resource Manager MCP Server](https://techcommunity.microsoft.com/blog/azuregovernanceandmanagementblog/introducing-the-azure-resource-manager-mcp-server/4517521)

> Companion to [`ARM-MCP-PoC-Ideas.md`](ARM-MCP-PoC-Ideas.md). Same six tools, same fleet build standards — but every PoC here is scoped to an SRE pain point: incident response, change safety, reliability posture, on-call toil, and post-incident learning.

## Tools recap

`generate_query` · `validate_query` · `execute_query` · `create_template_deployment` · `get_arm_template_deployment_status` · `cancel_arm_template_deployment`

---

## SRE-PoC 1 — "First 60 seconds" incident triage agent

**Goal:** When paged, the on-call invokes one command and the agent returns: what changed in the affected scope in the last N hours, who changed it, and which deployments are still in-flight.

**Wow moment:** Pager fires at 03:14. Engineer types `triage payments-prod 2h` → agent returns a ranked change feed (resource, change type, principal, correlation ID), highlights two ARM deployments still RUNNING, and offers a one-key `cancel`.

**Tools used:** `generate_query`, `execute_query`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`.

**Acceptance criteria:**

*   ARG against `resourcechanges` + `resourcecontainers`, scoped by RG/sub/tag.
*   Lists in-flight deployments with confirm-to-cancel gate.
*   Output ≤ 1 screen, copy-paste ready for incident bridge.
*   Records an audit trail (who triaged, what was cancelled).

---

## SRE-PoC 2 — Change-freeze enforcer

**Goal:** During declared freeze windows, intercept any `create_template_deployment` call, check it against the freeze policy (scope, severity, exemption tags), and either block or require a break-glass justification logged to ticketing.

**Wow moment:** Engineer tries to deploy mid-freeze → agent responds _"Blocked: freeze active until 18:00 UTC for_ `_tier-1-prod_`_. Cite CR-12345 to override."_ — with override, deploys and posts the justification to the change record.

**Tools used:** `validate_query`, `execute_query` (resolve resource scope), `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Freeze schedule + scopes defined in YAML.
*   Resolves template's target scope before allowing the call.
*   Break-glass path requires a CR ID and emits an audit event.
*   Dry-run mode for testing freeze rules without real deploys.

---

## SRE-PoC 3 — Pre-flight deployment safety check

**Goal:** Before every prod ARM deployment, automatically run a battery of ARG queries to assert health preconditions (no active incidents in scope, dependencies healthy, no overlapping deploys, capacity available).

**Wow moment:** _"Deploy_ `_payments-api-v47.json_` _to_ `_payments-prod_`_."_ → agent runs 9 preflight checks, fails one (_"_`_payments-db_` _reports 3 throttling alerts in last 15 min"_), and refuses to deploy until cleared.

**Tools used:** `generate_query`, `validate_query`, `execute_query`, `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Configurable preflight ruleset per environment.
*   Each check has a clear pass/fail + remediation hint.
*   Force-deploy flag emits an audit warning.
*   Preflight runs in \<30s for a typical RG.

---

## SRE-PoC 4 — Auto-rollback orchestrator

**Goal:** Watch a deployment; if it fails or breaches a health gate (post-deploy ARG checks), automatically cancel and apply the previously-known-good template.

**Wow moment:** Bad template ships → agent detects `Failed` status, cancels remaining ops, redeploys last-good template from Git, posts a one-line postmortem stub to chat — all before the engineer finishes their coffee.

**Tools used:** `create_template_deployment`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`, `execute_query`.

**Acceptance criteria:**

*   Pulls last-good template from a Git ref or artifact store.
*   Configurable health gate (ARG-based) with timeout.
*   Bounded rollback attempts; halts on second failure.
*   Generates an incident-ready timeline of every step.

---

## SRE-PoC 5 — Reliability posture scorecard

**Goal:** Continuously score every workload (RG or tag set) on SRE basics: zone redundancy, backup configured, diagnostic settings present, public-IP exposure, single-instance services, expiring certs.

**Wow moment:** _"Show me the bottom 10 services on reliability score in_ `_prod_`_."_ → ranked table with each failing check linked to the exact ARG query that produced it, plus a generated ARM patch to fix the most common gaps (e.g., enable diagnostic settings).

**Tools used:** `generate_query`, `validate_query`, `execute_query`, `create_template_deployment`.

**Acceptance criteria:**

*   ≥10 reliability rules with weighted scoring.
*   Per-workload drill-down with raw ARG.
*   Auto-generated remediation ARM templates for top 3 gap types.
*   Trend export so scores can be tracked weekly.

---

## SRE-PoC 6 — SLO-aware deployment gate

**Goal:** Block deploys to services whose SLO error budget is already burned, using ARG to fetch related Application Insights / Log Analytics workspace metadata and component tags.

**Wow moment:** _"Deploy v33 to_ `_checkout-api_`_."_ → agent answers _"Error budget for_ `_checkout-api_` _is at 12% with 6 days left in the window. Deploy requires SRE approval."_ and pages the SRE rota for sign-off.

**Tools used:** `generate_query`, `execute_query`, `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Service ↔ SLO mapping by tag.
*   Budget calc input pluggable (Azure Monitor / Prometheus / external).
*   Approval workflow with timeout + auto-deny.
*   Bypass requires an incident or CR reference.

---

## SRE-PoC 7 — Capacity & quota guardian

**Goal:** Continuously query subscription/region quotas and active resource counts; warn before deploys would breach a quota or exhaust capacity in a region.

**Wow moment:** _"Add 40 D8s\_v5 VMs to_ `_eastus2-prod_`_."_ → agent: _"You have headroom for 27. Suggested split: 27 in_ `_eastus2_`_, 13 in_ `_eastus3_` _(same latency tier). Want me to file the quota increase for_ `_eastus2_` _while you deploy the split?"_

**Tools used:** `generate_query`, `execute_query`, `create_template_deployment`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   ARG queries enumerate by SKU + region.
*   Suggests alternate regions based on policy/distance config.
*   Optional auto-file quota request via separate Azure SDK call.

---

## SRE-PoC 8 — Blast-radius simulator for ARM templates

**Goal:** SRE-grade what-if: parse a template, project the change set, and quantify _user-facing_ risk — affected DNS names, exposed endpoints flipping, identities/role assignments rotating, certificates regenerating.

**Wow moment:** Drop a Front Door + WAF template into chat → agent: _"This will rotate the WAF policy referenced by 3 routes serving_ `_api.contoso.com_` _(~14k RPS). Estimated 5–10s 502 window per route. Stagger recommended."_

**Tools used:** `generate_query`, `validate_query`, `execute_query`, `create_template_deployment` (what-if).

**Acceptance criteria:**

*   Maps resource changes to user-impact categories.
*   Surfaces dependency edges (FD ↔ AGW ↔ AKS, etc.).
*   Risk score + recommended deploy strategy (canary/blue-green/staggered).

---

## SRE-PoC 9 — Stuck deployment janitor

**Goal:** Background agent that finds ARM deployments stuck `Running` past expected duration, classifies why, and offers cancel + cleanup.

**Wow moment:** Daily report: _"3 deployments running >2h: 1 waiting on a deleted dependency, 1 looping on quota, 1 genuinely slow (Cosmos restore). Cancel the first two?"_

**Tools used:** `execute_query`, `get_arm_template_deployment_status`, `cancel_arm_template_deployment`.

**Acceptance criteria:**

*   Configurable per-resource-type expected duration.
*   Classifier produces a reason string per stuck deploy.
*   Cancel + post-cancel cleanup template (e.g., remove orphaned subresources).

---

## SRE-PoC 10 — On-call runbook executor

**Goal:** Convert text runbooks into MCP-driven agents. Each runbook step is either an ARG check or a parameterized ARM deployment. Agent walks the runbook, pauses on human gates.

**Wow moment:** Runbook _"Failover SQL primary to secondary region"_ → agent runs preflight ARG checks, prompts the on-call to confirm, deploys the failover template, monitors, validates post-state — with a rollback step pre-staged.

**Tools used:** All six.

**Acceptance criteria:**

*   Runbook DSL (YAML) with `check`, `deploy`, `confirm`, `rollback` steps.
*   State machine that resumes from interruption.
*   Every run produces an evidence pack (queries, templates, statuses).

---

## SRE-PoC 11 — Post-incident "what changed" reconstructor

**Goal:** Given an incident time window and impacted scope, reconstruct the full change timeline (ARM deployments + resource property changes + RBAC changes) for the postmortem doc.

**Wow moment:** _"Build me the change timeline for INC-9831 (14:02–14:47 UTC,_ `_payments-prod_`_)."_ → markdown timeline with timestamps, principals, and links to each underlying ARG query, ready to paste into the postmortem template.

**Tools used:** `generate_query`, `validate_query`, `execute_query`, `get_arm_template_deployment_status`.

**Acceptance criteria:**

*   Time- and scope-bounded ARG over `resourcechanges` + `authorizationresources`.
*   Correlates to ARM deployment IDs where possible.
*   Output formatted for the team's postmortem template.

---

## SRE-PoC 12 — Toil killer: weekly drift + cleanup PRs

**Goal:** Weekly job that finds drift between IaC repo and live state, plus orphaned resources (no tags, no owners, no traffic), and opens a PR with a corrective ARM patch.

**Wow moment:** Monday morning: GitHub PR titled _"Weekly Azure cleanup: 12 orphaned resources, 4 NSG drifts, 2 missing diag settings — proposed ARM patch + estimated $317/mo savings."_

**Tools used:** `generate_query`, `execute_query`, `create_template_deployment` (dry-run only — humans merge).

**Acceptance criteria:**

*   Runs unattended on a schedule.
*   Produces a single PR per week with categorized diffs.
*   Never deploys; only proposes templates.
*   Includes savings estimate per cleanup item.

---

## Suggested SRE rollout order

1.  **Toil reducers, ship first (1–2 days each):** SRE-PoC 1, 9, 11 — pure read + cancel, instant on-call value.
2.  **Change-safety wins (3–5 days):** SRE-PoC 2, 3, 6, 8 — high visibility, protects prod.
3.  **Reliability flywheel (1–2 weeks):** SRE-PoC 4, 5, 7, 10, 12 — these change how the org runs Azure.

## SRE-specific build standards (additive to base catalog)

*   Every agent emits structured events compatible with the team's incident timeline tool.
*   Read paths must work with a Reader + Resource Graph Reader role; write paths document required RBAC.
*   All deploy-capable agents honor a global "freeze" flag (env var or config) without code changes.
*   Cancel paths are first-class — no deploy PoC ships without a tested cancel flow.
*   Every PoC ships with a chaos-test scenario (fault injected, agent must respond correctly).