---
name: arm-template-fixer
description: Deterministic procedure to deploy a broken ARM template, classify errors using a fixed error-code→fix-pattern rule pack, apply fixes, and redeploy in a bounded retry loop.
---

# Procedure

Inputs:
- `template`: path to the ARM template JSON file (required).
- `scope`: name of a runbook under `runbooks/<scope>.yaml`. Defaults to `prod`.
- `verb`: one of `fix` (default), `status`, `cancel`.

## Step 1 — Load configuration (no LLM judgement)

1. Read `runbooks/<scope>.yaml` as raw text. If a sibling `runbooks/<scope>.values.yaml` exists,
   parse it and substitute every `${key}` token in the runbook text with the corresponding value.
   Then parse the substituted text as YAML. If `<scope>.values.yaml` is missing, abort with:
   `ABORT: runbooks/<scope>.values.yaml missing — copy <scope>.values.yaml.example and fill in real values`.
2. Extract from the parsed runbook: `subscription_id`, `resource_group`, `max_retries` (default 3),
   `destructive_change_types[]`, `allowed_fix_patterns[]`.
3. Read `skills/arm-template-fixer/rules/rules.yaml`. Compute SHA-256 of the file contents; keep
   first 8 hex chars as `ruleset_hash8`.
4. Read the user-supplied template file. Record its filename as `template_filename`.
5. Compute `run_id = "FIX-" + UTC date YYYYMMDD + "-" + template_filename + "-" + ruleset_hash8`.
6. Set `attempt = 0`, `changelog = []`, `current_template = <contents of template file>`.

## Step 2 — Initial deploy attempt (simulated)

> ⚠️ v1: Do NOT call `create_template_deployment`. Simulate the call and emit a fabricated error
> response (or success) to drive the classification loop. Document the call that would be made.

1. Log: `[Attempt {attempt+1}/{max_retries}] Simulating deployment of {template_filename} to
   {resource_group} in subscription {subscription_id}`.
2. Produce the simulated ARM error response JSON (or success). If this is the first attempt, use
   the errors embedded in the template or provided by the user. On subsequent attempts, use the
   simulated response from the previous redeploy.
3. If the simulated response indicates success → jump to **Step 8 (Final summary)**.
4. If `attempt >= max_retries` → emit `STATUS=EXHAUSTED` and jump to **Step 8**.

## Step 3 — Error classification (rules.yaml lookup)

1. Parse the simulated ARM error response. Extract the top-level `code` field (e.g.,
   `MissingDependency`, `InvalidTemplateDeployment`, `QuotaExceeded`, `Conflict`).
2. Search `rules.yaml` for a rule where `error_code` matches the extracted code
   (case-insensitive). If no match, classify as `UNCLASSIFIED` and continue — the loop still
   increments `attempt` and logs the miss.
3. Record: `{attempt, error_code, matched_rule_id, fix_pattern}`.

## Step 4 — Apply fix pattern (deterministic order)

Apply fixes in this fixed order per attempt (skip if the current error does not match):

1. **R001 — MissingDependency → add dependsOn:** Locate the resource that is referenced before
   its dependency is provisioned. Add a `dependsOn` entry pointing to the dependency's resource
   name.
2. **R002 — InvalidSku → suggest valid SKU:** Replace the offending `sku.name` with the first
   valid SKU from the rule's `valid_skus` list. Log the substitution.
3. **R003 — QuotaExceeded → suggest smaller SKU/region:** Downgrade to the next smaller SKU in
   the rule's `fallback_skus` list, or change `location` to the first entry in `fallback_regions`.
   Prompt the user to choose if both options are available.
4. **R004 — Conflict → switch to incremental:** Set `"mode": "Incremental"` in the template's
   `deploymentProperties`. If already `Incremental`, rename the conflicting resource by appending
   `-v2`.

Fix R005 is a guard (see Step 6), never an applied edit.

After applying: update `current_template`, append a changelog entry
`{attempt, rule_id, fix_applied, description}`.

## Step 5 — Diff log

