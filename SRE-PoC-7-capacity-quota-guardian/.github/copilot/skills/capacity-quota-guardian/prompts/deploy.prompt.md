---
mode: agent
agent: capacity-quota-guardian
---

Gate and (what-if) deploy template `${input:template}` for scope `${input:scope:prod}`.

Strict requirements:
1. **Run the full quota check first** (same as `check` verb). Do NOT skip Step 1–4 of SKILL.md.
2. If any quota row has `usage_pct > headroom_threshold_pct`:
   - Render `templates/output-quota-check.md` showing all breached rows and alternate region suggestions.
   - Set `{{deploy_gate_decision}}` to `DEPLOY BLOCKED`.
   - **Stop here. Do not proceed to deployment.**
3. If all rows pass:
   - **MUST NOT call `create_template_deployment` in v1.** This is a what-if run only.
   - Output a `WOULD DEPLOY (NOT EXECUTED — v1 what-if)` block showing:
     - Template path, subscriptions, deployment mode (Incremental), and a note that no ARM call was made.
   - Render `templates/output-quota-check.md` with `{{deploy_gate_decision}}` = `QUOTA PASS — simulated`.
4. Output ONLY the rendered template output and the would-deploy block (if applicable). No commentary.
