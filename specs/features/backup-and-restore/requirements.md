# Encrypted local backup and restore

Status: current implemented feature contract; final release-device checks
remain in [validation](validation.md).

BR-01. Backup is an explicit action. Encrypt the complete supported local
snapshot before a file leaves the app, using the versioned Argon2id and
AES-256-GCM envelope implemented by the vetted cryptography package. Keep
health values out of filenames, share metadata, logs, API calls, analytics,
and crash metadata. Never invent custom cryptography or upload plaintext.

BR-02. A person chooses a passphrase. Saving it to platform secure storage is
optional and reversible; the passphrase is never included in the backup file.
The app saves a timestamped encrypted file in its `letter/` documents folder
and opens the OS destination sheet. Choosing an installed destination or
cancelling stays under the person's control; no provider receives an automatic
background upload. Help explains file location, password handling, and restore.

BR-03. Restore decrypts and validates version, authentication, schema, and
integrity before touching the existing database. Show a staged preview with
per-record action and reason as well as collection counts. Require an explicit
Merge or Replace choice and a final confirmation. A wrong passphrase, corrupt
or unsupported file, cancellation, or partial stage leaves existing records
unchanged and provides a recoverable message.

BR-04. Merge is deterministic: for the same ID, choose the later `updatedAt`;
equal timestamps keep the device version. Records present only on one side
remain. Replace substitutes the supported collections as previewed. The
staged plan and commit are atomic; no preview is presented as a completed
restore. After commit, derived Cycle, Care, Patterns, and report views refresh
from the restored source records.

BR-05. The superseded sealed angry-draft flow is not a supported backup
collection. If old files contain such records, import must not reveal or
overwrite them. The web development preview remains memory-only and must not
pretend to offer durable health recovery. Backup is available without Plus
and is distinct from any future cloud sync service.
