# Mobile improvement status

## Local cancellation activation completed (2026-10-17)

- [x] Verified the target is **development**, PostgreSQL `vesper` on `localhost:5432`, and the only pending migration was `20261016000000_add_investment_recovery`. Applied that additive migration with `prisma migrate deploy`; all 21 migrations are now applied and all four cancellation guards are installed. No seed, reset or destructive operation was performed.
- [x] Selected `bmafazi` (Burhan Mafazi), the sole active account and an existing Super Admin, as the local operator. Explicitly assigned the dedicated `INVESTMENT_RECOVERY_REVIEWER` role containing only `sync.investment-recoveries.review`. Verified that this permission has exactly one member; existing shared roles were not broadened.
- [x] Compared counts and complete-row checksums before/after activation across **11 financial tables**. All match, including **34 accounts, 5,707 transactions and 690 transfers**. Recovery requests and permanently cancelled IDs remain empty; no actual financial command was reviewed or cancelled.
- [x] Revalidated the unchanged backend before activation: full `npm run validate` passes (**237 tests**, formatting, lint, types, build and OpenAPI); fresh isolated PostgreSQL suite passes **31 tests**. Isolated test containers were retained. Financial-data preservation above is a read-only deployment verification, not a test suite against development data.
- [x] Local API remains ready after activation (`/health/ready`: **200**), serves all **3 recovery OpenAPI paths**, and rejects an unauthenticated recovery read with **401**. The current database authorization lookup confirms the intended operator permission.
- [x] Flutter revalidation after activation: `flutter analyze --no-pub` is clean and all **306 Flutter tests** pass. Application source and the previously verified Android APK were unchanged during this deployment.

## Never-applied investment cancellation (2026-10-16)

- [x] Accepted scope is cancellation of commands that never applied. Applied-trade reversal is excluded. Added owner/device-bound recovery requests, canonical wire SHA-256, owner-scoped receipts and final operator approval/denial. Current database permission grants are locked/rechecked; roles from tokens do not authorize review. Reasons/reviewer identity remain in the restricted audit record.
- [x] Additive recovery migration stores durable decisions and permanently reserves both financial UUIDs. Database guards cover investment, transaction/import and transfer creation, including cross-namespace reuse. Existing or soft-deleted financial records refuse cancellation. Approval publishes authoritative accounts and explicit absence tombstones atomically, with the same global sync lock as execution. No permission is granted automatically.
- [x] Mobile confirms and saves request intent locally before transport, polls through sync or **Periksa status pembatalan**, and preserves optimistic rows/outbox while waiting. Approved receipts must match owner, command fingerprint and both IDs. Only a complete replay plus one durable commit replaces balances, removes the cancelled optimistic rows and releases that command. Interrupted replay, failed persistence, wrong receipts and missing authoritative rows retain financial state. Unrelated outbox entries survive.
- [x] Definitive refusal or unsupported older APIs preserve financial rows and permit explicit unchanged retry; lost responses resume by durable identity. Denied reviews permit unchanged retry. A shared fixed Dart/TypeScript vector verifies the wire fingerprint independently of the local queue ID. Support references retain their legacy hash and add `wire_command_sha256`.
- [x] New focused verification: **17 mobile repository tests** across legacy/v3, **1 widget confirmation test**, **5 backend HTTP/schema/fingerprint/OpenAPI tests**, and **7 PostgreSQL cancellation tests**. Full backend `npm run validate` passes (**237 tests**); full isolated PostgreSQL suite passes **31 tests**. The additive migration was applied only to fresh test containers, retained without cleanup.
- [x] Android emulator integration passes **4 tests**, including cancellation after a lost response and restart using native encrypted storage and secure keys. Physical-device and iOS certification remain separate.
- [x] Final Flutter analyzer is clean; all **306 Flutter tests** pass. The final main-entry debug APK builds, installs as an update in the Android emulator and starts with **zero fatal/unhandled startup markers**.
- [x] Activated against the local service on **2026-10-17**: additive migration applied and the dedicated review permission explicitly assigned to existing administrator `bmafazi`. See the activation checkpoint above. No financial records were modified.

Contract and operator steps: `investment-terminal-recovery-contract.md`, `investment-recovery-runbook.md`.

## Backend quality gate completed (2026-10-16)

