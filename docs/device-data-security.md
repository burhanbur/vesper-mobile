# Device data security and recovery policy

## Current implementation

- Authentication credentials use the existing secure-storage adapter; financial snapshots and the durable outbox do not contain credentials by design.
- Native active v3 data, outbox, metadata, financial query indexes and WAL use SQLite3MultipleCiphers ChaCha20-Poly1305 authenticated page encryption. Existing v0/v1/v2 snapshots migrate through the authenticated AES-256-GCM compatibility reader; the encrypted original file is retained. User-scoped filenames and approximate file sizes remain visible. The randomly generated per-user 256-bit key is persisted and read back through secure storage before encryption, with device-only unlocked keychain accessibility on iOS. No key is included in the database or financial exports.
- Browser financial snapshots use localStorage. Browser profile access and injected same-origin scripts can expose that data; this is not equivalent to native secure storage.
- Optional device-wide app lock is implemented using `local_auth` with device credentials/biometrics. Enabling and disabling require platform verification. Enabled lock starts closed, locks on inactive, and invalidates authentication results on hidden/paused/detached or identity change. Cancellation, platform errors, missing credentials and unreadable preferences do not reveal financial content. Failed preference reads have an explicit retry screen; unavailable authentication never silently bypasses an enabled lock. Browser lock is unavailable and browser data remains unencrypted; use a trusted private browser profile.
- The root gate conceals Navigator routes, blocks focus/semantics/input and retains the same user's drafts. Route pop guards prevent hardware back from dismissing a concealed draft. The lifecycle privacy shield also blocks keyboard focus when app lock is disabled. A different user/session identity resets routes so a later user cannot inherit previous-user dialogs. Lock/logout/authentication failure never deletes persisted pending changes or encryption keys.
- Android backup and device-transfer exclusions are explicit, with `allowBackup=false`, legacy full-backup rules and Android 12+ cloud/device-transfer rules for all storage domains. `FLAG_SECURE` protects task previews, screenshots and non-secure displays from the first native activity frame. The merged debug manifest and APK build were checked.
- iOS setup includes Face ID description, a native task-preview shield, and a storage-protection bridge applying complete file protection and backup exclusion to application support and existing Vesper files/sidecars. Native encryption keys are not synchronizable/migratable. This code has **not** been compiled or certified on macOS/iOS in this environment.

## Encryption migration and failure behavior

- v0 snapshots are validated before modification, then their complete JSON is encrypted in one SQLite transaction. IDs, exact decimal strings, tombstones, every outbox status, cursors, investment coverage and reconciliation staging are retained.
- v1 marks a durable encrypted commit whose old logical pages/WAL may still require cleanup. Restart resumes secure-delete/VACUUM/checkpoint cleanup. v2 records completion. These operations do not promise forensic erasure of historical flash copies, old backups or operating-system snapshots.
- Wrong/missing/corrupted keys, invalid ciphertext, unsupported versions, full storage and failed commits propagate errors; they never trigger a reset, key replacement for encrypted data or an empty cache. The login screen explains local-data failures and advises against clearing data/reinstalling.
- Secure key creation is serialized with a SQLite write lock. No restore, key rotation or uninstall/reinstall recovery is exposed. There is no approved plaintext debug financial export.
- v3 copies and canonically validates the entire source in a worker isolate before switching a secure-storage pointer. A source write lock protects copy and activation; writes in the intervening gap are detected by a source hash. After activation, a missing/corrupt destination never falls back to the old outbox. Normal edits update only affected rows plus outbox/metadata using a field-level rollback journal.
- Whole-history migration remains a one-time operation; monthly totals have an indexed cold read and incremental exact-cent cache. Ordinary commits and bounded list queries remain synchronous with measured host p95 below the proposed targets; a dedicated asynchronous database isolate and physical cold/frame/memory profiling remain future work. See `local-storage-performance.md`.

## Verification in this continuation

- Eight indexed-store regressions cover exact content, unknown metadata, row-level writes, atomic rollback, keyset filters, migration/activation interruption, source mutation, missing active destination, owner/key mismatch, concurrent writers and exact monthly-cache updates. Existing transfer and investment workflows run against both stores (44 tests).
- Native sqlite3mc is enabled through the existing sqlite3 package build hook. Its MIT notice is bundled in `assets/licenses/SQLite3MultipleCiphers.txt` and registered in Flutter licenses. [Cipher documentation](https://utelle.github.io/SQLite3MultipleCiphers/docs/ciphers/cipher_chacha20/) describes page authentication; [license source](https://github.com/utelle/SQLite3MultipleCiphers/blob/main/LICENSE).

- Five app-lock controller tests plus gate/session-routing widget tests cover startup, preference failure, cancellation/unavailability, duplicate/stale prompts, enable/disable persistence, interruption, focus/semantics and same-user draft retention.
- Six encryption/key/migration tests cover user authentication binding, tampering, fresh nonces, complete pending/rejected/conflict/acknowledged outbox retention, failed migration commit, restart at the cleanup checkpoint, wrong/missing/malformed keys and database/WAL/SHM plaintext-marker checks.
- Two integration tests pass on Android 17/API 37 emulator using real SQLite, secure storage and local authentication: exact restart/missing-key recovery behavior and locked presentation after cancelled/unavailable platform verification. Synthetic test users only; existing financial data is untouched.
- Physical Android biometric success/enrollment changes, manufacturer backup/transfer behavior, iOS and full-device TalkBack/VoiceOver certification remain unverified.

## Invariants for current and future changes

1. Locking, logout, session expiry and authentication failure must not erase snapshots, pending commands, cursors or reconciliation staging.
2. Lock UI must fail closed after backgrounding and must not expose financial content while platform authentication is pending, cancelled, unavailable or fails. Unsupported devices need an explicit product policy; never silently bypass an enabled lock.
3. Use device credentials/biometrics through platform authentication. Do not invent a locally hashed short PIN or put encryption keys in preferences, logs or exports.
4. Application lock is a presentation/access control, **not database encryption**. Encryption requires a separate authenticated, versioned key and migration design.
5. Never overwrite a database on restore while it has unresolved commands. Replaying a restored outbox must retain original command identities and respect server idempotency.
6. Exports must be explicit and authenticated, exclude credentials, identify the owner/schema and use authenticated encryption before leaving app-private storage. Plaintext debug exports are not an approved backup feature.
7. Do not enable destructive key rotation, uninstall/reinstall recovery or cloud restore until key loss, interrupted migration and pending-command recovery have been tested.

## Required validation before claiming completion

- Android/iOS background/resume, obscured task previews, authentication cancellation/failure, missing device credential, biometric enrollment changes and session/user changes during a prompt.
- Persistence before/after locking and restart with pending, rejected, conflicted and acknowledged commands.
- Native database/WAL/SHM and platform backup inclusion audit; iOS data-protection and backup policy audit.
- Explicit browser limitations and shared-device guidance.

The unchecked physical/platform acceptance criteria must not be inferred from passing automated tests. Backup restore and terminal investment cancellation are not implemented recovery paths.
