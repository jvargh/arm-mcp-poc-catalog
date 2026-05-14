# Capacity & Quota Guardian (ARM MCP PoC)

A Copilot CLI / VS Code chat agent that queries subscription and region resource counts via ARG,
compares them against quota limits, **warns before deploys would breach quota**, and suggests
alternate regions. The `deploy` verb is **gated** — it is blocked until all quota checks pass.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## Purpose

Production teams routinely lose capacity headroom slowly — a `Standard_D4s_v3` quota silently
climbs to 94% across `eastus`, public IPs creep into the 80s, a fresh storage account fails
to deploy because the subscription is one over the per-sub cap. By the time the deploy fails,
on-call is paged at the worst possible time.

This PoC is a **deterministic Copilot agent** that turns capacity headroom into a *checkable
artifact*. It runs four pre-canned ARG queries to count the resources that most often trip
operators (VMs by SKU, vCPUs, storage accounts, public IPs), compares each count against the
limits pinned in `runbooks/<scope>.yaml`, and emits a single Markdown report — the same report
every time, for the same inputs.

The same agent **gates the `deploy` verb**: if any quota breaches `headroom_threshold_pct`
(default 80), the agent refuses to deploy and tells the operator which alternate region to
target (latency-tier ordered, from the runbook). v1 is what-if — the gate decision is emitted
but `create_template_deployment` is **not** actually called (see [Hard rules](#known-limitations)).

**Audience:** SREs and platform engineers responsible for Azure capacity planning who want a
deterministic, diffable report and a guard rail in front of every deploy.

## Intended end state

After you've configured `runbooks/prod.values.yaml` (your sub ID) and extended `quota_limits`
in `prod.yaml` to cover the SKUs your fleet actually runs, a healthy steady state looks like:

*   Running `check scope prod` produces `Overall result: PASS` with every row well under
    `headroom_threshold_pct` and **zero `LIMIT_UNKNOWN` rows** — every SKU you run has a limit
    pinned in the runbook, so every row resolves to a real `usage_pct`.
*   Running `deploy scope prod --template <path>` on a PASS subscription emits a
    `WOULD DEPLOY (NOT EXECUTED — v1 what-if)` block — the gate has cleared.
*   The Run ID (`QUOTA-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`) is reproducible. Re-running
    with the same rules, runbook, and UTC date yields the same Run ID, same column order, same
    row ordering. Reports are review-friendly and diff-friendly, and committing them under
    `exports/` lets you track headroom over time.
*   When usage approaches the threshold, the agent produces a `FAIL` report with concrete
    alternate-region suggestions — operators get a remediation hint along with the alarm,
    not just a number.

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

1.  **Chat client routes the message.** VS Code Copilot Chat sees the `@capacity-quota-guardian` mention,
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

Then run `@capacity-quota-guardian check scope prod`.

## Run

VS Code chat:

```
@capacity-quota-guardian check scope prod
@capacity-quota-guardian deploy scope prod --template <path-to-arm-template>
@capacity-quota-guardian status scope prod <deployment-name>
```

GitHub Copilot CLI (tag the agent file directly — `@<name>` mention routing only works in
VS Code chat):

```
copilot
> @.github\copilot\agents\capacity-quota-guardian.agent.md check scope prod
> @.github\copilot\agents\capacity-quota-guardian.agent.md deploy scope prod --template <path>
> @.github\copilot\agents\capacity-quota-guardian.agent.md status scope prod <deployment-name>
```

> **Local fallback when ARM MCP is not bound.** If `generate_query` / `execute_query` are not
> available in your CLI session (e.g., the ARM MCP server entry isn't loaded), the literal `kql`
> blocks in `rules/rules.yaml` can be executed verbatim via `az graph query -q "<kql>"
> --subscriptions <sub>`. Same ARG endpoint, no query rewriting — keeps determinism rule #1
> intact. The output report should call this out explicitly so reviewers know which path was used.

## Sample run — what to expect end-to-end

Two artifacts under `exports/` show what the agent emits in practice. Read these before your
first invocation so you know what a healthy report looks like and what to do with `LIMIT_UNKNOWN`.

### Live run on a real subscription (2026-05-14)

[`exports/QUOTA-20260514-prod-38ada451.md`](exports/QUOTA-20260514-prod-38ada451.md) was
produced by `@capacity-quota-guardian check scope prod` against subscription `463a82d4-…`.
Top observations (use these to calibrate expectations on your own first run):

*   **All 4 rules executed cleanly** (`Rules errored: 0`) end-to-end via the
    `generate_query` → `execute_query` ARM MCP path. No retry logic kicked in, no QUERY_ERROR
    rows. This is the happy path the deterministic flow is designed for.
*   **3 regions checked** (`centralus`, `eastus`, `eastus2`) — exactly the regions where the
    sub had resources deployed. `regions_checked` correctly excludes the synthetic
    `subscription-scoped` location used by the storage-accounts rule (R003).
*   **`Overall result: PASS`** — top usage was 7.3% (public IPs in `centralus`), nothing close
    to the 80% threshold. `Quota breaches (above threshold) = 0`. A small / dev subscription
    will look like this; a production sub will have higher numbers but the same shape.
*   **4 `LIMIT_UNKNOWN` rows** for VM SKUs not in the shipped starter map
    (`Standard_E2s_v3`, `Standard_DC2s_v3`). The agent **did not block** on these — they are
    visibility-only rows so the operator knows which SKUs to add to `quota_limits` and re-run.
*   **Reproducible Run ID:** `QUOTA-20260514-prod-38ada451`. Re-running the same rules against
    the same scope on the same UTC date yields the same ID. The `38ada451` suffix is the first
    8 chars of `sha256(rules.yaml)` — change a rule, the suffix changes, and you can tell at a
    glance that two reports were generated by different rule packs.

### Simulated FAIL + PASS scenarios

[`exports/test-run.md`](exports/test-run.md) (built during development) shows what you can't
see in the live PASS run: the `DEPLOY BLOCKED` path with alternate-region suggestions, and the
`WOULD DEPLOY (NOT EXECUTED — v1 what-if)` appendix on a PASS-path `deploy` invocation. Use
this file as the contract reference when reviewing real reports.

### What to do after your first run

1.  **Triage the `LIMIT_UNKNOWN` rows.** Each one is a SKU your subscription is running that
    the shipped `quota_limits.virtual_machines` map (D-series starter only) does not cover.
    Pull the real limit with `az vm list-usage --location <region> -o table` and add the SKU
    under the right region in `runbooks/prod.yaml`. Re-run `check`; the row should turn into a
    real `usage_pct` with `PASS`/`FAIL` status. **The end-state goal is zero `LIMIT_UNKNOWN`
    rows.**
2.  **Audit `vcpu_per_sku` in `rules.yaml` (R002) for the SKUs you just added.** If a SKU is
    missing from the map, R002 silently falls back to `_default = 4` — under-reporting an
    8-vCPU SKU by 50% can hide a real regional vCPU breach (see [Known limitations](#known-limitations)).
3.  **Pin the limits you raise.** Azure quotas change after a quota-increase request, but
    `quota_limits` does not. Whenever you raise a limit in Azure, update `prod.yaml` in the
    same change so the agent stops blocking deploys against the old number — and stops
    *passing* deploys against an unrealistic ceiling.
4.  **Commit the rendered report.** The `exports/QUOTA-{date}-{scope}-{hash}.md` file is the
    audit artifact — drop it into `exports/` (or wherever your team tracks reliability evidence)
    so you can diff week-over-week and watch headroom shrink *before* it bites.

## Layout

```
SRE-PoC-07-capacity-quota-guardian/
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
    test-run.md                         # simulated FAIL/PASS scenarios from build time
    QUOTA-YYYYMMDD-prod-<hash8>.md      # rendered output from each live `check` run
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
*   **`quota_limits.virtual_machines` ships with a D-series starter pack only.** Any VM SKU not
    explicitly listed (e.g., `Standard_DC2s_v3`, `Standard_E2s_v3`, B-/F-/L-series) produces
    `LIMIT_UNKNOWN` rows in the report — the agent does **not** block on these but they are noise
    until the operator extends the map. See `exports/QUOTA-20260514-prod-38ada451.md` for an
    example of what `LIMIT_UNKNOWN` rows look like.
*   **`vcpu_per_sku._default = 4` is silently applied** for any SKU missing from the map in R002.
    A `Standard_DC8s_v3` (8 vCPU) treated as 4 will under-report regional vCPU usage by 50% and
    can hide a real breach. Audit the map after every Azure SKU GA wave.
*   **`_total` keys under `quota_limits.virtual_machines.<region>` are advisory in v1** — no rule
    reads them. They are reserved for a future "regional VM-count rollup" rule. Do not rely on
    them as an enforcement mechanism today.
*   **`regions_checked` excludes the synthetic `subscription-scoped` location** emitted by R003
    (storage accounts), so the count reflects real Azure regions only.

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
