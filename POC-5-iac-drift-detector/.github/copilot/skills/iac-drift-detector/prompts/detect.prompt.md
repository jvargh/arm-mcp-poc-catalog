---
mode: agent
agent: iac-drift-detector
---

Run the **iac-drift-detector** skill in `detect` mode for scope `${input:scope:prod}`.

Strict requirements:
- Read the ARM template path from `runbooks/<scope>.yaml` (`template_repo_path` key).
- Use the rule pack at `skills/iac-drift-detector/rules/rules.yaml` exactly. Do not invent rules or KQL.
- For every rule, call `generate_query` (with scope tokens substituted) then `execute_query`. Do NOT call `validate_query`.
- Process resources in ARM template declaration order. Sort drifted fields alphabetically.
- Diff format is JSON patch (RFC 6902): `replace` for changed values, `add` for fields present in template but absent in live, `remove` for fields absent in template but present in live.
- Render the report by literal substitution into `templates/output-report.md`.
- Write the rendered report to `exports/drift-<scope>-latest.md`.
- Output ONLY the rendered report and one final line confirming the export path. No commentary.
