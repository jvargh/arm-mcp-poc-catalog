---
name: iac-drift-detector
description: Deterministic procedure to compare a checked-in ARM template with live Azure state and emit a property-level drift report in markdown + JSON patch (RFC 6902) format.
---

# Procedure

Inputs:
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `mode`: one of `detect` (default), `drilldown <resource_id>`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value (lists/maps are inlined as YAML). Then parse the substituted text
   as YAML. If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscriptions[]`, `workload_key` (default `resourceGroup`),
   `rg_include[]`, `rg_exclude[]`, `template_repo_path` (path to the ARM template file),
   `resource_types_to_check[]` (list of ARM resource types to diff).
3. Read `skills/iac-drift-detector/rules/rules.yaml`. Compute SHA-256 of the file contents;
   keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "DRIFT-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

## Step 2 — Load the ARM template

1. Read the ARM template file at `template_repo_path` (relative to workspace root).
   If the file is missing, abort with the literal message:
   `ABORT: ARM template not found at <template_repo_path>`.
2. Parse the JSON. Extract the `resources[]` array.
3. Filter `resources[]` to only those whose `type` (case-insensitive) appears in
   `resource_types_to_check`. Preserve file-declaration order — do NOT sort.
4. Record `resources_total` = count of filtered resources.

## Step 3 — Per-rule drift detection loop

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Identify resources in the ARM template that match `rule.resource_type` (case-insensitive).
   If none → record `status: NO_TEMPLATE_RESOURCES` and continue.
3. Build the scope-filter tokens:
   - `${subscriptions_filter}` → comma-separated quoted subscription IDs, e.g. `"sub-a","sub-b"`
   - `${rg_filter}` → a KQL `where resourceGroup in~ (...)` clause, or empty string if `rg_include` is empty
   - `${resource_names_filter}` → a KQL `where name in~ (...)` clause using the template resource names for this rule's type
4. Substitute the three tokens into `rule.kql` (string replacement only).
5. Call `generate_query` with the substituted KQL string.
6. Call `execute_query` with the query returned by `generate_query`.
7. For each returned row, match to the corresponding ARM template resource by `name` (case-insensitive).
8. For each matched pair (template resource, live resource), compute the property diff:
   - Identify the property fields specified by `rule.diff_fields`.
   - For each field, compare template value vs live value.
   - If any field differs → record a **drift entry**:
     ```
     resource_id: <live ARG id>
     resource_name: <name>
     resource_type: <type>
     resource_group: <resourceGroup>
     rule_id: <rule.id>
     drifted_fields: [<alphabetically sorted list of field names that differ>]
     json_patch: [<RFC 6902 patch operations, one per drifted field, sorted by /path>]
     ```
   - If no fields differ → record `status: IN_SYNC` for this resource.
9. Resources in the template with no matching live row → record `status: MISSING_IN_LIVE`.

## Step 4 — Aggregate results

1. `resources_drifted` = count of resources with at least one drift entry.
2. `resources_missing` = count of resources with `status: MISSING_IN_LIVE`.
3. `resources_clean` = `resources_total` - `resources_drifted` - `resources_missing`.
4. Collect all drift entries. Keep them in ARM template declaration order (rule file order
   is secondary when a resource appears in multiple rules).

## Step 5 — Render output (mode-specific)

### Mode = `detect`

1. Read `templates/output-report.md`.
2. Substitute placeholders **literally**:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601 to seconds, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{template_repo_path}}`.
   - `{{resources_total}}`, `{{resources_drifted}}`, `{{resources_missing}}`, `{{resources_clean}}`.
   - `{{drift_summary_table}}` — one row per drifted or missing resource, in ARM template
     declaration order. Columns: `Resource Name | Type | Resource Group | Rule | Drifted Fields | Status`.
   - `{{json_patch_block}}` — fenced JSON block containing an array of per-resource patch
     objects. Each object:
     ```json
     {
       "resource_id": "...",
       "resource_name": "...",
       "rule_id": "...",
       "patch": [<RFC 6902 operations sorted by /path ascending>]
     }
     ```
     Outer array ordered by ARM template declaration order.
3. Write rendered report to `exports/drift-<scope>-latest.md` (overwrite if exists).
4. Print the rendered report and one final line confirming the export path. Nothing else.

### Mode = `drilldown <resource_id>`

1. Identify the drift entries for the given `resource_id` (match on ARG `id` field,
   case-insensitive).
2. Read `templates/output-drilldown.md`.
3. Substitute placeholders:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`, `{{resource_id}}`,
     `{{resource_name}}`, `{{resource_type}}`, `{{resource_group}}`.
   - `{{drift_properties_table}}` — one row per drifted property (alphabetical order).
     Columns: `Property | Template Value | Live Value`.
   - `{{json_patch_entry}}` — fenced JSON block with the RFC 6902 patch for this resource.
4. Print the rendered drilldown. No file write.

## Failure handling

- ARM MCP timeouts: do not retry; record the rule as `INVALID` with the error message and continue.
- Empty result set from `execute_query`: all template resources of that type are `MISSING_IN_LIVE`
  for this rule — record accordingly, do not error out.
- If `rules.yaml` cannot be read, abort with the literal message: `ABORT: rules.yaml unreadable`.
- If a field listed in `rule.diff_fields` is absent from both template and live resource,
  treat as `IN_SYNC` for that field (absent == absent).
- If a field is absent from template but present in live, produce an RFC 6902 `add` operation.
- If a field is present in template but absent in live, produce an RFC 6902 `remove` operation.
- If values differ, produce an RFC 6902 `replace` operation.

## Output contract (what callers can rely on)

- The first H1 line of every drift report is exactly: `# IaC Drift Report`.
- The order of sections is exactly: Header → Summary → Drift Summary Table → JSON Patch Block → Footer.
- Resources appear in ARM template declaration order throughout.
- Drifted fields within a resource are always sorted alphabetically.
- RFC 6902 patch operations within a resource are sorted by `/path` ascending.
