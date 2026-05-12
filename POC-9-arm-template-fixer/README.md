# ARM Template Fixer Loop (ARM MCP PoC — POC-9)

A Copilot CLI / VS Code chat agent that deploys a broken ARM template, captures the ARM error
codes, classifies them against a **fixed error-code → fix-pattern rule pack**, edits the
template to apply the correct fix, and redeploys in a bounded retry loop — until the deployment
goes green or `max_retries` is exhausted.

Backed by the [Azure Resource Manager MCP Server](https://aka.ms/JoinARMMCP).

## What it does

1. Loads a fixed rule pack (`skills/arm-template-fixer/rules/rules.yaml`) — 5 error-code →
   fix-pattern rules covering dependency, SKU, quota, conflict, and destructive-change halt.
2. **Simulates** the initial deployment (v1 — see [Determinism Deviation](#determinism-deviation)).
3. Classifies the ARM error code against `rules.yaml` and selects the deterministic fix pattern.
4. Applies the fix to `current_template` and emits a **unified diff** for every attempt.
5. Checks for destructive changes against `runbooks/prod.yaml → destructive_change_types` before
   each retry — halts immediately if a protected resource type would be deleted.
6. Repeats steps 2–5 up to `max_retries` (default 3) times.
7. Renders a deterministic fix report (`templates/output-report.md`) on success or a status
   report (`templates/output-status.md`) on halt or exhaustion.
8. Writes the fixed template to `exports/` and appends one row to `exports/fix-run-log.csv`.

## Why the output is deterministic

- Error classification is NOT done by the LLM — it is a lookup against `error_code:` fields in
  `rules.yaml`, read verbatim.
- Fix application order is fixed: R001 (dependency) → R002 (SKU) → R003 (quota) → R004 (conflict).
- Diff format is pinned: unified diff, `---` / `+++` / `@@` headers, no paraphrasing.
- `run_id` is assembled from fixed inputs: `FIX-{YYYYMMDD}-{template_filename}-{sha256(rules.yaml)[:8]}`.
- Retry count is fixed at `max_retries` (default 3 from runbook).
- Report templates are fixed-format with `{{placeholder}}` substitution only.

## Determinism Deviation

> **rules.yaml schema deviation — binding per ratification #1 (2026-05-12)**

This PoC does **NOT** use Azure Resource Graph (ARG) or KQL queries. It has no `execute_query`,
`validate_query`, or `generate_query` tools in its allowlist.

The `rules.yaml` file in this PoC **replaces** the standard `kql:` field with two new fields:

| Standard field (other PoCs) | This PoC's replacement |
|---|---|
| `kql:` — ARG KQL query string | `error_code:` — ARM deployment error code to match |
| _(not present)_ | `fix_pattern:` — deterministic action string |

The **outer structure** is identical to the fleet standard:

```yaml
version: 1
rules:
  - id: R001
    title: ...
    severity: ...
    category: ...
    # ← here is where kql: would appear in other PoCs
    error_code: MissingDependency
    fix_pattern: add dependsOn
    ...
```

This deviation is intentional. The PoC's purpose is to fix ARM templates based on ARM error
codes, not to query Azure Resource Graph. The `rules.yaml` schema mismatch is documented here
and in `agents/arm-template-fixer.agent.md` hard rules.

This PoC also does **NOT** include `validate_query` in its tool allowlist, per ratification #7
(2026-05-12): the source spec's "Tools used" line is authoritative.

## How it works (end-to-end flow)

What happens after you type `@arm-template-fixer fix template=broken-vnet.json scope=prod`:

1. **Chat client routes the message.** VS Code Copilot Chat sees the `@arm-template-fixer` mention,
   loads `.github/copilot/agents/arm-template-fixer.agent.md` as the system prompt, and reads its
   `tools:` declarations.
2. **Workspace MCP servers start.** The runtime reads `.vscode/mcp.json`, sees the
   `Azure Resource Manager MCP Server` entry, performs the MCP `initialize` handshake, and asks
   `tools/list`. The server returns descriptors for `create_template_deployment`,
   `get_arm_template_deployment_status`, and `cancel_arm_template_deployment`.
3. **LLM gets its toolbox.** The model sees the agent's hard rules, the SKILL.md procedure, the
   user prompt, and JSON schemas for the 3 MCP tools. No Azure call has happened yet.
4. **LLM follows SKILL.md Step 1 — load inputs.** It reads `runbooks/prod.yaml` (subscription,
   RG, `max_retries`, `destructive_change_types`, `allowed_fix_patterns`) and
   `rules/rules.yaml` (5 error-code → fix-pattern rules). Computes `ruleset_hash8`.
5. **LLM computes `run_id` deterministically.** `FIX-{YYYYMMDD}-{template_filename}-{ruleset_hash8}`.
6. **LLM enters the fix loop (SKILL.md Steps 2–7).** For each attempt:
   - Simulates the deploy call (v1 — no actual `create_template_deployment` invocation).
   - Classifies the simulated ARM error code against `rules.yaml`.
   - Applies the matched fix pattern in deterministic order.
   - Emits a unified diff.
   - Checks for destructive changes → halts if triggered.
7. **On success or halt/exhaustion,** LLM renders the appropriate output template and appends
   one row to `exports/fix-run-log.csv`.

**Where the LLM ≠ the oracle:** steps 4, 5, 6 (classification, fix order, diff format) are
rule-driven mechanics. The LLM is a workflow runner.

## Install

1. Clone this folder anywhere and open it as a workspace in VS Code.
   The ARM MCP server is **already declared** at workspace scope in `.vscode/mcp.json` — VS Code
   will prompt you to start it the first time you open chat.
   - If your VS Code account isn't yet authorized for the ARM MCP preview, click
     <https://aka.ms/JoinARMMCP> once.
   - For GitHub Copilot CLI users: copy the `Azure Resource Manager MCP Server` entry from
     `.vscode/mcp.json` into `~/.copilot/mcp.json`.
2. Sign in to Azure (`az login`) with Reader + Contributor on the target resource group.

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

## Configure your scope (do this before first run)

`scope prod` maps to `runbooks/prod.yaml`. The agent loads that YAML to know which subscription
and resource group to target.

### Two-file pattern: template + values

| File | Committed? | Contains |
|---|---|---|
| `runbooks/prod.yaml` | ✅ yes | Template with `${placeholder}` tokens. No real values. |
| `runbooks/prod.values.yaml` | ❌ **gitignored** | Your real subscription ID and RG name. |
| `runbooks/prod.values.yaml.example` | ✅ yes | Schema reference — copy this to start. |

### First-time setup

1. Copy the example:
   ```powershell
   Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml
   ```
2. Edit `runbooks/prod.values.yaml` and fill in real values:
   ```yaml
   subscription_id: "11111111-2222-3333-4444-555555555555"
   resource_group: "my-arm-poc-rg"
   ```
3. Verify `.gitignore` excludes it (root `.gitignore` has `**/runbooks/*.values.yaml`).

## Run

VS Code chat:
```
@arm-template-fixer fix template=path/to/broken.json scope=prod
```

Check deployment status:
```
@arm-template-fixer status deployment_name=fix-20260512-attempt-2
```

Cancel a hanging deployment (requires explicit confirmation):
```
@arm-template-fixer cancel deployment_name=fix-20260512-attempt-2
```

## Layout

```
POC-9-arm-template-fixer/
  README.md
  .vscode/mcp.json                          # ARM MCP server declaration
  .github/copilot/
    agents/
      arm-template-fixer.agent.md           # agent persona + tool allowlist (3 tools)
    skills/
      arm-template-fixer/
        SKILL.md                            # deterministic fix procedure
        rules/rules.yaml                    # 5 rules: error_code → fix_pattern (NON-STANDARD)
        templates/
          output-report.md                  # fix report template (success path)
          output-status.md                  # status report template (halt/exhaustion path)
        prompts/
          fix.prompt.md                     # fix verb prompt
          status.prompt.md                  # status verb prompt
          cancel.prompt.md                  # cancel verb prompt (with confirm gate)
  runbooks/
    prod.yaml                               # committed template (placeholders only)
    prod.values.yaml                        # GITIGNORED — your real sub ID / RG
    prod.values.yaml.example                # committed schema reference
  exports/
    .gitkeep                                # fixed templates and run log land here
    test-run.md                             # simulated test run (fabricated values)
```

## Acceptance criteria mapping

| Criterion | Where it lives |
|---|---|
| Bounded retry loop (default 3) with diff log per attempt | SKILL.md Steps 2–7, `max_retries` in prod.yaml |
| Halt-on-destructive-change safeguard | SKILL.md Step 6, `destructive_change_types` in prod.yaml, agent hard rule #3 |
| Final summary: working template + changelog | `templates/output-report.md`, exports/ |
| Cancel path with user confirmation | SKILL.md Step 7, `prompts/cancel.prompt.md`, agent hard rule #4 |
| What-if only (no actual deploy in v1) | agent hard rule #1, `prompts/fix.prompt.md`, test-run.md appendix |
| Deterministic error classification | `rules/rules.yaml` error_code lookup, no LLM judgment |
| Deterministic fix order | agent hard rule #5, SKILL.md Step 4 |
