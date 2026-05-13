# Remediation Run

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}

## Templates Applied

| # | Rule ID | Template | Target RG | Deployment Name | Status |
|---:|---|---|---|---|---|
{{remediation_table}}

## Notes

- Deployments use mode `Incremental` and were submitted via `create_template_deployment`.
- Poll `get_arm_template_deployment_status` with the deployment names above for progress.
- To roll back, re-deploy the previous template version from your IaC repository.
