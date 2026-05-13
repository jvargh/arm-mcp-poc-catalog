# ⚠️ Cancel Confirmation Required

You are about to **cancel** an ARM template deployment. This action is **irreversible**.

| Field | Value |
|---|---|
| **Deployment name** | {{deployment_name}} |
| **Resource group** | {{resource_group}} |
| **Subscription** | {{subscription_id}} |
| **Running for** | {{duration_hours}} hours |
| **Classification** | {{classification}} |
| **Detail** | {{detail}} |

> Cancelling this deployment will set its `provisioningState` to `Canceled`.
> Any resources partially provisioned will remain in their current state.
> Post-cancel cleanup must be performed manually (see README § Out of scope).

**Type `yes` to confirm cancellation, or anything else to skip this deployment.**
