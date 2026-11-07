# Credit Cards — Simplified Mobile Delivery Plan

Status: mobile implementation exists in the working tree; release validation is incomplete. The plan below remains the approved scope, not a claim that every release gate has passed.

## Mobile verification — 2026-11-07

- Existing account detail already uses `!account.isCreditCard`; the reported unnecessary nullable access is absent. No additional edit was needed there.
- Changed the group-pocket header from Row to Wrap with spacing so the title and transparency badge can wrap. Added a 320px / 1.5x-text widget regression.
- Editor changes add braces in the transaction modal, BigInt addition for local balance deltas, and exact minor-unit reconciliation instead of dropping authoritative fractional cents. Added regressions for large balances, fractional-edit rollback and fractional authoritative reconciliation with a pending expense.
- Windows SDK invoked from WSL using `cmd.exe /c C:\\flutter\\bin\\flutter.bat`. Initial requested credit-card/offline-transfer/navigation run: **26 passed**. Subsequent run including group-pocket widgets: **28 passed**. Full Flutter suite: **674 passed**.
- Important validation limitation: the terminal still read older disk contents for the transaction modal, finance repository and credit-card test despite successful editor edits. Therefore the 28/674 results validate the on-disk state, including the responsive header regression, but **do not validate the additional editor-only arithmetic regressions or braces fix**. Two executed analyzer runs each reported the same single braces info at transaction modal line 602; no clean analyzer run is claimed. Editor diagnostics for the four affected Dart files reported no errors.
- Remaining release work: save only the affected editor buffers and rerun analyzer, targeted tests and the full suite. Account presentation still rejects fractional Rupiah through the existing integer adapter; exact fractional account display and an explanatory unsupported-edit state are not proven complete. Live backend metadata compatibility, authenticated end-to-end synchronization and the required isolated-service integration flow were not verified. Creation retains its existing metadata-capability guard; no database operation, migration or code generation was run.
- Unrelated working-tree changes were not reverted or intentionally reformatted.

Canonical requirements: **CC-PRD-01**, `vesper-be/docs/credit-cards-prd.md`. Backend/web companion plans are `docs/credit-cards-implementation.md` in their respective repositories. Repository paths are identifiers, not portable links across filesystems.

## Scope and accounting

Extend existing accounts, ordinary EXPENSE purchases and the existing atomic bank-to-card TRANSFER repayment. Add no credit-card module, commands, cancellation protocol, separate ledger or queue. Statements, installments, specialized refunds, issuer cash refunds, cash advances, reminders, imports and automated billing/interest are out of scope, not later phases.

- Account `is_credit_card` defaults false; explicit new cards stay compatible with CASH, without changing CASH/INVESTMENT enums. `credit_limit` is nullable and positive when supplied, transported as an exact decimal string; null means untracked.
- For signed balance B: debt = max(-B, 0), overpayment credit = max(B, 0). Tracked remaining contractual limit = L - debt, never L + B; negative remaining limit is valid.
- Purchase subtracts from B and counts as spending once. Repayment lowers bank balance and raises B atomically without income/expense. Manual fees/posted interest are ordinary EXPENSE; any bank fee is separate from transfer principal.
- Over-limit purchases and lower-limit edits are allowed. Overpayment shows nonblocking information only, no extra confirmation gate.
- Positive B is “Kelebihan Bayar”, consumed by subsequent ordinary expenses, never forfeited or automatically refunded by the issuer. Do not imply it increases issuer capacity.

## Minimal delivery tasks

### MOB-01 Existing state, local metadata and contracts

