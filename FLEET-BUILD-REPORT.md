# ARM MCP PoC Fleet Build Report

| Field | Value |
|-------|-------|
| **Date** | 2026-05-12 |
| **Total PoCs** | 23 |
| **Approved** | 23 / 23 (100%) |
| **Author** | Bishop (Fleet Lead) |
| **Ratifications applied** | `copilot-bishop-ratifications-2026-05-12.md` |

---

## Executive Summary

The ARM MCP PoC fleet comprises 23 proof-of-concept agents (12 POC + 11 SRE-PoC) spanning READ, DEPLOY, DEPLOY+CANCEL, and DEPLOY what-if patterns. All 23 PoCs achieved APPROVE status — 15 on first pass, 8 after marker-discipline rewrites enforced by reviewer lockout. Validation was schema/parity only; no live ARM or ARG calls were made during the build. Notable deviations (POC-9 non-standard `rules.yaml` schema, SRE-PoC-10 runbook DSL, SRE-PoC-12 null remediation template) are documented per ratification and do not violate the determinism contract.

---

## Per-PoC Status Table

| # | ID | Slug | Pattern | Wave | Tools | Final Verdict | Rewrite Cycles |
|---|----|------|---------|------|-------|---------------|----------------|
| 1 | POC-1 | POC-1-tag-hygiene-czar | DEPLOY (read+remediate) | 2 | — | APPROVE (1st pass) | 0 |
| 2 | POC-2 | POC-2-blast-radius-analyzer | DEPLOY what-if | 3 | — | APPROVE (1st pass) | 0 |
| 3 | POC-3 | POC-3-cost-driver-finder | READ | 1 | — | APPROVE (1st pass) | 0 |
| 4 | POC-4 | POC-4-golden-path-provisioner | DEPLOY+CANCEL | 4 | 4 | APPROVE on v2 | 1 |
| 5 | POC-5 | POC-5-iac-drift-detector | READ | 1 | — | APPROVE (1st pass) | 0 |
| 6 | POC-6 | POC-6-incident-responder | READ+CANCEL | 2 | — | APPROVE (1st pass) | 0 |
| 7 | POC-7 | POC-7-policy-what-if | READ | 1 | — | APPROVE (1st pass) | 0 |
| 8 | POC-8 | POC-8-estate-cartographer | READ | 1 | — | APPROVE (1st pass) | 0 |
| 9 | POC-9 | POC-9-arm-template-fixer | DEPLOY+CANCEL | 4 | 3 | APPROVE on v2 | 1 |
| 10 | POC-10 | POC-10-crown-jewels-security | READ | 1 | — | APPROVE (1st pass) | 0 |
| 11 | POC-11 | POC-11-finops-rightsizer | DEPLOY | 2 | — | APPROVE (1st pass) | 0 |
| 12 | POC-12 | POC-12-chatops-bot | READ | 1 | — | APPROVE on v2 | 1 |
| 13 | SRE-PoC-1 | SRE-PoC-1-incident-triage | READ+CANCEL | 2 | — | APPROVE on v3 | 2 |
| 14 | SRE-PoC-2 | SRE-PoC-2-change-freeze-enforcer | DEPLOY | 3 | — | APPROVE on v2 | 1 |
| 15 | SRE-PoC-3 | SRE-PoC-3-preflight-safety | DEPLOY | 3 | — | APPROVE (1st pass) | 0 |
| 16 | SRE-PoC-4 | SRE-PoC-4-auto-rollback | DEPLOY+CANCEL | 4 | 4 | APPROVE on v2 | 1 |
| 17 | SRE-PoC-6 | SRE-PoC-6-slo-deployment-gate | DEPLOY | 3 | — | APPROVE (1st pass) | 0 |
| 18 | SRE-PoC-7 | SRE-PoC-7-capacity-quota-guardian | DEPLOY | 3 | — | APPROVE (1st pass) | 0 |
| 19 | SRE-PoC-8 | SRE-PoC-8-blast-radius-simulator | DEPLOY what-if | 3 | — | APPROVE (1st pass) | 0 |
| 20 | SRE-PoC-9 | SRE-PoC-9-stuck-deployment-janitor | READ+CANCEL | 2 | — | APPROVE (1st pass) | 0 |
| 21 | SRE-PoC-10 | SRE-PoC-10-runbook-executor | DEPLOY+CANCEL | 4 | 6 | APPROVE (1st pass) | 0 |
| 22 | SRE-PoC-11 | SRE-PoC-11-post-incident-reconstructor | READ | 2 | — | APPROVE on v2 | 1 |
| 23 | SRE-PoC-12 | SRE-PoC-12-weekly-cleanup-prs | DEPLOY-shape (UNREACHABLE) | 4 | — | APPROVE on v2 | 1 |

