# Encrypted Vault Folder Feature

## Overview

The vault folder feature provides **AES-256 encryption** for notes stored in special vault folders. Notes in vault folders are automatically encrypted before being saved to disk and decrypted when loaded.

## How It Works

### 1. **Encryption**

- Uses **AES-256-CBC** encryption (industry standard)
- Encryption keys are securely stored using `flutter_secure_storage`
- Each device generates its own unique encryption key on first use
- Both note titles and content are encrypted for vault folders

### 2. **Folder Model**

The `Folder` model now includes an `isVault` boolean field:

```dart
@HiveField(10, defaultValue: false)
bool isVault; // Mark as encrypted vault folder
```

### 3. **Note Model**

The `Note` model now includes a `folderId` field to link notes to folders:

```dart
@HiveField(6)
String? folderId; // Reference to folder (including vault folders)
```

### 4. **Automatic Encryption/Decryption**

The `NotesRepository` automatically handles encryption:

- When **creating/updating** a note in a vault folder → encrypts title and content
- When **reading** a note from a vault folder → decrypts title and content
- Regular notes (not in vault folders) are stored as plain text

## Usage

### Creating a Vault Folder

```dart
final vaultFolder = Folder(
  name: 'Private Notes',
  color: Colors.red.value,
  icon: 'lock',
  isVault: true, // Mark as vault folder
);
await folderRepository.createFolder(vaultFolder);
```

### Creating a Note in a Vault Folder

```dart
// The note will be automatically encrypted when saved
final note = await notesRepository.createNote(
  title: 'Secret Note',
  content: 'This content will be encrypted',
  folderId: vaultFolder.id, // Link to vault folder
);
```

### Reading Notes from Vault

```dart
// Notes are automatically decrypted when read
final allNotes = await notesRepository.getAllNotes();
// Vault notes appear decrypted in the UI
```

## Security Features

- **AES-256-CBC encryption**: Military-grade encryption standard
- **Secure key storage**: Keys stored in platform secure storage (Keychain on iOS, Keystore on Android)
- **Automatic encryption**: No manual intervention needed
- **Transparent to UI**: Encryption/decryption happens at the repository level

## UI Integration (To Be Implemented)

To complete the vault feature, you'll want to add:

1. **Vault Folder Icon**: Display a lock icon for vault folders in the folder list
2. **Folder Selection**: Allow users to select a folder when creating/editing notes
3. **Authentication** (optional): Use `local_auth` package to require biometric/PIN before accessing vault folders
4. **Settings**: Option to create/manage vault folders

## Files Modified

1. **`lib/models/folder.dart`**: Added `isVault` field
2. **`lib/models/note.dart`**: Added `folderId` field
3. **`lib/utils/encryption_helper.dart`**: New encryption utility class
4. **`lib/repositories/notes_repository.dart`**: Added encryption/decryption logic
5. **`lib/controllers/notes_controller.dart`**: Added `folderId` parameter
6. **`pubspec.yaml`**: Added `encrypt` and `flutter_secure_storage` packages

## Important Notes

⚠️ **Key Management**:

- The encryption key is unique per device
- If the encryption key is lost, encrypted notes cannot be recovered
- Resetting encryption keys will make existing vault notes unreadable

⚠️ **Backup/Export**:

- Exported notes will be in their current state (encrypted if from vault)
- Consider adding a "decrypt on export" option for vault notes

⚠️ **Testing**:

- Vault notes can only be read on the device where they were created
- Test the encryption by checking the raw Hive box data

## Next Steps

1. **Add UI for folder selection** in note editor
2. **Add vault folder creation** in folder management screen
3. **Add lock icon** for vault folders in the folder list
4. **Add biometric authentication** (optional) for vault access
5. **Add settings** for vault management
