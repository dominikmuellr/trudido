import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents an automatic backup file
class AutoBackupFile {
  final String filename;
  final int size;
  final DateTime lastModified;
  final String path;

  const AutoBackupFile({
    required this.filename,
    required this.size,
    required this.lastModified,
    required this.path,
  });

  factory AutoBackupFile.fromMap(Map<String, dynamic> map) {
    return AutoBackupFile(
      filename: map['filename'] as String,
      size: map['size'] as int,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['lastModified'] as int,
      ),
      path: map['path'] as String,
    );
  }

  /// Gets a human-readable file size
  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Gets a human-readable date
  String formattedDate([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final difference = currentTime.difference(lastModified);

    if (difference.inDays == 0) {
      return 'Today ${lastModified.hour}:${lastModified.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${lastModified.hour}:${lastModified.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${lastModified.day}/${lastModified.month}/${lastModified.year}';
    }
  }
}

/// Service for managing automatic background backups using Android WorkManager
class AutoBackupService {
  static const AutoBackupService instance = AutoBackupService._();
  const AutoBackupService._();

  static const MethodChannel _channel = MethodChannel('app.files');

  /// Schedules automatic periodic backups
  ///
  /// [intervalHours] - How often to backup (default: 24 hours = daily)
  /// [requiresCharging] - Only backup when device is charging
  Future<bool> scheduleAutoBackup({
    int intervalHours = 24,
    bool requiresCharging = false,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('scheduleAutoBackup', {
        'intervalHours': intervalHours,
        'requiresCharging': requiresCharging,
      });
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to schedule auto backup: $e');
      return false;
    }
  }

  /// Cancels automatic backup scheduling
  Future<bool> cancelAutoBackup() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('cancelAutoBackup');
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to cancel auto backup: $e');
      return false;
    }
  }

  /// Checks if automatic backup is currently scheduled
  Future<bool> isAutoBackupScheduled() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('isAutoBackupScheduled');
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to check auto backup status: $e');
      return false;
    }
  }

  /// Opens the backup folder in the system file manager
  Future<bool> openBackupFolder() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('openBackupFolder');
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to open backup folder: $e');
      return false;
    }
  }

  /// Opens folder picker to choose custom backup location
  Future<bool> chooseBackupFolder() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('chooseBackupFolder');
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to choose backup folder: $e');
      return false;
    }
  }

  /// Gets the currently selected custom backup folder path (if any)
  Future<String?> getCustomBackupFolder() async {
    if (!Platform.isAndroid) return null;

    try {
      final result = await _channel.invokeMethod('getCustomBackupFolder');
      return result as String?;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to get custom backup folder: $e');
      return null;
    }
  }

  /// Clears the custom backup folder setting (reverts to default)
  Future<bool> clearCustomBackupFolder() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('clearCustomBackupFolder');
      return result == true;
    } catch (e) {
      debugPrint(
        '[AutoBackupService] Failed to clear custom backup folder: $e',
      );
      return false;
    }
  }

  /// Lists all available auto backup files
  Future<List<AutoBackupFile>> listAutoBackups() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _channel.invokeMethod('listAutoBackups') as List?;
      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return AutoBackupFile.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to list auto backups: $e');
      return [];
    }
  }

  /// Imports a specific auto backup file
  Future<bool> importAutoBackup(String filename) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod('importAutoBackup', filename);
      return result == true;
    } catch (e) {
      debugPrint('[AutoBackupService] Failed to import auto backup: $e');
      return false;
    }
  }

  /// Gets a user-friendly description of backup frequency
  static String getBackupFrequencyDescription(int intervalHours) {
    if (intervalHours < 24) {
      return 'Every $intervalHours hours';
    } else if (intervalHours == 24) {
      return 'Daily';
    } else if (intervalHours == 168) {
      // 24 * 7
      return 'Weekly';
    } else if (intervalHours == 336) {
      // 24 * 14
      return 'Bi-weekly';
    } else if (intervalHours >= 720) {
      // 24 * 30
      return 'Monthly';
    } else {
      final days = intervalHours ~/ 24;
      return 'Every $days days';
    }
  }

  /// Predefined backup intervals
  static const Map<String, int> backupIntervals = {
    'Every 6 hours': 6,
    'Every 12 hours': 12,
    'Daily': 24,
    'Every 2 days': 48,
    'Every 3 days': 72,
    'Weekly': 168,
    'Bi-weekly': 336,
    'Monthly': 720,
  };
}