- [x] Applied Prettier only to the 53 files reported by the backend formatting check. Changes cover indentation, wrapping and line endings; no dependency versions or compiler/security settings changed.
- [x] Removed the unused empty `seedCategories` declaration and its already-commented seed loop. Active seed account/category/instrument definitions and financial rules remain unchanged; no seed execution or development database migration/reset occurred.
- [x] Gave the collaboration ownership-update mock explicit Prisma argument types, resolving the unsafe-return lint error while retaining its ownership/privacy assertions. Updated the stale seed-account test expectation to the existing `Reksadana Succorinvest Stable Fund` name, preserving parent exclusion, child order, account type and unique-ID checks.
- [x] Full backend `npm run validate` passes with its normal configuration: formatting, ESLint, TypeScript, **232 tests across 29 files**, production build and generated OpenAPI validation. No test skipping, timeout increases, serial-only workaround or weakened checks were added.
- [x] Full PostgreSQL integration suite passes **24 tests across 5 files** after cleanup. Existing migrations were deployed only into a fresh, randomly named test-only container; it was retained without cleanup. Development financial data was not modified.

This supersedes the backend quality-gate failures recorded in the earlier checkpoints below.

## Initial sync speed improvement (2026-10-16)

- [x] Backend adds opt-in compact sync with latest snapshots per identity and batched authorized account/transaction/trade reads. Legacy pagination, persisted events, tombstones, cursor/replay semantics and owner/device authorization remain covered. No migration or dependency added.
- [x] Mobile negotiates compact mode with same-cursor fallback for older strict servers. A full initial REST transaction baseline is retained for older seed/import data; a durable user-bound marker avoids downloading all history again after successful incremental sync. Failed sync/persistence preserves the REST fallback, outbox and local edits.
- [x] Real local-API host diagnostic: initial load **130,216 ms -> 16,447 ms**, first accounts **109 ms**, complete **34 accounts / 5,707 transactions**. Subsequent refresh **384 ms**, one pull and no transaction-list requests. One initial 429 was handled using `Retry-After`. These are host measurements, not physical-device certification; no financial records changed. Details: `initial-sync-performance.md`.
- [x] Five new mobile regressions, two backend schema tests and four new PostgreSQL regressions pass. Full isolated PostgreSQL suite: **24 tests pass**. Backend production build, OpenAPI validation and focused formatting/lint pass. Full backend gates still have 53 unrelated formatting files, unused `seedCategories` and the existing seed naming test failure (**231 pass / 1 fail** with one worker).
- [x] Corrected transaction/month/date layout overflow at 200% text on a 320px viewport; large amounts get their own row on narrow/scaled layouts. Updated the balance dialog regression to assert its existing Rupiah-formatted value. All seven focused accessibility/balance-dialog tests pass.
- [x] Final `flutter analyze --no-pub` is clean and the full `flutter test --no-pub` suite passes **288 tests**.
- [x] Android emulator integration: all **3 tests pass** with current source, covering early account rendering/history persistence, encrypted native outbox/key restart and locked presentation after cancelled/unavailable platform authentication.
- [x] Main-entry Android debug APK builds, installs as an update in the emulator and stays running. Startup logs contain **zero fatal/unhandled markers**.

## Dashboard transfer button fix (2026-10-16)

- [x] Removed the stale disabled/gembok state from the dashboard Transfer quick action and connected its existing `onTransfer` callback to the transfer form.
- [x] Regression now taps the actual dashboard button, verifies the transfer form and no premature writes, then submits an isolated offline fixture and verifies one durable command, two ledger rows and both balances. Focused UX/accessibility checks: **10 tests pass**.
- [x] Final analyzer is clean, all **283 Flutter tests pass**, and the updated main-entry debug APK builds, installs as an update and starts in the Android emulator.

## Android login data-loading fix (2026-10-16)

