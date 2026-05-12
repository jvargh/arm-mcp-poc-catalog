# Fleet build prompt — ARM MCP PoC catalog

Paste the block below to a Copilot CLI agent (or `@squad`) at the repo root
`c:\Users\varghesejoji\Desktop\squad-test\arm-mcp\`. It will fan out one
sub-agent per PoC and build all 23 in parallel using
[`reliability-posture-scorecard/`](reliability-posture-scorecard) as the
reference implementation.

---

## The prompt

> You are the **fleet lead** for building out the ARM MCP PoC catalog.
>
> ### Scope
>
> Implement **every** PoC defined in:
>
> - [`ARM-MCP-PoC-Ideas.md`](ARM-MCP-PoC-Ideas.md) — `PoC 1` through `PoC 12`
> - [`ARM-MCP-SRE-PoCs.md`](ARM-MCP-SRE-PoCs.md) — `SRE-PoC 1` through `SRE-PoC 12`
>
> **Skip exactly one:** `SRE-PoC 5 — Reliability posture scorecard`. It is
> already implemented at [`reliability-posture-scorecard/`](reliability-posture-scorecard)
> and serves as the **reference implementation** — read it before you start
> and copy its structure verbatim. Total to build: **23 PoCs**.
>
> ### Reference structure (mandatory — match it)
>
> Every PoC folder must mirror this layout (from `reliability-posture-scorecard/`):
>
> ```
> <poc-folder>/
>   README.md                           # what / why / install / configure / run / layout / acceptance mapping / how-it-works flow
>   .vscode/
>     mcp.json                          # workspace-scope ARM MCP server declaration (copy verbatim from reference)
>   .github/copilot/
>     agents/
>       <poc-slug>.agent.md             # agent persona + hard determinism rules + tool allowlist (only the MCP tools listed in the PoC)
>     skills/
>       <poc-slug>/
>         SKILL.md                      # numbered procedure: load → validate → execute → aggregate → render
>         rules/                        # IF the PoC uses pre-canned ARG queries — keep them literal (string-substitution only, never LLM-generated)
>           rules.yaml                  # or equivalent (policy.yaml, runbook.yaml, gates.yaml — name to fit the PoC)
>         templates/
>           output-*.md                 # one frozen markdown template per output mode, with {{placeholder}} slots
>         remediation/                  # IF the PoC creates ARM templates — pre-shipped template stubs
>           *.json
>         prompts/
>           *.prompt.md                 # one per agent verb (run / drilldown / remediate / cancel / etc.)
>   runbooks/
>     prod.yaml                         # COMMITTED template — placeholders only (${subscription_id}, ${rg_include}, ${rg_exclude})
>     prod.values.yaml                  # GITIGNORED — real sub IDs / RG names (covered by root .gitignore: **/runbooks/*.values.yaml)
>     prod.values.yaml.example          # COMMITTED schema reference users copy to start
>   exports/
>     .gitkeep                          # report + trend artifacts land here at run time
> ```
>
> ### Folder naming convention
>
> - Enterprise PoCs from `ARM-MCP-PoC-Ideas.md`: `POC-{n}-{kebab-title}/`
>   e.g. `POC-1-tag-hygiene-czar/`, `POC-2-blast-radius-analyzer/`,
>   `POC-3-cost-driver-finder/`, `POC-4-golden-path-provisioner/`,
>   `POC-5-iac-drift-detector/`, `POC-6-incident-responder/`,
>   `POC-7-policy-what-if/`, `POC-8-estate-cartographer/`,
>   `POC-9-arm-template-fixer/`, `POC-10-crown-jewels-security/`,
>   `POC-11-finops-rightsizer/`, `POC-12-chatops-bot/`
> - SRE PoCs from `ARM-MCP-SRE-PoCs.md`: `SRE-PoC-{n}-{kebab-title}/`
>   e.g. `SRE-PoC-1-incident-triage/`, `SRE-PoC-2-change-freeze-enforcer/`,
>   `SRE-PoC-3-preflight-safety/`, `SRE-PoC-4-auto-rollback/`,
>   *(skip 5)*, `SRE-PoC-6-slo-deployment-gate/`,
>   `SRE-PoC-7-capacity-quota-guardian/`,
>   `SRE-PoC-8-blast-radius-simulator/`,
>   `SRE-PoC-9-stuck-deployment-janitor/`,
>   `SRE-PoC-10-runbook-executor/`,
>   `SRE-PoC-11-post-incident-reconstructor/`,
>   `SRE-PoC-12-weekly-cleanup-prs/`
>
> Folders live at the **repo root**, peers of `reliability-posture-scorecard/`.
>
> ### Execution model — fan out
>
> Spawn **one sub-agent per PoC**, in parallel where the platform allows.
> Each sub-agent owns its folder and is independent — no shared mutable state.
>
> Each sub-agent must:
>
> 1. **Read first:** the PoC's section in the source MD, then read the
>    full reference implementation at
>    [`reliability-posture-scorecard/`](reliability-posture-scorecard) to
>    understand the determinism contract, file layout, template style,
>    and how `validate_query` → `execute_query` is sequenced.
> 2. **Write the agent file** (`.github/copilot/agents/<slug>.agent.md`)
>    with the same hard-rule format as
>    [`reliability-posture-scorecard/.github/copilot/agents/scorecard.agent.md`](reliability-posture-scorecard/.github/copilot/agents/scorecard.agent.md):
>    persona, allowed tools (only the MCP tools the PoC lists under
>    "Tools used"), and "never invent KQL / always validate before execute /
>    no retries on invalid / no deploys without confirm" clauses. PoCs
>    that don't deploy must explicitly disallow `create_template_deployment`
>    and `cancel_arm_template_deployment`.
> 3. **Write the skill** (`SKILL.md`) as a numbered, deterministic procedure.
>    Define run_id, sort orders, tie-breaks, scoring/aggregation formulas
>    (where applicable), and the failure paths (`INVALID`, `BLOCKED`,
>    `CANCELLED`, etc.).
> 4. **Write the rule pack / config** (`rules/*.yaml`) with **literal KQL**
>    or literal policy bodies. The LLM must never author queries at run time.
> 5. **Write the templates** (`templates/output-*.md`) — frozen markdown with
>    `{{placeholder}}` slots only. One template per agent verb.
> 6. **Write remediation/deploy templates** (`remediation/*.json`) for any
>    PoC that uses `create_template_deployment` — minimum: one parameterized
>    template per gap type the PoC fixes.
> 7. **Write prompts** (`prompts/*.prompt.md`) — one per verb (`run`,
>    `drilldown`, `remediate`, `cancel`, `simulate`, etc.).
> 8. **Write the runbook as a template + values pair** — exactly like the
>    reference's [`runbooks/prod.yaml`](reliability-posture-scorecard/runbooks/prod.yaml),
>    [`runbooks/prod.values.yaml.example`](reliability-posture-scorecard/runbooks/prod.values.yaml.example),
>    and the gitignored `runbooks/prod.values.yaml`:
>    - `runbooks/prod.yaml` is **committed** and contains only `${placeholder}`
>      tokens — no real subscription IDs, no real RG names. Same shape as
>      the reference (`scope`, `subscriptions: ["${subscription_id}"]`,
>      `workload_key`, `rg_include: ${rg_include}`, `rg_exclude: ${rg_exclude}`)
>      plus PoC-specific keys (`freeze_windows`, `slo_targets`,
>      `golden_paths`, `quota_thresholds`) — also as `${...}` placeholders
>      when they hold environment-specific values.
>    - `runbooks/prod.values.yaml.example` is **committed** with `<placeholder>`
>      strings users overwrite. List every key the template references.
>    - `runbooks/prod.values.yaml` is **gitignored** (the root `.gitignore`
>      already excludes `**/runbooks/*.values.yaml`). For your own dry-run
>      validation, create it locally with the test sub/RG list from the
>      "Validation & test phase" section. Never commit it.
>    - SKILL.md step 1 must document the substitution: load the template
>      as text, substitute every `${key}` from the values file, then parse
>      as YAML. Abort with the literal message
>      `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`
>      if the values file is absent.
>    - README's "Configure your scope" section must walk the user through
>      `Copy-Item runbooks/prod.values.yaml.example runbooks/prod.values.yaml`
>      → fill in values → verify `git status` does not list it.
> 9. **Copy the workspace MCP config** (`.vscode/mcp.json`) verbatim from
>    the reference so each PoC folder is independently openable in VS Code.
> 10. **Write the README** matching the reference's section order:
>     What it does · Why the output is deterministic · How it works
>     (end-to-end flow, numbered) · Install · Configure your scope · Run ·
>     Layout · Acceptance criteria mapping (one row per criterion in the
>     source MD).
>
> ### Determinism contract (applies to every PoC)
>
> - KQL is read from YAML, never generated by the LLM at run time.
>   String substitution for scope filters only.
> - Every ARG call sequence is `validate_query` → `execute_query`. On
>   `validate_query` failure: mark `INVALID`, do not retry, continue.
> - Run ID format: `<POC-PREFIX>-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`.
> - Sort orders, column headers, and section order are pinned in `SKILL.md`
>   and the templates.
> - All numeric output is integer unless the source data is a percentage —
>   then fixed to 1 decimal.
> - For deploy-capable PoCs: never deploy without an explicit user verb
>   (e.g. `apply`, `remediate`) AND a confirm gate; honor a global freeze
>   flag from `runbooks/prod.yaml`.
> - PoCs that include a cancel path must implement and test it.
>
> ### Tools — use only what the PoC lists
>
> Each PoC's "Tools used" line in the source MD is the **exact** allowed
> tool set for that agent. Do not add `create_template_deployment` to a
> read-only PoC, and do not omit `cancel_arm_template_deployment` from
> any PoC that includes deploy.
>
> ### Validation & test phase (mandatory before declaring done)
>
> For each PoC, after build:
>
> 1. **Schema check** — every YAML parses; every JSON ARM template parses;
>    every `*.prompt.md` has frontmatter; every `agents/*.agent.md` has
>    a tool allowlist; every `templates/output-*.md` placeholder is
>    referenced from `SKILL.md`.
> 2. **Reference-parity check** — file tree matches the reference layout
>    (allow PoC-specific extras under `skills/<slug>/`).
> 3. **Dry-run execution** — invoke the agent against the user's current
>    scope (subscription `463a82d4-1896-4332-aeeb-618ee5a5aa93`,
>    resource groups: `aks01day2-rg`, `aks02day2-rg`, `aksnapday2-rg`,
>    `apicenter-rg`, `apptesting-rg`, `az-foundry-rg`) and confirm:
>    - All `validate_query` calls return valid (or `INVALID` is recorded
>      in the report — never silently swallowed).
>    - **Real artifacts land in `<poc-folder>/exports/`** — not stubs, not
>      placeholders. The rendered report (e.g. `<slug>-prod-latest.md`)
>      must contain the **actual** numbers, resource IDs, and findings
>      returned by ARM MCP against the live scope above. If the PoC
>      defines a trend CSV, append a real row with real counts. If the
>      scope produces zero findings for a rule, the report must say so
>      explicitly (e.g. `0 failing resources`) rather than omitting it.
>    - Output renders against the template (no unsubstituted
>      `{{placeholder}}` strings, no leftover `${...}` tokens from the
>      runbook).
>    - For deploy PoCs: dry-run / what-if path executes; **no real
>      deployment is performed during validation**. The what-if output
>      is captured under `exports/` (e.g. `whatif-<run_id>.json`).
>    - For cancel PoCs: trigger the cancel path against a mock or
>      a deliberately-stuck test deployment; capture the cancel response
>      under `exports/`.
>    - Re-running the same scope produces the same `run_id` and identical
>      report bytes (modulo timestamp).
> 4. **Record the test outcome** in `<poc-folder>/exports/test-run.md`
>    with: timestamp, scope used, tools called (count by tool name),
>    output artifacts produced (filenames + byte sizes), counts of
>    findings by severity, and any `INVALID` / skipped rules. This file
>    is the **proof** the dry-run actually executed against live Azure —
>    a PoC with an empty `exports/` folder is not done.
> 5. **Open a tracking issue or PR-ready commit** per PoC titled
>    `[<POC-ID>] <PoC title>` with a checklist of the acceptance
>    criteria mapping showing pass/fail.
>
> ### Final deliverable from the fleet lead (you)
>
> When all 23 PoCs report green:
>
> - Write `FLEET-BUILD-REPORT.md` at the repo root with one row per PoC:
>   `id | folder | status | run_id | tools_called | invalid_rules | notes`.
> - Sort: `POC-1` through `POC-12`, then `SRE-PoC-1` through `SRE-PoC-12`
>   (skipping 5).
> - Flag any PoC that needed scope adjustments or could not be fully
>   tested against the user's sub (e.g., no SQL DBs in scope to exercise
>   geo-backup checks).
>
> ### Hard rules (do not violate)
>
> - **Do not modify** [`reliability-posture-scorecard/`](reliability-posture-scorecard).
> - **Do not deploy real Azure resources** during validation. Use what-if /
>   dry-run only. Real deploys are end-user actions, gated behind explicit
>   verbs.
> - **Do not invent ARG schema** — if a PoC needs a table or column you
>   are not sure exists, mark the rule `INVALID` with a note and continue.
> - **Do not put secrets** in any YAML, agent, or template.
> - **Do not edit** the two source MDs (`ARM-MCP-PoC-Ideas.md`,
>   `ARM-MCP-SRE-PoCs.md`) — they are the spec.
>
> Begin.

---

## Open questions to confirm before kicking the fleet off

1. **Test scope.** I assumed the user's existing 6-RG scope
   (`aks01day2-rg`, `aks02day2-rg`, `aksnapday2-rg`, `apicenter-rg`,
   `apptesting-rg`, `az-foundry-rg` in sub `463a82d4-…`) is fine for
   validation runs. Some PoCs (`POC-4 Golden Path`, `POC-9 ARM Template
   Fixer`, `SRE-PoC-7 Capacity Guardian`, `SRE-PoC-10 Runbook Executor`)
   need a sandbox sub where deploys can be tried. **OK to keep
   what-if-only on the existing sub, or do you have a sandbox sub to
   point them at?**
2. **Parallelism.** "Fan out one sub-agent per PoC" can mean truly
   parallel (23 simultaneous) or capped (e.g. 4 at a time). **Cap, or
   unbounded?**
3. **Fleet lead model.** The fleet lead invocation needs to be `@squad`
   (multi-agent) or your default agent. Above is written for `@squad`.
   **Confirm or swap.**
4. **Real deploys, ever.** PoC validation explicitly forbids real
   deploys. **Want a follow-up "live demo" pass that actually deploys
   one or two flagship PoCs (e.g. PoC-4 Golden Path, SRE-PoC-4
   Auto-rollback) end-to-end against a throwaway RG?**
5. **Output reporting venue.** `FLEET-BUILD-REPORT.md` lives at the
   repo root. **Want it pushed to a GitHub issue/PR instead?**

Ship the prompt as-is if those defaults are fine; otherwise tell me
which to flip and I'll patch the file.
