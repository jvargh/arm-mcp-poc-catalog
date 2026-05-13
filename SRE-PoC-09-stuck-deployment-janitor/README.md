# Stuck Deployment Janitor (ARM MCP PoC — SRE-PoC-9)

A Copilot CLI / VS Code chat agent that finds ARM deployments stuck in `Running` state
past their expected duration, classifies the cause using a fixed rule pack, and offers
cancel with explicit per-deployment confirmation.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## What it does

1. Loads a fixed rule pack (`skills/stuck-deployment-janitor/rules/rules.yaml`) — 4 rules
   that identify and classify stuck ARM deployments using **pre-defined literal ARG KQL**.
2. For each rule: calls `execute_query` directly (see § Determinism Deviation below).
3. Enriches each stuck deployment with a live `get_arm_template_deployment_status` call.
4. Renders a report using a **fixed markdown template** (`templates/output-report.md`).
5. On the `cancel` verb: presents a per-deployment confirmation gate before calling
   `cancel_arm_template_deployment`. Emits an `[AUDIT]` log line for every attempt.

## Why the output is deterministic

- Queries are NOT generated or modified by the LLM at run time — they are read verbatim
  from `rules.yaml`.
- Scope substitution (subscription IDs, RG filters, threshold hours) is a plain string
  replacement with no model judgment.
- The agent renders the report using a fixed template with no paraphrasing.
- Sort order is fixed: descending by `durationHours`, ties broken by `name` ascending.
- Run ID is the input scope name + UTC date + rules.yaml hash — identical inputs → identical run ID.

## Determinism Deviation

> **Ratification #7 — DOUBLE EXCEPTION (SRE-PoC-9 stricter literal-KQL discipline)**

This PoC does **not** include `validate_query` or `generate_query` in its tool allowlist,
per the source spec and Bishop ratification #7. Both tools are **explicitly excluded**.

The `SKILL.md` procedure skips the `validate_query → execute_query` pattern used by the
reference implementation and goes **directly to `execute_query`** with the literal KQL from
`rules.yaml` (after scope token substitution only).

**KQL correctness is assured by pre-testing during development.**
Operators running this PoC live who wish to hand-verify the KQL should copy the queries from
`rules/rules.yaml` and test them manually via the `validate_query` tool in a separate
workspace before the first production run.

The agent's `hard_rules` block explicitly forbids any LLM-side KQL derivation or rewriting
under any circumstances.

## Out of scope (future enhancements)

**Post-cancel cleanup templates are NOT implemented in this PoC.**

After calling `cancel_arm_template_deployment`, some resources may have been partially
provisioned. Cleaning them up (deleting half-created VMs, orphaned NICs, etc.) requires
deploying a cleanup template via `create_template_deployment`. However,
`create_template_deployment` is **not in the tool allowlist** for this PoC.

Operators must perform post-cancel cleanup manually using the Azure portal or Azure CLI:

```powershell
# Example: delete a partially-created resource after cancel
az resource delete --ids /subscriptions/<sub>/resourceGroups/<rg>/providers/<type>/<name>
```

A future PoC (e.g., a Golden Path variant) may implement automated post-cancel cleanup
once `create_template_deployment` is available and the cleanup template set is validated.

## How it works (end-to-end flow)

1. **Chat client routes the message.** VS Code Copilot Chat loads
   `.github/copilot/agents/stuck-deployment-janitor.agent.md` as the system prompt.
2. **Workspace MCP server starts.** Runtime reads `.vscode/mcp.json`, handshakes with
   `https://mcp.management.azure.com`. Tools `execute_query`,
   `get_arm_template_deployment_status`, and `cancel_arm_template_deployment` are available.
3. **LLM loads config.** Reads `runbooks/prod.yaml` + `prod.values.yaml`, extracts scope
   tokens and thresholds. Reads `rules.yaml`, computes `ruleset_hash8`.
4. **LLM computes `run_id`** as `STUCK-{YYYYMMDD}-{scope}-{ruleset_hash8}`.
5. **Per-rule loop.** For each of 4 rules, substitutes scope tokens into the literal KQL,
   calls `execute_query` directly (no `validate_query`), stores rows.
6. **Enrichment.** Calls `get_arm_template_deployment_status` per unique deployment ID.
7. **Deduplication + classification priority.** Each deployment gets one classification
   reason (deleted-dep > quota-loop > genuinely-slow > exceeded-threshold).
