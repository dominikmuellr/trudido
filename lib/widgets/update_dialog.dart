import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

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

/// Dialog for showing update available - opens browser to download
class UpdateDialog extends ConsumerWidget {
  final UpdateCheckResult result;

  const UpdateDialog({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = result.latestRelease!;
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
                          'Current: v${result.currentVersion}',
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

            // Info about downloading
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap "Download" to open GitHub and download the APK.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Skip this version
        TextButton(
          onPressed: () async {
            final service = ref.read(updateServiceProvider);
            await service.skipVersion(release.version);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Skip'),
        ),
        // Later
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later'),
        ),
        // Download - opens browser
        FilledButton.icon(
          onPressed: () async {
            final service = ref.read(updateServiceProvider);
            await service.openReleaseUrl(release.releaseUrl);
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.open_in_browser),
          label: const Text('Download'),
        ),
      ],
    );
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
