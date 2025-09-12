import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_backup_service.dart';
import '../services/files_channel.dart';
import '../services/markdown_export_service.dart';
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
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
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
          content: Text('Data refreshed - your imported tasks and notes should now be visible!'),
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
    bool requiresWifi = true;

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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                           color: Theme.of(context).colorScheme.primary, size: 20),
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
                      .map((entry) => DropdownMenuItem(
                            value: entry.value,
                            child: Text(entry.key),
                          ))
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
                CheckboxListTile(
                  title: const Text('Only on WiFi'),
                  subtitle: const Text('Recommended to avoid mobile data usage'),
                  value: requiresWifi,
                  onChanged: (value) {
                    setState(() => requiresWifi = value ?? true);
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
        requiresWifi: requiresWifi,
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
                          subtitle: Text('${backup.formattedDate} • ${backup.formattedSize}'),
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
          final success = await AutoBackupService.instance.importAutoBackup(selectedBackup!.filename);
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
          children: [
            Text('Where would you like to save your backup?'),
          ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Data'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Backup and restore your tasks, categories, notes, and settings.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Backup Folder Section
            const Text('Backup Location', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<String?>(
              future: AutoBackupService.instance.getCustomBackupFolder(),
              builder: (context, snapshot) {
                final customFolder = snapshot.data;
                
                return Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('Current Location', 
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          customFolder != null 
                            ? 'Custom folder selected' 
                            : 'Default app folder (Android/data/...)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  final success = await AutoBackupService.instance.chooseBackupFolder();
                                  if (!mounted) return;
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  if (success) {
                                    setState(() {}); // Refresh the UI
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Backup folder updated! All future backups will use this location.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Choose Folder'),
                              ),
                            ),
                            if (customFolder != null) ...[
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final success = await AutoBackupService.instance.clearCustomBackupFolder();
                                  if (!mounted) return;
                                  if (success) {
                                    setState(() {}); // Refresh the UI
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Reverted to default app folder'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.restore),
                                label: const Text('Reset'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),

            // Manual Backup & Restore
            const Text('Manual Backup & Restore', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: () async {
                  // Check if user has a custom backup folder set
                  final customFolder = await AutoBackupService.instance.getCustomBackupFolder();
                  
                  if (customFolder != null) {
                    // Show choice: custom folder or traditional picker
                    await _showExportLocationDialog();
                  } else {
                    // No custom folder set, use traditional export
                    await _performTraditionalExport();
                  }
                },
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Export JSON'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await FilesChannel.instance.startImport();
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text('Import started - select your backup file'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text('Import failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import JSON'),
              ),
            ]),
            const SizedBox(height: 16),
            
            // Markdown Notes Export/Import Section
            const Text('Markdown Files', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: _exportNotesToMarkdown,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Export .md'),
              ),
              OutlinedButton.icon(
                onPressed: _importNotesFromMarkdown,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Import .md'),
              ),
            ]),
            const SizedBox(height: 16),
            
            // Auto Backup Settings
            const Text('Automatic Backup', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<bool>(
              future: AutoBackupService.instance.isAutoBackupScheduled(),
              builder: (context, snapshot) {
                final isScheduled = snapshot.data ?? false;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              isScheduled ? Icons.backup : Icons.backup_outlined,
                              color: isScheduled ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isScheduled ? 'Auto Backup: Enabled' : 'Auto Backup: Disabled',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isScheduled ? Colors.green : null,
                                    ),
                                  ),
                                  Text(
                                    isScheduled 
                                      ? 'Your tasks are automatically backed up daily'
                                      : 'Enable automatic backups to protect your data',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isScheduled,
                              onChanged: (enabled) async {
                                if (enabled) {
                                  await _showAutoBackupSetupDialog();
                                } else {
                                  await AutoBackupService.instance.cancelAutoBackup();
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                        if (isScheduled) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: _showAutoBackupSetupDialog,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Configure'),
                              ),
                              TextButton.icon(
                                onPressed: _showAutoBackupImportDialog,
                                icon: const Icon(Icons.restore, size: 16),
                                label: const Text('Import'),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                                  final success = await AutoBackupService.instance.openBackupFolder();
                                  if (!context.mounted) return;
                                  
                                  if (success) {
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Opening file manager...'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    // Show dialog with manual instructions
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Backup Location'),
                                        content: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Your automatic backups are saved to:'),
                                            SizedBox(height: 8),
                                            SelectableText(
                                              'Android/data/com.trudido.app/files/AutoBackups/',
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                backgroundColor: Color(0xFFF5F5F5),
                                              ),
                                            ),
                                            SizedBox(height: 12),
                                            Text('To access this folder manually:'),
                                            SizedBox(height: 4),
                                            Text('1. Open your file manager'),
                                            Text('2. Navigate to Internal Storage'),
                                            Text('3. Go to Android → data → com.trudido.app → files → AutoBackups'),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.folder, size: 16),
                                label: const Text('Location'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Help Section
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'About Backups',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Manual backups let you choose exactly when and where to save\n' 
                      '• Automatic backups run in the background on your schedule\n' 
                      '• Both use the same backup folder you select above\n' 
                      '• JSON files contain all your tasks, categories, and settings',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
