# Mobile improvement status

## Verified on 2026-10-15

- `flutter analyze`: no issues.
- `flutter test`: 223 tests passed in the latest workspace run, including independent collaboration pagination, owner controls outside the visible member page, confirmed retry of an unchanged investment command, and the new lifecycle privacy shield.
- Added an immutable investment command preparation model: distinct generated trade/cash UUIDs, stable repeated JSON serialization, history-account binding, strictly newer UTC millisecond timestamps, exact BUY/SELL settlement and position projection, and cent-precise cash arithmetic including values above JS safe integers. Five tests cover envelope stability, fees, overselling, identity/chronology and cash bounds. The model is now integrated into atomic repository persistence and the decimal-string BUY/SELL form. See `offline-investment-trades.md` for reconciliation and recovery limits.
- Investment history coverage is persisted with user, schema, cursor and completion status. Legacy snapshots without compatible coverage replay the feed from zero without deleting local data/outbox. Starting sync invalidates readiness; only a final validated page commits readiness atomically. Owner-scoped history reads reject missing/deleted/non-investment accounts and pending account/trade edits. Coverage is not current server authorization; enabled BUY/SELL additionally requires conservative cached ownership/activity guards and server authorization during sync.
- Latest isolated PostgreSQL suite: 17 tests passed (10 investment, 6 transfer, 1 collaboration privacy/revocation); all 20 migrations deployed into a fresh test-only database. No development database was migrated or reset. Eight collaboration unit tests and OpenAPI validation also passed. Backend typecheck still fails on the existing unused `seedCategories` in `prisma/seed.ts`.
- Incomplete push result sets now fail atomically: acknowledged removals in that response roll back, commands/ledgers/balances survive restart, and pull does not advance. A two-transfer regression covers this behavior.
- Investment history replay validates account scope, duplicate IDs, canonical UTC timestamps and tombstones; sorts by timestamp then ID; handles legacy dividends without changing holdings; and enforces strictly newer append times. The repository establishes feed coverage separately and persists optimistic trades with the command envelope.
- Connected Android emulator hot reload succeeded; no runtime errors were reported immediately afterward. This is not a completed device accessibility or end-to-end trade audit.

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

Owners can create income/expense group categories through the existing online endpoint. The UI labels connectivity requirements, disables the action offline, validates names/types, and prevents duplicate form submissions. Server responses are persisted without modifying personal categories or financial outbox entries. Session-generation guards prevent stale responses from entering a new user's cache. Successful creation invalidates cached group reports and attempts a report refresh. Owners can also edit category names/types using PATCH. Editing checks the originating group and cached category, validates response identity, and preserves local data when the backend rejects a mapped-category type change. Members can now connect/disconnect their own matching-type personal categories through the online mapping endpoints. Unsynchronized personal category edits must be synchronized first. Conflicts preserve cache, and successful mapping changes invalidate group reports. The new paginated GET `/groups/:id/category-mappings` returns only the actor's own active mappings. Mobile loads complete validated lists, distinguishes cached/loading/error/fresh states, and blocks mutations until status is fresh. Owners can delete a category from its edit sheet after explicit confirmation describing removal of all group mappings and possible report changes. The action is disabled offline; cache is removed only after server success, preserving personal categories, transactions, balances, and outbox. Rejected requests leave persisted data unchanged.

## Group account sharing

Owners and members can share/unshare their own accounts using the existing online endpoints. Both actions require confirmation; sharing explains that mapped transactions, including earlier history, can contribute to aggregates visible to group members. Pending account/account-type mutations must be synchronized first. Ownership, active group, offline mode, and stale sessions are guarded. Successful changes invalidate reports without changing personal balances, transactions, or outbox. The new paginated GET `/groups/:id/accounts` returns only the actor's own active shared accounts, without balances or other members' private account data. Mobile uses guarded complete-list replacement and reloads status after mutations; failed reads preserve cache without calling it fresh.

## Household collaboration checkpoint

Online-only collaboration displays shared CASH balances separately per currency, mapped monthly income/expense contributions, privacy-filtered activity, and paginated membership. Transfers and investment-linked cash rows are excluded from activity/contributions. Member removal/self-leave and ownership transfer require confirmation and server authorization; removal revokes sharing/mappings without deleting personal financial records. Successful membership changes refresh group state before reloading the panel. Cross-member responses are not stored in the personal sync cache; group/user/offline changes clear presentation and invalidate stale responses. Response validation rejects numeric money, malformed activity and oversized pages. Unloaded information remains explicitly different from zero.

Contribution, activity and member lists now have independent page indices. Owner controls use a fresh bounded membership scan rather than relying on the visible page; repeated pages fail closed. A widget regression verifies an owner on member page 2 can manage page 1 and contribution navigation leaves other page indices unchanged. Real-device end-to-end management and concurrent revocation coverage remain follow-up work.

## Snapshot loading safeguards

