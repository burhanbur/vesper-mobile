# Financial export and reconciliation

Entry point: **Lainnya & Pengaturan -> Ekspor & Rekonsiliasi**.

## Export

CSV export and clipboard copy have been removed. Export is generated locally
without uploading financial data or depending on an API response. The first
complete transaction snapshot is required and sync must not be applying changes.
Only the signed-in user's active accounts, including hidden accounts, are
exported. Other members' accounts, tombstones, credentials and device keys are
excluded. Pending/rejected local ledger entries are included.

### Excel (.xls)

Matches the supplied Money Manager Excel HTML format (not BIFF and not a renamed
CSV). Eleven columns in order: Date, Account, Category, Subcategory, Note, IDR,
Income/Expense, Description, Amount, Currency, Account. When exporting another
currency, its code replaces the IDR heading; values remain in the original
currency and no exchange rate is invented. Flat Vesper categories leave
Subcategory empty. Transfer Category contains the other account; the final
Account column contains the amount in account currency, as in the reference. Transaction descriptions are in Note; Description is empty.

Choose inclusive calendar dates, one currency, and optionally an account.
Settings timezone determines the date range and the displayed calendar time;
changing it clears the prepared workbook. Paired transfers appear once as
Transfer-Out, like the example. A destination-only selection shows Transfer-In.
Both legs still contribute to exact movement totals, which include transfers
and settlements and are not income/expense reporting totals.

Cells are HTML escaped and text cells explicitly use Excel text formatting;
formula-like text also receives a literal apostrophe. Values beyond Excel's
15-digit precision are text so their decimal digits are retained. All financial
calculations use integer minor units. Excel may warn that this HTML workbook's
content differs from its .xls extension, as with the supplied example.

### Money Manager Android (.mmbak)

A new plain SQLite database using the supplied backup's v19 schema, tables and
indexes. The schema asset contains DDL only, never sample financial records.
Includes all owned active accounts, categories (including historical labels),
and all available transaction history, for the selected currency, regardless of Excel date/account filters. Credit cards use the Card group.
Income/expense use DO_TYPE 0/1; transfer debit/credit use 3/4 with reciprocal
transaction and account references. Derived cash settlements remain ledger
entries. Opening entries are calculated as current leaf balance minus exported
movements so a complete history reproduces the current balance. Parent account
containers receive no artificial opening entries.

A separate VESPER_EXPORT table retains original account fields (including credit
limits) and transaction payloads with local sync status. Money Manager does not
understand Vesper investment positions, loan contracts or these extra fields.
This is a Money Manager exchange export, not a complete Vesper disaster-recovery
backup or a new Vesper restore feature. Actual restore in the Money Manager app
still requires manual compatibility testing; SQLite integrity alone does not
prove app-level restore support.

Money Manager's REAL amount column has less precision than Vesper's decimal
strings. Unsupported large amounts are explicitly rejected with an Excel
alternative. Each backup contains one selected currency because Vesper has no exchange-rate
source. Export another .mmbak for each additional currency; no foreign amounts
are silently converted.

Both native and browser exports construct the database in an isolated in-memory
filesystem, never by copying the live encrypted Vesper store. Native uses the
existing sqlite3 dependency. The browser uses its matching 3.7.0 WASM binary,
bundled from the official sqlite3.dart release, without a runtime CDN request:
https://github.com/simolus3/sqlite3.dart/releases/tag/sqlite3-3.7.0
License: assets/licenses/sqlite3-wasm-LICENSE.txt (SQLite itself is public domain).

Android uses the system Create Document picker and a binary saveFile channel.
Cancellation returns without writing. Other native platforms save into app
documents; browsers download a local Blob. Native changes require a full rebuild.

${reconciliation}
## Validation

Unit coverage includes ownership, exact decimals, filtering and pagination,
worksheet layout, literal/escaped cells, transfer pairing, SQLite integrity,
v19 tables, card identity, opening balances and precision/rate failures.
Browser coverage generates and reopens an actual WASM SQLite database.
Widget coverage checks binary Excel delivery, no CSV actions, reconciliation,
and session isolation. The Android document picker and actual Money Manager
restore require a manual device check.
