# IaC source tree (sample)

Referenced by `runbooks/prod.values.yaml` -> `iac_repo_path: ./iac`.

Used by:

- **R003 (NSG drift)** — NSG rule definitions are read from files here and compared
  against the live `securityRules` array returned by Azure Resource Graph.
- **R006 (IaC coverage)** — every resource ID / name declared here is treated as
  "covered"; live resources not represented here are flagged as orphaned.

## Conventions

Drop your real Bicep / ARM / Terraform under this directory. The agent scans
recursively. Suggested layout:

```
iac/
  network/
    nsg-<name>.bicep        # one NSG per file; rules in `securityRules` array
  workloads/
    <rg-name>/              # one folder per resource group
      *.bicep | *.json | *.tf
```

The two sample files below are placeholders so R003 and R006 have something to
parse on a first run; replace them with your real definitions.