- Preserve current AppState/ChangeNotifier, Navigator, repository/local-store boundaries and existing local-first outbox. Do not migrate to Riverpod/go_router, add a card feature module or assume a new Drift/generated schema.
- Extend existing account model, local persistence, create/edit forms and sync serialization with compatible defaults and decimal strings. Review any necessary additive local migration against actual storage; preserve records, pending work and fields omitted by older clients.
- Use explicit metadata instead of name/icon heuristics. Restrict new cards to private, own, IDR leaf accounts; select same-owner bank sources and disallow group sharing. Backend online/sync authorization remains authoritative.
- Existing obligation-mapped accounts remain locked: no conversion, mapping changes, name-based reclassification or historical rewrites.
- Create with zero initial balance if no safe opening representation exists; defer opening-debt input rather than fake income/expense/transfer or introduce adjustments.
- Preserve exact balance/limit and opaque version strings. Use proven exact decimal or BigInt minor-unit helpers, never floating point. Whole-IDR input must explicitly reject fractions; display received fractional values exactly and block unsupported editing with explanation, never truncate.
- Request no PAN, CVV, PIN, expiry or bank credentials. Keep financial local data/outbox owner-scoped and out of logs; do not expose it to another session.

### MOB-02 Local-first purchases, transfers and sync

- Save through existing local account/transaction/transfer paths before network delivery. UI must not depend on API success; widgets delegate mutations to state/repositories.
- Atomically save both local payment legs, balances and existing outbox operation; roll back memory/disk on failure. Never enqueue the legs independently.
- Retain existing stable IDs, expected versions, replay/conflict rules, tombstones and cursor/pull reconciliation. Add no card-specific command envelope or cross-domain command gate.
- Preserve pending work through restart, network/auth failure and response loss. Connectivity only triggers sync, not proof of API reachability; do not treat timeout as definitive rejection or generate a duplicate payment blindly.
- Reconcile authoritative accounts/transactions across pull pages without applying acknowledged deltas twice. Extend account metadata push/pull; verify old/new server/client field preservation before enabling creation.

### MOB-03 Existing UI and reporting

- Extend account detail and current purchase/transfer forms using existing AppState/Navigator conventions. Show “Utang Terpakai”, “Sisa Limit”, untracked limit, “Kelebihan Bayar”, pending sync and confirmed state.
- Explain “Pencatatan ini tidak melakukan pembayaran ke bank.” Overpayment information must not block saving; limits and credits are not liquid cash.
- Preserve loading/empty/error/offline/pending/conflict/auth states, duplicate-submit protection, accessible labels, small-screen/large-text support and non-color-only status.
- Exclude limits and positive credits from liquid cash/emergency funds despite CASH classification. Count signed B in net worth once under inclusion settings and mapped-obligation rules; positive B is a non-liquid asset. Never duplicate liability or rewrite snapshots.
- Include purchases/manual charges once in budgets/spending, never repayment principal.

## Required tests and release gates

- Unit/widget: explicit identity, false defaults, null/positive limits, zero-balance creation, locked mapped accounts, group-sharing refusal, exact fractions/large versions, whole-IDR validation and no truncation.
- Shared fixture: B = -2000000.00 → pay 2500000.00 → B = 500000.00 → spend 200000.00 → B = 300000.00 → spend 400000.00 → B = -100000.00, with no extra confirmation or lost credit.
- Limit fixture: L = 1000000.00, debt = 1200000.00 gives remaining -200000.00. Lower-limit edits save without changing B; null stays untracked. Check liquidity exclusion, signed net worth once and spending/principal separation.
- Repository/sync: atomic local failure, restart, duplicate delivery, lost response, split pull pages, stale versions, auth failure and authoritative reconciliation without duplication. Regress existing transfers, transactions, obligations, account grouping and session restoration.
- Integration: create → purchase → offline repayment/overpayment → restart → sync → subsequent expense, using shared API fixtures and isolated services.

For future implementation run `flutter analyze`, `flutter test` and relevant integration tests; generate code only if actual schema/dependencies require it. Never erase real local financial data for tests. No runtime validation is claimed by this documentation update.

Backend additive migration/contracts and compatible web/mobile parsing precede creation enablement. If compatibility is unproven, keep creation disabled while retaining reads, local history and pending sync. Persistence upgrades and rollback must never delete accounts, financial records or outbox work.
