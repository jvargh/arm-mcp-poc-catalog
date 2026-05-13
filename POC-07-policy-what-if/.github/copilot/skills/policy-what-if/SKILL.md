---
name: policy-what-if
description: Deterministic procedure to simulate the compliance impact of a draft Azure Policy definition by translating its if-block into ARG queries and counting would-be non-compliant resources.
---

# Procedure

Inputs:
- `policy_json`: the draft Azure Policy definition JSON (the `if`/`then` block or a full definition).
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `simulate` (default) or `drilldown <resource-id>`.

## Step 1 — Load inputs (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted
   text as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`, `policy_alias_map_version`, `output_format`.
3. Read `skills/policy-what-if/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "POL-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.
5. Parse `policy_json`. Extract the `if` block. Collect all `field` values referenced
   in the `if` block (these are the policy aliases to simulate, e.g.
   `Microsoft.Compute/virtualMachines/sku.name`, `tags['Owner']`).

## Step 2 — Resolve policy aliases to ARG fields

For each `field` value found in the policy `if` block:

1. Determine the short alias name:
   - If the field path contains `sku` → alias = `sku`
   - If the field path is `location` → alias = `location`
   - If the field path starts with `tags[` or `tags.` → alias = `tags`
   - If the field path contains `networkAcls` → alias = `networkAcls`
   - Otherwise → alias is unsupported. Record `STATUS=UNSUPPORTED ALIAS=<field>` and skip.
2. For supported aliases, select the matching rule from `rules.yaml` by `alias_field_map` key:
   - `sku` → R001 (compute) or R003 (storage), depending on resource type in policy
   - `networkAcls` → R002 (network/storage)
   - `location` → R003 (storage) or R002 (network), depending on resource type in policy
   - `tags` → R001 (compute) for VM resources; R003 (storage) for storage; R004 (generic) otherwise
3. Resolve `alias_field_arg` from the matched rule's `alias_field_map[alias]`.
   - For `tags`, parse the tag name from the policy field (e.g., `tags['Owner']` → `alias_field_arg = tags.Owner`).
4. Determine `alias_value`:
   - If the policy condition is `exists: false` or `exists: "false"` → set `alias_value = __EXISTS__`
   - If the policy condition is `equals: <val>` → set `alias_value = <val>`
   - If the policy condition is `notEquals: <val>` → reinterpret as "compliant if field equals <val>";
     set `alias_value = <val>` and note in output that the query finds resources where field equals <val>
     (those would be non-compliant under a `notEquals` policy — i.e., resources that DO have the value
     that's denied). Emit a `NOTE: notEquals polarity` marker in the output.
   - For `in`/`notIn` list conditions: use the first value in the list as `alias_value` and note in
     output that the simulation covers only the primary value. Full list simulation is out of scope.

## Step 3 — Evaluate each resolved alias (fixed loop)

For each successfully resolved alias:

1. Take the `kql` template from the matched rule verbatim.
2. Substitute `{{alias_field}}` with `alias_field_arg` and `{{alias_value}}` with the resolved value.
   Perform only these two literal string replacements. Do not modify any other part of the KQL.
3. Call `validate_query` with `query = substituted_kql`, `subscriptions = runbook.subscriptions`.
   - On failure → record `status: INVALID`, store error message, continue.
4. Call `execute_query` with the same arguments.
5. Apply `rg_include` / `rg_exclude` filters from runbook to returned rows.
6. Record per alias: `{rule_id, alias_name, alias_field_arg, alias_value, non_compliant_resource_count, rows}`.

## Step 4 — Render output (mode-specific)

### Mode = `simulate`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{alias_map_version}}`, `{{policy_name}}` (from input or `<unnamed-policy>`).
   - `{{rules_evaluated}}` — count of aliases that reached `execute_query`.
   - `{{rules_invalid}}` — count of aliases that returned INVALID.
   - `{{aliases_unsupported}}` — count of aliases that had no matching rule.
   - `{{total_noncompliant}}` — sum of `non_compliant_resource_count` across all evaluated aliases.
   - `{{noncompliant_table}}` — one row per resource, **sorted ascending by `ownerTag`, then ascending
     by `type`**. Columns: `Owner Tag | Resource Type | Resource Group | Resource ID`.
     Include one row per unsupported alias in format: `STATUS=UNSUPPORTED | ALIAS=<name> | — | —`.
   - `{{alias_map_table}}` — one row per alias in the input policy, ascending by alias name.
     Columns: `Policy Alias | ARG Field | Status` (RESOLVED / INVALID / UNSUPPORTED).
3. If `output_format` is `csv` or `detailed`: write full resource list to
   `exports/policy-what-if-<run_id>.csv` (create with header if missing):
   `run_id,generated_utc,scope,policy_name,alias_name,alias_field,rule_id,resource_id,resourceGroup,type,location,ownerTag`
4. Print the rendered report and the export confirmation line (if applicable). Nothing else.

### Mode = `drilldown <resource-id>`

1. Read `templates/output-drilldown.md`.
2. Re-run only the rules that flagged this specific resource ID.
3. Substitute, print. No CSV write.

## Failure handling

- ARM MCP timeouts: do not retry; record the alias as `INVALID` with the error and continue.
- Empty result set: alias has zero non-compliant resources for the scope; include it in the
  alias map summary with count `0` — do not treat as a failure.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- If `policy_json` cannot be parsed, abort with:
  `ABORT: policy_json unparseable — supply a valid Azure Policy definition JSON`.
- Unsupported aliases: output `STATUS=UNSUPPORTED ALIAS=<alias-name>` and continue.

## Output contract (what callers can rely on)

- The first H1 line of every simulate report is exactly: `# Policy What-If Report`.
- Section order is exactly: Header → Summary → Would-Be Non-Compliant Resources → Alias Mapping Summary → Footer.
- Sort order: non-compliant resources sorted ascending by `ownerTag`, then ascending by `type`.
- Every `csv` or `detailed` run writes exactly one export file to `exports/`.
- UNSUPPORTED alias rows always appear at the end of the noncompliant table.
