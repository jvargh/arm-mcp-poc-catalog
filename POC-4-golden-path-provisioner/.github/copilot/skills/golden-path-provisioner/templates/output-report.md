# Golden Path Provisioner — Deployment Plan

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}
**Workload:** {{workload}}
**Selected Template:** {{selected_template}}

## Naming + Tag Plan

### Resource Names

| Resource Type | Generated Name |
|---|---|
{{naming_table}}

### Tags

| Key | Value |
|---|---|
{{tag_table}}

## Template Parameter Summary

| Parameter | Value |
|---|---|
{{param_schema_summary}}

## Estimated Resource Count

**{{resource_count}}** resources to be created.

## Pre-Deploy Compliance Check

| Rule ID | Title | Status | Failing Resources |
|---|---|---|---:|
{{compliance_table}}

## What-If Plan Summary

{{what_if_summary}}

---

> ⚠ **WOULD DEPLOY (NOT EXECUTED in v1 — what-if only per locked decision)**
>
> To execute this plan in a future version, run with the `apply` verb and provide explicit confirmation.
> To cancel an in-progress deployment, use: `@golden-path-provisioner cancel <deployment_name>`.
