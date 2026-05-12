# Decision Drop — Bishop Manifest Ratifications

**From:** Coordinator (Copilot CLI)
**To:** Bishop (Lead/Fleet Lead) + all wave builders
**Date:** 2026-05-12
**Re:** `bishop-fleet-manifest.md` Open Questions (lines 642–656)
**Status:** RATIFIED by user "Copilot Scribe" via interactive prompt

---

The user has ratified all 7 of Bishop's open questions. Builders MUST treat these as binding decisions and inline the relevant policy into their PoC's `README.md`, `SKILL.md`, and `rules.yaml` where applicable.

## Ratifications

| # | Item | Decision |
|---|------|----------|
| 1 | `resourcechanges` table availability (POC-3, POC-6, SRE-PoC-1, SRE-PoC-11, SRE-PoC-12) | **Mark rules `SKIP_IF_UNAVAILABLE` defensively.** Live validation in VS Code will discover whether the table is enabled in subscription `463a82d4-1896-4332-aeeb-618ee5a5aa93`. Builders implement the rule with try-the-table semantics: if `execute_query` returns an empty resultset OR errors with table-not-found, skill emits an output row `STATUS=SKIPPED REASON=resourcechanges-unavailable` and continues. |
| 2 | `authorizationresources` table queryability (POC-10, SRE-PoC-1, SRE-PoC-11) | **Same `SKIP_IF_UNAVAILABLE` pattern as #1.** |
| 3 | What-if mode for `create_template_deployment` (POC-2, SRE-PoC-8) | **Templates only — never call the tool in any test path.** The agent.md `tools:` block MAY list `create_template_deployment` (because the source MD's "Tools used" line is authoritative), but the agent.md `hard_rules` block MUST forbid calling it without an explicit `apply` verb + a confirm gate. The default agent verb is `simulate`, which writes the template + parameters to disk only. This honors the locked decision: "What-if templates only — never call create_template_deployment." |
| 4 | POC-7 KQL templates with `{{alias_field}}` / `{{alias_value}}` placeholders | **Accepted as a contract-compliant pattern.** This is still literal KQL + string substitution — the substitution source is the policy JSON input rather than the runbook scope filter. The KQL TEMPLATES live in `rules.yaml` verbatim; the runtime only substitutes the placeholders. POC-7's README MUST document this placeholder convention and list the supported policy aliases (sku, location, tags, networkAcls). Unsupported aliases output `STATUS=UNSUPPORTED ALIAS=<name>`. |
| 5 | SRE-PoC-6 SLO error budget calculation | **Workspace metadata only — actual budget % is `OUT_OF_SCOPE_FOR_ARM_MCP`.** ARG can locate the App Insights / Log Analytics workspace resource but cannot read metric values. Output template MUST include a row `STATUS=OUT_OF_SCOPE REASON=arg-cannot-read-metrics` with a pointer to the workspace resource ID for the operator to investigate manually. |
| 6 | SRE-PoC-7 Quota limits | **Hardcode known limits in `runbooks/prod.yaml` under a `quota_limits:` block.** ARG returns current usage but not subscription limits. Builder MUST seed prod.yaml with at least these limits documented as `# operator must keep in sync with az vm list-usage output`: `vm_cores_per_region`, `public_ip_addresses`, `network_interfaces`, `storage_accounts`. Auto-file quota request is OUT OF SCOPE. |
| 7 | PoCs missing `validate_query` in tool allowlist (POC-3, POC-5, POC-6, POC-8, POC-11, POC-12, SRE-PoC-1, SRE-PoC-4, SRE-PoC-6, SRE-PoC-7, SRE-PoC-9, SRE-PoC-12) | **Skip the validate step.** The source MD's "Tools used" line is authoritative — builders MUST NOT add `validate_query` to the agent's `tools:` block if it's not listed there. The `SKILL.md` procedure for these PoCs SHALL skip step "(a) validate_query → (b) execute_query" and go directly to `execute_query` (or `generate_query` → `execute_query` for PoC-3). Each affected PoC's README MUST contain a `## Determinism Deviation` section noting: "This PoC does not include `validate_query` in its tool allowlist per source spec. KQL correctness is assured by pre-testing during development. Operators running this PoC live should hand-verify rules.yaml KQL via the `validate_query` tool in another workspace if uncertain." |

## Wave Plan — Approved

User approved Bishop's proposed wave grouping verbatim:
- **Wave 1 (6):** POC-3, POC-5, POC-7, POC-8, POC-10, POC-12 — pure read-only
- **Wave 2 (6):** POC-1, POC-6, POC-11, SRE-PoC-1, SRE-PoC-9, SRE-PoC-11 — read+cancel + simple deploy
- **Wave 3 (6):** POC-2, SRE-PoC-2, SRE-PoC-3, SRE-PoC-6, SRE-PoC-7, SRE-PoC-8 — deploy with what-if + gates
- **Wave 4 (5):** POC-4, POC-9, SRE-PoC-4, SRE-PoC-10, SRE-PoC-12 — multi-verb deploys with cancel paths

## Builder Conduct (binding for all 23 builders)

1. Each builder receives ONE manifest row (verbatim) + the full determinism contract + this ratifications file. Builder MUST NOT re-read the source MDs (`ARM-MCP-PoC-Ideas.md`, `ARM-MCP-SRE-PoCs.md`).
2. Builder MUST read the reference implementation at `reliability-posture-scorecard/` and mirror its file layout exactly. Builder MUST NOT modify any file under `reliability-posture-scorecard/`.
3. Builder writes to its assigned folder slug at the repo root only. No edits outside that folder + nothing under `.squad/`.
4. After writing all PoC files, builder MUST write `<slug>/exports/test-run.md` with a SIMULATED test outcome (since live validation is operator-driven in VS Code per locked decision). The simulated output uses the agent's intended output template, populated with placeholder values clearly marked `<simulated>`.
5. Builder reports back a JSON-ish summary: `files_written: [...], deviations: [...], open_questions: [...], parity_with_reference: ok|drift`. Bishop will review.

## Reviewer Lockout

If Bishop rejects any builder's PoC, a DIFFERENT builder must do the rewrite. The original builder is locked out of that artifact for the rest of the fleet build.
