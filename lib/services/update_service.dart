import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';

/// GitHub release information
class ReleaseInfo {
  final String tagName;
  final String version;
  final String? releaseNotes;
  final String? apkDownloadUrl;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    this.releaseNotes,
    this.apkDownloadUrl,
    this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    // Find APK asset in release
    String? apkUrl;
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        final name = asset['name'] as String?;
        if (name != null && name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    final tagName = json['tag_name'] as String;
    // Remove 'v' prefix if present (e.g., 'v1.2.0' -> '1.2.0')
    final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    return ReleaseInfo(
      tagName: tagName,
      version: version,
      releaseNotes: json['body'] as String?,
      apkDownloadUrl: apkUrl,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
    );
  }
}

/// Update check result
class UpdateCheckResult {
  final bool updateAvailable;
  final ReleaseInfo? latestRelease;
  final String currentVersion;
  final String? error;

  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestRelease,
    required this.currentVersion,
    this.error,
  });
}

/// Service for checking and downloading app updates from GitHub
class UpdateService {
  static const String _repoOwner = 'dominikmuellr';
  static const String _repoName = 'trudido';

  // GitHub Personal Access Token (read-only public repo access)
  static const String _githubToken = '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';

  static const String _keyLastCheckTime = 'update_last_check_time';
  static const String _keySkippedVersion = 'update_skipped_version';
  static const String _keyAutoCheck = 'update_auto_check';

  SharedPreferences? _prefs;
  PackageInfo? _packageInfo;

  // Singleton
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _packageInfo = await PackageInfo.fromPlatform();
  }

  /// Get current app version
  String get currentVersion => _packageInfo?.version ?? '0.0.0';

  /// Get current build number
  String get currentBuildNumber => _packageInfo?.buildNumber ?? '0';

  /// Check if auto-update check is enabled
  bool get autoCheckEnabled => _prefs?.getBool(_keyAutoCheck) ?? true;

  /// Set auto-update check preference
  Future<void> setAutoCheckEnabled(bool enabled) async {
    await _prefs?.setBool(_keyAutoCheck, enabled);
  }

  /// Get the last time we checked for updates
  DateTime? get lastCheckTime {
    final ms = _prefs?.getInt(_keyLastCheckTime);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  /// Get the version the user chose to skip
  String? get skippedVersion => _prefs?.getString(_keySkippedVersion);

  /// Skip a specific version (user doesn't want to be reminded)
  Future<void> skipVersion(String version) async {
    await _prefs?.setString(_keySkippedVersion, version);
  }

  /// Clear skipped version
  Future<void> clearSkippedVersion() async {
    await _prefs?.remove(_keySkippedVersion);
  }

  /// Check for updates from GitHub
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    try {
      // Check if we should skip this check (unless forced)
      if (!force && !autoCheckEnabled) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
        );
      }

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final headers = <String, String>{
        'Accept': 'application/vnd.github.v3+json',
      };

      // Add authorization if token is set
      if (_githubToken != 'YOUR_GITHUB_TOKEN_HERE' && _githubToken.isNotEmpty) {
        headers['Authorization'] = 'token $_githubToken';
      }

      final response = await http.get(url, headers: headers);

      // Update last check time
      await _prefs?.setInt(
        _keyLastCheckTime,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final release = ReleaseInfo.fromJson(json);

        final updateAvailable = _isNewerVersion(
          release.version,
          currentVersion,
        );

        // Check if user skipped this version
        if (updateAvailable && release.version == skippedVersion && !force) {
          return UpdateCheckResult(
            updateAvailable: false,
            latestRelease: release,
            currentVersion: currentVersion,
          );
        }

        return UpdateCheckResult(
          updateAvailable: updateAvailable,
          latestRelease: release,
          currentVersion: currentVersion,
        );
      } else if (response.statusCode == 404) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'No releases found',
        );
      } else {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'GitHub API error: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Error checking for updates: $e');
      return UpdateCheckResult(
        updateAvailable: false,
        currentVersion: currentVersion,
        error: e.toString(),
      );
    }
  }

  /// Compare versions (returns true if remote > local)
  bool _isNewerVersion(String remoteVersion, String localVersion) {
    try {
      final remoteParts = remoteVersion.split('.').map(int.parse).toList();
      final localParts = localVersion.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (remoteParts.length < 3) remoteParts.add(0);
      while (localParts.length < 3) localParts.add(0);

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('UpdateService: Error comparing versions: $e');
      return false;
    }
  }

  /// Download the APK update
  Future<String?> downloadUpdate(
    ReleaseInfo release, {
    void Function(double progress)? onProgress,
  }) async {
    if (release.apkDownloadUrl == null) {
      debugPrint('UpdateService: No APK download URL available');
      return null;
    }

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        debugPrint('UpdateService: Could not get storage directory');
        return null;
      }

      final fileName = 'trudido-${release.version}.apk';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      // Delete old file if exists
      if (await file.exists()) {
        await file.delete();
      }

      // Download with progress tracking
      final request = http.Request('GET', Uri.parse(release.apkDownloadUrl!));

      // Add auth header if token is set
      if (_githubToken != 'YOUR_GITHUB_TOKEN_HERE' && _githubToken.isNotEmpty) {
        request.headers['Authorization'] = 'token $_githubToken';
      }

      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        debugPrint(
          'UpdateService: Download failed: ${streamedResponse.statusCode}',
        );
        return null;
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = file.openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      debugPrint('UpdateService: Downloaded update to $filePath');
      return filePath;
    } catch (e) {
      debugPrint('UpdateService: Error downloading update: $e');
      return null;
    }
  }

  /// Install the downloaded APK
  Future<bool> installUpdate(String apkPath) async {
    try {
      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('UpdateService: Error installing update: $e');
      return false;
    }
  }
}
