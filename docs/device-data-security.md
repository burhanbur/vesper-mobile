# Device data security and recovery policy

## Current implementation

- Authentication credentials use the existing secure-storage adapter; financial snapshots and the durable outbox do not contain credentials by design.
- Native financial data is a user-scoped SQLite JSON snapshot in application support storage, with WAL enabled. This database is **not encrypted by the application**.
- Browser financial snapshots use localStorage. Browser profile access and injected same-origin scripts can expose that data; this is not equivalent to native secure storage.
- No application lock has been implemented or certified. A dependency appearing in generated plugin registration is not evidence of protection.
- Android backup eligibility is not explicitly restricted in the current application manifest. Do not describe local financial data as excluded from backup.

## Required invariants for future changes

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

These are implementation acceptance criteria, not claims that app lock, encryption or backup recovery already exists.
