# Investment command support runbook

## Mobile support entry point

The BUY/SELL form offers **Info pemulihan** for an unresolved command. It displays read-only command/user/trade/ledger/account/instrument IDs, status and a SHA-256 fingerprint. No request, support message, file export, rollback or replacement trade is performed. Amounts, quantities, descriptions, server payloads, passwords and tokens are omitted. Share these identifiers only with the service operator through an established trusted support channel.

The legacy `command_sha256` support fingerprint includes the local queue `id` and original command fields. The additional `wire_command_sha256` used by the cancellation API excludes that local queue ID and hashes only `entity_type`, `entity_id`, `operation`, `client_version` and `payload`. Both use UTF-8 JSON with recursively sorted keys; decimal strings stay strings. Retry counters, errors and delivery status are excluded. A fixed Dart/TypeScript vector verifies the wire format. Neither hash is a signature or permission to alter money.

## Operator review

1. Verify the requesting person's identity and ownership through the existing support/authentication process. A screenshot or recovery reference alone is not authorization. Do not request access/refresh tokens, database encryption keys or the complete local database.
2. Use authorized read-only access to inspect the server's durable idempotency result for the exact original command, plus the trade, linked cash ledger and both affected account identities. Check authorization/activity/deletion state and investment chronology. Keep the review owner-scoped; do not expose another member's private data.
3. Distinguish an applied command with a lost response from a genuinely rejected command. If the command already applied, retry the original envelope through the existing sync mechanism; backend idempotency returns the original result. A full validated pull must reconcile authoritative trade/cash/account rows before the mobile command is removed.
4. If rejection is repairable through an already authorized server operation, explain and resolve that underlying condition, then advise retry of the **same** original envelope. Do not change IDs, timestamps, quantities, fees or cash accounts while retrying. Mobile confirmation preserves the original command and balance state.
5. For a never-applied command, the user confirms **Ajukan pembatalan**. This stores the intent locally and submits the original command through `POST /sync/investment-recoveries`. Inspect the durable request through existing authorized database/support access, scoped to its owner. Check both financial UUIDs including soft-deleted records, ownership and the wire fingerprint. A trusted operator with the current `sync.investment-recoveries.review` permission records a reason and `CANCELLED` or `DENIED` via `POST /sync/investment-recoveries/:tradeId/review`. The server repeats the checks under locks; a screenshot is never approval. Record the investigation evidence in the restricted support system. If records are inconsistent or already applied, keep the command and escalate rather than approve cancellation.
6. The user chooses **Periksa status pembatalan** or normal sync resumes it. Receipt identity/hash must match; an approved decision is reconciled through a complete feed before one local atomic commit releases the command and replaces cash with the authoritative balance. Interrupted replay or failed persistence retains the command. A denied review permits explicit unchanged retry. Do not issue ad hoc SQL balance edits, delete the outbox, reset a database, or create a replacement trade.

## Deployment and boundary

Cancellation is implemented by the contract in `investment-terminal-recovery-contract.md`. Deploy backend migration `20261016000000_add_investment_recovery` and explicitly grant the review permission to trusted operators before using it against a live service. Tests apply the migration only to fresh isolated PostgreSQL containers. No permission is granted automatically. Older/unmigrated services cannot approve this recovery and failures retain local financial data.

Local deployment is active as of 2026-10-17 on development `localhost:5432/vesper`. The existing administrator `bmafazi` has the dedicated `INVESTMENT_RECOVERY_REVIEWER` role with only the review permission. All financial tables matched their before-deployment checksums; no real command was reviewed or cancelled during activation. Other environments still require their own migration and explicit operator provisioning.

Applied-trade reversal remains outside the accepted scope. Device reinstall, clearing app data, browser storage reset and manual local rollback are not recovery procedures.