- [x] Reproduced the empty-dashboard failure against the local API: login succeeds and account/transaction endpoints contain data, but initial sync replays hundreds of pages, hits HTTP 429, and the old short retry delays exhaust before the rate-limit window resets. Loading/error presentation was hidden when the outbox was empty.
- [x] Load and publish account types, accounts, categories and groups before the long history replay. Publish each committed sync page so cached data appears during loading. Existing repository guards retain pending edits, transfer/investment rows and command-owned balances.
- [x] Preserve the server's numeric `Retry-After` on 429, stop further requests in that refresh attempt, and schedule bounded retry after that delay. Continue from the last committed cursor; keep partial history and outbox intact.
- [x] Dashboard shows loading/error status even with an empty outbox. Manual retry awaits completion and reports success only after a successful refresh. Five new automated regressions pass across legacy/v3 storage, transport retry metadata and the loading/error UI.
- [x] Live local-API verification with an isolated encrypted cache: all **34 accounts** became available after **232 ms**; all **5,707 transactions** loaded successfully with no final error after approximately **130 seconds**, including server-required waiting. This is a host diagnostic, not an Android timing guarantee. No financial records were changed. The temporary diagnostic source/cache was removed.
- [x] Android emulator integration: **3 tests pass**, including account rendering while history is gated, complete history persistence/restart, native encrypted storage and locked presentation after cancelled/unavailable authentication.
- [x] Final analyzer is clean and the full Flutter suite passes **283 tests**. Main-entry Android debug APK builds, installs as an update and starts in the emulator. Startup logs contain zero fatal/unhandled markers.

## Reconnection continuation (2026-10-15)

The interrupted Codex transport did not remove working-tree changes. Current source has been revalidated; earlier results below are retained as historical checkpoints.

- [x] Native indexed v3 storage implemented with authenticated page/index/WAL encryption; supported sqlite3mc build hook, device-only per-user key, canonical snapshot validation, retained encrypted legacy source, guarded activation and fail-closed active pointer. Eight storage tests and the native cipher regression pass.
- [x] Ordinary edits journal only changed fields and write affected rows, outbox and metadata in one durable transaction. Existing investment/transfer behavior runs against both legacy and v3 stores: **44 tests pass**, including rejection, retry, lost acknowledgement, incomplete pulls and failed commits.
- [x] Transaction/account history use bounded 100-row keyset pages; dashboard reads five rows; reports restrict reads to the selected month. Exact BigInt monthly totals cache and update from changed rows. Large-text pagination overflow was corrected and all four accessibility regressions pass.
- [x] Indexed synthetic benchmark: at 50k rows, warm atomic edit median **13.9 ms**, p95 **26.6 ms**; 100-row query median **0.84 ms**, p95 **11.3 ms**, on the Windows host under concurrent build load. This does not certify physical-device performance.
- [x] Current analyzer/test/native validation: analyzer clean; **278 Flutter tests pass**; **2 Android emulator integration tests pass** with v3; main-entry debug APK builds, installs and starts. Startup log has zero fatal/unhandled markers. Final-source JavaScript web build and Wasm dry run pass; actual Wasm runtime certification was not performed.
- [ ] Physical-device performance, iOS and device accessibility certification remain unavailable in this session.

## Completion tracker — continuation on 2026-10-15

Items are checked only after implementation and the relevant verification pass.

- [x] Device app lock controller/root gate/settings implemented; 5 controller tests, 2 gate tests and a session-navigation test pass (startup/read failure, enable/disable persistence, cancellation/unavailable auth, stale prompt, interruption, focus/semantics, hardware-back protection, draft retention and previous-user route removal). Native device verification is tracked separately below.
- [x] Native AES-256-GCM snapshot envelopes, user-scoped secure keys and restartable v0/v1/v2 migration implemented; 6 tests pass (tampering/user binding, plaintext cleanup, full outbox/cursor preservation, failed commit, interrupted cleanup, wrong/missing/corrupt keys). `cryptography` is added for authenticated encryption; the Flutter SDK `integration_test` dev dependency supports device verification below.
- [x] Android backup restrictions: cloud and device-transfer exclusions, `allowBackup=false`, native biometric setup and screenshot/task-preview protection compile in `flutter build apk --debug`. Merged manifest includes all backup attributes and biometric permission.
- [x] Android emulator security integration: 2 tests pass on Android 17/API 37 using real secure storage, SQLite, path provider and local authentication. Encrypted commands survive restart; removing only the synthetic user's key fails closed without creating a replacement; restoring that key recovers the exact outbox. Platform authentication cancellation/unavailability leaves the UI locked. No existing user data or session is touched.
- [ ] iOS file protection/backup exclusion and native task-preview shield implemented; compilation and device verification require macOS/iOS, which is unavailable on this host.
- [x] Large-history benchmark and versioned indexed-storage migration plan: isolated 1k/10k/50k histories measured; results, limitations, migration stages and acceptance gates recorded in `local-storage-performance.md`. Historical full-snapshot edits were slow; indexed v3 implementation and comparative host measurements are now recorded above. Physical-device certification remains incomplete.
- [x] Investment support-reference UI and operator investigation/retry runbook: immutable command fingerprint and identifiers only, with a passing redaction/retry/restart regression (`investment-recovery-runbook.md`).
- [x] Terminal cancellation of never-applied investment commands implemented and verified; see the current cancellation checkpoint above for rollout status. Applied-trade reversal remains outside the accepted scope.
- [x] Household mobile revocation regressions: 403 during management clears old private data/controls; background invalidates in-flight responses and resume reauthorizes; absent actor membership fails closed. All 3 new regressions and the independent-pagination test pass.
- [x] Backend concurrent-revocation transaction checks: 3 new isolated PostgreSQL tests pass for share/mapping versus removal, ownership transfer versus self-leave, and snapshot reads versus revocation. Fixed sync publication's compound-unique lookup (`findUnique` for single-record writes). Full isolated suite: 20 tests pass; all existing migrations applied only to a fresh test database. No development data changed or test-container cleanup performed.
- [ ] Household physical-device end-to-end member management; user confirmed no physical device is available in this session.
- [x] Automated accessibility regressions: 4 tests pass for body/status contrast >=4.5:1, 200% text on a 320px viewport, large transaction amounts, named search/clear/quick-action controls, navigation selection, Android tap-target and labeled-target guidelines, security/lock usability and hidden private semantics. Readability colors and overflowing transaction/empty-state/navigation layouts were corrected.
- [ ] Physical TalkBack/VoiceOver and full-device accessibility audit remains separate from automated checks. No physical device is available (confirmed by user).
- [x] Earlier final checkpoint: analyzer clean and 245 tests passed before v3. The reconnection section above records the latest 278-test result.

