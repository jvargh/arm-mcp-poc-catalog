# Tag Patch Remediation Run

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}

## Templates Applied

| # | Rule ID | Tag Key | Target Resource ID | Tag Value Applied | Deployment Name | Status |
|---:|---|---|---|---|---|---|
{{remediation_table}}

## Notes

- Deployments use mode `Incremental` and were submitted via `create_template_deployment`.
- Poll `get_arm_template_deployment_status` with the deployment names above for progress.
- The `Microsoft.Resources/tags` resource type patches tags non-destructively — existing tags on the resource are preserved.
- To roll back, re-deploy your previous tag state via your IaC repository or Azure Policy.
