# Local storage performance and indexed migration

## Reproducible baseline (2026-10-15)

Run `flutter test --no-pub tool/snapshot_benchmark.dart --reporter expanded`.
The harness writes `build/benchmarks/snapshot-storage.json` and uses isolated temporary databases. It never opens an existing user's data or calls an API.

These are representative synthetic server-shaped household histories, not measurements of a real user's private data or a physical phone. Each workload includes 20 pending commands and a cursor above the JavaScript safe integer range. Timings are Windows host test VM medians of three runs after warm-up, file-backed SQLite WAL with `synchronous=FULL`. Other build/emulator activity was present; use the harness for comparative investigation, not a release performance guarantee.

| Transactions | JSON size | Plain write | Encrypted write | Encrypted read | Encrypted atomic edit |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 284,320 B | 10.0 ms | 76.9 ms | 66.1 ms | 76.6 ms |
| 10,000 | 2,883,620 B | 78.8 ms | 935.4 ms | 995.6 ms | 1,036.6 ms |
| 50,000 | 14,635,620 B | 663.8 ms | 5,996.6 ms | 4,732.1 ms | 5,442.3 ms |

The legacy snapshot repository serializes a full rollback snapshot and persists the entire JSON document for every atomic edit. Authenticated encryption adds another full-document pass and base64 allocation. Lazy widgets reduce rendering work but cannot solve this persistence cost. Large-history performance is **not solved** by this baseline. Do not weaken encryption or remove durable commits to hide the cost.

## Implemented v3 storage (2026-10-15)

Native opens now use a separate user-scoped v3 SQLite file with SQLite3MultipleCiphers ChaCha20-Poly1305 authenticated page encryption. The existing sqlite3 package supplies its supported sqlite3mc native build hook; no new database package was added. Payloads, indexed account/date/type/search columns, metadata and WAL are encrypted. The MIT notice is bundled in assets/licenses and registered in Flutter licenses. [Native cipher documentation](https://utelle.github.io/SQLite3MultipleCiphers/docs/ciphers/cipher_chacha20/) and [upstream license](https://github.com/utelle/SQLite3MultipleCiphers/blob/main/LICENSE).

The compatibility reader encrypts/cleans legacy v0/v1/v2 snapshots first. A worker isolate copies all entity tables, unknown metadata, cursor/coverage/staging and original outbox statuses/envelopes. Owner, format, a canonical full-content SHA-256 digest and initialized/revision markers are validated before activation. The source is write-locked while copying; a payload digest and second write lock detect writes before secure-pointer activation. The encrypted legacy source is retained. Once the secure pointer selects v3, a missing/wrong-key/corrupt destination fails closed; it cannot replay the old outbox.

Entities use primary key (entity_type,id), with indexed transaction date/account/type/tombstone fields. Tracked maps/lists maintain a changed-field undo journal, avoiding whole-history rollback copies. Each ordinary commit writes only changed entity records plus changed metadata/outbox in one WAL/FULL transaction, with a revision check against stale concurrent writers. Outbox order, immutable payload fields and exact decimal/cursor strings survive restart. Investment history still consumes complete ordered records; rounded portfolio reads do not seed arithmetic.

Transaction and account screens use stable date-descending/ID-ascending keyset pages of at most 100 rows. Search keeps literal substring semantics and Unicode category/actor matching. Dashboard requests five rows. Reports read only their selected month. Monthly income/expense/daily-net summaries use BigInt cents, exclude transfers and update cached windows using changed records after a successful commit. SQL never converts money to REAL. Failed commits leave both memory and summary caches unchanged.

Eight storage regressions plus a native cipher regression pass. Existing investment and transfer workflow suites run against both storage formats (44 tests), including lost acknowledgement, interrupted pull, exact balances/positions and rollback. Widget tests cover paging across more than 200 records and large-text layouts. Android emulator validation and final build outcomes are recorded in mobile-improvement-status.md.

## Indexed host measurements

Run flutter test --no-pub tool/indexed_benchmark.dart --reporter expanded. Results are written to build/benchmarks/indexed-storage.json. All inputs and databases are isolated synthetic fixtures. This benchmark does not open an existing user's store or call an API.

Windows Flutter host test VM, SQLite3MultipleCiphers, WAL/FULL, 25 warm samples, under concurrent Android/web build load:

| Transactions | Atomic edit median | Atomic edit p95 | 100-row page median | 100-row page p95 | Cold month summary | Cached summary p95 |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 2.39 ms | 3.12 ms | 0.90 ms | 1.27 ms | 59.9 ms | 0.31 ms |
| 10,000 | 1.77 ms | 2.87 ms | 0.85 ms | 1.61 ms | 97.0 ms | 0.28 ms |
| 50,000 | 13.92 ms | 26.64 ms | 0.84 ms | 11.25 ms | 1,324.9 ms | 0.42 ms |

Each measured save changes one transaction description, a cash-account record and one of 20 pending commands. These figures demonstrate bounded ordinary edits/queries on this host; the earlier full-snapshot benchmark had a different save workload and only three samples. The 50k initial import took 37.7 seconds under build load; this is a one-time bulk import in the harness, not a measurement of complete encrypted legacy migration. Migration runs off the UI isolate, retains the original and blocks repository availability until validated activation.

## Remaining release acceptance

- Physical Android/iPhone measurements: proposed page p95 <50 ms and ordinary save p95 <100 ms. Profile memory, cold summary latency, migration duration and frame timings independently. No physical device is available in this session.
- iOS compilation/cipher/protection verification requires macOS/iOS. Android emulator success cannot certify physical backup/transfer or biometric enrollment behavior.
- Ordinary database queries/commits remain synchronous; only bulk migration uses a worker isolate. A dedicated async database isolate remains future work if target-device cold reads/commits exceed frame budgets. Cold monthly summary performance is not yet certified, particularly during concurrent workloads.
- Larger financial report windows still materialize the selected month's records. Investment replay requires a complete ordered history. Neither path claims constant-memory aggregation of arbitrary histories.
- Retention/recovery policy for removing the encrypted legacy source is deliberately unimplemented; unresolved commands and source files are never automatically deleted.
