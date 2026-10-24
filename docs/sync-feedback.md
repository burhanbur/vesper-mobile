# Sync feedback

A successful refresh is not proof that every local mutation has settled. The
dashboard and Settings sync action wait for completion and inspect both the
refresh error and remaining outbox before reporting success.

Pending commands are waiting to send. Rejected/conflicting commands need review;
the banner opens their server messages instead of offering a retry that cannot
resolve them. Acknowledged commands, approved cancellations awaiting settlement,
and requested recovery commands retain their waiting-for-confirmation status.
Unknown statuses require review rather than being silently treated as success.
Mixed queues retain a sync action for their sendable entries and a details link.

The status sheet displays entity labels, statuses and server errors without raw
financial payloads. Existing conflict resolution remains available. No command
is deleted, reset, automatically retried or marked applied by these views.
Only the repository's existing validated push/pull/recovery flow settles it.
