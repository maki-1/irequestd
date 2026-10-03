# Shared account lifecycle

`lib/accountLifecycle.js` is vendored from the canonical `irq-admin/server/lib/accountLifecycle.js`. Change the canonical source and synchronize it with `irq-admin/scripts/sync-account-lifecycle.cjs`; the main repository's cross-service tests verify identical source, allowing Windows/Unix line-ending differences.

Resident and staff access now requires a current active account and a matching `sessionVersion`. Deleted residents are denied. Login, protected requests, OTP verification, and password recovery enforce this policy. Password changes/resets revoke all sessions, including the current one. Earlier reset tokens cannot be reused. Reset tokens are never accepted as access tokens.

Before deploying, apply the main repository's `20261003000000_resident_account_lifecycle` and `20261003010000_account_session_revocation` migrations through its authoritative migration history. They add the account state/session columns and database triggers shared by both services. Do not run a separate mobile migration history against that same database. Generate the Prisma client here after installing dependencies:

```powershell
node node_modules/prisma/build/index.js generate
```

Both backends must be updated together. Configure `JWT_SECRET` on each; use the same value to accept each other's tokens. Legacy access tokens and approval links are intentionally rejected, so users must sign in again. The resident app's password-change screen now clears saved credentials and returns to login.

Full rollout instructions and test limitations are in the main repository's `docs/account-lifecycle.md`. Run its cross-service tests from `irq-admin/server`:

```powershell
$env:MOBILE_BACKEND_DIR = 'D:\irequestd\backend'
npm.cmd test
```

This change was validated locally. The shared database migration and production deployment were not performed.
