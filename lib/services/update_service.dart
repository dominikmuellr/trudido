import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub release information
class ReleaseInfo {
  final String tagName;
  final String version;
  final String? releaseNotes;
  final String releaseUrl;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.version,
    this.releaseNotes,
    required this.releaseUrl,
    this.publishedAt,
  });
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

/// Service for checking app updates from GitHub using the public Atom feed
/// This approach has NO rate limits and works for unlimited users
class UpdateService {
  static const String _repoOwner = 'dominikmuellr';
  static const String _repoName = 'trudido';
  static const String _releasesUrl =
      'https://github.com/$_repoOwner/$_repoName/releases';
  static const String _atomFeedUrl = '$_releasesUrl.atom';

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

  /// Get the releases page URL
  String get releasesUrl => _releasesUrl;

  /// Check for updates from GitHub using the public Atom feed (NO rate limits!)
  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    try {
      // Check if we should skip this check (unless forced)
      if (!force && !autoCheckEnabled) {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
        );
      }

      final url = Uri.parse(_atomFeedUrl);
      final response = await http.get(url);

      // Update last check time
      await _prefs?.setInt(
        _keyLastCheckTime,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (response.statusCode == 200) {
        final release = _parseAtomFeed(response.body);

        if (release == null) {
          return UpdateCheckResult(
            updateAvailable: false,
            currentVersion: currentVersion,
            error: 'Could not parse release info',
          );
        }

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
      } else {
        return UpdateCheckResult(
          updateAvailable: false,
          currentVersion: currentVersion,
          error: 'Failed to check for updates: ${response.statusCode}',
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

  /// Parse the Atom feed XML to extract the latest release info
  ReleaseInfo? _parseAtomFeed(String xml) {
    try {
      // Find the first entry (latest release)
      final entryStart = xml.indexOf('<entry>');
      final entryEnd = xml.indexOf('</entry>');

      if (entryStart == -1 || entryEnd == -1) {
        return null;
      }

      final entry = xml.substring(entryStart, entryEnd);

      // Extract tag name from <id> tag
      // Format: tag:github.com,2008:Repository/.../v1.2.0
      final idMatch = RegExp(
        r'<id>tag:github\.com,\d+:Repository/\d+/(.+?)</id>',
      ).firstMatch(entry);
      if (idMatch == null) return null;

      final tagName = idMatch.group(1)!;
      final version = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      // Extract release URL from <link> tag
      final linkMatch = RegExp(
        r'<link[^>]*href="([^"]+)"[^>]*rel="alternate"',
      ).firstMatch(entry);
      final releaseUrl = linkMatch?.group(1) ?? '$_releasesUrl/tag/$tagName';

      // Extract title (release name)
      final titleMatch = RegExp(r'<title>([^<]*)</title>').firstMatch(entry);
      final title = titleMatch?.group(1);

      // Extract content (release notes) - it's HTML encoded
      final contentMatch = RegExp(
        r'<content[^>]*>([^<]*)</content>',
      ).firstMatch(entry);
      String? releaseNotes = contentMatch?.group(1);
      if (releaseNotes != null) {
        // Decode HTML entities
        releaseNotes = releaseNotes
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&amp;', '&')
            .replaceAll('&quot;', '"')
            .replaceAll('&#39;', "'");
        // Strip HTML tags for plain text
        releaseNotes = releaseNotes.replaceAll(RegExp(r'<[^>]*>'), '');
        releaseNotes = releaseNotes.trim();
        if (releaseNotes.isEmpty) releaseNotes = null;
      }

      // Use title as release notes if content is empty
      releaseNotes ??= title;

      // Extract updated date
      final updatedMatch = RegExp(
        r'<updated>([^<]*)</updated>',
      ).firstMatch(entry);
      DateTime? publishedAt;
      if (updatedMatch != null) {
        publishedAt = DateTime.tryParse(updatedMatch.group(1)!);
      }

      return ReleaseInfo(
        tagName: tagName,
        version: version,
        releaseNotes: releaseNotes,
        releaseUrl: releaseUrl,
        publishedAt: publishedAt,
      );
    } catch (e) {
      debugPrint('UpdateService: Error parsing Atom feed: $e');
      return null;
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

  /// Open the releases page in the browser
  Future<bool> openReleasesPage() async {
    try {
      final uri = Uri.parse(_releasesUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('UpdateService: Error opening releases page: $e');
      return false;
    }
  }

  /// Open a specific release page in the browser
  Future<bool> openReleaseUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('UpdateService: Error opening release URL: $e');
      return false;
    }
  }
}
