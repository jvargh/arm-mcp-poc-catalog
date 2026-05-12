---
mode: agent
agent: runbook-executor
---

Show the current run state for runbook `${input:runbook:prod}` (`status` verb).

Strict requirements:
- Read `state_file_path` declared in `runbooks/${input:runbook:prod}.yaml`.
- If the state file does not exist, emit: `No active or recent run found for runbook '${input:runbook:prod}'.`
- If the state file exists, parse it and render the following:
  1. `run_id`, `run_status`, `started_utc`, `completed_utc` (if present).
  2. Step-by-step summary table: step index, name, type, status.
  3. Current step (if IN_PROGRESS): step name + type.
  4. Evidence pack entry count.
- Render via `templates/output-report.md` (partial — omit notes section if IN_PROGRESS).
- Output ONLY the rendered status. No commentary.
