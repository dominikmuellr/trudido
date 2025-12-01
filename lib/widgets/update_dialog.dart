import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';

/// GitHub releases URL
const String _githubReleasesUrl =
    'https://github.com/dominikmuellr/trudido/releases';

/// Provider for the update service
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

/// Provider for checking updates (call .refresh to force check)
final updateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final service = ref.read(updateServiceProvider);
  await service.init();
  return service.checkForUpdates();
});

/// Dialog for showing update available
class UpdateDialog extends ConsumerStatefulWidget {
  final UpdateCheckResult result;

  const UpdateDialog({super.key, required this.result});

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final release = widget.result.latestRelease!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(Icons.system_update, color: cs.primary, size: 48),
      title: const Text('Update Available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current: v${widget.result.currentVersion}',
                          style: TextStyle(color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New: v${release.version}',
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: cs.onPrimaryContainer),
                ],
              ),
            ),

            // Release notes
            if (release.releaseNotes != null &&
                release.releaseNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'What\'s new:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Text(
                    release.releaseNotes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],

            // Download progress
            if (_isDownloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                'Downloading... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // GitHub source info
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(_githubReleasesUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Download from GitHub Releases',
                        style: TextStyle(color: cs.primary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Skip this version
        TextButton(
          onPressed: _isDownloading
              ? null
              : () async {
                  final service = ref.read(updateServiceProvider);
                  await service.skipVersion(release.version);
                  if (context.mounted) Navigator.pop(context);
                },
          child: const Text('Skip'),
        ),
        // Later
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        // Download & Install
        FilledButton.icon(
          onPressed: _isDownloading ? null : _downloadAndInstall,
          icon: _isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_isDownloading ? 'Downloading...' : 'Update'),
        ),
      ],
    );
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _error = null;
    });

    try {
      final service = ref.read(updateServiceProvider);
      final release = widget.result.latestRelease!;

      final apkPath = await service.downloadUpdate(
        release,
        onProgress: (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (apkPath == null) {
        setState(() {
          _isDownloading = false;
          _error = 'Download failed. Please try again.';
        });
        return;
      }

      // Install the APK
      final installed = await service.installUpdate(apkPath);

      if (!installed && mounted) {
        setState(() {
          _isDownloading = false;
          _error = 'Could not open installer. Check your Downloads folder.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = 'Error: $e';
        });
      }
    }
  }
}

/// Shows the update dialog if an update is available
Future<void> showUpdateDialogIfAvailable(
  BuildContext context,
  WidgetRef ref, {
  bool force = false,
}) async {
  final service = ref.read(updateServiceProvider);
  await service.init();

  final result = await service.checkForUpdates(force: force);

  if (result.updateAvailable &&
      result.latestRelease != null &&
      context.mounted) {
    showDialog(
      context: context,
      builder: (context) => UpdateDialog(result: result),
    );
  } else if (force && context.mounted) {
    // Show "no updates" message when manually checking
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error != null
              ? 'Error checking for updates: ${result.error}'
              : 'You\'re on the latest version (v${result.currentVersion})',
        ),
      ),
    );
  }
}
