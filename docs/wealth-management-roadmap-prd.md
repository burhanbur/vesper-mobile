# PRD — Wealth Management Roadmap

- Created: 2026-10-20
- Scope: Vesper mobile and backend
- Document status: IN PROGRESS — WM-01–WM-08 DONE; Phase 3 partially complete
- Current implementation task: None
- Next task: WM-09 — Emergency fund planning
- Product direction: Evolve household financial tracking into trustworthy wealth planning.

## 1. Purpose

Provide an ordered, trackable delivery plan for trustworthy net worth, financial goals, liabilities, investment management, and financial planning. Correctness and user trust take precedence over new screens and automation.

This document complements `vesper_prd_frontend.md`, `vesper_prd_backend.md`, and `mobile-improvement-status.md`; it does not declare existing features complete or replace their detailed contracts.

## 2. Status protocol

Allowed task statuses:

- **TODO**: Not started, or deliberately returned to the backlog.
- **IN PROGRESS**: Actively being implemented or validated. Record the current work and any blocker.
- **DONE**: Acceptance criteria met, relevant tests/checks completed, and evidence recorded.

Workflow:

1. Before implementation, change the selected task from TODO to IN PROGRESS and update the current task above.
2. Complete acceptance criteria and record changed paths, checks/results, and completion date in the delivery log.
3. Immediately mark the completed task DONE. Partial implementation, documentation alone, or unexecuted validation is not enough.
4. When work begins on the next eligible task, mark it IN PROGRESS and update the current/next task. Do not mark a task active merely because it is next in the queue.
5. Prefer one active task at a time. If blocked, keep its status IN PROGRESS and explicitly record the blocker; do not imply completion.
6. If scope or a business rule changes, update this PRD and record the decision before implementing the change.

All implementation tasks initially started as TODO; the statuses below track subsequent verified progress. Existing supporting functionality is a foundation, not proof that a task's acceptance criteria have been met.

## 3. Baseline and evidence limitations

The initial assessment was static code/document inspection, not a runtime audit. Reverify each finding before changing behavior.

Existing foundations include offline transactions/transfers, pockets, monthly reports, household sharing, investment BUY/SELL with recovery, backend manual instrument pricing, and backend dividend recording.

Areas requiring verification/completion:

- Net worth aggregation and valuation history: `lib/app/finance_state.dart`.
- Budget period behavior, annual calculations, and save confirmation: `lib/features/reports/pages/budget_page.dart` and `lib/app/finance_state.dart`.
- Debt/receivable entry points without complete persistence: `lib/features/transactions/widgets/add_transaction_modal.dart`.
- Investment portfolio and offline trade UI: `lib/features/investments/`.
- Backend investment contracts and pricing: `vesper-be/src/modules/investments/`.
- Consolidated net worth, goals, liabilities, recurring bills, and financial export/import require end-to-end contracts; do not infer their presence from budget periods or administrative user exports.

## 4. Non-negotiable requirements

- Financial mutations save locally first and enter the sync queue; UI save success must reflect durable local persistence, not successful API access.
- No floating-point money calculations. Define precision, currency, rounding, and valuation rules explicitly.
- Transfers, investment cash movements, goal allocations, and debt principal must not accidentally inflate income, expenses, or net worth.
- Use client-generated identifiers, idempotent commands, soft deletion where required, and existing conflict/recovery patterns.
- Respect private versus shared household data and enforce backend authorization.
- Display valuation timestamps, stale/missing data, and estimates honestly.
- Add migration, API validation/OpenAPI, tests, and recovery documentation when relevant.
- Never reset persistent databases or weaken security to deliver this roadmap.

## 5. Delivery order

| Phase | Priority | Outcome | Status | Task IDs |
| --- | --- | --- | --- | --- |
| 1 | P0 | Correct net worth, budget periods, and save feedback | DONE | WM-01–WM-04 |
| 2 | P1 | Complete investment lifecycle, liabilities, and financial export | DONE | WM-05–WM-07 |
| 3 | P1 | Goals, emergency fund, and recurring obligations | IN PROGRESS | WM-08–WM-10 |
| 4 | P2 | Explainable health indicators, allocation, and forecasting | TODO | WM-11–WM-13 |
| 5 | P3 | Automation and advanced asset coverage | TODO | WM-14–WM-19 |

