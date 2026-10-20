# WM-01 — Financial baseline verification

Date: 2026-10-20. Scope: static trace plus focused executable characterization. No production behavior or persistence schema changed.

## Verified sources and findings

| Area | Actual source / behavior | Consequence / follow-up |
| --- | --- | --- |
| Cash | `lib/app/finance_state.dart`: `accounts` maps repository account balances through `rupiah`; `totalLiquidCash` sums included cash/bank/wallet accounts. | Account inclusion controls aggregation, not visibility. The sum itself does not remove parents; existing account mutation guards prevent including a parent with children. WM-02 must also validate legacy/imported hierarchy state. |
| Investment total | `investments` returns an empty list; `totalInvestmentValue` therefore sums included investment account balances. | Dashboard total is not consolidated market valuation. Do not assume an investment account balance represents market value or separately held settlement cash without tracing its ledger semantics. |
| Liabilities | `totalDebt` subtracts absolute included credit-card/loan-classified balances. Classification uses raw labels/type metadata/name heuristics. | This is not a complete debt register. WM-06 must define signed balances, credit balances, counterparty liabilities, and migration without duplication. |
| Net worth history | `monthNetWorthTrend` and `monthGrowthPercentage` reconstruct from current total and monthly income minus expense. | This is a cash-flow-derived estimate, not historical balance/valuation evidence. WM-02 must replace or clearly relabel it. |
| Portfolio reads | `lib/features/investments/data/portfolio_repository.dart`: separate `investment_read_cache` scoped by account and holdings/date, with `fetched_at`; missing/corrupt cache returns null. | Portfolio data is not wired into dashboard investment aggregation. Holdings contain quantity/cost; dated snapshots contain nullable market values. Fetch time is not price date. |
| Backend valuation | `vesper-be/src/modules/investments/investment.repository.ts`: snapshot uses positions through the requested date, stored snapshot when present, otherwise latest manual price on/before that date. | Snapshot response exposes snapshot date, but not the selected underlying price date. A freshness policy cannot be honestly inferred from fetch time alone. Missing values remain null, not zero. |
| Budget read | `AppState.refresh` requests current UTC period per budget type and stores `progress:<budgetId>`. `budgets` uses cached allowance/total, falling back to current amount/zero when absent. | Cache is not period-scoped; missing progress may look like zero spending. Selected UI period does not drive the request. WM-03 needs period-scoped results and unavailable/stale states. |
| Budget presentation | `lib/features/reports/pages/budget_page.dart`: annual allocation multiplies by 12; spending by 9, both summary and item rows. Month/year controls change labels only. | Annual figures are not actual selected-year totals. Existing widget tests only verify navigation labels, not financial period correctness. |
| Budget save | `setCategoryBudget` chooses first budget for category, calls `writeOnline`, then refreshes. Modal calls the Future without awaiting, closes, and displays success. | There is no budget local-first outbox save. Offline save fails; delayed failure can follow success feedback. WM-04 requires persistence/sync design, not only adding await. Selection must distinguish schedules in WM-03. |
| Money precision | `rupiah` accepts integer-valued decimal strings and rejects nonzero fractional Rupiah. Backend budget proration can produce fractional amounts with Decimal arithmetic. | Define exact presentation of fractional allowance before wiring period results; never silently round, parse as double, or reinterpret stored values. |

## Budget backend contract to preserve

Evidence: `vesper-be/src/common/utils/budget-period.ts`, `src/modules/budgets/budget.repository.ts`, `budget.service.ts`.

- All ranges use UTC and half-open boundaries `[start, end)`.
- MONTHLY `YYYY-MM` identifies the anchor day's month, not necessarily a calendar month starting on day 1; clamp short months.
- ANNUAL `YYYY` starts at anchor month/day. WEEKLY aligns a containing date to anchor weekday. DAILY covers one UTC day.
- Mobile month summaries use device-local calendar boundaries: they are not interchangeable with these UTC budget ranges.
- Spending matches budget category/type and currency, active owner accounts, non-deleted transactions, and excludes transfer legs.
- Allowance is prorated over effective amount segments; each segment rounds HALF_UP to two decimal places before summing.
- Budget creation/amendment amount takes effect on current UTC date; historical queries must not apply the latest amount retroactively.
- Category/anchor/period schedule changes are rejected to preserve history; create a new schedule instead.

## Implementation rules and compatibility decisions

These are roadmap constraints, not claims that future models have been designed or approved.

1. Preserve existing UTC anchored budget contracts. Expose actual start/end in UI; do not silently migrate anchors to calendar month or device timezone.
2. Net worth must use included owned assets minus supported liabilities with no pocket/parent or settlement double count. Report unsupported debt/receivables until WM-06.
3. Preserve exact decimal storage and explicit unknown valuation. Keep valuation date, price date, and fetch time distinct; freshness threshold and FX rules require explicit definition in WM-02.
4. Never present cash-flow reconstruction as verified historical net worth. Historical opening balances and adjustments must be accounted for before claiming reconstruction is complete.
5. Private and household totals are separate scopes; sharing does not transfer ownership. No mixed-currency summation without an explicit FX contract.
6. Local save success means durable local commit. A pending sync is not a save failure. Budget currently violates this target and is not corrected by this audit.

## Migration assessment

No migration is needed for WM-01 and none was executed.

- WM-02: first evaluate existing account balances, transaction coverage/opening adjustments, portfolio snapshots and read caches. Additional historical balance/valuation provenance may need new storage/API fields. Existing cache must never be treated as a complete audited history. No approved new schema yet.
- WM-03: period-scoped cache can be additive, but legacy `progress:<id>` must not be reused for arbitrary historical selections. Preserve existing budget/amount history and schedules. Fractional allowance presentation needs an explicit contract.
- WM-04: budgets currently use online writes, not syncable local commands. Inspect backend sync allowlists, versions/tombstones and idempotency before introducing local budget entities. Any required schema/API/outbox migration belongs to that task.
- WM-06: introduce explicit liability/receivable mapping without reinterpreting or double-subtracting legacy account balances. Requires separate model/contract review.
- No destructive cleanup, database reset, dependency upgrade, or financial data rewrite is justified by this audit.

## Verification evidence

- Focused Flutter run: `wealth_baseline_test.dart`, `account_total_and_parent_balance_test.dart`, `reports_and_budget_tabs_test.dart`: **10 tests passed**.
- New characterization tests cover current account-based net worth, single-key budget cache behavior, offline budget rejection without local writes, and fractional Rupiah rejection. They document limitations, not desired future behavior; update them as WM-02–WM-04 replace those contracts.
- `flutter analyze`: **passed, no issues found**.
- Backend `npx vitest run tests/unit/budget-period.test.ts`: **9 tests passed**, covering anchors, month-end clamping, UTC ranges and invalid labels.
- Full `flutter test` was attempted; captured output showed progress beyond 220 tests but no final completion summary was available. **Full-suite success is not claimed.** Focused baseline tests establish this audit's executable evidence.
- No physical-device UI certification or PostgreSQL integration suite executed; no backend code changed. DTD discovery/connect succeeded but no running application was available, so hot reload could not be performed. Changes are documentation and test code only.

## Follow-up

WM-01 verification is complete. WM-02 is now DONE: owner-scoped partial assessments exist, complete `net_worth` remains null pending WM-06, and history is limited to durable first daily observations without backfill. Existing product defects in budget periods and save feedback remain assigned to WM-03 and WM-04; this baseline does not claim they are fixed.
