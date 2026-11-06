# Credit Cards — Mobile Product and Delivery Plan

Status: draft; documentation only. No Dart feature, local schema or migration is implemented here.

Canonical requirements: **CC-PRD-01**, `vesper-be/docs/credit-cards-prd.md` in the backend repository. This checkout is on a different filesystem from the backend, so the repository path is an identifier rather than a portable relative link. Backend and web plans use `docs/credit-cards-implementation.md` in their respective repositories.

## Product scope and accounting

Phase 1: private IDR cards, opening debt/credit, categorized purchases, posted fees/interest, linked refunds, partial/full payments from owned cash accounts, reversals, local history and recoverable sync. Statements/reminders follow in Phase 2; installments follow in Phase 3. No bank payment execution, automatic interest, FX, cash advances or shared cards.

Signed card balance B is the source for debt max(-B,0), non-liquid credit max(B,0), and available credit limit+B. Purchase lowers B and increases expense. Principal payment lowers bank balance and raises B without expense. Refund is positive expense linked to the purchase. Posted fees/interest are expense. Limit never contributes to cash or net worth. Opening debt creates no fake income/expense.

## Verified integration points

- `lib/features/accounts/models/account.dart`: creditCard display type already exists, but is not a complete backend card domain.
- `lib/app/finance_state.dart`: account classification includes metadata/keyword fallbacks; explicit server metadata must supersede heuristics safely.
- `lib/features/transactions/models/transaction.dart`: whole-Rupiah display model and optional signed ledger amount.
- `lib/features/sync/data/finance_repository.dart`: durable exact raw values, versions and financial sync orchestration.
- `lib/features/obligations/data/obligations_repository.dart`: BigInt monetary arithmetic and existing atomic command/recovery conventions.
- `lib/database/local_store.dart`: local persistence boundary.
- `lib/features/accounts/pages/account_detail_page.dart`, `lib/features/settings/pages/settings_page.dart`, `lib/features/transactions/widgets/add_transaction_modal.dart`: existing UX entry points.
- `lib/app/app.dart`: actual navigation/state uses Navigator and AppState/ChangeNotifier. Follow implementation patterns; do not introduce Riverpod/go_router or code generation as an unrelated migration.

Inspect actual repository/storage interfaces before choosing a local table design. Do not assume a generated Drift migration is required just because the target stack mentions Drift. Never edit generated files manually.

## Proposed feature boundary

Add `lib/features/credit_cards/` using the project's existing folder naming and repository/controller/page conventions. UI delegates to state/controller, repository, then local/remote data sources. Widgets never perform money mutations or HTTP requests directly.

Persist decimal/version strings at boundaries and use BigInt minor units for calculations. Phase 1 input accepts whole Rupiah only, explicitly rejecting fractional entry; received fractional card values must display exactly or block unsupported editing with a clear explanation. No double conversion or silent truncation. Reuse precision helpers where proven, not generic integer display code that drops cents.

## Work packages

### MOB-00 Contract and readiness

- Approve canonical PRD decisions and shared monetary fixtures.
- Add explicit card metadata parsing without relying on account names.
- Detect backend capability and complete initial sync before enabling card mutations.
- Extend the existing investment/obligation/bill unresolved-command gate: initial card delivery permits one unresolved cross-domain monetary command at a time.
- Preserve unsupported-server commands for retry; never downgrade to generic transactions.

### MOB-01 Local atomic projection

- Generate stable operation and all derived ledger UUIDs before persistence.
- Commit card operation, optimistic rows/balances and immutable outbox in one atomic local operation; rollback memory and disk on failure.
- Distinguish provisional projections from confirmed values and persist them across process restart.
- Do not enqueue payment legs separately or recalculate through floating point.
- A newly created offline card waits for authoritative creation reconciliation before further monetary writes in the initial release.

### MOB-02 Sync, replay and cancellation

