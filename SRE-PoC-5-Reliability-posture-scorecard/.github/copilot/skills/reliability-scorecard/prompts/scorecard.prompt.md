---
mode: agent
agent: scorecard
---

Run the **reliability-scorecard** skill in `scorecard` mode for scope `${input:scope:prod}`.

Strict requirements:
- Use the rule pack at `skills/reliability-scorecard/rules/rules.yaml` exactly. Do not invent rules.
- Run preflight (auth + ensure `exports/`, `exports/_run/` exist) before the rule loop.
- For every rule: collapse internal whitespace to single spaces, call `validate_query`,
  then `execute_query` with pagination (drain `skip_token`). No retries on failure.
- After each `execute_query`, enforce the schema-shape contract: row keys MUST equal
  the projected column set parsed from the rule's final `| project ...`. On mismatch,
  mark the rule `INVALID` with reason `result-schema-mismatch` (this is the defense
  against transport-mangled queries silently returning the full ARG resource shape).
- Cache raw pre-filter rows to `exports/_run/{run_id}/{rule_id}.json` and write a
  `manifest.json` for the run.
- Render the report by literal substitution into `templates/output-report.md`.
- Persist to `exports/scorecard-${input:scope:prod}-latest.md` AND `exports/{run_id}.md`.
- **Upsert** (do not append a duplicate) one row in `exports/scorecard-trend.csv`
  keyed by `run_id`.
- Output ONLY the rendered report and one final line confirming the CSV upsert. No commentary.