List reads validate response shape, page size, and record identifiers, reject duplicate/repeated pages, and stop after 1,000 pages of 100 records. Exhausting the bound fails explicitly rather than returning a truncated snapshot. Repository regression tests verify failed reads leave both memory and persisted cache unchanged. This is a safety bound, not a replacement for indexed local queries or scalable incremental loading.

## Backend validation checkpoint

The new group read routes/repository tests pass (33 tests), and focused Prettier/ESLint checks pass. Production build and OpenAPI validation pass. Full `npm run validate` is not green: existing formatting issues span 34 unrelated files; `prisma/seed.ts` has unused `seedCategories`; the full test run reports 191 passed and one seed-account name expectation failure (`Succorinvest Stable Fund` versus `Reksadana Succorinvest Stable Fund`). These seed definitions were not silently changed and no seeding/reset was executed.

## Offline finance checkpoint

Atomic offline transfers now persist stable command/ledger UUIDs, paired optimistic ledgers, and balance changes in one local commit. Backend idempotency, authorization, and isolated PostgreSQL tests are implemented. Pull-before-ack balance reconciliation is covered; transfers are no longer an unimplemented contract.

Backend investment BUY/SELL commands and synchronization exist, including linked cash publication and sharing revocation tombstones. Mobile has exact BigInt cash settlement and an immutable moving-weighted-average position projection. The projection excludes fees from purchase average, retains average on partial SELL, clears it on liquidation, rejects oversell/quantity overflow, and rounds valuations HALF_UP including negative P/L. Seven projection tests cover repeating averages, large values, validation, and numeric limits.

The projection is a foundation, not an authoritative synced holding: callers must supply complete backend-ordered history, never partial pages or rounded holdings snapshots. Internal averages use exact rational arithmetic; backend Decimal uses 80 significant digits. Broader pathological cross-runtime differential coverage remains useful; authoritative settlement rows replace the optimistic projection after acknowledgement and a complete replay.

Synced category-null derived cash rows cannot be changed through generic transaction mutations; the edit UI explains this restriction. BUY/SELL is enabled through the new offline form. One unresolved command is allowed; rejected/conflicted commands remain durable and require server-reviewed recovery, not unsafe automatic rollback.

## Device data security policy

`docs/device-data-security.md` documents the current state: native SQLite is plaintext, browser localStorage is unencrypted, no app lock is active, and Android backup is not restricted. The policy defines invariants (no deletion of pending changes on lock/logout/expiry/failure, fail-closed lock, platform auth only, lock ≠ encryption, no restore overwrites unresolved commands) and acceptance criteria for device lifecycle, auth failures, user changes, native backup, iOS, and browser.

## Lifecycle privacy shield

`lib/app/widgets/lifecycle_privacy_shield.dart` is integrated via `MaterialApp.builder` in `lib/app/app.dart`. When the app transitions to inactive/hidden/paused, a gray overlay with a shield icon replaces the visible content. Interactions and semantics are blocked while concealed; the child widget tree and all local state (including unsaved form text and the outbox) remain mounted and intact. On resume the overlay is removed. A widget regression (`test/widget/lifecycle_privacy_shield_test.dart`) verifies inactive/hidden/paused concealment, IgnorePointer activation, state preservation, and clean resume. This is not an authentication lock and does not encrypt data; it only prevents casual screen capture while the app is backgrounded.



## Remaining work (not implemented)

1. Investment recovery operations: confirmed retry of the original rejected/conflicted command is implemented. Repository tests cover restart, unchanged IDs/payload, exact cash balance and failed durable retry commit; a widget test verifies cancel/confirm behavior. Confirmation also checks current state/repository identity. This is retry only, not cancellation: terminal invalid commands still require a server-reviewed support/admin recovery workflow. No unsafe discard/rebase action is provided.
2. Investment read coverage: read-only holdings and dated portfolio snapshots are integrated with exact decimal text, durable user/account-scoped cache, freshness/error states, and stale-response guards. These rounded read snapshots must not seed command cost-basis arithmetic.
3. Household collaboration follow-up: core online balances/contributions/activity/member management, independent pagination and owner-control availability across pages are integrated with regression coverage. Real-device management and concurrent revocation checks remain. Actor-owned sharing/mapping lists are not complete lists of other members' relationships.
4. Large-history performance: benchmark real workloads, then plan versioned migration from snapshot persistence to indexed local tables and paginated queries. Preserve outbox/cursors and existing user data.
5. Device security: app lock using `local_auth` (already in `pubspec.yaml`) is not yet implemented. The lifecycle privacy shield conceals content while backgrounded but is not a lock. Encryption and backup restriction are also not yet implemented. Never delete pending local changes implicitly.
6. Accessibility: complete TalkBack/VoiceOver, contrast, large-text and touch-target device checks.

These remaining features must not be considered complete merely because the current test suite passes. No backend schema migration or destructive data operation was performed in this continuation.