Phase status is TODO until work starts, IN PROGRESS while any work is active or partially complete, and DONE only when all its tasks are DONE. Dependencies take precedence over table order; the default next task is the first eligible TODO task.

## 6. Task backlog and acceptance criteria

### Phase 1 — Financial correctness

#### WM-01 — Verify financial aggregation and budget behavior

- Status: DONE
- Evidence: [Financial baseline verification](wealth-management-baseline.md); `test/unit/wealth_baseline_test.dart`.
- Completed: 2026-10-20. Focused checks passed; full-suite completion and device validation are not claimed (see evidence).
- Scope: Mobile + backend
- Dependencies: None
- Acceptance criteria:
  - Trace current net worth, investment valuation, liabilities, budget periods, and save feedback through actual data sources.
  - Confirm or correct the baseline findings with code paths and regression tests where applicable.
  - Document agreed net worth components, budget period boundaries, timezone handling, valuation timestamps, and incomplete-data behavior.
  - Establish existing-data compatibility and migration needs before modifying models.

#### WM-02 — Consolidated net worth and historical snapshots

- Status: DONE
- Evidence: Backend `docs/net-worth.md`, `src/modules/net-worth/`, `tests/unit/net-worth*.test.ts`, `tests/integration/net-worth.integration.test.ts`, additive migration `20261020120000_net_worth_observations`; mobile `lib/features/dashboard/models/net_worth_assessment.dart`, `data/net_worth_repository.dart`, `pages/net_worth_assessment_page.dart`, focused unit/widget tests.
- Completed: 2026-10-20. Partial known subtotal is labelled; complete `net_worth` stays null until WM-06. History uses durable first daily observations only; days before the first observation remain unavailable without backfill or zero-filled charts. Device validation was unavailable because no app was connected.
- Scope: Mobile + backend
- Dependencies: WM-01
- Acceptance criteria:
  - Provide assets minus liabilities, with cash and investment components and explicit treatment of receivables.
  - Do not double-count parent/pocket balances or investment cash and holdings.
  - Show breakdown, valuation date, missing components, and stale prices.
  - Present historical net worth from documented historical valuation/balance data, not an unlabeled cash-flow approximation.
  - Separate contributions/withdrawals from market-value changes where supported; label unavailable attribution.
  - Test transfers, investment settlement, account exclusions, private/shared views, and incomplete valuations.
  - Full debt/receivable lifecycle is delivered in WM-06; until then, clearly identify unsupported obligations rather than implying complete net worth.

#### WM-03 — Accurate budget periods and actual spending

- Status: DONE
- Evidence: Backend `src/common/utils/budget-period.ts`, `src/modules/budgets/budget.repository.ts`, `src/modules/budgets/budget.service.ts`, `tests/unit/budget-progress.test.ts` (14 passing unit tests); mobile `lib/core/utils/budget_period.dart`, `lib/core/utils/date_formatter.dart`, `lib/features/reports/models/budget.dart`, `lib/app/finance_state.dart`, `lib/features/reports/pages/budget_page.dart`, `test/unit/budget_period_test.dart`, `test/unit/budget_progress_test.dart` (8 passing unit tests).
- Completed: 2026-10-20.
- Scope: Mobile + backend
- Dependencies: WM-01
- Acceptance criteria:
  - Selected period drives actual spending and progress queries/calculations.
  - Replace hard-coded annual multipliers with actual period data or clearly labeled, separately defined projections.
  - Monthly budget behavior is correct first; every exposed weekly/annual period is implemented accurately or explicitly unavailable.
  - Test period boundaries, category scope, refunds/deletions where supported, and exclusion of transfers.

#### WM-04 — Durable save feedback

