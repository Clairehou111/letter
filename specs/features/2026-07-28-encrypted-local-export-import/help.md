# Letter Within Backup & Restore — User Guide

This guide explains how to export your Letter Within data to a file, optionally upload
it to cloud storage, and restore it on the same or a different device.

---

## 1. Understanding Letter Within Backups

Letter Within creates **encrypted `.letter` files** that contain your saved records:
period logs, Care actions, health records, private notes, cycle reflections,
and moment check-ins.

What is **never** included:
- Sealed impulse letters (protected by their own 24-hour lock)
- Unsaved text or clipboard contents
- Your backup password (Letter Within never uploads it)

Every backup is protected by a password you choose. Without the correct
password, the file cannot be opened — not by Letter Within, not by anyone.

---

## 2. How To Export Your Data

### Step 1: Open Backup Settings
Go to **Settings** → **Encrypted local backup** (or **You** → **Backup**).

### Step 2: Create The Backup
1. Tap **"Create encrypted backup"**.
2. Choose a password. Letter Within will offer to save it securely on your device so
   you don't have to re-enter it next time.
3. The encrypted `.letter` file is generated.

### Step 3: Save The File
After encryption, your device's **share sheet** opens. From here you can:
- **Save to Files** (iOS) or **Downloads** (Android) — the file is also saved
  automatically in Letter Within's local documents folder.
- **AirDrop** to another Apple device.
- **Send via email, messaging app, or cloud storage app** (see Section 3).

The file is named with its creation timestamp, for example
`letter-backup-2026-08-04-18-49-25-123.letter`, and is saved in a dedicated
`letter` folder. Renaming it does not affect the backup — Letter Within identifies the
format from the file contents, not the name.

The local save always happens first. The native destination sheet then shows
the storage providers installed on the device. You can choose one provider or
cancel and keep only the local copy. Letter Within never uploads the same backup to
all cloud services in the background.

### Where The File Lives On Your Device
Letter Within saves a local copy at:
- **iOS**: Inside the `letter` folder in the Letter Within app's Documents folder
  (accessible via Files → On My iPhone/iPad → Letter Within, or via Finder when
  connected to a Mac).
- **Android**: Inside the Letter Within app's internal files directory, under its
  `letter` subfolder (accessible via a file manager app, under
  Android/data/com.letter.app/files/).

**Important**: The local copy is tied to the app. If you delete the Letter Within app
without saving the backup elsewhere, the local copy is also deleted. Always
save the file to an external location (Files app, cloud, or another device).

---

## 3. Uploading To Cloud Storage (Optional)

Letter Within does not have built-in cloud sync. You can manually upload the
`.letter` file to any cloud service:

| Service | How To Upload |
|---|---|
| **iCloud Drive** | From the share sheet, tap "Save to Files" → choose an iCloud folder. |
| **Google Drive** | From the share sheet, tap the Drive app icon, or open Drive and upload the file. |
| **Dropbox** | From the share sheet, tap the Dropbox app icon, or open Dropbox and upload. |
| **Email (to yourself)** | From the share sheet, tap your email app and send the file as an attachment. |

**Recommended**: Keep at least one copy outside the device that created it.
Upload the encrypted file to iCloud Drive, Google Drive, Dropbox, or another
private storage location. Keep the backup password separate from the file—for
example, in a password manager. Do not rely on the app's local copy alone:
uninstalling the app or losing the device can remove it.

**Privacy note**: The file is already encrypted with your password before it
leaves Letter Within. Even if someone gains access to your cloud storage, they cannot
read your health data without your backup password. It is normal for a text
editor to show envelope fields such as `salt` and `nonce`: these are random
parameters needed for decryption, not secrets or readable health data. The
records remain inside the authenticated ciphertext.

---

## 4. How To Import / Restore A Backup

### Step 1: Get The File Onto This Device
- If the file is in cloud storage, download it to your device first.
- If the file was AirDropped or emailed, save it to Files/Downloads.
- If the file is on another device, transfer it using any method (AirDrop,
  email, messaging app, USB).

### Step 2: Open Backup Settings
Go to **Settings** → **Encrypted local backup**.

### Step 3: Choose An Import Policy
Letter Within offers two ways to bring records in. You will see a **preview of exact
record counts** before anything changes:

#### Merge (Recommended)
Merges the backup into your current records using these rules:
- **New records** (IDs not on this device) → **Added**.
- **Duplicate records** (same ID on both devices) → The **newer one wins**
  (based on last-updated timestamp). If the backup record is newer, it
  replaces the local record. If the local record is newer, it stays.