- Push CREATE-only card command/cancellation envelopes through existing sync infrastructure.
- Preserve command UUID, expected versions and normalized payload through retries, timeouts, auth refresh and restart.
- Reconcile all affected authoritative records; acknowledgement alone does not remove projections/outbox.
- Support split pull pages, duplicate events, cursor persistence, replay from zero and versioned tombstones without double-applying money.
- Stale versions retain the original command and show review/retry/cancel, never silent version replacement.
- Cancellation reserves an unapplied command on the server; if already applied, reconcile it. It is not a local undo or a reversal of accepted payment.
- Scope local records and outbox by authenticated owner; logout/session expiry must not leak commands to another user or silently discard unresolved money.
- Connectivity triggers delivery but never proves reachability. Auth/network failure leaves durable financial work intact.

### MOB-03 UI and reporting

- Add card management and detail from accounts/settings, using current navigation conventions.
- Show Utang Terpakai, Sisa Limit, Saldo Kredit, pending sync and last confirmed state.
- Add purchase, posted-charge, linked-refund and payment forms with accessible labels and duplicate-submit protection.
- Payment preview includes cash source, principal, optional bank fee, projected cash/debt and explicit overpayment confirmation.
- State “Pencatatan ini tidak melakukan pembayaran ke bank.”
- Keep card capacity/positive credit out of liquid cash and emergency-fund totals; align dashboard/budget/net-worth classifications with the API.
- Block ordinary income, cash advances, card-to-card transfers and generic writes to protected card rows.
- Existing mapped obligations are migration-needed and remain locked; do not convert them based on names.

### MOB-04 Statements and installments later

Statement close is online-only until complete authoritative history is proven. Display immutable snapshot versus current debt separately. Use explicit billing timezone/calendar dates, not device timezone. Minimum due is issuer-provided, not an invented formula. Partial payment allocations and their reversal do not change balances twice.

Opt-in reminders must tolerate denied permission, stale offline data and delivery failure without changing money. Installments allocate the already-recognized purchase principal; they do not create another expense each month. Interest/admin remains separately posted expense.

## Required UX states

Initial loading, empty cards, offline saved, pending delivery, synchronizing, confirmed, rejected, conflict, unknown outcome, unsupported server, expired session, over-limit, positive card credit and permission denial. Preserve a support reference and recovery path. Never show a timeout as a definitive failed payment or invite a new UUID blindly.

Check small screens, large text, semantics/focus, screen readers and desktop keyboard behavior where supported. Financial status is never color-only. Card identity requests only optional issuer/last four, never PAN, CVV, PIN or expiry.

## Tests and release evidence

- Unit: exact amounts, signs, opening debt, refunds, overpayment, same-owner payment eligibility and explicit card classification.
- Repository: local commit failure restores memory/disk; restart persists outbox; duplicate pushes and lost acknowledgement reconcile once.
- Sync: split pull pages, response loss, stale version, changed-payload collision, cancellation/application race, revoked access, cursor replay and old-server rejection.
- Widget: forms, partial payment, fee, refund bounds, overpayment confirmation, pending/recovery states, accessibility and whole-IDR validation.
- Integration: create → purchase → offline payment → restart → sync → refund/reverse, validated against API golden fixtures.
- Regression: obligations, bills, investments, offline transfers, generic transaction edit/delete, account grouping and session restoration.

Golden fixture: purchase 500000, pay 300000, fee 25000 yields debt 225000, expense 525000 and a 300000 bank reduction. Add fractional .01 transport and maximum-range fixtures; no silent rounding is permitted.

Run `flutter analyze`, `flutter test`, and relevant integration tests for implementation. Only run code generation if actual dependencies/schema require it. Use isolated API test services and never erase real local financial data for test cleanup. No runtime validation is claimed for this documentation-only change.

## Rollout and rollback

Backend schema/contracts and compatible read support deploy first. Enable writes only after both frontend clients handle explicit card classification and protected history. Local persistence upgrades are additive and preserve pending commands. Disabling the feature must retain reads/recovery and must not delete outbox, accounts or history. Restore the normal app entry point after device integration tests as required by the existing development workflow.
