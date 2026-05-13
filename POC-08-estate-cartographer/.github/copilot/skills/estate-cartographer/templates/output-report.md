# Azure Estate Map

**Run ID:** {{run_id}}
**Scope:** {{scope}}
**Generated (UTC):** {{generated_utc}}
**Ruleset hash:** {{ruleset_hash8}}

## Summary

| Metric | Value |
|---|---|
| Subscriptions in scope | {{subscriptions_total}} |
| Resource groups | {{rg_total}} |
| Resources | {{resources_total}} |
| Relationship edges | {{relationships_total}} |
| High-risk resources | {{high_risk_total}} |

## Estate Diagram

> Rendered by VS Code Mermaid preview. If the diagram is blank, open this file in VS Code
> and install the Markdown Preview Mermaid Support extension.

```mermaid
{{mermaid_diagram}}
```

## High-Risk Overlay

| Subscription | Resource Group | Resource Name | Type | Risk Reason |
|---|---|---|---|---|
{{high_risk_table}}

## Relationships

| Type | Source ID | Target ID |
|---|---|---|
{{relationships_table}}

---
*Run `@estate-cartographer drilldown <resource-id>` for relationship detail on a specific resource.*