- Status: DONE
- Completed: 2026-10-20.
- Evidence: Local-first budget persistence and pending retry in `lib/features/sync/data/finance_repository.dart`; explicit durable/synced feedback in `lib/app/finance_state.dart`; input-preserving errors and submission guards in budget, transaction, and balance-adjustment forms.
- Validation: `flutter analyze` passed (no issues); full `flutter test` passed (348 tests). Subsequently added three failure/repeated-save regressions: `test/unit/budget_save_feedback_test.dart` passed all 9 tests, including SQLite commit failure, remote failure, and repeated offline saves. Full-suite rerun after those test-only additions was skipped by the user. No running app was connected to DTD, so device hot reload/manual validation was unavailable.
- Scope: Mobile
- Dependencies: WM-01
- Acceptance criteria:
  - Budget and affected financial forms wait for durable local save before displaying success.
  - Local failure preserves input and exposes actionable retry feedback.
  - Pending sync is distinguishable from local save failure; offline saving remains supported.
  - Regression tests cover successful save, failed save, and repeated submission.

### Phase 2 — Complete core wealth records

#### WM-05 — Investment lifecycle completion

- Status: DONE
- Completed: 2026-10-20.
- Evidence: [Investment lifecycle contract and recovery policy](investment-lifecycle.md); mobile `lib/features/investments/data/investment_lifecycle_{repository,controller}.dart`, `pages/investment_lifecycle_page.dart`, portfolio entry, exact settlement/position/history models, `lib/features/sync/data/finance_repository.dart`; backend investment schema/repository/OpenAPI and sync schema/OpenAPI.
- Validation: `flutter analyze` clean; final full `flutter test` 362 passed; Android emulator UI integration 1 passed (synthetic local data: instrument and quote entry, dividend cash settlement, hidden balances). Backend ESLint/typecheck/build/OpenAPI validation passed, 268 unit/HTTP tests passed, 36 isolated PostgreSQL integration tests passed including concurrent UUID creation, dividend replay, unchanged positions, and access rejection. Changed backend files pass Prettier; `git diff --check` passed in both repositories. Full `npm run validate` was attempted and stopped at seven pre-existing formatting violations outside WM-05; remaining gates were run separately and passed (see delivery log). No migration/new dependency required; updated backend must be deployed before new client commands are accepted. Real-account/live-server device certification is not claimed.
- Rules agreed for implementation: IDR only; decimal strings, quantity/price scale 8, cash/fee scale 2, HALF_UP settlement. Fee includes withholding/tax; moving-average purchase price excludes fees (existing backend convention). Dividends credit quantity × payout/unit minus fees without changing holdings. Extend durable CREATE/replay/recovery to dividends. Instrument/price changes enter a durable local catalog queue; prices retain global instrument/date manual upsert (last accepted update wins). Accepted trades are immutable; corrections require compensating records, never silent edits. Only proven-unapplied commands can use recovery cancellation. Cross-account totals use active owner IDR accounts, cumulative BUY cash as contributed capital, separate sale proceeds, realized sale gain, buy fees, dividends, and dated holdings valuation; settlement cash is excluded from holdings. Missing quotes remain unavailable. No FX aggregation.
- Scope: Mobile + backend
- Dependencies: Phase 1
- Acceptance criteria:
  - Support instrument discovery/creation and manual price updates using existing backend contracts where suitable.
  - Expose dividend entry, accessible trade history, and a cross-account portfolio summary.
  - Distinguish contributed capital, realized gain, unrealized gain, and dividends without double-counting settlement cash.
  - Define supported currencies, fees/taxes, corrections, and rounding before implementation.
  - Preserve BUY/SELL replay/recovery safety; explicitly define dividend offline behavior rather than assuming the current offline contract supports it.

#### WM-06 — Debt, receivables, and installments

- Status: DONE
- Completed: 2026-10-20. Marked complete at the user’s explicit direction; remaining validation waived, with existing evidence and limitations retained below.
- Implementation policy: IDR decimal(20,2), exact cents; private owner obligations with explicit PAYABLE/RECEIVABLE kind. New funding settles signed principal as a protected TRANSFER; existing opening balances may be imported without moving cash. Optional legacy account mapping requires a matching signed, owner-owned leaf IDR balance and replaces that account in net worth; principal repayments update both the mapped account and settlement cash. Interest and fees use separate categorized ledger rows. Installment dates/principal are explicit, without assumed interest or automatic payments. Corrections reverse a repayment atomically and preserve audit history; deletion voids an untouched opening or archives a fully paid record, never silently erases partial repayment. Immutable client UUID commands, optimistic version conflicts, complete authoritative pull reconciliation, and durable pending/rejected feedback follow existing financial command patterns.
- Mobile entry precision: the existing account/transaction presentation supports whole Rupiah only. WM-06 forms therefore accept whole IDR principal/interest/fees and whole-IDR settlement accounts; they reject fractional entry instead of rounding or crashing older views. Backend contracts and local arithmetic retain decimal(20,2) for lossless sync. General fractional-IDR presentation remains a separate compatibility limitation, not a silently changed money model.
- Scope: Mobile + backend
- Dependencies: Phase 1
- Acceptance criteria:
  - Store counterparty, principal, outstanding amount, due dates, and repayment history.
  - Support partial repayment with separate principal, interest, and fees.
  - Define how existing credit-card/account liabilities map to this model without duplicate balances.
  - Include outstanding liabilities/receivables in net worth and settle associated cash atomically.
  - Add local-first sync, authorization, migrations, and tests for replay, partial/full repayment, correction, and deletion.