Unchecked items above remain incomplete. The following baseline is retained for context; current continuation results are listed in this tracker and the latest-validation section.

## Earlier continuation validation (2026-10-15; superseded by reconnection section)

- `flutter test --no-pub`: **245 tests passed**.
- `flutter test --no-pub integration_test/device_security_test.dart -d emulator-5554`: **2 tests passed** on Android 17/API 37 emulator.
- `flutter build apk --debug --no-pub`: **passed**, including the final main application entry point.
- `flutter build web --no-pub`: **JavaScript build passed** and Wasm dry run succeeded; an actual Wasm build/runtime audit was not run.
- Snapshot benchmark: **passed**, 1k/10k/50k isolated synthetic histories; substantial large-snapshot latency remains documented.
- Backend focused Prettier/ESLint: **passed**; isolated PostgreSQL suite: **20 tests passed**.
- `flutter analyze --no-pub`: **no issues**, final run.
- Backend production build: **passed**. Backend-wide gates remain **not green**: formatting check reports 53 files, typecheck reports the existing unused `seedCategories`, and the unit suite reports **229 passed / 1 failed** on the existing seed-account name expectation. No seed definitions were changed or executed. The backend edit is limited to sync publication plus the new concurrency regression file.

## Earlier baseline verified on 2026-10-15

- `flutter analyze`: no issues.
- `flutter test`: 223 tests passed in the earlier workspace run, including independent collaboration pagination, owner controls outside the visible member page, confirmed retry of an unchanged investment command, and the lifecycle privacy shield. Superseded by the continuation result above.
- Added an immutable investment command preparation model: distinct generated trade/cash UUIDs, stable repeated JSON serialization, history-account binding, strictly newer UTC millisecond timestamps, exact BUY/SELL settlement and position projection, and cent-precise cash arithmetic including values above JS safe integers. Five tests cover envelope stability, fees, overselling, identity/chronology and cash bounds. The model is now integrated into atomic repository persistence and the decimal-string BUY/SELL form. See `offline-investment-trades.md` for reconciliation and recovery limits.
- Investment history coverage is persisted with user, schema, cursor and completion status. Legacy snapshots without compatible coverage replay the feed from zero without deleting local data/outbox. Starting sync invalidates readiness; only a final validated page commits readiness atomically. Owner-scoped history reads reject missing/deleted/non-investment accounts and pending account/trade edits. Coverage is not current server authorization; enabled BUY/SELL additionally requires conservative cached ownership/activity guards and server authorization during sync.
- Earlier isolated PostgreSQL suite: 17 tests passed (10 investment, 6 transfer, 1 collaboration privacy/revocation); all 20 migrations deployed into a fresh test-only database. No development database was migrated or reset. Eight collaboration unit tests and OpenAPI validation also passed. Backend typecheck still fails on the existing unused `seedCategories` in `prisma/seed.ts`.
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
- Account total balance calculation: hero summary now strictly calculates liquid cash/bank/wallet accounts marked as included in total (`isCashBankOrWallet && isIncludeTotal`), excluding investment, liability, and debt accounts from inflating liquid cash.
- Parent-pocket balance aggregation: parent account cards (such as Bareksa) aggregate balances from connected child pockets for display (`parentDisplayBalance`), with connected pocket counts and indicators.
- Include in total setting toggle: interactive toggle controls on both the account settings modal and the account detail page allow toggling `isIncludeTotal` with double-counting prevention (parent accounts with active child pockets are guarded and disabled). State and outbox synchronization verified with unit and widget test suites.
- Read-only investment holdings and dated portfolio snapshots: exact decimal text, durable user/account-scoped cache, freshness/error states and stale-response guards. Rounded read snapshots never seed command cost-basis arithmetic.

