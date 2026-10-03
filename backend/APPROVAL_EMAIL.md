# Approval email

`lib/emailDelivery.js`, `lib/approveLink.js`, `lib/purokNotify.js` and `lib/notificationContact.js` are maintained in the main admin repository and synchronized with `scripts/sync-approval-notifications.cjs` there.

Configure `EMAIL_USER`, `EMAIL_PASS` (Gmail app password), `PORTAL_URL=https://www.irq-dologon.com`, and the same `APPROVE_LINK_SECRET` used by the web API that verifies the links. Notifications go to all active leaders assigned to the resident's purok. Each email uses Notify Email and carries that leader's own session-versioned approval link.

The shared database must have the main repository's lifecycle/session migrations before these clients run. Regenerate the Prisma client and deploy both backends together. The admin site must serve the updated `/purok-approve` page. Local environment changes are not automatically applied to hosted services.

Gmail authentication was verified locally without sending mail. Free Render services block SMTP; such a deployment needs an HTTPS email provider or a service plan that permits SMTP. See the main repository's `docs/approval-email-fix.md` for test evidence and rollout steps.
