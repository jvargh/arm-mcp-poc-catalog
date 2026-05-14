---
mode: agent
agent: auto-rollback
---

Manually trigger a rollback to the last-known-good template for scope `${input:scope:prod}`.

Run the **auto-rollback** skill in `rollback` mode:

Strict requirements:
- Load `runbooks/<scope>.yaml` + `<scope>.values.yaml`. Extract `last_good_template_ref`,
  `max_rollback_attempts`, `subscription_id`, `resource_group`.
- Do NOT watch a new deployment. Go directly to rollback (SKILL.md Step 6).
- Before initiating: confirm with the user - "Manually triggering rollback to `<last_good_template_ref>`.
  Proceed? Reply YES to confirm."
- On YES: follow Step 6 exactly (bounded by `max_rollback_attempts`).
- v1: `create_template_deployment` is NOT invoked - mark simulated steps with `[SIMULATED]`.
- Run health gate after LKG redeployment to verify the rollback succeeded (R001 → R002 → R003 → R004).
- Emit timeline in canonical format. Halt on max attempts exhausted.
- Render via `templates/output-report.md` and write to `exports/rollback-<run_id>.md`.
