# Initial sync performance (2026-10-16)

## Measured result

Windows host diagnostic using the actual local API, normal authentication/device registration, the application refresh flow and an isolated encrypted native cache:

| Measurement | Earlier run | Current run |
| --- | ---: | ---: |
| Initial load, including required retry waiting | 130,216 ms | 16,447 ms |
| First accounts available | 232 ms | 109 ms |
| Accounts / transactions retained | 34 / 5,707 | 34 / 5,707 |
| Subsequent refresh | Not recorded | 384 ms |

The observed initial load is about 87% shorter. These are individual local host runs, not a controlled distribution or physical Android/iOS certification. Rate-limit window occupancy and concurrent host load affect elapsed time. The current initial run encountered one HTTP 429 and respected `Retry-After`; it finished without a final error. The subsequent refresh used 11 requests, one sync pull, zero transaction-list requests and encountered no rate limit.

The earlier initial replay required 208 pull pages. The current run made 59 pull requests, including the resume check after the rate limit. A full initial REST transaction baseline is deliberately retained: existing seed/import data can predate sync publication. Its partial attempt plus complete retry made 63 transaction-list requests. The temporary diagnostic source and encrypted cache were removed; no financial rows were created or modified. Diagnostic login/device registration only wrote session/device metadata.

## Implementation and rollout

- Backend `/sync/pull?compact=true` returns the latest change for each entity identity above the requested cursor, ordered by commit version. The existing feed already carries current snapshots, rather than historical deltas. Persisted events are retained. Omitted/false `compact` retains legacy event pagination.
- Each page batches accounts, transactions and investment transactions with the same authorization/deletion filters as point reads. Deleted, missing or revoked entities produce tombstones. Existing writer locking, owner-scoped device checks, watermark, delivery cursor and explicit replay semantics remain in effect. A newer write between pages can cause an identity to appear again.
- Mobile requests compact pulls. An older strict server's first 422 response triggers one retry at the same cursor without the additive flag; accepted servers' later 422s and rate limits retain normal error behavior.
- A successful full transaction-list replacement atomically stores a user-bound coverage marker. Later refreshes skip that full list only after successful incremental synchronization. Failed sync retains the existing REST fallback. Pending local edits, command-owned rows and outbox entries retain their existing guards. Failed list persistence never marks coverage complete.
- Deploy the additive backend first for the speed benefit. The client can still use an older backend. No migration or new dependency is required. Future writes must follow the existing backend sync-publication contract; direct SQL/seed changes after the baseline are not incremental events.

## Verification

- Five mobile regressions cover old-server negotiation, cursor/error handling, restart/user-bound baseline coverage, failed-sync fallback and atomic marker persistence.
- Two backend schema regressions cover optional legacy behavior, supported mode strings, strict input and page limits.
- Four new isolated PostgreSQL regressions cover repeated edits and equivalent final snapshots, one ledger query per 100-row page, tombstones/replay/concurrent updates, owner/device boundaries and revoked sharing. The full isolated suite passes 24 tests. Migrations ran only against a fresh test database; test containers were retained.
- At the initial performance checkpoint, backend production build, generated OpenAPI validation and focused Prettier/ESLint passed. Full validation was blocked by formatting, unused `seedCategories` and a stale seed-account name expectation. The subsequent quality-gate cleanup on 2026-10-16 resolves these: normal `npm run validate` now passes, including all 232 tests, without a worker override or increased timeout. Active seed data definitions were preserved and no seed was executed. See the latest status checkpoint for full results.

Final Flutter and Android results are recorded in [mobile-improvement-status.md](mobile-improvement-status.md).