- **Records only on this device** → **Kept unchanged**.
- **No records are deleted** during a merge.

Use merge when you've been using Letter Within on two devices and want to combine
their data.

#### Replace
Replaces **all** records in each collection with the backup's version:
- Collections present in the backup → **Replaced entirely**.
- Collections not in the backup → **Left unchanged**.
- Records only on this device but not in the backup → **Removed** from those
  collections.

Use replace when you're setting up a new device and want an exact copy of
your data from another device.

### Step 4: Enter Your Password
1. Tap **"Preview merge"** or **"Preview replace"**.
2. Select the `.letter` file from your device.
3. Enter the password you used when creating the backup.
   - If you saved the password on this device, Letter Within will offer to reuse it.

**Write down or memorize this password before you move the file.** Letter Within
cannot reset or recover it. A password saved in Letter Within's secure storage stays
on the original device and is not included in the backup, so it will not be
available automatically on a new device.

### Step 5: Review The Preview
Letter Within shows you exactly what will change:
- How many records will be **added**, **replaced**, **kept**, or **removed**
- Broken down by collection (Periods, Care records, Health records, etc.)

### Step 6: Confirm Or Discard
- Tap **"Merge previewed records"** or **"Replace this device..."** to apply.
- Or tap **"Discard preview"** to cancel — your data is unchanged.

---

## 5. Merge Conflict Rules (Detailed)

When merging, Letter Within compares records by their internal ID and timestamp:

| Situation | Result |
|---|---|
| Record exists **only in backup** | Added to this device. |
| Record exists **only on device** | Kept unchanged. |
| Same ID, backup is **newer** | Backup version replaces device version. |
| Same ID, device is **newer** | Device version is kept. |
| Same ID, **same timestamp** | Device version is kept (no change). |

**Important**: Letter Within never "merges fields" within a single record. Each
record (a period entry, a Care action, a health record) is replaced as a
whole unit. If you edited the same period entry differently on two devices,
only the newer version survives.

---

## 6. Managing Your Backup Password

### Saving Your Password
When you create a backup, Letter Within asks: **"Remember this password?"**
- Tap **"Save password"** to store it in your device's secure keychain
  (iOS Keychain / Android Keystore). It stays on this device only.
- Tap **"Not now"** to skip — you'll need to enter it manually next time.

### Using A Saved Password
On future backups and restores, Letter Within offers: **"Use saved backup password?"**
- Tap **"Reuse saved password"** to skip typing.
- Tap **"Use different password"** to enter a new one.

### Forgetting A Saved Password
You can remove the stored password at any time. In the backup screen, tap
**"Forget"** next to the password status. Your existing `.letter` files are
unaffected — you'll just need to enter the password manually next time.

### What If I Forget My Password?
Letter Within **cannot recover** a forgotten backup password. The file is encrypted
with AES-256-GCM and cannot be opened without the correct password. We
recommend:
- Write your password down and store it somewhere safe (separate from your
  device).
- Use a password manager.
- Verify that you can recall the password before deleting the original data or
  moving to a new device.
- Create a new backup with a password you'll remember, and discard the old
  file.

---

## 7. Troubleshooting

| Problem | What To Do |
|---|---|
| "The password is incorrect or this backup has been changed" | Double-check you entered the exact password used during export. Passwords are case-sensitive. |
| "This backup was created by an unsupported version of Letter Within" | Update Letter Within to the latest version on both devices. |
| "This backup does not contain a valid Letter Within data package" | The file may be corrupted. Try exporting a fresh backup from the original device. |
| "This backup is too large" | The backup exceeds 5 MB. This is unusual — contact support if it persists. |
| Import preview shows unexpected counts | The counts reflect what's actually in the backup file. If numbers seem wrong, verify you selected the correct file. |
| App crashes during import | Your data is safe. Letter Within stages imports and only applies changes after you confirm. Restart Letter Within and try again. |

---

## 8. Best Practices

- **Back up before switching devices.** Export from the old device, transfer
  the `.letter` file (via AirDrop, cloud, or email), then import on the new
  device using **Merge**.
- **Create regular backups.** We recommend exporting after significant data
  entry — e.g., after logging a full cycle or recording several Care actions.
- **Keep at least one copy off-device.** Save the `.letter` file to cloud
  storage or email it to yourself. If your phone is lost or damaged, the
  local copy inside the Letter Within app is lost too.
- **Use the same password for all backups** if you save it on-device. This
  way Letter Within can reuse it automatically.
- **Merge, don't replace**, unless you're setting up a fresh device. Merge
  preserves data from both sources; replace discards everything not in the
  backup file.
