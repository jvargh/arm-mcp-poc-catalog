---
name: golden-path-provisioner
description: >
  Deterministic procedure to provision, monitor, and cancel pre-approved ARM golden-path
  template deployments with naming guardrails, tag enforcement, and compliance checks.
---

# Procedure

Inputs:
- `verb`: one of `provision`, `status`, `cancel`.
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `workload`: free-text workload description (used for template selection in `provision`).
- `team`: team slug injected into resource naming.
- `region`: Azure region short-name (e.g. `eastus2`). Must be in `allowed_regions`.
- `deployment_name`: required for `status` and `cancel` verbs.

---

## Step 1 — Load configuration (no LLM judgment)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml`
   exists, parse it and substitute every `${key}` token in the runbook text with the
   corresponding value. Then parse the substituted text as YAML.
   If `<scope>.values.yaml` is missing, abort with the literal message:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook:
   - `subscriptions[]`
   - `naming_prefix`
   - `default_tags` (map)
   - `allowed_regions[]`
   - `golden_path_catalog` (map: template_name → {path, keywords[], param_schema})
3. Read `skills/golden-path-provisioner/rules/rules.yaml`. Compute SHA-256 of the file
   contents; keep first 8 hex chars as `ruleset_hash8`.
4. Compute `run_id = "GP-" + UTC date YYYYMMDD + "-" + scope + "-" + ruleset_hash8`.

---

## Step 2 — Workload-to-template selection (keyword-deterministic)

*Only applies to the `provision` verb.*

1. Tokenise the `workload` input to lowercase words.
2. Iterate `golden_path_catalog` entries **in file order**. For each entry, check whether
   any of its `keywords[]` appear in the tokenised workload. The **first matching entry wins**.
3. If no entry matches, abort with:
   `ABORT: No catalog entry matched workload keywords — check golden_path_catalog in prod.yaml`.
4. Record `selected_template = catalog_entry.name`, `template_path = catalog_entry.path`,
   `param_schema = catalog_entry.param_schema`.
5. Log selection: `TEMPLATE SELECTED: <selected_template> (matched keyword: <keyword>)`.

---

## Step 3 — Naming + tag enforcement (pre-deploy)

*Only applies to the `provision` verb.*

1. Validate `region` is in `allowed_regions`. If not, abort:
   `ABORT: Region <region> is not in allowed_regions list`.
2. For each resource type in `param_schema.resource_types[]`, generate a name:
   ```
   name = "{naming_prefix}-{team}-{region}-{resource_type_short}"
   ```
   where `resource_type_short` is the last segment of the Azure resource type slug
   (e.g. `managedclusters` → `aks`, `registries` → `acr`, `vaults` → `kv`,
   `workspaces` → `la`, `sites` → `app`, `servers` → `sql`, `storageaccounts` → `st`,
   `factories` → `adf`).
3. Build the merged tag set: `default_tags` from runbook, plus `Team: <team>`,
   `ManagedBy: golden-path-provisioner`, `DeployedOn: <UTC date YYYYMMDD>`.
4. Output the naming table and tag set as the "Naming + Tag Plan" section of the report.

---

## Step 4 — Pre-deploy compliance check (execute_query only)

*Only applies to the `provision` verb, run before the what-if plan.*

For each `rule` in `rules.yaml` **in file order**:

1. If `rule.kql` is missing → record `status: SKIPPED` and continue.
2. Substitute `<subscriptions>` placeholder in `rule.kql` with the subscriptions list
   from the runbook. No other KQL modification.
3. Call `execute_query` with the substituted KQL.
   - On error → record `status: INVALID`, store error message, continue.
4. Record per rule: `{rule_id, status, failing_resource_count, failing_resource_ids}`.
5. If any rule returns `failing_resource_count > 0`, append a `⚠ PRE-DEPLOY FINDING`
   block to the report for operator review. Do NOT abort — the operator decides.

> **No `validate_query` is called.** Per tool allowlist, only `execute_query` is
> available for KQL. See `## Determinism Deviation` in README.md.

---

## Step 5 — What-if plan rendering

*Only applies to the `provision` verb.*

1. Load `templates/output-report.md`.
2. Substitute placeholders:
   - `{{run_id}}`, `{{scope}}`, `{{generated_utc}}` (ISO 8601, UTC, `Z` suffix),
     `{{ruleset_hash8}}`, `{{selected_template}}`, `{{workload}}`,
     `{{naming_table}}`, `{{tag_table}}`, `{{resource_count}}`, `{{param_schema_summary}}`,
     `{{compliance_table}}`, `{{what_if_summary}}`.
3. Emit the rendered plan with a prominent footer:
   ```
   WOULD DEPLOY (NOT EXECUTED in v1 — what-if only per locked decision)
   ```
4. Do NOT call `create_template_deployment`. Stop here in v1.

---

## Step 6 — Live progress (10s polling)

*Applies to the `status` verb — and is the live continuation of `provision` when
`create_template_deployment` is eventually called in a future version.*

1. Call `get_arm_template_deployment_status` with `deployment_name` and `resource_group`.
2. Extract `provisioningState`, `timestamp`, `duration`, `resource_statuses[]`.
3. Load `templates/output-status.md` and substitute:
   - `{{deployment_name}}`, `{{resource_group}}`, `{{provisioning_state}}`,
     `{{timestamp}}`, `{{duration}}`, `{{resource_statuses_table}}`.
4. Emit the rendered status block.
5. If `provisioningState` is not terminal (`Succeeded`, `Failed`, `Canceled`),
   wait exactly **10 seconds**, then repeat from step 1.
6. If `provisioningState == "Failed"`, emit:
   `⚠ DEPLOYMENT FAILED — run cancel verb to trigger rollback hook`.

---

## Step 7 — Cancel flow

*Applies to the `cancel` verb, and is triggered automatically on sub-resource failure
in a live run.*

1. Display:
   ```
   ⚠ CANCEL REQUEST
   Deployment : <deployment_name>
   Resource Group: <resource_group>
   Current State : <provisioningState>

   Type "confirm" to proceed with cancellation. Any other input aborts.
   ```
2. **Wait for user to type exactly `confirm`.** If not received, abort with:
   `CANCEL ABORTED — no confirmation received`.
3. On confirmation, call `cancel_arm_template_deployment` with `deployment_name`
   and `resource_group`.
4. Write one JSON line to `exports/cancel-audit.jsonl`:
   ```json
   {"event":"cancel_attempt","deployment_name":"<name>","resource_group":"<rg>","confirmed":true,"outcome":"<Canceled|error>","utc":"<ISO8601>"}
   ```
5. Emit confirmation: `CANCEL SUBMITTED — monitor with status verb`.

---

## Failure handling

- `execute_query` timeout: record rule as `INVALID` with error; continue.
- `get_arm_template_deployment_status` error: log error; retry after 10s up to 3 times,
  then abort with `ABORT: status poll failed after 3 attempts`.
- `cancel_arm_template_deployment` error: log error; write audit JSON with `"outcome":"error"`.
- If `rules.yaml` cannot be read, abort: `ABORT: rules.yaml unreadable`.

---

## Output contract

- Every `provision` run produces one rendered `output-report.md` with the run_id header.
- Every `status` poll produces one rendered `output-status.md` block.
- Every `cancel` attempt (confirmed or not) appends one JSON line to `exports/cancel-audit.jsonl`.
- No LLM-generated content appears outside the fixed template substitution points.
