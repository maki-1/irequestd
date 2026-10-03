# Request status contract

This backend shares the request/read and workflow rules from `D:\irqadmin\irq-admin\server\lib\requestStatus.js` and `requestWorkflow.js`. Keep the vendored copies identical using the main repository's `scripts/sync-request-status.cjs` script; the cross-service regression suite checks parity.

`GET /api/requests/summary` returns the same flat contract as the resident web backend:

```json
{"total":0,"pending":0,"processing":0,"printing":0,"ready":0,"claimed":0,"rejected":0,"readyDocuments":[]}
```

`ready` is the number of actual, unclaimed completed documents in `readyDocuments`, read from one database snapshot. The dashboard uses this list directly. `/completed` returns these ready documents; `/claimed` returns handed-over documents. Historical duplicate releases count once per request. Legacy request strings alone never create a pickup item.

Canonical statuses: **Pending**, **Processing**, **Printing**, **Ready for Pickup**, **Claimed**, **Rejected**. Approval/payment are separate attributes. On a completed-document row, `claimStatus: "pending"` means Ready for Pickup.

Admin status updates use the shared transactional workflow. Finalizing Printing creates a release, timestamp, and claim code atomically. Handover updates the release and associated request together in the main backend. These rules also apply to kiosk-origin requests.

Full definitions, legacy handling, tests, and rollout notes are in `D:\irqadmin\irq-admin\docs\request-status-contract.md`. This change has not been deployed and needs no additional migration. Deploy the two backends and client updates together; the separate account-lifecycle migration requirements in `ACCOUNT_LIFECYCLE.md` still apply.