## Group category creation

Owners can create income/expense group categories through the existing online endpoint. The UI labels connectivity requirements, disables the action offline, validates names/types, and prevents duplicate form submissions. Server responses are persisted without modifying personal categories or financial outbox entries. Session-generation guards prevent stale responses from entering a new user's cache. Successful creation invalidates cached group reports and attempts a report refresh. Owners can also edit category names/types using PATCH. Editing checks the originating group and cached category, validates response identity, and preserves local data when the backend rejects a mapped-category type change. Members can now connect/disconnect their own matching-type personal categories through the online mapping endpoints. Unsynchronized personal category edits must be synchronized first. Conflicts preserve cache, and successful mapping changes invalidate group reports. The new paginated GET `/groups/:id/category-mappings` returns only the actor's own active mappings. Mobile loads complete validated lists, distinguishes cached/loading/error/fresh states, and blocks mutations until status is fresh. Owners can delete a category from its edit sheet after explicit confirmation describing removal of all group mappings and possible report changes. The action is disabled offline; cache is removed only after server success, preserving personal categories, transactions, balances, and outbox. Rejected requests leave persisted data unchanged.

## Group account sharing

Owners and members can share/unshare their own accounts using the existing online endpoints. Both actions require confirmation; sharing explains that mapped transactions, including earlier history, can contribute to aggregates visible to group members. Pending account/account-type mutations must be synchronized first. Ownership, active group, offline mode, and stale sessions are guarded. Successful changes invalidate reports without changing personal balances, transactions, or outbox. The new paginated GET `/groups/:id/accounts` returns only the actor's own active shared accounts, without balances or other members' private account data. Mobile uses guarded complete-list replacement and reloads status after mutations; failed reads preserve cache without calling it fresh.

## Household collaboration checkpoint

Online-only collaboration displays shared CASH balances separately per currency, mapped monthly income/expense contributions, privacy-filtered activity, and paginated membership. Transfers and investment-linked cash rows are excluded from activity/contributions. Member removal/self-leave and ownership transfer require confirmation and server authorization; removal revokes sharing/mappings without deleting personal financial records. Successful membership changes refresh group state before reloading the panel. Cross-member responses are not stored in the personal sync cache; group/user/offline changes clear presentation and invalidate stale responses. Response validation rejects numeric money, malformed activity and oversized pages. Unloaded information remains explicitly different from zero.

Contribution, activity and member lists have independent page indices. Owner controls use a fresh bounded membership scan rather than relying on the visible page; repeated pages and absent actor membership fail closed. A widget regression verifies an owner on member page 2 can manage page 1 and contribution navigation leaves other page indices unchanged. New mobile and PostgreSQL regressions cover concurrent revocation; failed management clears old private presentation and backgrounding invalidates in-flight reads. A read authorized before server revocation can finish with its existing transaction snapshot; new reads after commit deny. Physical-device end-to-end management remains unverified.

## Snapshot loading safeguards

List reads validate response shape, page size, and record identifiers, reject duplicate/repeated pages, and stop after 1,000 pages of 100 records. Exhausting the bound fails explicitly rather than returning a truncated snapshot. Repository regression tests verify failed reads leave both memory and persisted cache unchanged. This is a safety bound, not a replacement for indexed local queries or scalable incremental loading.

## Earlier backend validation checkpoint

