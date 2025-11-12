import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';

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

  void setImportCallbacks({
    Function(String)? onComplete,
    Function(String)? onError,
    Function()? onRefreshNeeded,
  }) {
    _onImportComplete = onComplete;
    _onImportError = onError;
    _onRefreshNeeded = onRefreshNeeded;
  }

  void setBackupFolderCallback(Function(String)? onFolderSelected) {
    _onBackupFolderSelected = onFolderSelected;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (!Platform.isAndroid) {
      _initialized = true;
      return;
    }
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onImport') {
        final jsonStr = call.arguments as String?;
        debugPrint(
          '[FilesChannel] Received import data, length: ${jsonStr?.length ?? 0}',
        );
        if (jsonStr == null) {
          debugPrint('[FilesChannel] Import data is null, aborting');
          _onImportError?.call('No data received');
          return;
        }
        try {
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
      }
    });
    _initialized = true;
  }

  Future<void> startExport() async {
    if (!Platform.isAndroid) return;
    try {
      // Keep call to ensureInitialized in case caller forgot
      await ensureInitialized();

      // Get actual data to export
      final exportData = await StorageService.exportData();
      final jsonString = json.encode(exportData);

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
}
