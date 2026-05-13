# Golden Path Provisioner — Deployment Status

**Deployment:** {{deployment_name}}
**Resource Group:** {{resource_group}}
**Provisioning State:** {{provisioning_state}}
**Last Updated (UTC):** {{timestamp}}
**Duration:** {{duration}}

## Resource Statuses

| Resource | Type | State |
|---|---|---|
{{resource_statuses_table}}

---

*Polling every 10 seconds. Run `@golden-path-provisioner status {{deployment_name}}` to refresh manually.*
*If state is `Failed`, run `@golden-path-provisioner cancel {{deployment_name}}` to trigger rollback.*
