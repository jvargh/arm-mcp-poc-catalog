---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `drilldown` mode for workload `${input:workload}` in scope `${input:scope:prod}`.

Strict requirements:
- Snapshot semantics: explain the **most recent scorecard snapshot** for this scope and
  current `ruleset_hash8`. Read cached per-rule rows from
  `exports/_run/{run_id}/{rule_id}.json` (validated against
  `exports/_run/{run_id}/manifest.json`). If no snapshot exists for the current
  `(scope, ruleset_hash8)`, abort: `ABORT: no scorecard snapshot available — run @scorecard run for scope ${input:scope:prod} first`.
- Identify only the rules whose cached rows include this workload after applying the
  current runbook's `rg_include` / `rg_exclude` filter (cache rows are pre-filter, so
  a runbook tweak between scorecard and drilldown is safe).
- Render via literal substitution into `templates/output-drilldown.md`.
- Display the **verbatim multi-line KQL** from `rules.yaml` (NOT the transport-collapsed
  form). Include up to 25 distinct resource IDs per failed rule.
- Persist to `exports/drilldown-${input:scope:prod}-${input:workload}.md`.
- Output ONLY the rendered drilldown. No commentary. No CSV write.