8. **Render report.** Literal substitution into `templates/output-report.md`. Write to
   `exports/stuck-prod-latest.md`.
9. **Cancel flow (if requested).** Per-deployment confirmation gate → audit log line →
   `cancel_arm_template_deployment` call.

## Install

1. Clone this folder and open it as a workspace in VS Code.
   The ARM MCP server is **already declared** at workspace scope in `.vscode/mcp.json`.
2. Sign in to Azure (`az login`) with at minimum Reader + Resource Graph Reader on target
   subscriptions. For cancel, you also need **Contributor** (or the built-in
   `Deployment Operator` role) on the target resource groups.

> The MCP server entry at workspace scope (`.vscode/mcp.json`):
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

## Configure your scope

`scope prod` maps to [`runbooks/prod.yaml`](runbooks/prod.yaml). Real values live in a
gitignored sibling `prod.values.yaml`.

| File | Committed? | Contains |
|---|---|---|
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens |
| `runbooks/prod.values.yaml` | ❌ gitignored | Your real subscription ID(s) and RG names |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference — copy this to start |

### First-time setup

1. Copy the example:
   ```powershell
   Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
   ```
2. Edit `runbooks/prod.values.yaml` with real values:
   ```yaml
   subscription_id: "11111111-2222-3333-4444-555555555555"
   rg_include:
     - "payments-prod-rg"
   rg_exclude: []
   ```
3. Verify `.gitignore` excludes it (`**/runbooks/*.values.yaml`).

### Tuning thresholds

Edit `prod.yaml` (committed) to adjust:
- `auto_cancel_threshold_hours`: default `4` — deployments running longer than this are flagged.
- `expected_duration_by_type`: per-resource-type expected duration for `over_expected` flag.
- `known_slow_types`: types matched by R004 (genuinely-slow classifier).

## Run

VS Code chat — scan:
```
@stuck-deployment-janitor scan for scope prod
```

VS Code chat — cancel:
```
@stuck-deployment-janitor cancel for scope prod
```

GitHub Copilot CLI:
```
gh copilot -p "Scan for stuck deployments in scope prod"
```

## Layout

```
SRE-PoC-09-stuck-deployment-janitor/
  README.md
  .vscode/mcp.json
  .github/copilot/
    agents/
      stuck-deployment-janitor.agent.md   # agent persona + tool allowlist (3 tools)
    skills/stuck-deployment-janitor/
      SKILL.md                            # deterministic procedure
      rules/rules.yaml                    # 4 rules: literal KQL, classification reasons
      templates/
        output-report.md                  # fixed scan report format
        output-cancel-confirmation.md     # per-deployment cancel gate
      prompts/
        scan.prompt.md
        cancel.prompt.md
  runbooks/
    prod.yaml                             # committed template (placeholders only)
    prod.values.yaml                      # GITIGNORED — your real sub IDs / RG names
    prod.values.yaml.example              # committed schema reference
  exports/
    .gitkeep
    test-run.md                           # simulated test outcome
```

## Tool allowlist

Exactly 3 tools — no additions permitted:

| Tool | Purpose |
|---|---|
| `execute_query` | Run literal KQL from rules.yaml against ARG |
| `get_arm_template_deployment_status` | Enrich stuck deployments with live status |
| `cancel_arm_template_deployment` | Cancel a specific stuck deployment (cancel verb only, requires confirmation) |

`generate_query`, `validate_query`, and `create_template_deployment` are explicitly **NOT** in
the allowlist and must not be called.

## Acceptance criteria mapping

| Criterion | Where it lives |
|---|---|
| Configurable per-resource-type expected duration | `runbooks/prod.yaml` → `expected_duration_by_type` map |
| Classifier produces reason string per stuck deploy | R002/R003/R004 in `rules.yaml`, dedup logic in `SKILL.md` Step 5 |
| Cancel with post-cancel cleanup template | Cancel: `cancel_arm_template_deployment` (implemented). Cleanup template: FUTURE — see § Out of scope |
| Sort descending by duration | SKILL.md Step 5, pinned in `output-report.md` column order |
| Cancel requires per-deployment confirmation | `cancel.prompt.md`, SKILL.md Step 7, `output-cancel-confirmation.md` |
