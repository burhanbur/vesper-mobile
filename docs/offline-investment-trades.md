# Offline investment BUY/SELL

## Local workflow

The investment action opens the decimal-string BUY/SELL form. An authenticated repository, complete user-scoped investment sync checkpoint, active visible owner-owned IDR investment/cash accounts and active IDR instrument are required. Pending account/type/instrument dependencies and any unresolved trade prevent submission. The form previews the same exact repository validation used at save; save validates again. Dividends are not enabled.

`FinanceRepository.createInvestmentTrade` prepares stable trade and linked ledger UUIDs once, then atomically commits the trade, exact cash ledger, cash balance and durable outbox to SQLite. The position is derived losslessly from the persisted complete history plus the optimistic trade; no independent position cache can drift from that history. Quantity/price use eight-decimal BigInt arithmetic; settlement rounds HALF_UP to two cash decimals. SELL cannot exceed holdings. Fees affect settlement, not moving-average cost. No double conversion occurs in the new form/command path.

A failed SQLite write rolls back memory and persistence together. Restart reloads the same envelope and IDs. Trades cannot be edited through generic mutations or direct online writes. Cash/account/type/instrument changes touching an unresolved trade are blocked, including moving an existing cash transaction away from the locked account.

## Delivery and reconciliation

The persisted push-only CREATE command matches the backend sync contract. Network failures keep it pending and retry the original envelope. Lost acknowledgement is recovered by backend idempotent replay with the original trade/ledger IDs. Pull data alone is never treated as acknowledgement.

An applied response changes the durable status to `acknowledged`, not complete. A fresh replay from cursor zero stages authoritative cash account, trade and linked ledger without overwriting optimistic rows page by page. Only a completed pull containing all three commits them and removes the command atomically. Interrupted or missing-row pulls retain the command; the next sync replays again. Dependency snapshots arriving during reconciliation are committed with it. This deliberately favors safety over availability.

Conflict/rejection retains the original command and optimistic state, exposes status/error in the form and blocks subsequent trades and dependent edits. Generic “mine/server” resolution is forbidden: a server-reviewed recovery is required because blindly undoing or rebasing a financial command could duplicate a lost-response trade. There is intentionally no unsafe discard button. Backend authorization remains authoritative; cached ownership is only a conservative offline guard.

## Scope and limits

No backend migrations or database resets are required. The backend UNC workspace was inspected for command fields and decimal constraints; no backend files are changed by this workflow.

The legacy asset valuation model is not an exact-position UI and is not populated with fabricated prices. The trade form shows exact local position/average cost and pending command state. Market valuation remains the separate account-scoped portfolio read feature. Only one unresolved investment command is allowed across the repository. Conflict/rejection recovery needs server investigation; it is not automatic rollback.

## Regression coverage

`test/unit/offline_investment_workflow_test.dart` covers BUY/SELL, stable delivery after lost response/restart, split and interrupted pulls, missing settlement rows, durable conflict/rejection, dependency protection, hidden/foreign accounts, incomplete history, oversell and SQLite commit failure. Existing history, position, settlement, command, coverage and widget suites remain part of the full validation task.
