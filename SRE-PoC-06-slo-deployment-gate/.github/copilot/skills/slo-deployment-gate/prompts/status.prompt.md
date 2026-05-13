---
mode: agent
agent: slo-deployment-gate
---

Run the **slo-deployment-gate** skill in `status` mode for scope `${input:scope:prod}` and service `${input:service}`.

Strict requirements:
- Look for the most recent `exports/gate-<run_id>*.md` file matching this scope + service.
- If found: print its contents verbatim. No re-evaluation.
- If not found: emit `STATUS=NO_PRIOR_GATE_RUN SCOPE=<scope> SERVICE=<service>`.
- Do NOT call any MCP tools for this mode (no ARG queries, no deployments).
- Output ONLY the gate result file contents (or the NO_PRIOR_GATE_RUN message). No commentary.
