# Terminal investment recovery contract proposal

Status: **draft, not an implemented API or an approved financial rule**.

The existing application supports retry of the original immutable command and
read-only support references. It must retain an unresolved command until a
durable server result and complete authoritative reconciliation establish its
outcome. This proposal makes the remaining product decision concrete.

## Proposed scope: cancel a command that never applied

Example: a pending BUY was permanently rejected because its instrument cannot
be used. The server has neither the original trade UUID nor its linked cash
ledger UUID, including soft-deleted records. After an authorized operator
review, the server may permanently reserve both identities as cancelled. A
delayed or repeated delivery must then be rejected without moving money.

Cancellation must refuse an already-applied or partially persisted command.
An applied BUY/SELL requires a separate reversal use case. This proposal does
not invent reversal quantity, cost basis, price, fee, timestamp or chronology
rules, and does not delete an applied trade or directly edit account balances.

## Proposed API and durable decision

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
3. Authorized operator review: recheck the original owner/accounts and absence
   of both trade and linked ledger under the same database locks used by normal
   sync processing. Record reviewer identity, reason, decision and time in the
   same transaction as durable cancellation reservations. Repeated identical
   approval returns the original receipt. No API call or support screenshot can
   substitute for server authorization.

The persistence migration must add a durable recovery decision and uniqueness
for both reserved IDs. Approval and command execution must share sync and
command locks. Investment, generic client-UUID cash transactions and offline
transfers must all reject a reserved ledger UUID. Soft deletion must not free
an idempotency identity. No development database migration or seed execution is
part of implementing or testing this proposal.

## Mobile reconciliation

Requesting review preserves the original outbox, optimistic trade, cash ledger,
balance, cursor and investment coverage. Network failures leave the request
retryable. Approval alone never adds an inverse cash delta locally.

The mobile client must durably validate an approved receipt against current
user, trade UUID, linked ledger UUID and the exact original command fingerprint.
It then replays a complete authoritative owner-scoped feed. Only one atomic
local commit may install authoritative cash/account and history state, remove
the cancelled optimistic trade and linked cash row, and release its command.
Other unresolved commands and reconciliation staging remain intact. Missing
authoritative rows, an interrupted replay or a failed local commit retain the
command and block unsafe replacement trades. Restart resumes reconciliation.

## Required verification

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

## Decision still needed

Choose whether the remaining feature is limited to **cancellation of never-applied
commands** as proposed above, or must also **reverse already-applied trades**.
The latter needs explicit rules for historical price, fees, cost basis and later
BUY/SELL chronology before implementation. Project `AGENTS.md` requires that
business rules and data models are not silently changed.
