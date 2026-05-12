# Cancel Deployment — Confirmation Required

> ⚠️  This action is IRREVERSIBLE while in effect.
> The deployment will be sent a cancellation signal. Resources already
> provisioned by this deployment are NOT rolled back automatically.

**Deployment name:** {{deployment_name}}
**Resource group:** {{resource_group}}
**Subscription:** {{subscription_id}}
**Current state:** {{current_state}}
**Started at (UTC):** {{start_time}}

---

To confirm cancellation, type exactly: `YES`
Any other response will abort with no action taken.

---

<!-- POST-CANCEL SECTION (rendered after user confirms and tool returns) -->

## Cancel Result

**Deployment name:** {{deployment_name}}
**Final state:** {{final_state}}
**Cancelled at (UTC):** {{cancelled_at}}
**Audit record:** `{{audit_file}}`

> Audit JSON-Lines record appended. No further action required.
> If the deployment state is still `Canceling`, ARM is processing the
> request — check back in 30–60 seconds with:
> `@incident-triage triage scope {{scope}}`
