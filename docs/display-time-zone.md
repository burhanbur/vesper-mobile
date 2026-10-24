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
- Emergency-fund history and the emergency baseline within financial health
  use the same selected-zone complete-month boundaries and month evidence.
- Goal creation dates, suggested deadlines, today's linear progress and overdue
  status follow the owner's selected calendar. Existing start/target dates stay
  unchanged. New bill/forecast defaults use the preferred Indonesian zone when
  supported; existing explicit schedule/planning zones are preserved.
- Export date pickers describe an inclusive selected-zone range. The repository
  converts calendar midnights into a half-open instant range, including the last
  selected day. Changing zones clears a prepared CSV so it must be regenerated.
  CSV timestamp columns remain UTC for interchange.

All persisted/API transaction timestamps remain UTC. Display conversion never
rewrites or resyncs existing transactions, balances or investment positions.

## Calendar contracts retained

Budget allowance periods remain the existing UTC anchored calendar; both the
budget page and dashboard budget attention keep that rule.
The budget month selector stores calendar values in UTC and derives its request
key from the selected year/month. Device-local midnight must not be converted
into a period key: October 1 midnight in WIB is September 30 in UTC, which would
request September while the heading still says October.

Bill due dates retain each schedule's explicit timezone. Cash-flow planning retains its own saved
planning timezone. Financial-health assessment windows also follow the selected
display timezone; see [Financial health](financial-health.md). Backend as-of
valuation dates, market price reference dates and export contracts retain their
explicit domain rules. The settings sheet explains the budget/bill distinction.

Reference dates are validated as UTC calendar placeholders, independently of
the device timezone. They are never passed through instant display conversion.
Raw observation/cache/history instants use `DateFormatter.timestamp`; explicit
offsets are required instead of guessing the device zone for ambiguous strings.
Native summary day buckets are invalidated when the OS zone changes, before
incremental mutations are applied, including a later switch back.

See [Timezone audit](timezone-audit.md) for module coverage and retained server
calendar contracts.

## Validation

Unit coverage includes midnight/month/year boundaries, exclusive period bounds,
relative dates, preference persistence/isolation, unchanged financial rows,
dashboard comparisons, unchanged budget/bill periods and monthly summary parity
for snapshot and indexed encrypted stores. Widget coverage includes settings at
320px with 2x text, saving, stale sessions, reactive day/time regrouping and the
dashboard label. OS-specific timezone/DST changes have not been certified on
physical devices by these tests.