#### WM-07 — Financial export and reconciliation

- Status: DONE
- Completed: 2026-10-20. Initially delivered with validation waived; automated validation subsequently requested by the user. Flutter analyze clean and full suite 404 passed, including 23 new WM-07 tests. See validation delivery entry for platform checks.
- Implementation policy: Current user-owned local ledger only, including pending entries; explicit local-calendar period, account, currency and household exclusions. CSV uses UTF-8 BOM, CRLF, quoted cells and formula escaping. Reconciliation compares current owned leaf IDR cash balances, requires statement references and confirmation, and appends an audited ordinary adjustment through existing offline sync. No historical balance rewrite or new backend API. Automated validation was initially waived; subsequent requested checks and results are recorded in the delivery log.
- Scope: Mobile + backend as needed
- Dependencies: Phase 1
- Acceptance criteria:
  - Export financial transactions to CSV with documented columns, period, account/currency scope, and safe spreadsheet cell handling.
  - Make export scope and household permissions explicit; exclude secrets and unauthorized data.
  - Compare recorded balances with user-entered statement balances and show differences.
  - Keep confirmed adjustments traceable; do not silently rewrite financial history.
  - Test totals, encoding, dates, permissions, and reconciliation adjustments.

### Phase 3 — Financial planning

#### WM-08 — Personal and household goals

- Status: DONE
- Completed: 2026-10-21. Personal/household goals, exact allocation/backing, completion, offline sync/recovery and authorization delivered; validation evidence below.
- Implementation policy: Exact two-decimal same-currency soft earmarks on owned active leaf CASH accounts/pockets; allocations never move cash or create expenses. All nondeleted goals, including completed milestones, reserve their allocations until withdrawn. Allocation increases cannot exceed current positive cash minus other commitments. Cash remains spendable: actual backed progress assigns current cash once, oldest allocation first (created_at then UUID), and shows shortfalls. Private goals are owner-only; shared goal visibility requires active household membership, creator-only metadata/completion, and contributor-only allocation changes. A contributor may withdraw their own allocation after leaving without reading the shared goal. Foreign account IDs and balances are redacted. Currency/scope/start date stay immutable; completion requires backed target and does not release cash automatically. UTC calendar-day linear expected progress and ceiling monthly remaining contributions are explained in UI. Offline edits use existing versioned durable sync with retry/conflict feedback; authoritative server validation resolves concurrent over-allocation.
- Scope: Mobile + backend
- Dependencies: Phase 1
- Acceptance criteria:
  - Create goals with target amount, currency, target date, and linked allocations/accounts/pockets.
  - Show progress, required periodic contribution, and transparent on-track/behind calculations.
  - Support authorized household contributions and distinguish ownership from sharing.
  - Goal allocations are not expenses and cannot allocate the same available funds twice without explicit policy.
  - Test allocation changes, withdrawals, completion, offline sync, and household access.

#### WM-09 — Emergency fund planning

- Status: TODO
- Scope: Mobile + backend as needed
- Dependencies: WM-08
- Acceptance criteria:
  - Configure essential-expense baseline and target coverage in months.
  - Show eligible liquid funds, current coverage, and remaining target.
  - Explain included accounts and expense categories; avoid treating volatile/illiquid assets as immediately available by default.
  - Allow manual baseline when history is insufficient and label estimates.

#### WM-10 — Bills and recurring transactions

