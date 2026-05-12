# Resize Remediation Run

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}

## Deployments

| # | Resource | RG | Current SKU | Target SKU | Deployment Name | Status |
|---:|---|---|---|---|---|---|
{{remediation_table}}

## Notes

- Deployments use mode `Incremental` and were submitted via `create_template_deployment`.
- Poll `get_arm_template_deployment_status` with the deployment names above for progress.
- Template used: `remediation/resize-vm.json` — patches `properties.hardwareProfile.vmSize` only.
- To roll back, re-deploy with the original SKU value or restore from your IaC repository.
