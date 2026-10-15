# Investment command support runbook

## Mobile support entry point

The BUY/SELL form offers **Info pemulihan** for an unresolved command. It displays read-only command/user/trade/ledger/account/instrument IDs, status and a SHA-256 fingerprint. No request, support message, file export, rollback or replacement trade is performed. Amounts, quantities, descriptions, server payloads, passwords and tokens are omitted. Share these identifiers only with the service operator through an established trusted support channel.

The fingerprint uses UTF-8 JSON with recursively sorted object keys and the original `id`, `entity_type`, `entity_id`, `operation`, `client_version`, and `payload` fields. Retry counters, error messages and current delivery status are excluded. Decimal strings remain strings. The fingerprint helps compare an original envelope; it is not a signature or permission to alter money.

## Operator review

1. Verify the requesting person's identity and ownership through the existing support/authentication process. A screenshot or recovery reference alone is not authorization. Do not request access/refresh tokens, database encryption keys or the complete local database.
2. Use authorized read-only access to inspect the server's durable idempotency result for the exact original command, plus the trade, linked cash ledger and both affected account identities. Check authorization/activity/deletion state and investment chronology. Keep the review owner-scoped; do not expose another member's private data.
3. Distinguish an applied command with a lost response from a genuinely rejected command. If the command already applied, retry the original envelope through the existing sync mechanism; backend idempotency returns the original result. A full validated pull must reconcile authoritative trade/cash/account rows before the mobile command is removed.
4. If rejection is repairable through an already authorized server operation, explain and resolve that underlying condition, then advise retry of the **same** original envelope. Do not change IDs, timestamps, quantities, fees or cash accounts while retrying. Mobile confirmation preserves the original command and balance state.
5. If permanently invalid, or if server records are inconsistent, keep the command durable and escalate to the service maintainer. Record the evidence and review decision in the operator's existing restricted support system. Do not issue ad hoc SQL balance edits, mark a command applied without settlement, delete the outbox, reset a database, or create a replacement trade.

## Boundary requiring additional backend implementation

There is currently no server-authorized terminal cancellation/reversal contract. A safe future operation needs a durable reviewed decision, current owner authorization, a lock shared with normal command processing, a transaction covering the original idempotency result and settlement state, and a response that can be replayed idempotently. It must refuse cancellation of an applied trade; reversal is a separate financial operation requiring explicit business rules. Mobile would then consume a validated complete authoritative reconciliation before releasing the original command.

The support-reference UI and this investigation/retry workflow are implemented. Terminal cancellation/reversal remains unavailable and must not be described as complete. Device reinstall, clearing app data, browser storage reset and manual local rollback are not recovery procedures.
