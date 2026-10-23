# Dashboard insights

The dashboard places a compact **Sekilas** card after quick actions and before
accounts. Its three rows open Bills, Reports and monthly Budgets. Existing
colors, spacing, rounded cards and text styles are reused. The monthly surplus
label is now **Surplus/Defisit Bulan Ini**.

All calculations read the current owner's local repository. No financial rows,
balances, outbox entries or backend models are changed by reading an insight.
Money and percentage arithmetic use integer minor units (`BigInt`). The card
states its personal IDR scope, distinguishes incomplete data from zero and
labels results provisional when the local outbox is not empty. Hidden-balance
mode masks amounts and derived percentages, including accessible text.

## Spending comparison

Requires a completed local transaction snapshot and investment history, with no
active sync. Read all relevant transaction pages across the current and previous
months in the selected display timezone. Include EXPENSE rows on active owned IDR accounts, excluding deleted
rows, transfers and investment ledger links (including legacy linked trades).
Expense magnitudes follow the existing reporting convention.

Compare day 1 through today's day number at the same selected-zone time of day in both
months. If the previous month has fewer days, use the shared completed calendar
days in both months; March 31 versus February uses days 1–28 (29 in a leap year).
The exact calendar ranges appear in the card, without a UTC suffix; the display
timezone is selected in Settings. Query bounds are converted to UTC instants.
A missing or zero
prior baseline never becomes an invented percentage. Percentage differences are
truncated to two decimals; a nonzero change below 0.01% is labelled explicitly.

## Upcoming bills

Requires owner/cursor-bound completed bill coverage and the transaction snapshot.
Reuse the existing bill occurrence generator and payment evidence validation.
Include today through today + 6 in each schedule's fixed timezone. Exclude
overdue dates, income schedules, receivables, paid and skipped occurrences.
Estimated amounts are included and labelled. These are recorded schedule
commitments, not a bank-balance forecast or a complete list of real-life debts.

Duplicate loan reminders for the same obligation/date count once when terms and
status agree. Inconsistent duplicates, invalid account/payment evidence and
missing linked debt history withhold the displayed total for review.

Normal refresh now activates bill history before syncing, so opening the Bills
page is not necessary. This reuses the existing replay/bootstrap protocol.
Incomplete bill coverage checkpointed at the current cursor resumes there after
an interrupted/429 pull; it must not restart at zero on every retry.
Activation during an existing pull retains a replay-required marker until a
subsequent full bill-aware replay completes.

## Budget attention

Show active monthly category budgets at or above 80% usage, ordered by highest
exact usage ratio. This is a display threshold, not a change to budget rules.
Use existing UTC anchored/clamped budget periods, including the prior month's
period when today's date precedes the anchor day. Exclude budgets not yet begun,
deleted budgets/categories and categories belonging to another owner.

Always calculate spending from the live local ledger. A period-specific cached
allowance can be reused; never reuse its stale spending or a generic other-period
cache. A pending local budget edit takes precedence over its cached allowance.
Without a period-specific allowance, the current local amount is labelled as an estimate,
consistent with the existing offline budget fallback. Remaining amounts retain
cents. This card does not extrapolate an expected end-of-month expense.

Tests cover snapshot/indexed stores, pagination, dates and timezones, owner and
currency exclusions, offline edits, exact thresholds, paid/review evidence,
duplicate reminders, privacy/semantics, 320px layouts with 2x text and navigation.

See [Display timezone](display-time-zone.md) for preference scope and unchanged
budget/bill calendar rules.