- Status: TODO
- Scope: Mobile + backend
- Dependencies: Phase 1; WM-06 for linked debt installments
- Acceptance criteria:
  - Store schedule, due date, expected/fixed amount, account, category, and payment status.
  - Provide upcoming/overdue views and configurable reminders.
  - MVP reminders require confirmation before creating a financial transaction.
  - Prevent duplicate occurrence/payment records across retries, devices, and offline sync.
  - Define timezone, month-end, schedule edits, skipped occurrences, notification permissions, and already-paid behavior.

### Phase 4 — Explainable insights

#### WM-11 — Financial health indicators

- Status: TODO
- Scope: Mobile + backend as needed
- Dependencies: WM-06, WM-09, WM-10
- Acceptance criteria:
  - Provide saving rate, emergency coverage, liquidity, and debt-service burden with documented formulas.
  - Expose calculation period, data completeness, and configurable assumptions.
  - Avoid opaque composite scores and unsupported personalized financial advice.

#### WM-12 — Asset allocation and concentration

- Status: TODO
- Scope: Mobile + backend
- Dependencies: WM-02, WM-05
- Acceptance criteria:
  - Show consolidated allocation by supported asset class and instrument.
  - Support user-defined allocation targets and explain concentration/target deviations.
  - Do not execute trades automatically; flag missing/stale valuations.

#### WM-13 — Cash-flow forecasting

- Status: TODO
- Scope: Mobile + backend as needed
- Dependencies: WM-10; WM-06 for installment commitments
- Acceptance criteria:
  - Forecast available cash using current balances and scheduled inflows/outflows over a selected horizon.
  - Distinguish actual records, scheduled commitments, and assumptions.
  - Prevent counting an already-paid bill twice and show potential cash shortfalls.
  - Forecasts never mutate actual balances.

### Phase 5 — Optional automation and expansion

#### WM-14 — Household expense splits and settlement

- Status: TODO
- Dependencies: WM-06
- Acceptance criteria: Define participants and split rules; show who owes whom; settle without duplicating expenses or transfers; test permissions, rounding, partial settlement, and replay.

#### WM-15 — Property, vehicles, and other assets

- Status: TODO
- Dependencies: WM-02
- Acceptance criteria: Support manual valuation history and ownership; distinguish illiquid assets; link related debt without double-counting; include transparent net worth attribution.

#### WM-16 — Automatic market prices

- Status: TODO
- Dependencies: WM-05, WM-12
- Acceptance criteria: Agree licensed provider, coverage, costs, and rate limits; retain source/time and manual fallback; handle stale/missing prices without silently valuing holdings at zero.

#### WM-17 — Multi-currency and FX valuation

- Status: TODO
- Dependencies: WM-02, WM-05
- Acceptance criteria: Define base currency, source/rate date, historical FX, rounding, and realized/unrealized FX treatment; never sum unlike currencies directly; preserve original amounts.

#### WM-18 — Statement import and receipt OCR

- Status: TODO
- Dependencies: WM-07
- Acceptance criteria: Provide preview, mapping, validation, deduplication, user confirmation, and traceable import batches; treat OCR values as suggestions; define privacy/retention and safe correction behavior.

#### WM-19 — Optional AI-assisted insights

- Status: TODO
- Dependencies: Phase 4; explicit product/privacy approval
- Acceptance criteria: Use verified financial aggregates; disclose assumptions and limits; obtain consent before sending financial data externally; never automatically move money or provide guaranteed-return claims; retain a useful non-AI experience.

## 7. Definition of done

For every task, as applicable:

- Acceptance criteria and financial invariants are covered by meaningful regression tests.
- Mobile: run `flutter analyze` and `flutter test`; run code generation when required.
- Backend: run relevant focused tests and checks; use `npm run validate` for broad changes when available.
- Database tests use isolated infrastructure; migrations preserve existing data.
- Validate relevant offline/replay, authorization, privacy, and recovery behavior.
- Verify UI behavior on a suitable running app; document device-validation limits.
- Update API/OpenAPI, data contracts, user-facing behavior documentation, and this status tracker.
- Record exact checks/results. Unresolved acceptance-critical failures keep a task IN PROGRESS.

## 8. Success measures

