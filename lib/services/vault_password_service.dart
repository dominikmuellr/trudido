// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2026 Dominik Müller
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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for managing vault passwords/PINs stored securely per folder
class VaultPasswordService {
  static const _storage = FlutterSecureStorage();
  static const _passwordPrefix = 'vault_password_';

  /// Get the storage key for a specific vault folder
  static String _getPasswordKey(String folderId) {
    return '$_passwordPrefix$folderId';
  }

  /// Hash a password using SHA-256 for secure storage comparison
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set password for a specific vault folder
  static Future<void> setVaultPassword(String folderId, String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    final hashedPassword = _hashPassword(password);
    await _storage.write(key: _getPasswordKey(folderId), value: hashedPassword);
  }

  /// Verify password for a specific vault folder
  /// Returns true if password matches, false otherwise
  static Future<bool> verifyVaultPassword(
    String folderId,
    String password,
  ) async {
    final storedHash = await _storage.read(key: _getPasswordKey(folderId));

    if (storedHash == null) {
      return false; // No password set
    }

    final inputHash = _hashPassword(password);
    return storedHash == inputHash;
  }

  /// Check if a vault folder has a password set
  static Future<bool> hasVaultPassword(String folderId) async {
    final password = await _storage.read(key: _getPasswordKey(folderId));
    return password != null;
  }

  /// Remove password for a specific vault folder
  static Future<void> removeVaultPassword(String folderId) async {
    await _storage.delete(key: _getPasswordKey(folderId));
  }

  /// Update password for a vault folder (requires old password verification)
  static Future<bool> updateVaultPassword(
    String folderId,
    String oldPassword,
    String newPassword,
  ) async {
    // Verify old password first
    final isValid = await verifyVaultPassword(folderId, oldPassword);
    if (!isValid) {
      return false;
    }

    // Set new password
    await setVaultPassword(folderId, newPassword);
    return true;
  }

  /// Clear all vault passwords (use with caution - for testing or reset)
  static Future<void> clearAllVaultPasswords() async {
    await _storage.deleteAll();
  }
}
