# Cash-flow forecasting (WM-13)

Open Settings → Proyeksi Arus Kas. This is a personal IDR scenario from the local ledger, WM-10 schedules and WM-06 outstanding principal. It never creates payments, changes balances, marks a bill paid or writes to the financial sync queue. Only scenario assumptions are saved, atomically, per owner/device. There is no new API, backend entity or migration.

## Opening cash and scope

Choose active owned leaf CASH accounts in IDR. Investment, parent, other-owner and mapped loan accounts are ineligible. Current signed ledger balances form actual opening cash; overdrafts remain negative. This is the currently recorded balance, including already-recorded future-dated transactions and optimistic local mutations, not a reconstructed midnight bank balance.

When enabled, WM-08's currently backed own goal allocations reduce opening available cash once per account. Unbacked earmarks cannot subtract more than the positive balance backing them. These reserves stay fixed throughout the scenario; future goal deposits, withdrawals and automatic reserve releases are not modeled. Disable the reserve assumption to view a scenario against the full recorded cash balance.

The UI shows actual opening balances, reserved amounts, available opening cash, projected closing cash, conservative minima and per-account shortfalls. Positive pooled cash does not authorize or imply a transfer to cover a negative individual account.

## Dates and commitments

Choose 7, 30, 60 or 90 calendar days, including today, and a fixed UTC/WIB/WITA/WIT planning timezone without daylight saving. The horizon is [planning-day today, today + N days). Both first and last included dates are displayed. New defaults follow the owner's selected supported Indonesian timezone; an existing saved planning zone remains authoritative. Observation timestamps follow the display selection.

WM-10 recurrence reuses its original anchor, month-end clamping, inclusive end date and immutable schedule terms. Forecast generation extends the reusable bill occurrence reader to the chosen horizon, leaving its existing 60-day default unchanged. A bill's due date is interpreted at 00:00 in its own fixed timezone, then mapped to the planning calendar day. WM-06 installment/balloon dates without a linked bill use the planning timezone. This date mapping is an explicit scenario assumption, not a promised payment timestamp.

Active ordinary schedules produce one event per bill/date. Fixed bills are labelled scheduled commitments; estimated amounts are labelled assumptions and can be excluded. Valid PAID records and SKIPPED ordinary occurrences are not added again: their actual financial effects are already in opening balances. A payment recorded independently must be explicitly linked in WM-10; the forecast does not infer a match from equal dates or amounts.

Overdue carry-forward is optional and defaults on. It places all included unpaid historical commitments on the first planning day. Disable it to exclude past dates. Generation is capped at 10,000 entries and reports an error rather than silently truncating old arrears. Inactive/archived/deleted schedules do not produce new ordinary commitments. NEEDS_REVIEW or invalid payment evidence prevents a misleading forecast until reviewed through Tagihan & Jadwal.

## Loan principal and duplicate prevention

Use WM-06's explicit principal/date installments; if no installment schedule exists, an explicit due date creates one balloon for the remaining principal. Outstanding loans without dated terms appear as unmodeled warnings. Receivable inflows are excluded by default and become explicitly labelled assumptions only when enabled. No future interest/fee schedule is invented: loan events contain principal only and disclose that limitation.

For each loan:

1. Start with the original principal allocated to its installment dates (or the original principal at its balloon date).
2. Compute principal already repaid as original principal minus current outstanding principal.
3. Apply valid WM-10 repayment links to their explicitly selected dates first. Validate the date's remaining capacity and each repayment receipt's aggregate principal capacity.
4. Apply any remaining unallocated repaid principal to the oldest installment dates first.
5. Project only the principal still remaining at each included date.

This avoids both a second charge for an already-paid bill and a second subtraction for the same repayment under a FIFO approximation. For example, if three 100-IDR installments exist and a 100-IDR repayment is explicitly linked to the last date, only the first two dates remain in the forecast. A 50-IDR unallocated repayment instead leaves 50/100/100 by date.

The loan/date identity is the forecast identity, so multiple identical bill reminders for the same loan/date create one financial event. Contradictory reminder statuses, different payment accounts, overlapping receipt allocations or reversed/invalid linked evidence require review. Skipping a linked loan reminder suppresses that occurrence and shows a warning; it never forgives principal or changes outstanding debt. Archiving a reminder also does not remove the underlying WM-06 debt schedule.

An active linked bill supplies its cash account and timezone. Otherwise choose an explicit fallback payment/receipt account in scenario settings; the app never guesses one. A fallback can point to another eligible owned account outside the selected scenario: the loan then remains outside that cash scope. Invalid/deleted fallback accounts require updated assumptions. A missing account for an included dated unpaid loan withholds the forecast rather than implying a zero payment.

## Daily balances and shortfalls

All amounts use exact integer minor units, including negative balances and cents. Per account and for the pool:

`opening_day_1 = current_signed_cash − optional_backed_goal_reserves`

`low_day = opening_day − scheduled_outflows_day`

`closing_day = low_day + scheduled_inflows_day`

`opening_next_day = closing_day`

Outflows are assumed to happen before inflows on the same day. The first negative low and its amount expose a conservative potential shortfall even when end-of-day cash becomes positive. The UI distinguishes this from a forecast with no modeled shortfall. Daily timelines show opening, inflow, outflow, low and closing amounts; event lists show account, mapped due date, projected date, source, estimate and arrears labels.

## Completeness, assumptions and validation

Required owner-scoped transaction, bill and obligation snapshots must be complete, with bill coverage at the current sync cursor. Goal reserves also require complete goal-allocation coverage. In-progress sync, invalid account scope and ambiguous payment evidence withhold financial results. The same initial-history bootstrap as Bills/Goals is reused. A completed local feed does not prove all real-life obligations are recorded. Offline, pending/conflicting local writes, undated debts and missing future loan costs are disclosed.

Assumptions are editable offline, persist through restart and do not sync to another device. Stale-session dialogs cannot save the previous owner's scenario. Hidden-balance mode masks actual and projected amounts, including shortfall amounts. No automatic transfer, interest accrual, historical-spending extrapolation, unrecorded income, investment sale or financial advice is introduced.

Tests cover snapshot and encrypted indexed stores, inclusive/exclusive horizon bounds, fixed-zone mapping and month-end recurrence, paid/skipped records, estimated/overdue scenarios, actual negative balances, backed earmarks, per-account shortfalls, explicit later installment payments, FIFO partial repayments, duplicate reminders, unavailable/review states, due-date balloons, outside-scope mappings, atomic persistence, restart and stale sessions. Widget tests cover scenario forms, hidden balances, shortfall display, narrow layout and incomplete snapshots. Device/emulator runtime is not claimed.