**Legend — Tools column:** `—` = standard tool count for pattern; explicit count shown only for multi-verb DEPLOY+CANCEL PoCs with non-standard tool sets. `NO ARG` note: POC-9 uses 3 tools with no ARG dependency. SRE-PoC-10 uses ALL 6 tools.

---

## Wave Summary

| Wave | Count | PoCs | 1st-pass approvals | Rewrites |
|------|-------|------|---------------------|----------|
| Wave 1 — Read-only | 6 | POC-3, POC-5, POC-7, POC-8, POC-10, POC-12 | 5 | 1 (POC-12) |
| Wave 2 — Read+cancel + simple deploy | 6 | POC-1, POC-6, POC-11, SRE-PoC-1, SRE-PoC-9, SRE-PoC-11 | 4 | 2 (SRE-PoC-1, SRE-PoC-11) |
| Wave 3 — Deploy with what-if + gates | 6 | POC-2, SRE-PoC-2, SRE-PoC-3, SRE-PoC-6, SRE-PoC-7, SRE-PoC-8 | 5 | 1 (SRE-PoC-2) |
| Wave 4 — Multi-verb deploy+cancel | 5 | POC-4, POC-9, SRE-PoC-4, SRE-PoC-10, SRE-PoC-12 | 1 (SRE-PoC-10) | 4 |
| **Total** | **23** | | **15** | **8** |

---

## Ratifications Applied

Source: `copilot-bishop-ratifications-2026-05-12.md`

