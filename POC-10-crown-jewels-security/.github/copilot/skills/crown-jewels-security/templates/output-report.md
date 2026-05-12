# Crown Jewels Security Posture

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Rules total | {{rules_total}} |
| Rules evaluated | {{rules_evaluated}} |
| Rules skipped | {{rules_skipped}} |
| Rules invalid | {{rules_invalid}} |
| Resources scored | {{resources_scored}} |

## Top Crown Jewels (Descending by Severity Score)

| Rank | Resource | Resource Group | Severity Score | Matched Rules |
|---:|---|---|---:|---|
{{top_crown_jewels_table}}

## Rule Findings

| Rule ID | Title | Severity | Weight | Matched Resources |
|---|---|---|---:|---:|
{{rule_findings_table}}

## Skipped / Invalid Rules

{{skipped_rules_block}}

---
*Run `@crown-jewels-security drilldown <resource_id>` for per-resource detail.*
*Export written to `exports/` in configured format (sarif or csv).*
