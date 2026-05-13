---
mode: agent
agent: golden-path-provisioner
---

Run the **golden-path-provisioner** skill in `cancel` mode for scope `${input:scope:prod}`.

Deployment name: `${input:deployment_name}`
Resource group: `${input:resource_group}`

Strict requirements:
- **Before calling `cancel_arm_template_deployment`, display the following confirmation prompt
  verbatim and wait for the user to type exactly `confirm`:**

  ```
  ⚠ CANCEL REQUEST
  Deployment : <deployment_name>
  Resource Group: <resource_group>
  Current State : <provisioningState from status check>

  Type "confirm" to proceed with cancellation. Any other input aborts.
  ```

- If the user does not respond with exactly `confirm`, abort with:
  `CANCEL ABORTED — no confirmation received`.
- On `confirm`, call `cancel_arm_template_deployment`.
- **Always** append one JSON audit line to `exports/cancel-audit.jsonl` regardless of outcome:
  ```json
  {"event":"cancel_attempt","deployment_name":"<name>","resource_group":"<rg>","confirmed":true,"outcome":"<Canceled|error>","utc":"<ISO8601>"}
  ```
- Emit: `CANCEL SUBMITTED — monitor with status verb`. No further commentary.
