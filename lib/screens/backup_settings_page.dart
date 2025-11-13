import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_backup_service.dart';
import '../services/files_channel.dart';
import '../services/markdown_export_service.dart';
import '../services/pdf_export_service.dart';
import '../providers/app_providers.dart';
import '../repositories/notes_repository.dart';

class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  @override
  void initState() {
    super.initState();

    // Set up import callbacks for refreshing UI
    FilesChannel.instance.setImportCallbacks(
      onComplete: (message) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        );
        // Trigger refresh after successful import
        _refreshProviders();
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
          ),
        );
      },
      onRefreshNeeded: () {
        _refreshProviders();
      },
    );
  }

  /// Refreshes all providers after import to ensure UI shows updated data
  Future<void> _refreshProviders() async {
    if (!mounted) return;

    try {
      debugPrint('[BackupSettings] Starting provider refresh after import...');

      // Invalidate and refresh available providers
      ref.invalidate(tasksProvider);
      ref.invalidate(preferencesStateProvider);
      ref.invalidate(notesProvider);

      // Force rebuild by reading providers
      ref.read(tasksProvider.notifier).refresh();
      ref.read(preferencesStateProvider);
      ref.read(notesProvider.notifier).refresh();

      // Wait a moment for providers to refresh
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('[BackupSettings] Provider refresh completed');

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Data refreshed - your imported tasks and notes should now be visible!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[BackupSettings] Error during provider refresh: $e');
      if (!mounted) return;

      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Refresh failed: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showAutoBackupSetupDialog() async {
    int selectedInterval = 24; // Default: daily
    bool requiresCharging = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Setup Automatic Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Configure when automatic backups should run:'),
                const SizedBox(height: 16),

                // Info about backup location
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Backups will be saved to your chosen backup location (set in main settings)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Backup Frequency
                DropdownButtonFormField<int>(
                  value: selectedInterval,
                  decoration: const InputDecoration(
                    labelText: 'Backup Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: AutoBackupService.backupIntervals.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.value,
                          child: Text(entry.key),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedInterval = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Conditions
                CheckboxListTile(
                  title: const Text('Only when charging'),
                  subtitle: const Text('Saves battery life'),
                  value: requiresCharging,
                  onChanged: (value) {
                    setState(() => requiresCharging = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enable'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final success = await AutoBackupService.instance.scheduleAutoBackup(
        intervalHours: selectedInterval,
        requiresCharging: requiresCharging,
      );

      if (!mounted) return;

      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto backup enabled! Backing up ${AutoBackupService.getBackupFrequencyDescription(selectedInterval).toLowerCase()}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to enable auto backup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAutoBackupImportDialog() async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading backups...'),
          ],
        ),
      ),
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final backups = await AutoBackupService.instance.listAutoBackups();

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (backups.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('No automatic backups found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show backup selection dialog
      AutoBackupFile? selectedBackup;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Import Auto Backup'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  const Text('Select a backup to import:'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: backups.length,
                      itemBuilder: (context, index) {
                        final backup = backups[index];
                        return RadioListTile<AutoBackupFile>(
                          value: backup,
                          groupValue: selectedBackup,
                          onChanged: (value) {
                            setState(() => selectedBackup = value);
                          },
                          title: Text(backup.filename),
                          subtitle: Text(
                            '${backup.formattedDate} • ${backup.formattedSize}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedBackup != null
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('Import'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true && selectedBackup != null) {
        if (!mounted) return;
        // Confirm import
        final reallyImport = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Import'),
            content: Text(
              'Import "${selectedBackup!.filename}"?\n\n'
              'This will replace your current data with the backup.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Import'),
              ),
            ],
          ),
        );

        if (reallyImport == true) {
          // Perform the import
          final success = await AutoBackupService.instance.importAutoBackup(
            selectedBackup!.filename,
          );
          if (!mounted) return;

          final scaffoldMessenger = ScaffoldMessenger.of(context);
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Backup imported successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            _refreshProviders();
          } else {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Failed to import backup'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog if still open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading backups: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showExportLocationDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Export Location'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('Where would you like to save your backup?')],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('custom'),
            child: const Text('Custom Folder'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('picker'),
            child: const Text('Choose Location'),
          ),
        ],
      ),
    );

    if (choice == 'custom') {
      await _performCustomFolderExport();
    } else if (choice == 'picker') {
      await _performTraditionalExport();
    }
  }

  Future<void> _performCustomFolderExport() async {
    // Export to the user's chosen backup folder
    try {
      await FilesChannel.instance.startExport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export saved to your backup folder!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _performTraditionalExport() async {
    // Use the traditional file picker
    try {
      await FilesChannel.instance.startExport();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export started - choose save location'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportNotesToMarkdown() async {
    try {
      final success = await MarkdownExportService.exportNotesToFiles();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Notes exported as markdown files!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No notes to export or export cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importNotesFromMarkdown() async {
    try {
      final result = await MarkdownExportService.importNotesFromFiles();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      if (result.success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh notes provider to show imported notes
        ref.read(notesProvider.notifier).refresh();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAllDataToPdf() async {
    try {
      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating PDF export...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final success = await PdfExportService.exportAllDataToPdf();
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.clearSnackBars();

      if (success) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'PDF export ready! Choose where to save or share it.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No data to export or export cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Data')),
      body: ListView(
        children: [
          // Header description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Backup and restore your tasks, categories, notes, and settings.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Backup Location Section
          _buildSectionHeader(context, 'Backup Location'),
          FutureBuilder<String?>(
            future: AutoBackupService.instance.getCustomBackupFolder(),
            builder: (context, snapshot) {
              final customFolder = snapshot.data;
              final hasCustomFolder = customFolder != null;

              return ListTile(
                leading: Icon(
                  Icons.folder_outlined,
                  color: colorScheme.primary,
                ),
                title: const Text('Storage Location'),
                subtitle: Text(
                  hasCustomFolder
                      ? 'Custom folder selected'
                      : 'Default app folder',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasCustomFolder)
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Reset to default',
                        onPressed: () async {
                          final success = await AutoBackupService.instance
                              .clearCustomBackupFolder();
                          if (!mounted) return;
                          if (success) {
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reverted to default folder'),
                              ),
                            );
                          }
                        },
                      ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () async {
                  final success = await AutoBackupService.instance
                      .chooseBackupFolder();
                  if (!mounted) return;
                  if (success) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup folder updated successfully'),
                      ),
                    );
                  }
                },
              );
            },
          ),

          // Export Section
          _buildSectionHeader(context, 'Export'),
          ListTile(
            leading: Icon(
              Icons.upload_file_outlined,
              color: colorScheme.primary,
            ),
            title: const Text('Export All Data (JSON)'),
            subtitle: const Text('Save tasks, notes, and settings'),
            onTap: () async {
              final customFolder = await AutoBackupService.instance
                  .getCustomBackupFolder();
              if (customFolder != null) {
                await _showExportLocationDialog();
              } else {
                await _performTraditionalExport();
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.picture_as_pdf_outlined,
              color: colorScheme.error,
            ),
            title: const Text('Export as PDF'),
            subtitle: const Text('Create readable document of all data'),
            onTap: _exportAllDataToPdf,
          ),
          ListTile(
            leading: Icon(Icons.note_outlined, color: colorScheme.tertiary),
            title: const Text('Export Notes (Markdown)'),
            subtitle: const Text('Save notes as .md files'),
            onTap: _exportNotesToMarkdown,
          ),

          // Import Section
          _buildSectionHeader(context, 'Import'),
          ListTile(
            leading: Icon(Icons.download_outlined, color: colorScheme.primary),
            title: const Text('Import Backup (JSON)'),
            subtitle: const Text('Restore from backup file'),
            onTap: () async {
              try {
                await FilesChannel.instance.startImport();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select your backup file')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.note_add_outlined, color: colorScheme.tertiary),
            title: const Text('Import Notes (Markdown)'),
            subtitle: const Text('Import .md or .json files'),
            onTap: _importNotesFromMarkdown,
          ),

          // Automatic Backup Section
          _buildSectionHeader(context, 'Automatic Backup'),
          FutureBuilder<bool>(
            future: AutoBackupService.instance.isAutoBackupScheduled(),
            builder: (context, snapshot) {
              final isScheduled = snapshot.data ?? false;
              return SwitchListTile(
                secondary: Icon(
                  isScheduled ? Icons.backup : Icons.backup_outlined,
                  color: isScheduled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text('Auto Backup'),
                subtitle: Text(
                  isScheduled
                      ? 'Backing up automatically on schedule'
                      : 'Enable to protect your data automatically',
                ),
                value: isScheduled,
                onChanged: (enabled) async {
                  if (enabled) {
                    await _showAutoBackupSetupDialog();
                  } else {
                    await AutoBackupService.instance.cancelAutoBackup();
                    setState(() {});
                  }
                },
              );
            },
          ),
          FutureBuilder<bool>(
            future: AutoBackupService.instance.isAutoBackupScheduled(),
            builder: (context, snapshot) {
              final isScheduled = snapshot.data ?? false;
              if (!isScheduled) return const SizedBox.shrink();

              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Configure Schedule'),
                    subtitle: const Text('Adjust backup frequency'),
                    onTap: _showAutoBackupSetupDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('Restore from Auto Backup'),
                    subtitle: const Text('Import previous automatic backup'),
                    onTap: _showAutoBackupImportDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('View Backup Files'),
                    subtitle: const Text('Open backup folder'),
                    onTap: () async {
                      final success = await AutoBackupService.instance
                          .openBackupFolder();
                      if (!context.mounted) return;
                      if (!success) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Backup Location'),
                            content: const Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Automatic backups are saved to:'),
                                SizedBox(height: 8),
                                SelectableText(
                                  'Android/data/com.trudido.app/files/AutoBackups/',
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),

          // Help Section
          _buildSectionHeader(context, 'About Backups'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Backup Options',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• JSON backups contain all data and can be restored\n'
                      '• PDF exports create readable documents for sharing\n'
                      '• Markdown files are for notes only\n'
                      '• Automatic backups run in the background on your schedule',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
