---
mode: agent
agent: stuck-deployment-janitor
---

Run the **stuck-deployment-janitor** skill in `cancel` mode for scope `${input:scope:prod}`.

Strict requirements:
- Re-run or use in-context scan results to populate the stuck-deployment list.
- Present the stuck-deployment table to the user for selection.
- For **each selected deployment**, display `templates/output-cancel-confirmation.md`
  with literal substitution and **wait for explicit `yes` / `confirm`** per deployment.
- Do NOT call `cancel_arm_template_deployment` without receiving explicit per-deployment
  confirmation. Any reply other than `yes` or `confirm` (case-insensitive) = skip.
- Emit one `[AUDIT]` log line per cancel attempt regardless of outcome:
  `[AUDIT] CANCEL attempt — deployment: <name> rg: <rg> sub: <sub> duration: <h>h classification: <reason> outcome: <CONFIRMED|SKIPPED|ERROR> utc: <ISO8601>`
- Do NOT call `create_template_deployment` (not in allowlist).
  Post-cancel cleanup is a future enhancement — instruct the operator to follow manual
  cleanup steps documented in the README.
- Output a final summary table of actions taken. No other commentary.