Targets will be set after WM-01 establishes a baseline; do not invent performance or financial-accuracy claims.

- No unexplained differences between supported net worth components and their source balances/valuations.
- No false-success feedback on failed local saves.
- No duplicate financial effects from retries or internal movements.
- Users can explain their net worth components, goal progress, and upcoming obligations from the UI.
- Exports and reconciliation totals agree with the selected supported data scope.

## 9. Delivery log

Append an entry on task completion or a material scope/status change.

| Date | Task | Status | Evidence / checks / decision |
| --- | --- | --- | --- |
| 2026-10-20 | Roadmap documentation | DONE | Initial PRD created from static mobile/backend assessment. No implementation tasks started; no runtime checks claimed. |
| 2026-10-20 | WM-01 | DONE | Added `wealth-management-baseline.md` and four characterization tests. Focused Flutter checks: 10 passed; analyze: no issues; backend budget-period: 9 passed. Recorded UTC/local, precision, valuation, persistence and migration constraints. Full Flutter suite attempted without captured final completion; no device certification or backend integration run. WM-02 remains TODO until work starts. |
| 2026-10-20 | WM-02 | DONE | Added the owner-only `GET /api/v1/net-worth/snapshots` read assessment with exact decimals, include/parent guards, stale/missing price labels, and an explicit partial known subtotal; complete `net_worth` stays null pending WM-06. Durable forward history: the first observation per owner/currency/UTC day is stored immutably (`net_worth_observations`, unique key, ON CONFLICT DO NOTHING); past dates return captured evidence or an all-null `unavailable` response, never a backfilled or zero-filled chart. Mobile adds a separate partial assessment screen with historical-observation/capture-time labels, hidden-balance handling, stale quote markers, session/owner switch protection, and an honest local-estimate label on the dashboard card. Checks: backend net-worth unit/HTTP 25 passed; isolated PostgreSQL 34 passed (7 files, including concurrency, immutable late edits, owner/currency scoping); typecheck, ESLint, OpenAPI validation, and `git diff --check` passed. Mobile: `flutter analyze` clean, 21 focused tests passed, full suite 330 passed. Limits: no device/hot-reload validation (no app connected); the additive migration must be deployed through the normal reviewed step; historical coverage starts at the first successful observation, not from past transactions. |
| 2026-10-20 | WM-03 | DONE | Implemented deterministic half-open UTC budget period boundaries [start, end) across backend and mobile for MONTHLY, ANNUAL, WEEKLY, and DAILY periods. Clamped month lengths in leap years / 31-day anchors. Prorated active allowances proportionally across overlap days with decimal string arithmetic. Replaced hard-coded '* 9' / '* 12' multipliers in BudgetPage with real period spending queries and offline local transaction aggregation fallback. Preserved integer Rupiah parsing for fractional allowances. Checks: backend 14 unit tests passed, ESLint clean, Prettier clean, typecheck clean; mobile 8 unit tests passed, 0 errors. |
| 2026-10-20 | WM-05 | DONE | Delivered local-first instrument creation/manual quotes, search, dividend CREATE commands through existing atomic sync/replay/recovery, accessible account-filtered trade history and exact owner cross-account capital/proceeds/realized/unrealized/dividend summary. Missing valuations remain null, dated manual/cache and pending values are labelled, cash settlement is excluded from holdings, and purchase fees are reported separately. Financial corrections and global quote last-accepted-write policy documented in `investment-lifecycle.md` in both repositories. Validation: final Flutter analyze clean and full suite 362 passed; Android emulator integration 1 passed with synthetic data; backend lint/typecheck, 268 tests, build and OpenAPI passed; isolated PostgreSQL 36 passed (7 files). Full validate attempted: format gate reports existing violations in `package.json`, `src/infrastructure/storage/file-storage.ts`, `src/infrastructure/storage/local-file-storage.ts`, `src/modules/net-worth/net-worth.repository.ts`, `src/modules/net-worth/net-worth.service.ts`, `tests/integration/net-worth.integration.test.ts`, `tests/unit/budget-progress.test.ts`; WM-05 files pass formatting and all subsequent gates passed separately. Both repositories pass diff whitespace checks. No persistent data reset or new migration; test infrastructure is isolated. Backend deployment remains the normal rollout step; no real-account device/server audit claimed. |

