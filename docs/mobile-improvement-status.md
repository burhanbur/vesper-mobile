# Mobile improvement status

## Verified on 2026-10-14

- `flutter analyze`: no issues.
- `flutter test`: 129 tests passed.
- No running Flutter application was exposed by the IDE Dart Tooling Daemon; hot reload and device-level validation remain pending.

## Implemented in the current working tree

- Cached-session offline resilience with regression coverage.
- Connectivity/lifecycle synchronization triggers and bounded retry.
- Awaited dashboard refresh, period selection, and date presentation improvements.
- Non-investment balance labeling and explicit unavailable household/unsupported-action presentation.
- Repository-backed regression fixtures instead of fabricated demo state.
- Unknown-account category lookup returns an empty list.
- Group creation normalizes cached maps before inserting server data.
- Online group joining accepts a group UUID and 12-character invitation code, persists the server response, and guards against stale session responses. The group screen exposes both invitation components.
- Transaction header wraps within available width, including larger text layouts.
- Household category reports use the existing server endpoint and explicit UTC calendar months. Decimal strings are retained exactly, cached per group/month with fetch timestamps, and remain available offline. Loading/errors, missing-data presentation, period switching, and stale-response guards have regression coverage.

## Group category creation

Owners can create income/expense group categories through the existing online endpoint. The UI labels connectivity requirements, disables the action offline, validates names/types, and prevents duplicate form submissions. Server responses are persisted without modifying personal categories or financial outbox entries. Session-generation guards prevent stale responses from entering a new user's cache. Successful creation invalidates cached group reports and attempts a report refresh. Editing/deleting categories and personal category mappings remain pending.

## Snapshot loading safeguards

List reads validate response shape, page size, and record identifiers, reject duplicate/repeated pages, and stop after 1,000 pages of 100 records. Exhausting the bound fails explicitly rather than returning a truncated snapshot. Repository regression tests verify failed reads leave both memory and persisted cache unchanged. This is a safety bound, not a replacement for indexed local queries or scalable incremental loading.

## Remaining work (not implemented)

1. Offline transfers: the backend sync contract explicitly excludes transfer and investment writes. Define atomic paired-ledger synchronization and idempotency, authorization, conflict handling, and balance reconciliation before enabling mobile mutations.
2. Investment holdings/trades: integrate real server contracts and exact decimal quantity/price arithmetic. Do not represent financial calculations with floating point.
3. Household collaboration: invitation joining, category report aggregates, and owner-only category creation are integrated; shared cash balances, contribution totals, transaction feeds, category editing/deletion/mappings, and member management remain pending.
4. Large-history performance: benchmark real workloads, then plan versioned migration from snapshot persistence to indexed local tables and paginated queries. Preserve outbox/cursors and existing user data.
5. Device security: implement app lock and define encryption/backup/recovery policy. Never delete pending local changes implicitly.
6. Accessibility: complete TalkBack/VoiceOver, contrast, large-text and touch-target device checks.

These remaining features must not be considered complete merely because the current test suite passes. No backend schema migration or destructive data operation was performed in this continuation.
