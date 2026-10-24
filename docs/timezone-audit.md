# Mobile timezone audit

Audit date: 2026-10-24. Scope: all Dart sources under `lib`, including UI,
repositories, query boundaries, native summary caches, auth and sync. Backend
goal schemas and investment snapshot semantics were inspected without changing
the API or rewriting existing financial data.

## Rules

1. Events are instants. Persist/send UTC; project into the owner-selected zone
   only for display or when deriving a personal calendar query boundary.
2. A date (`YYYY-MM-DD`) or month (`YYYY-MM`) is a calendar key, not an instant.
   Validate it independently of the OS. Never convert picker midnight to UTC
   before extracting a key: that can silently select yesterday/last month.
3. Convert the next calendar midnight to get an exclusive end. Do not add 24
   hours to a device-zone instant across a daylight-saving transition.
4. Shared server calendars and explicit recurring-schedule zones retain their
   business rules. Changing display preference does not move existing due dates,
   price dates, trades, balances or allocations.

## Coverage

| Area | Result |
| --- | --- |
| Settings/session | Owner-scoped offline preference, stale-session protection, device fallback and resume refresh retained. |
| Dashboard | Selected-zone monthly totals and spending comparison; budget attention retains the server allowance calendar. Comparison labels use calendar month values. |
| Transactions/transfers | Selected-zone grouping, details, times, date input and half-open monthly filters; UTC writes and stable IDs retained. |
| Personal reports | Selected month stays selected when zones change; bounds follow its new zone. |
| Budget | Calendar selector/request key agree; no local-midnight conversion into the previous month. Annual transaction-year fallback explicitly uses the server UTC calendar. |
| Emergency fund | Complete-month history bounds, evidence counts and displayed dates follow the selection. Health uses that same baseline zone. |
| Financial health | Personal cash-flow windows and underlying emergency history align; displayed exclusive ends are converted before formatting. |
| Goals | Creation date, suggested target, today's progress and overdue status follow owner preference. Existing date-only fields remain intact. Shared backing observation timestamp is formatted in the selected zone. |
| Bills | New anchor uses the new schedule's zone. New supported-zone default follows preference. Existing explicit zone is preserved. Payment history timestamps follow display selection; recurrence dates retain schedule semantics. |
| Cash-flow planning | New supported-zone default follows preference; saved explicit planning zone wins. Forecast observation instant follows display selection. Schedule-to-planning-zone date mapping retained. |
| Obligations | Due dates are validated without OS timezone dependence. Event history timestamps follow display selection; commands stay UTC. |
| Investments/portfolio | Trade/history and catalog/cache timestamps use the selection. Snapshot picker maximum uses the server reference day, not device today. Price/snapshot date validation is independent of OS timezone. |
| Net worth/asset allocation | Observation instants follow selection; snapshot/price reference dates stay calendar keys. Latest server observation is labelled latest rather than implying device-local today. |
| Household | Activity and report-fetch timestamps follow selection. Aggregate report month is a server reference calendar; navigation keeps the exact month key. |
| Notifications/settings activity | Existing selected-zone relative-day formatting retained. |
| CSV/reconciliation | Inclusive picker dates become selected-zone UTC query bounds in the repository. Prepared exports invalidate on preference/device-zone changes. CSV and reconciliation metadata retain UTC interchange timestamps. |
| Native database | Instant indexes/pagination remain UTC. Daily summary cache is discarded before mutations after an OS-zone change; query keys include boundary offsets. |
| Auth/sync | Expiry comparisons, cursors, retries, idempotency and audit timestamps remain instant-based. No timezone migration or financial-row rewrite. |

## Retained server calendar contracts

Budget allowance proration, household monthly aggregates, investment price dates
and as-of valuation dates use the existing server reference calendar. The mobile
API cannot request those server aggregates with a different timezone. Their
date-only keys stay unchanged; actual observation timestamps are localized.

Bill and forecast configuration currently supports fixed offsets 0, +07, +08 and
+09. For a device zone outside that set, a new configuration visibly defaults to
GMT+00:00 and can be changed in its form. An existing saved configuration always
wins. These fixed schedule zones do not adopt device daylight-saving rules.
Personal transaction/report/export device-mode calendars use OS DST rules.

## Verification

Regression coverage exercises device/WIB/WITA/WIT, year rollover, exclusive
start/end boundaries, full-month history/evidence, selected-zone export UI,
prepared CSV invalidation, overdue goals and preserved planning settings in both
snapshot and encrypted indexed stores. Existing settings/session and transaction
grouping tests cover reactive changes and small-screen layouts. Full analyzer
and test suite are required. Physical-device timezone switches and overseas DST
transitions have not been certified by the Windows test runner.
