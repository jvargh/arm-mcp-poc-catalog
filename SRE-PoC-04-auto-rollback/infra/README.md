# Infrastructure (PoC)

Minimal ARM template used by the auto-rollback orchestrator as the deployment
under watch.

| File | Role |
|---|---|
| `main.json` | NEW template (the deployment being watched). |
| `main.parameters.json` | Parameters for the NEW deployment. |
| `lkg.parameters.json` | Last-known-good parameters (paired with the LKG template ref in `runbooks/prod.yaml`). |

The LKG template itself is resolved from `last_good_template_ref` in
`runbooks/prod.yaml` (default: `git:refs/heads/main:infra/main.json`), so the
last-known-good template is whatever `infra/main.json` was at the tip of `main`
when the rollback runs.

This is a PoC. The template provisions a single Standard storage account and is
intentionally trivial; swap in your real workload template before using this
runbook for anything other than demos.
