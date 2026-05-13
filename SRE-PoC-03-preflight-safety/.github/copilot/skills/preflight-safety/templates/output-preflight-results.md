# Pre-flight Deployment Safety Check

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Timeout budget:** {{preflight_timeout_seconds}}s

## Preflight Summary

| Metric | Value |
|---|---|
| Checks passed | {{checks_pass}} |
| Checks failed | {{checks_fail}} |
| Checks skipped / invalid | {{checks_skip}} |
| Decision | **{{decision}}** |

## Preflight Results

| Rule ID | Title | Severity | Status | Failing Resources | Remediation Hint |
|---|---|---|---|---:|---|
{{preflight_results_table}}

---
*Run `@preflight-safety deploy scope <scope> template <file> params <file>` to proceed if all checks pass.*
*Run `@preflight-safety status` to check last deployment status.*
