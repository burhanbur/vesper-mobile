# Terminal investment recovery contract

Status: **implemented for cancellation of never-applied commands**, the scope accepted on 2026-10-16. Reversal of applied trades is excluded. Verification and rollout status are tracked in `mobile-improvement-status.md`.

The application retains an unresolved command until a durable server decision
and complete authoritative reconciliation establish its outcome. The original
immutable retry and read-only support references remain available.

## Scope: cancel a command that never applied

Example: a pending BUY was permanently rejected because its instrument cannot
be used. The server has neither the original trade UUID nor its linked cash
ledger UUID, including soft-deleted records. After an authorized operator
review, the server may permanently reserve both identities as cancelled. A
delayed or repeated delivery must then be rejected without moving money.

Cancellation must refuse an already-applied or partially persisted command.
An applied BUY/SELL requires a separate reversal use case. This proposal does
not invent reversal quantity, cost basis, price, fee, timestamp or chronology
rules, and does not delete an applied trade or directly edit account balances.

## API and durable decision

All paths use `/api/v1`. Existing sync push result statuses remain compatible.

1. Owner `POST /sync/investment-recoveries`: submit the original sync command
   and registered device ID. Validate the existing command schema, owner and
   original account identities. Persist a review request keyed by trade UUID,
   with linked ledger UUID and a canonical wire-command SHA-256 fingerprint.
   Repeat requests with identical identity/content return the same record;
   mismatched content returns 409. A mobile queue ID remains a support reference
   and must not alter the hash of the actual wire command.
2. Owner `GET /sync/investment-recoveries/:tradeId`: return an owner-scoped
   receipt containing trade/ledger identity, fingerprint and decision. Return
   404 for another owner's request. Never expose another person's portfolio.
3. Operator `POST /sync/investment-recoveries/:tradeId/review` with `decision`
   (`CANCELLED` or `DENIED`) and a nonempty `reason`. The current permission
   `sync.investment-recoveries.review` is required; token role claims do not
   authorize review. Recheck the original owner/accounts and absence
   of both trade and linked ledger under the same database locks used by normal
   sync processing. Record reviewer identity, reason, decision and time in the
   same transaction as durable cancellation reservations. Repeated identical
   approval returns the original receipt. No API call or support screenshot can
   substitute for server authorization.

The additive migration `20261016000000_add_investment_recovery` adds durable
requests/decisions and a permanently reserved UUID table. Approval and command
execution share the existing global sync writer lock. Database triggers also
protect investment, generic cash, transfer and direct/import inserts against
either reserved ID; deleting/updating reservations is refused. Soft deletion
does not free an identity. Review publishes both current account snapshots and
explicit trade/ledger tombstones atomically. A denied review reserves nothing.

The migration registers the review permission without granting it to any role.
Deployment must apply the migration and explicitly grant that permission to
trusted operators using the existing authorization management. Code generation
does not deploy a database. Implementation tests deploy only into fresh isolated
PostgreSQL containers. Local activation on 2026-10-17 applied this migration to
development `localhost:5432/vesper` and explicitly granted the dedicated review
role to the existing administrator `bmafazi`. Before/after checksums confirm all
11 financial tables were preserved; no seed or real cancellation was executed.

## Mobile reconciliation

Requesting review preserves the original outbox, optimistic trade, cash ledger,
balance, cursor and investment coverage. Network failures leave the request
retryable. Approval alone never adds an inverse cash delta locally.

The user confirms **Ajukan pembatalan** in the investment form. Intent is saved
locally before transport; normal synchronization and **Periksa status pembatalan**
resume the request/poll. An approved decision resets replay to zero. Review in
progress blocks unchanged retry; a denied review permits explicit original retry.
A definitive request conflict (for example an already-applied trade) retains
money/command rows and permits explicit original retry. Lost responses remain
durable, without automatically retrying financial execution.

The mobile client must durably validate an approved receipt against current
user, trade UUID, linked ledger UUID and the exact original command fingerprint.
It then replays a complete authoritative owner-scoped feed. Only one atomic
local commit may install authoritative cash/account and history state, remove
the cancelled optimistic trade and linked cash row, and release its command.
Other unresolved commands and reconciliation staging remain intact. Missing
authoritative rows, an interrupted replay or a failed local commit retain the
command and block unsafe replacement trades. Restart resumes reconciliation.

## Verification coverage

- Cancel versus normal execution in both lock orders: exactly one terminal
  outcome; a cancelled command can never subsequently apply.
- Applied trade, existing/tombstoned ledger, cross-owner identity, mismatched
  fingerprint and reused cash UUID all refuse cancellation or replay safely.
- Review authorization is checked against current server state. Lost approval
  responses and repeat requests return the original durable decision.
- Isolated PostgreSQL migration/concurrency tests; runtime Zod/OpenAPI contracts;
  owner/operator HTTP authorization tests.
- Mobile lost response, interrupted replay, failed commit, restart, exact money,
  unchanged unrelated outbox and authoritative balance/history coverage tests.

## Excluded scope

Reversal of already-applied trades requires separate explicit rules for historical
price, fees, cost basis and later BUY/SELL chronology. This feature never deletes
or reverses an applied trade and never edits balances to compensate for one.