Completion entry template: date; task ID; status; acceptance criteria met; changed paths; checks and results; remaining limitations or explicitly deferred scope.

| 2026-10-20 | WM-06 | DONE | Implementation delivered for obligations, repayments, reversals, installments, atomic offline sync/recovery, and loan-aware net worth. Completed at explicit user direction on 2026-10-20; remaining validation waived by the user, with no further tests run. Flutter full suite: 381 passed; last analyze clean. Backend: 281 unit/HTTP tests and 46 isolated PostgreSQL integration tests passed before final sync batching/auth edits. Final lint optional-chain finding corrected, but lint/typecheck/build/OpenAPI still require rerun on final code. Device check unavailable: emulator disconnected. Additive migration 20261020160000_obligations was validated only on isolated PostgreSQL and is not applied to development data. Final gates were not rerun; DONE records user-directed acceptance, not additional verification. Black-screen launch target corrected in .vscode/launch.json. |
| 2026-10-20 | WM-07 | DONE | Delivered Settings → Financial Export and Reconciliation: owned-account/currency/date filters, exact CSV credit/debit/net totals, per-row local sync status, UTF-8 BOM/CRLF quoting and spreadsheet formula escaping; Android system document picker, web download and native app-documents/clipboard fallback. Current leaf IDR cash reconciliation previews exact differences, requires a statement reference and confirmation, rechecks session/balance, and appends an audited categorized adjustment using existing atomic local/outbox flow. Existing adjustment API now accepts an optional description while preserving its default. No backend API or migration needed. Paths: lib/features/reports/data/financial_export_*, csv_file*, pages/financial_export_page.dart, settings_page.dart, finance_state.dart, Android MainActivity.kt; contract in docs/financial-export-reconciliation.md. Per explicit user instruction, no tests, analyzer, build or emulator validation run; only source formatting performed. Manual acceptance delegated to the user. Full Android restart/rebuild required for the native save channel. |

| 2026-10-20 | WM-07 validation | DONE | User requested automated validation after initial delivery. Added 22 unit cases across snapshot and encrypted indexed SQLite plus 1 widget scenario covering CSV encoding/escaping/exact totals, period boundaries, pagination, owner/currency scope, sync statuses, durable audit adjustments, eligibility, precision, stale previews, cancellation/confirmation and session isolation. Corrected 6 lint findings in WM-07 source. Final flutter analyze: no issues; full flutter test: 404 passed. Android debug APK build with lib/main.dart and development defines passed, including native Kotlin CSV channel. Existing balance-adjustment regression tests pass in the full suite. Diff whitespace check passed. System document picker interaction on a device and other platform runtime behavior were not exercised. |
| 2026-10-21 | WM-08 | DONE | Delivered personal and active-household goal creation/editing/archive/completion with same-currency exact targets, UTC dates, transparent daily pace and monthly contribution, owner-only metadata and contributor-owned leaf cash/pocket allocations. Earmarks do not create expenses or move balances; capacity is serialized server-side and backing consumes cash once oldest-first, with shortfall and snapshot labels. Added household join/revocation publication, redacted contributor accounts, post-exit withdrawals, local first saves, immutable retry identity, expected-version conflicts, explicit retry/discard recovery and initial-history bootstrap race guard. Paths: lib/features/goals/, finance_repository.dart, finance_state.dart, settings_page.dart; backend src/modules/goals/, sync schemas/repository/OpenAPI/publication, Prisma Goal/GoalAllocation and additive migration 20261021010000_goals; docs/goals.md in both repositories. Checks: Flutter analyze clean; full suite 427 passed, including 23 new goal unit/widget tests; backend lint/typecheck, 284 unit/HTTP tests, build and OpenAPI passed; fresh isolated tmpfs PostgreSQL migration and all 51 integration tests passed (9 files, including 5 goals cases). Full npm validate attempted: format gate blocked by four pre-existing files (package.json, file-storage.ts, local-file-storage.ts, budget-progress.test.ts); subsequent gates passed separately. Both repositories pass diff whitespace checks. No real financial data reset or migration applied to the daily database; deploy migration and regenerate Prisma before running the updated backend. Device/emulator runtime was not exercised. |