| # | Ratification | Effect |
|---|-------------|--------|
| 1 | `resourcechanges` / `authorizationresources` table availability | `SKIP_IF_UNAVAILABLE` defensive pattern adopted across all PoCs querying these tables. |
| 2 | (Covered by #1) | — |
| 3 | What-if mode for `create_template_deployment` | Templates only; never called in v1. Listed in `tools:` for schema parity but FORBIDDEN by hard rule. |
| 4 | POC-7 KQL templates with `{{alias_field}}` placeholders | Accepted as contract-compliant. |
| 5 | SRE-PoC-6 SLO error budget | Workspace metadata only; percentage calculation out of scope. |
| 6 | SRE-PoC-7 quota limits | Hardcoded in `runbooks/prod.yaml` `quota_limits:` block. |
| 7 | PoCs missing `validate_query` in tool allowlist | Skip validate, document in `## Determinism Deviation` section in each PoC README. |

---

## Notable Deviations

| PoC | Deviation | Disposition |
|-----|-----------|-------------|
| POC-9 | `rules.yaml` uses non-standard schema (`error_code:` + `fix_pattern:` instead of `kql:`). | Documented in README per ratification #1. Fixed template IS the output; no `remediation/*.json` files. |
| SRE-PoC-10 | `rules.yaml` defines step-type SCHEMAS (4 types) instead of a rule list (novel runbook DSL). | Documented in README + `rules.yaml` header per ratification #1. |
| SRE-PoC-12 | Rule R005: `remediation_template: null` — no 4th template. | 3-template mandate met; 4th rule has no remediation action (PR markdown only). |
| All DEPLOY PoCs | `create_template_deployment` listed in `agent.md` `tools:` block but FORBIDDEN in v1. | Validation = schema/parity only this pass (per ratification #3). |

---

## Determinism Contract Compliance

All 23 PoCs satisfy the six-point determinism contract:

| # | Requirement | Status |
|---|-------------|--------|
| 1 | KQL is read from YAML — never LLM-authored | ✅ |
| 2 | `validate_query` → `execute_query` sequence with INVALID-and-continue (where applicable per ratification #7) | ✅ |
| 3 | Deterministic `run_id` (e.g., `GP-{YYYYMMDD}-{scope}-{ruleset_hash8}`, `ROLL-…`, `RBOOK-…`, `CLEAN-…`, `FIX-…`) | ✅ |
| 4 | Frozen sort orders + templates with `{{placeholders}}` only | ✅ |
| 5 | No deploys outside an explicit verb + confirm gate | ✅ |
| 6 | Tool allowlist matches exactly what the source MD lists for that PoC | ✅ |

---

## Reference Parity

Every PoC folder mirrors the `reliability-posture-scorecard/` reference layout: `README.md`, `.vscode/mcp.json`, `.github/copilot/agents/<slug>.agent.md`, `.github/copilot/skills/<slug>/{SKILL.md, rules/rules.yaml, templates/output-*.md, [remediation/*.json], prompts/*.prompt.md}`, `runbooks/{prod.yaml, prod.values.yaml.example}`, `exports/{.gitkeep, test-run.md}`. No PoC deviates from this structure. ✅

---

## Validation Stance

| Aspect | Status |
|--------|--------|
| Schema/parity checks | ✅ Performed for all 23 PoCs |
| Live ARM/ARG calls | ❌ Not executed during build |
| Live Azure deploys | ❌ Not executed during build |
| `create_template_deployment` invocations | ❌ Never called by any PoC |
| `exports/test-run.md` content | Simulated outcomes with `<simulated>…</simulated>` markers wrapping every fabricated value |
| Exempt from markers | Prose and config-derived constants |
| Live validation path | Operator-driven in VS Code via the ARM MCP server |

---

## Reviewer Lockout Statistics

Per Squad protocol: when Bishop rejected a PoC, a DIFFERENT builder (suffix `-v2`, `-v3`) owned the rewrite. The original builder was locked out of that artifact for the remainder of the fleet build.

| Metric | Value |
|--------|-------|
| Total rewrite cycles | 8 |
| PoCs approved 1st pass | 15 |
| PoCs approved on v2 | 7 |
| PoCs approved on v3 | 1 (SRE-PoC-1) |
| Max rewrites for a single PoC | 2 (SRE-PoC-1: v2 minor 3-bare-Running fix → v3 APPROVE) |

Rewrite breakdown:

| PoC | Reason for rejection | Final version |
|-----|---------------------|---------------|
| POC-4 | Marker discipline | v2 |
| POC-9 | Marker discipline | v2 |
| POC-12 | Marker discipline | v2 |
| SRE-PoC-1 | Marker discipline (v1) → minor 3-bare-Running fix (v2) | v3 |
| SRE-PoC-2 | Systematic marker pass | v2 |
| SRE-PoC-4 | Marker discipline | v2 |
| SRE-PoC-11 | Marker discipline | v2 |
| SRE-PoC-12 | Marker discipline | v2 |

---

## Next Steps for Operators

1. **Open in VS Code** — Load any PoC folder with the ARM MCP server extension active.
2. **Run `validate_query` live** — Execute KQL validation against a real ARG endpoint to confirm table/column availability.
3. **Exercise verbs** — For DEPLOY-pattern PoCs, invoke the agent in chat and walk through the confirm gate. Verify `create_template_deployment` writes templates/parameters to disk without executing.
4. **Check `exports/test-run.md`** — Compare live output shape against the simulated reference. All `<simulated>…</simulated>` blocks should be replaced by real values.
5. **Validate ratification #1 defensively** — Confirm `resourcechanges` and `authorizationresources` tables are available in your tenant; if not, verify `SKIP_IF_UNAVAILABLE` triggers correctly.
6. **Review `runbooks/prod.yaml`** — Adjust scope filters, thresholds, and quota limits for your environment before any live run.
7. **Confirm tool allowlists** — Cross-check each `agent.md` `tools:` block against the PoC pattern table above.

---

*Report generated by Bishop (Fleet Lead) on 2026-05-12. All 23 PoCs APPROVED. Fleet build COMPLETE.*
