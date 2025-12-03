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
      // Generate new key if it doesn't exist
      final key = Key.fromSecureRandom(32); // 256 bits for AES-256
      await _storage.write(key: _keyName, value: key.base64);
      return key;
    }
    return Key.fromBase64(keyString);
  }

  /// Gets or generates the initialization vector
  static Future<IV> _getIV() async {
    String? ivString = await _storage.read(key: _ivName);
    if (ivString == null) {
      // Generate new IV if it doesn't exist
      final iv = IV.fromSecureRandom(16); // 128 bits for AES
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
}