Emit a unified diff between the previous template snapshot and `current_template`:

```
--- template (attempt {attempt})
+++ template (attempt {attempt+1})
@@ ... @@
 [unchanged lines]
-[removed lines]
+[added lines]
```

Store the diff in the run log. Do not summarise or paraphrase — emit verbatim.

## Step 6 — Halt-on-destructive-change check

Before proceeding to the next deploy attempt, scan `current_template` for any resource whose
`type` matches an entry in `runbooks/prod.yaml → destructive_change_types` AND whose deployment
mode would cause a deletion or full replacement (e.g., `Complete` mode with that resource absent,
or an explicit `delete` operation).

- If a destructive change is detected:
  - Emit: `STATUS=HALTED REASON=destructive-change-detected TYPE={matched_type} ATTEMPT={attempt+1}`
  - Stop the loop immediately. Do not apply the fix or redeploy.
  - Jump to **Step 8** with `final_status = HALTED`.
- If no destructive change: continue to the next attempt.

## Step 7 — Cancel flow

> This step is only entered when the verb is `cancel` OR when a simulated redeploy hangs
> (no status returned within the simulated timeout window).

1. Call `get_arm_template_deployment_status` with the deployment name to retrieve current status.
2. If status is `Running` or `Accepted`:
   - Display to the user:
     ```
     Deployment {deployment_name} is currently {status}.
     To cancel, type exactly: confirm cancel {deployment_name}
     Any other input will abort the cancel flow.
     ```
   - Wait for user input. If the user types `confirm cancel {deployment_name}` (exact match):
     - Call `cancel_arm_template_deployment` with `deploymentName = {deployment_name}`.
     - Log: `[Cancel] Cancellation submitted for {deployment_name}.`
   - Any other input → log `[Cancel] Cancel aborted by user.` and return to the fix loop (or halt).
3. If status is already `Succeeded` / `Failed` / `Canceled`: log the status and skip the cancel.

## Step 8 — Final summary

Increment `attempt` (now reflects completed attempts). Render the output:

1. If `final_status == SUCCESS`:
   - Load `templates/output-report.md`.
   - Substitute `{{run_id}}`, `{{template_filename}}`, `{{generated_utc}}`, `{{ruleset_hash8}}`,
     `{{attempts_total}}`, `{{final_status}}`, `{{changelog_table}}`, `{{fixed_template_path}}`.
   - Emit the rendered report.
   - Write the fixed template to `exports/{run_id}-fixed.json`.

2. If `final_status == EXHAUSTED` or `final_status == HALTED`:
   - Load `templates/output-status.md`.
   - Substitute `{{run_id}}`, `{{template_filename}}`, `{{generated_utc}}`, `{{final_status}}`,
     `{{reason}}`, `{{attempts_total}}`, `{{last_error_code}}`, `{{changelog_table}}`.
   - Emit the rendered status report.

3. In all cases: append one row to `exports/fix-run-log.csv` (create with header if missing):
   `run_id,generated_utc,template_filename,ruleset_hash8,attempts_total,final_status,last_error_code`

## Loop boundary

Steps 2–7 repeat until one of:
- Simulated deploy returns success.
- `attempt >= max_retries`.
- Halt-on-destructive-change fires.

## Failure handling

- Simulated ARM timeout: record `error_code = SimulatedTimeout`, mark attempt as failed, increment
  attempt counter, continue loop if under `max_retries`.
- Unclassified error: record `matched_rule_id = NONE`, no fix applied, increment attempt counter.
- If `rules.yaml` cannot be read: abort with `ABORT: rules.yaml unreadable`.

## Output contract

- The first H1 line of every fix report is exactly: `# ARM Template Fix Report`.
- The first H1 line of every status report is exactly: `# ARM Template Fix Status`.
- Section order for fix report: Header → Summary → Attempt Changelog → Fixed Template → Footer.
- Section order for status report: Header → Summary → Halt/Exhaust Reason → Attempt Changelog → Footer.
- Every emitted run appends exactly one row to `exports/fix-run-log.csv`.
