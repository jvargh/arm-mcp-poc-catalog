---
mode: agent
agent: change-freeze-enforcer
---

Run the **change-freeze-enforcer** skill with verb `status` for scope `${input:scope:prod}`.

Optional inputs:
- `deployment_name`: an existing ARM deployment name to check status for (triggers
  `get_arm_template_deployment_status`)

Strict requirements:
- Load freeze schedule from `runbooks/<scope>.yaml` + values file.
- Report current UTC time.
- List ALL `freeze_windows` from the runbook, sorted by `start_utc` ascending.
- For each window, label it:
  - `ACTIVE` — current_utc >= start_utc AND current_utc < end_utc
  - `UPCOMING` — current_utc < start_utc
  - `PAST` — current_utc >= end_utc
- If `deployment_name` was supplied, call `get_arm_template_deployment_status` and include
  the result in the status report.
- Do NOT call `create_template_deployment` under any circumstances.
- Do NOT write to `exports/` on `status` verb.
- Output a plain markdown status block. No template file required.
