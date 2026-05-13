---
mode: agent
agent: policy-what-if
---

Simulate the policy compliance impact of the draft Azure Policy definition provided below for scope `${input:scope:prod}`.

Strict requirements:
- Parse the policy `if` block to extract all field aliases referenced.
- For each alias, look up the matching rule in `skills/policy-what-if/rules/rules.yaml`; do not invent ARG queries.
- For every resolved alias, call `validate_query` then `execute_query`. No retries on failure.
- For unsupported aliases, emit `STATUS=UNSUPPORTED ALIAS=<alias-name>` in the output and continue.
- Render the report by literal substitution into `templates/output-report.md`.
- Sort non-compliant resources ascending by Owner tag, then ascending by resource type.
- If `output_format` is `detailed` or `csv`, write the export to `exports/policy-what-if-{{run_id}}.csv`.
- Output ONLY the rendered report and one final line confirming the export (if applicable). No commentary.

Policy JSON:
${input:policy_json}
