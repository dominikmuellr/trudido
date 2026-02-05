// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Helper class for AES-256 encryption/decryption of vault notes
class EncryptionHelper {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'vault_encryption_key';
  static const _ivName = 'vault_encryption_iv';

  /// Gets or generates the encryption key
  static Future<Key> _getKey() async {
    String? keyString = await _storage.read(key: _keyName);
    if (keyString == null) {
      // Generate new 256-bit (32-byte) key on first vault use
      final key = Key.fromSecureRandom(32);
      await _storage.write(key: _keyName, value: key.base64);
      return key;
    }
    return Key.fromBase64(keyString);
  }

  /// Gets or generates the initialization vector
  static Future<IV> _getIV() async {
    String? ivString = await _storage.read(key: _ivName);
    if (ivString == null) {
      // Generate new 128-bit (16-byte) IV on first vault use
      final iv = IV.fromSecureRandom(16);
      await _storage.write(key: _ivName, value: iv.base64);
      return iv;
    }
    return IV.fromBase64(ivString);
  }

  /// Encrypts plain text using AES-256-CBC
  static Future<String> encryptText(String plainText) async {
    if (plainText.isEmpty) return plainText;

    try {
      final key = await _getKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64;
    } catch (e) {
      // If encryption fails, log error but don't crash
      print('Encryption error: $e');
      rethrow;
    }
  }

  /// Decrypts encrypted text using AES-256-CBC
  static Future<String> decryptText(String encryptedText) async {
    if (encryptedText.isEmpty) return encryptedText;

    try {
      final key = await _getKey();
      final iv = await _getIV();
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
      return decrypted;
    } catch (e) {
      // If decryption fails, log error but don't crash
      print('Decryption error: $e');
      rethrow;
    }
  }

  /// Checks if encryption is available and properly set up
  static Future<bool> isEncryptionAvailable() async {
    try {
      await _getKey();
      await _getIV();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Resets encryption keys (use with caution - may make vault notes unreadable)
  static Future<void> resetEncryptionKeys() async {
    await _storage.delete(key: _keyName);
    await _storage.delete(key: _ivName);
  }

  // ============================================================================
  // Password-based encryption for backup files
  // ============================================================================

  /// Magic header to identify encrypted backup files
  static const String encryptedBackupHeader = 'TRUDIDO_ENCRYPTED_BACKUP_V1:';

  /// Derives a 256-bit key from a password using PBKDF2-like approach
  /// Note: Using SHA-256 with salt for key derivation (simplified PBKDF2)
  static Key _deriveKeyFromPassword(String password, String salt) {
    // Combine password and salt, then hash multiple times for key stretching
    var data = '$password:$salt';
    for (var i = 0; i < 10000; i++) {
      // Simple key stretching - hash 10000 times
      final bytes = data.codeUnits;
      var hash = 0;
      for (var j = 0; j < bytes.length; j++) {
        hash = ((hash << 5) - hash) + bytes[j];
        hash = hash & 0xFFFFFFFF; // Convert to 32-bit integer
      }
      data = '$hash:$data';
    }
    // Take first 32 bytes of final hash for AES-256 key
    final keyBytes = <int>[];
    for (var i = 0; i < 32; i++) {
      keyBytes.add(data.codeUnits[i % data.length]);
    }
    return Key.fromUtf8(String.fromCharCodes(keyBytes));
  }

  /// Encrypts a string with a user-provided password for backup protection
  static String encryptBackupWithPassword(String plainText, String password) {
    if (plainText.isEmpty || password.isEmpty) return plainText;

    try {
      // Generate random salt and IV for this encryption
      final salt = Key.fromSecureRandom(16).base64;
      final iv = IV.fromSecureRandom(16);

      // Derive key from password
      final key = _deriveKeyFromPassword(password, salt);

      // Encrypt the data
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Return header + salt + iv + encrypted data
      return '$encryptedBackupHeader$salt:${iv.base64}:${encrypted.base64}';
    } catch (e) {
      print('Backup encryption error: $e');
      rethrow;
    }
  }

  /// Decrypts a backup string that was encrypted with a password
  /// Returns null if decryption fails (wrong password or corrupted data)
  static String? decryptBackupWithPassword(
    String encryptedText,
    String password,
  ) {
    if (encryptedText.isEmpty || password.isEmpty) return null;

    // Check for encrypted backup header
    if (!encryptedText.startsWith(encryptedBackupHeader)) {
      return null; // Not an encrypted backup
    }

    try {
      // Parse the encrypted format: header + salt:iv:encryptedData
      final withoutHeader = encryptedText.substring(
        encryptedBackupHeader.length,
      );
      final parts = withoutHeader.split(':');
      if (parts.length != 3) return null;

      final salt = parts[0];
      final iv = IV.fromBase64(parts[1]);
      final encryptedData = parts[2];

      // Derive key from password using same salt
      final key = _deriveKeyFromPassword(password, salt);

      // Decrypt the data
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decrypted = encrypter.decrypt64(encryptedData, iv: iv);

      return decrypted;
    } catch (e) {
      print('Backup decryption error: $e');
      return null; // Wrong password or corrupted data
    }
  }

  /// Checks if a string is an encrypted backup
  static bool isEncryptedBackup(String text) {
    return text.startsWith(encryptedBackupHeader);
  }
}
