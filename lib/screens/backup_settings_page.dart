// Trudido - A privacy-focused todo and notes app
// Copyright (C) 2025 Dominik Müller
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auto_backup_service.dart';
import '../services/files_channel.dart';
import '../services/markdown_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/storage_service.dart';
import '../providers/app_providers.dart';
import '../repositories/notes_repository.dart';
import '../repositories/note_folder_repository.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

class BackupSettingsPage extends ConsumerStatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  ConsumerState<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends ConsumerState<BackupSettingsPage> {
  @override
  void initState() {
    super.initState();

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
      onPasswordRequired: () => _showPasswordInputDialog(
        title: 'Encrypted Backup',
        message:
            'This backup is password protected. Enter the password to decrypt:',
      ),
    );
  }

  /// Shows a password input dialog and returns the entered password
  Future<String?> _showPasswordInputDialog({
    required String title,
    required String message,
    bool isConfirm = false,
  }) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscureText,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
                ),
              ),
              if (isConfirm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscureText,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (isConfirm && controller.text != confirmController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(controller.text);
              },
              child: Text(isConfirm ? 'Encrypt' : 'Decrypt'),
            ),
          ],
        ),
      ),
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
      ref.invalidate(noteFoldersProvider);

      // Force rebuild by reading providers
      ref.read(tasksProvider.notifier).refresh();
      ref.read(preferencesStateProvider);
      ref.read(notesProvider.notifier).refresh();
      ref.read(noteFoldersProvider.notifier).refresh();

      // Wait a moment for providers to refresh
      await Future.delayed(const Duration(milliseconds: 100));

      debugPrint('[BackupSettings] Provider refresh completed');

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Data refreshed - your imported tasks, notes and folders should now be visible!',
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
    // Load current settings
    final isCurrentlyEnabled = await AutoBackupService.instance
        .isAutoBackupScheduled();
    int selectedInterval = 24; // Default: daily
    bool requiresCharging = false;
    final currentPassword = StorageService.getAutoBackupPassword();
    final passwordController = TextEditingController(
      text: currentPassword ?? '',
    );
    final confirmPasswordController = TextEditingController(
      text: currentPassword ?? '',
    );
    bool isEnabled = isCurrentlyEnabled;
    bool obscurePassword = true;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Auto Backup Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enable/Disable toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Auto Backup'),
                  subtitle: Text(
                    isEnabled
                        ? 'Backups run automatically'
                        : 'Backups are disabled',
                  ),
                  value: isEnabled,
                  onChanged: (value) => setState(() => isEnabled = value),
                ),
                SpacingGap.gapV8,

                // Settings (only shown when enabled)
                AnimatedOpacity(
                  opacity: isEnabled ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !isEnabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info about backup location
                        Container(
                          padding: SpacingEdgeInsets.insets12,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: SpacingBorderRadius.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              SpacingGap.gapH8,
                              Expanded(
                                child: Text(
                                  'Backups are saved to Android/data/com.trudido.app/files/AutoBackups/',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SpacingGap.gapV16,

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
                        SpacingGap.gapV12,

                        // Charging condition
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Only when charging'),
                          subtitle: const Text('Saves battery life'),
                          value: requiresCharging,
                          onChanged: (value) {
                            setState(() => requiresCharging = value ?? false);
                          },
                        ),
                        SpacingGap.gapV16,

                        // Password section
                        Text(
                          'Encryption (Optional)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SpacingGap.gapV8,
                        Text(
                          'Set a password to encrypt backups. Leave empty for no encryption.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        SpacingGap.gapV12,
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        SpacingGap.gapV12,
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscurePassword,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                            border: OutlineInputBorder(),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // Validate passwords match if set
                if (passwordController.text.isNotEmpty &&
                    passwordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'enabled': isEnabled,
                  'interval': selectedInterval,
                  'requiresCharging': requiresCharging,
                  'password': passwordController.text,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return; // Cancelled

    final enabled = result['enabled'] as bool;
    final interval = result['interval'] as int;
    final charging = result['requiresCharging'] as bool;
    final password = result['password'] as String;

    // Save password setting
    if (password.isEmpty) {
      await StorageService.setAutoBackupPassword(null);
    } else {
      await StorageService.setAutoBackupPassword(password);
    }

    if (enabled) {
      final success = await AutoBackupService.instance.scheduleAutoBackup(
        intervalHours: interval,
        requiresCharging: charging,
      );

      // Cache backup data immediately
      await AutoBackupService.instance.cacheBackupData();

      if (!mounted) return;

      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto backup enabled! Backing up ${AutoBackupService.getBackupFrequencyDescription(interval).toLowerCase()}${password.isNotEmpty ? ' (encrypted)' : ''}',
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
    } else {
      await AutoBackupService.instance.cancelAutoBackup();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto backup disabled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _showAutoBackupImportDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SpacingGap.gapH16,
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
                  SpacingGap.gapV16,
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
              ExpressiveTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ExpressiveElevatedButton(
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
              ExpressiveTextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ExpressiveElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ExpressiveElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
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
          ExpressiveTextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          ExpressiveOutlinedButton(
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
    // Ask user if they want to encrypt the backup
    final password = await _askForExportPassword();
    if (password == null) return; // User cancelled the password dialog

    // Export to the user's chosen backup folder
    try {
      await FilesChannel.instance.startExport(
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            password.isEmpty
                ? 'Export saved to your backup folder!'
                : 'Encrypted export saved to your backup folder!',
          ),
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
    // Ask user if they want to encrypt the backup
    final password = await _askForExportPassword();
    if (password == null) return; // User cancelled the password dialog

    // Use the traditional file picker
    try {
      await FilesChannel.instance.startExport(
        password: password.isEmpty ? null : password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            password.isEmpty
                ? 'Export started - choose save location'
                : 'Encrypted export started - choose save location',
          ),
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

  /// Asks user if they want to protect the backup with a password
  /// Returns empty string for no protection, password string for encryption, null if cancelled
  Future<String?> _askForExportPassword() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protect Backup?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Would you like to encrypt this backup with a password?'),
            SizedBox(height: 12),
            Text(
              '• Recommended if you have vault/locked folders\n'
              '• Protects your data if the backup file is accessed by others\n'
              '• If you forget the password, the backup cannot be restored',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Cancel
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(''), // No password
            child: const Text('No Protection'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop('SET_PASSWORD'), // Signal to show password dialog
            child: const Text('Set Password'),
          ),
        ],
      ),
    );

    if (choice == null) return null; // Cancelled
    if (choice == '') return ''; // No protection

    // User wants to set a password
    return await _showPasswordInputDialog(
      title: 'Set Backup Password',
      message: 'Enter a password to encrypt your backup:',
      isConfirm: true,
    );
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
            padding: SpacingEdgeInsets.insets16,
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
                      ExpressiveIconButton(
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
              final hasPassword =
                  StorageService.getAutoBackupPassword() != null;

              String subtitle;
              if (isScheduled) {
                subtitle = hasPassword
                    ? 'Enabled with encryption'
                    : 'Enabled (no encryption)';
              } else {
                subtitle = 'Disabled - tap to configure';
              }

              return ListTile(
                leading: Icon(
                  isScheduled ? Icons.backup : Icons.backup_outlined,
                  color: isScheduled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                title: const Text('Configure Auto Backup'),
                subtitle: Text(subtitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isScheduled && hasPassword)
                      Icon(Icons.lock, size: 16, color: colorScheme.primary),
                    if (isScheduled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: _showAutoBackupSetupDialog,
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
                                SpacingGap.gapV8,
                                SelectableText(
                                  'Android/data/com.trudido.app/files/AutoBackups/',
                                  style: TextStyle(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            actions: [
                              ExpressiveTextButton(
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
                padding: SpacingEdgeInsets.insets16,
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
                        SpacingGap.gapH8,
                        Text(
                          'Backup Options',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SpacingGap.gapV12,
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
