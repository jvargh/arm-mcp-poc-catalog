# ARM Template Fix Status

**Run ID:** {{run_id}}
**Template:** {{template_filename}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Status

| Metric | Value |
|---|---|
| Final status | {{final_status}} |
| Reason | {{reason}} |
| Attempts used | {{attempts_total}} |
| Max retries | {{max_retries}} |
| Last error code | {{last_error_code}} |

## Attempt Changelog

| Attempt | Error Code | Rule Matched | Fix Applied | Outcome |
|---:|---|---|---|---|
{{changelog_table}}

## Next Steps

{{next_steps_block}}

---
*Investigate the last error code above and edit the template manually if the fix loop could not resolve it. Then re-run `@arm-template-fixer fix` with the updated template.*
