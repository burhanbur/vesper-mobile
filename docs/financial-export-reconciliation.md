# Financial export and reconciliation (WM-07)

Entry point: **Lainnya & Pengaturan → Ekspor & Rekonsiliasi**.

## Export contract

The export is a snapshot of the current user's local transaction ledger. The first
complete transaction download must have finished, and export is disabled while
sync is applying changes. It includes pending/rejected local entries, labelled
with their outbox status. It is not a server-certified statement. Only undeleted
accounts owned by the signed-in user are eligible, including hidden accounts;
deleted accounts and other household members' accounts are excluded, even when
household reports are accessible. No tokens, secrets, device identifiers, private
obligation details, or household member profiles are exported.

Choose one currency and optionally one account. Start/end dates are inclusive
calendar dates in the Settings timezone, translated to a half-open UTC interval [start midnight,
midnight after end). Construct the next calendar midnight before converting,
so device daylight-saving days need not be 24 hours. Changing the timezone
clears a prepared export. CSV event timestamps remain UTC. Each transaction leg has its own row. Transfers and derived
investment/obligation cash settlements remain ledger entries, not additional
income/expense. Credit, debit, and net totals use exact integer cents and include
these movements; they are not income/expense report totals. Opening balances are
not transactions and are not included.

CSV is UTF-8 with BOM, comma separated, CRLF terminated. All fields are quoted;
embedded quotes are doubled, and embedded newlines remain inside quoted fields.
Text starting with spreadsheet formula characters (including after whitespace)
is prefixed with an apostrophe. Monetary columns are validated decimal strings
with two decimal places and no grouping separators; they are not rounded.

Columns, in order:

| Column | Meaning |
| --- | --- |
| transaction_id | Ledger row UUID |
| account_id, account_name | Owned account identity and current name |
| currency | Selected currency |
| type | Original ledger type |
| amount | Original stored decimal amount (transfers may be signed) |
| signed_amount | Cash direction: credit positive, debit negative |
| transacted_at_utc | ISO 8601 UTC transaction timestamp |
| category_name | Current owner category label, if available |
| description | Transaction note, including reconciliation audit reference |
| transfer_id | Optional transfer correlation UUID |
| sync_status | Outbox status, pending, or synced |
| version | Local/server row version |
| scope | `owned_local_ledger` |
| period_start_utc | Inclusive selected boundary |
| period_end_exclusive_utc | Exclusive selected boundary |
| exported_at_utc | Snapshot generation time |

Android saves through the system Create Document picker without storage
permissions. The new native channel requires a full app restart/rebuild after
updating; hot reload alone cannot register it. Web triggers a CSV download.
Other native platforms write to the app documents directory and display its path.
Copy CSV is also available on all platforms. The user explicitly chooses export
or copy; no financial data is uploaded by this feature.

## Reconciliation

Reconciliation compares the current local balance, including queued mutations,
against a user-entered **current** statement balance. It does not calculate a
historical closing balance and does not reuse the export period. Only owned,
undeleted leaf CASH accounts in IDR without an active obligation mapping qualify.
Amounts must be whole Rupiah within the existing safe integer presentation limit;
negative statement balances are allowed, and fractional values are rejected.

A statement/reference reason is required. The preview shows recorded, statement,
and difference values. Matching balances create no transaction. A nonzero
difference requires a separate confirmation explaining that it becomes a new
income/expense and affects reports. The user should record missing bank
transactions first to avoid compensating for them twice.

Confirmation checks session ownership and re-reads the eligible account and
balance. A changed balance invalidates the preview. Existing adjustment guards
reject syncing and unresolved command conflicts. The existing atomic local
adjustment saves a categorized INCOME/EXPENSE transaction, balance delta, and sync
queue together. The description embeds JSON with schema, original balance,
statement balance, difference, currency, reference, and comparison timestamp.
The ledger UUID identifies the adjustment; it is exported with the note and
sync status. No prior transaction or opening balance is rewritten. Existing
transaction correction and sync conflict flows apply. References belong in the
note, never in a secret field.

No new backend API, dependency, or database migration is needed: existing
transaction authorization, versioning, idempotency, and sync handle adjustments.

## Delivery validation

Initial delivery waived automated validation at the user's request. The user
subsequently requested WM-07 testing on 2026-10-20.

`test/unit/financial_export_test.dart` covers both snapshot and encrypted indexed
SQLite stores: exact decimal totals, account/currency/owner exclusions, BOM and
CSV quoting, spreadsheet formula escaping, UTC half-open boundaries, tombstones,
pagination past 100 rows, pending/rejected/command statuses, empty/incomplete
snapshots, durable audited adjustments, unchanged/negative balances, precision
and reference validation, ineligible accounts, stale previews and session changes.

`test/widget/financial_export_page_test.dart` covers preparing/copying CSV,
invalid statement input, cancelling and confirming an adjustment, and switching
sessions. Existing balance-adjustment tests cover transaction payloads, replay,
conflicts and atomic rollback. Validation results are recorded in the roadmap
delivery log. Building Android checks the new Kotlin channel; the system document
picker still requires a manual device check.