The new group read routes/repository tests pass (33 tests), and focused Prettier/ESLint checks pass. Production build and OpenAPI validation pass. Full `npm run validate` is not green: existing formatting issues span 34 unrelated files; `prisma/seed.ts` has unused `seedCategories`; the full test run reports 191 passed and one seed-account name expectation failure (`Succorinvest Stable Fund` versus `Reksadana Succorinvest Stable Fund`). These seed definitions were not silently changed and no seeding/reset was executed.

## Offline finance checkpoint

Atomic offline transfers now persist stable command/ledger UUIDs, paired optimistic ledgers, and balance changes in one local commit. Backend idempotency, authorization, and isolated PostgreSQL tests are implemented. Pull-before-ack balance reconciliation is covered; transfers are no longer an unimplemented contract.

Backend investment BUY/SELL commands and synchronization exist, including linked cash publication and sharing revocation tombstones. Mobile has exact BigInt cash settlement and an immutable moving-weighted-average position projection. The projection excludes fees from purchase average, retains average on partial SELL, clears it on liquidation, rejects oversell/quantity overflow, and rounds valuations HALF_UP including negative P/L. Seven projection tests cover repeating averages, large values, validation, and numeric limits.

The projection is a foundation, not an authoritative synced holding: callers must supply complete backend-ordered history, never partial pages or rounded holdings snapshots. Internal averages use exact rational arithmetic; backend Decimal uses 80 significant digits. Broader pathological cross-runtime differential coverage remains useful; authoritative settlement rows replace the optimistic projection after acknowledgement and a complete replay.

Synced category-null derived cash rows cannot be changed through generic transaction mutations; the edit UI explains this restriction. BUY/SELL is enabled through the offline form. One unresolved command is allowed; rejected/conflicted commands remain durable. Confirmed unchanged retry and read-only support references are available; see `investment-recovery-runbook.md` for operator review and the remaining terminal-cancellation boundary.

## Device data security policy

`docs/device-data-security.md` documents native v3 authenticated page encryption, including query indexes/WAL, and restartable legacy snapshot migration, optional device-wide platform app lock, Android backup/transfer exclusions and screenshot protection, plus explicit browser limitations. User-scoped filenames and approximate file sizes remain visible; retained legacy files contain authenticated AES-GCM payloads. The iOS protection bridge and preview shield are implemented but uncompiled on this Windows host. Invariants preserve pending data on lock/logout/expiry/failure and keep lock separate from encryption and backup recovery. Physical-device/platform certification remains explicit.

## Lifecycle privacy shield

`lib/app/widgets/lifecycle_privacy_shield.dart` is integrated via `MaterialApp.builder` in `lib/app/app.dart`. When the app transitions to inactive/hidden/paused, a gray overlay with a shield icon replaces the visible content. Interactions and semantics are blocked while concealed; the child widget tree and all local state (including unsaved form text and the outbox) remain mounted and intact. On resume the overlay is removed. A widget regression (`test/widget/lifecycle_privacy_shield_test.dart`) verifies inactive/hidden/paused concealment, IgnorePointer activation, state preservation, and clean resume. This is not an authentication lock and does not encrypt data; it only prevents casual screen capture while the app is backgrounded.



## Remaining implementation and device acceptance

- [x] Implement terminal recovery for the accepted never-applied cancellation scope: reviewed server decision, permanently reserved UUIDs and complete authoritative reconciliation. Local-service activation is tracked separately above; applied-trade reversal is excluded.
- [x] Implement v3 indexed encrypted storage with bounded transaction queries, exact cached totals and row-level durable edits; migration/failure tests and host benchmark pass.
- [ ] Certify v3 on physical Android/iOS targets, including migration frames/memory, cold summary latency and the proposed save/query targets.
- [ ] Physical-device household member management end to end. Mobile race regressions and isolated PostgreSQL concurrency coverage are complete; actor-owned sharing/mapping lists still do not expose other members' private relationships.
- [ ] Compile and test iOS protection on macOS/iOS; verify native backup/transfer behavior, successful biometrics, enrollment changes and lifecycle behavior on physical target devices. Windows-host tests and an Android emulator do not certify these cases.
- [ ] Physical TalkBack/VoiceOver and complete accessibility/device audit. Automated contrast, 200% text, tap-target, semantics and overflow checks are implemented and passing.

Unchecked items are not complete merely because tests pass. Development activation on 2026-10-17 applied the one additive recovery migration described above; no financial rows changed. Production was not migrated and no database was reset or deleted. Automated PostgreSQL suites use fresh isolated containers, retained without stop/down/drop/volume cleanup.
