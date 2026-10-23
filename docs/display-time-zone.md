# Display timezone

Settings → Zona waktu offers **Ikuti perangkat** (default), **WIB · Jakarta**,
**WITA · Makassar** and **WIT · Jayapura**. Indonesian zones have fixed offsets
+07:00/+08:00/+09:00. Device mode uses Dart/OS local timezone rules, including
daylight-saving changes; it is not a fixed offset captured when saving.

The preference is stored atomically in the owner's local metadata under
`display_time_zone`, with schema, owner and enum selection. It survives restart
on that device, works offline and creates no financial/outbox mutations or API
calls. Missing, unknown or differently owned metadata falls back to device mode.
No global mutable timezone is shared across sessions. A sheet opened in an old
session cannot save into a new session. Resume notifies presentation listeners
even offline, so device clock/timezone changes can refresh calendar boundaries.

## Presentation and filtering

- Dashboard monthly income/expense, surplus and expense comparisons use the
  selected timezone's calendar. Comparison labels no longer append UTC.
- Transaction month filters and report totals use half-open UTC instant bounds
  derived from the selected calendar month. Month-selector labels use the
  calendar month, never the prior UTC date at its opening instant.
- Changing zones preserves a manually selected report/history month. Initial
  entry uses the current month in the chosen zone. Transaction pagination resets
  when query boundaries change, including device-zone changes.
- Transaction day grouping, list times, details, relative dates, notifications,
  shared transaction dates and investment/cache timestamp presentation use the
  selected zone. Relative-day comparison uses calendar dates, not 24h durations.
- Transaction date picking interprets a chosen calendar date as midnight in the
  selected zone. Existing timestamps are not changed merely by opening an edit
  form or changing the timezone preference.

All persisted/API transaction timestamps remain UTC. Display conversion never
rewrites or resyncs existing transactions, balances or investment positions.

## Calendar contracts retained

Budget allowance periods remain the existing UTC anchored calendar; both the
budget page and dashboard budget attention keep that rule. Bill due dates retain
each schedule's explicit timezone. Cash-flow planning retains its own saved
planning timezone. Backend as-of valuation dates, market price reference dates,
financial-health assessment windows and export contracts retain their explicit
domain rules. The settings sheet explains the budget/bill distinction.

## Validation

Unit coverage includes midnight/month/year boundaries, exclusive period bounds,
relative dates, preference persistence/isolation, unchanged financial rows,
dashboard comparisons, unchanged budget/bill periods and monthly summary parity
for snapshot and indexed encrypted stores. Widget coverage includes settings at
320px with 2x text, saving, stale sessions, reactive day/time regrouping and the
dashboard label. OS-specific timezone/DST changes have not been certified on
physical devices by these tests.
