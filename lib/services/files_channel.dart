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

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../utils/encryption_helper.dart';

/// FilesChannel bridges Flutter and native (Android) import/export using SAF.
/// On Android, it uses MethodChannel('app.files') to trigger native pickers.
/// On iOS/web/desktop, it no-ops for now.
class FilesChannel {
  FilesChannel._();
  static final FilesChannel instance = FilesChannel._();

  static const MethodChannel _ch = MethodChannel('app.files');

  bool _initialized = false;
  Function(String)? _onImportComplete;
  Function(String)? _onImportError;
  Function()? _onRefreshNeeded;
  Function(String)? _onBackupFolderSelected;
  Function(int)? _onMarkdownExportComplete;

  /// Callback to request password for encrypted backup import
  /// Returns the password entered by user, or null if cancelled
  Future<String?> Function()? _onPasswordRequired;

  void setImportCallbacks({
    Function(String)? onComplete,
    Function(String)? onError,
    Function()? onRefreshNeeded,
    Future<String?> Function()? onPasswordRequired,
  }) {
    _onImportComplete = onComplete;
    _onImportError = onError;
    _onRefreshNeeded = onRefreshNeeded;
    _onPasswordRequired = onPasswordRequired;
  }

  void setBackupFolderCallback(Function(String)? onFolderSelected) {
    _onBackupFolderSelected = onFolderSelected;
  }

  void setMarkdownExportCallback(Function(int)? onComplete) {
    _onMarkdownExportComplete = onComplete;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }
    _ch.setMethodCallHandler((call) async {
      // Handle request for auto-backup data from Android
      if (call.method == 'getAutoBackupData') {
        debugPrint('[FilesChannel] Android requested auto-backup data');
        try {
          final jsonData = await StorageService.exportDataForAutoBackup();
          debugPrint(
            '[FilesChannel] Returning backup data, length: ${jsonData.length}',
          );
          return jsonData;
        } catch (e, st) {
          debugPrint('[FilesChannel] Error getting auto-backup data: $e\n$st');
          return null;
        }
      }
      if (call.method == 'onImport') {
        var jsonStr = call.arguments as String?;
        debugPrint(
          '[FilesChannel] Received import data, length: ${jsonStr?.length ?? 0}',
        );
        if (jsonStr == null) {
          debugPrint('[FilesChannel] Import data is null, aborting');
          _onImportError?.call('No data received');
          return null;
        }
        try {
          // Check if backup is encrypted
          if (EncryptionHelper.isEncryptedBackup(jsonStr)) {
            debugPrint(
              '[FilesChannel] Detected encrypted backup, requesting password...',
            );
            if (_onPasswordRequired == null) {
              _onImportError?.call('Encrypted backup requires password dialog');
              return null;
            }
            final password = await _onPasswordRequired!();
            if (password == null || password.isEmpty) {
              _onImportError?.call('Password required for encrypted backup');
              return null;
            }
            final decrypted = EncryptionHelper.decryptBackupWithPassword(
              jsonStr,
              password,
            );
            if (decrypted == null) {
              _onImportError?.call('Wrong password or corrupted backup');
              return null;
            }
            jsonStr = decrypted;
            debugPrint('[FilesChannel] Backup decrypted successfully');
          }

          debugPrint('[FilesChannel] Parsing JSON...');
          final map = json.decode(jsonStr) as Map<String, dynamic>;
          debugPrint(
            '[FilesChannel] JSON parsed successfully, keys: ${map.keys.toList()}',
          );
          debugPrint('[FilesChannel] Calling StorageService.importData...');
          await StorageService.importData(map);
          debugPrint('[FilesChannel] Import completed successfully');
          _onRefreshNeeded?.call();
          _onImportComplete?.call('Import completed successfully');
        } catch (e, st) {
          debugPrint('[FilesChannel] import handler error: $e');
          debugPrint('[FilesChannel] Stack trace: $st');
          _onImportError?.call('Import failed: $e');
        }
      } else if (call.method == 'onBackupFolderSelected') {
        final folderUri = call.arguments as String?;
        debugPrint('[FilesChannel] Backup folder selected: $folderUri');
        if (folderUri != null) {
          _onBackupFolderSelected?.call(folderUri);
        }
      } else if (call.method == 'onMarkdownExportComplete') {
        final count = call.arguments as int? ?? 0;
        debugPrint('[FilesChannel] Markdown export complete: $count notes');
        _onMarkdownExportComplete?.call(count);
      }
    });
    _initialized = true;
  }

  /// Starts the export process with optional password protection
  /// If [password] is provided, the backup will be encrypted
  Future<void> startExport({String? password}) async {
    if (!Platform.isAndroid) return;
    try {
      // Keep call to ensureInitialized in case caller forgot
      await ensureInitialized();

      final exportData = await StorageService.exportData();
      var jsonString = json.encode(exportData);

      // Encrypt backup if password is provided
      if (password != null && password.isNotEmpty) {
        debugPrint('[FilesChannel] Encrypting backup with password...');
        jsonString = EncryptionHelper.encryptBackupWithPassword(
          jsonString,
          password,
        );
        debugPrint('[FilesChannel] Backup encrypted successfully');
      }

      // Trigger native export flow with real data
      await _ch.invokeMethod('startExport', jsonString);
    } catch (e, st) {
      debugPrint('[FilesChannel] startExport error: $e\n$st');
    }
  }

  Future<void> startImport() async {
    if (!Platform.isAndroid) return;
    try {
      await ensureInitialized();
      await _ch.invokeMethod('startImport');
    } catch (e, st) {
      debugPrint('[FilesChannel] startImport error: $e\n$st');
    }
  }

  /// Start markdown export via SAF (for restricted storage like Nextcloud)
  /// [notes] is a list of maps with 'filename' and 'content' keys
  Future<bool> startMarkdownExport(List<Map<String, String>> notes) async {
    if (!Platform.isAndroid) return false;
    try {
      await ensureInitialized();
      final result = await _ch.invokeMethod('startMarkdownExport', notes);
      return result == true;
    } catch (e, st) {
      debugPrint('[FilesChannel] startMarkdownExport error: $e\n$st');
      return false;
    }
  }
}
