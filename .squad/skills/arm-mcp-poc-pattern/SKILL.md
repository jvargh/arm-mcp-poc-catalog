---
name: "arm-mcp-poc-pattern"
description: "Deterministic ARM MCP PoC folder scaffolding pattern — file layout, rules.yaml schema, template conventions, and agent.md structure"
domain: "azure-mcp-agents"
confidence: "high"
source: "observed from reliability-posture-scorecard reference implementation"
tools:
  - name: "validate_query"
    description: "Static-validates an ARG KQL query before execution"
    when: "Before every execute_query call, if validate_query is in the PoC tool allowlist"
  - name: "execute_query"
    description: "Runs an ARG KQL query against subscriptions"
    when: "After validate_query passes (or directly if validate_query not in allowlist)"
  - name: "create_template_deployment"
    description: "Deploys an ARM template"
    when: "Only on explicit user verb + confirm gate, only in DEPLOY PoCs"
---

## Context

Every ARM MCP PoC in this catalog follows an identical folder layout derived from `reliability-posture-scorecard/`. This skill encodes the pattern so builders produce parity-compliant PoCs without re-reading the reference each time.

## Patterns

### Folder Layout (non-negotiable)

```
<SLUG>/
  README.md
  .vscode/mcp.json                    # verbatim: {"servers":{"Azure Resource Manager MCP Server":{"type":"http","url":"https://mcp.management.azure.com"}}}
  .github/copilot/agents/<agent>.agent.md
  .github/copilot/skills/<skill-slug>/
    SKILL.md
    rules/rules.yaml
    templates/output-*.md
    remediation/*.json                 # DEPLOY PoCs only
    prompts/<verb>.prompt.md
  runbooks/prod.yaml
  runbooks/prod.values.yaml.example
  exports/.gitkeep
```

### agent.md Structure

```yaml
---
name: <slug>
description: <one-line>
tools:
  - <tool1>  # comment explaining usage
  - <tool2>
---
```

Then: `# <Title>`, `## Hard rules (do not deviate)` (numbered), `## Tool budget`, `## Skill` (link to SKILL.md).

### rules.yaml Schema

```yaml
version: 1
rules:
  - id: R001
    title: <what it checks>
    severity: critical|high|medium|low
    weight: <integer>
    category: <grouping>
    remediation_template: <filename.json or null>
    kql: |
      <literal ARG KQL — must return `id` and `resourceGroup` columns>
```

### Template Placeholder Convention

Only `{{placeholder}}` syntax. No Jinja, no Mustache partials.

### Runbook Two-File Pattern

- `runbooks/prod.yaml` — committed, contains `${key}` tokens
- `runbooks/prod.values.yaml` — gitignored, real values
- `runbooks/prod.values.yaml.example` — committed schema reference

### Run ID Formula

`<PREFIX>-{YYYYMMDD}-{scope}-{sha256(rules.yaml)[:8]}`

## Examples

- Reference: `reliability-posture-scorecard/` (12 rules, 3 verbs, 3 remediation templates)
- Run ID example: `RPS-20260512-prod-a1b2c3d4`
- Template substitution: `{{run_id}}`, `{{scope}}`, `{{generated_utc}}`

## Anti-Patterns

- NEVER generate KQL at runtime — always read from rules.yaml
- NEVER retry on validate_query failure — mark INVALID and continue
- NEVER deploy without explicit user verb AND confirmation gate
- NEVER add tools not in the source MD's "Tools used" line
- NEVER use `${...}` in templates (that's for runbook value substitution only)
- NEVER change sort orders, column headers, or section order from what SKILL.md pins
