# ARM Template Fix Report

**Run ID:** {{run_id}}
**Template:** {{template_filename}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Final status | {{final_status}} |
| Attempts used | {{attempts_total}} |
| Max retries | {{max_retries}} |
| Last error code | {{last_error_code}} |
| Fixed template | {{fixed_template_path}} |

## Attempt Changelog

| Attempt | Error Code | Rule Matched | Fix Applied | Outcome |
|---:|---|---|---|---|
{{changelog_table}}

## Diff Log

{{diff_log_block}}

## Fixed Template

The corrected template has been written to `{{fixed_template_path}}`.

To review the final template before deploying:
```
cat {{fixed_template_path}}
```

To deploy (after live validation in VS Code with ARM MCP server attached):
```
@arm-template-fixer fix template={{fixed_template_path}} scope=prod
```

---
*Run `@arm-template-fixer status` to check a deployment in progress. Run `@arm-template-fixer cancel` to cancel a hanging deployment (requires user confirmation).*
