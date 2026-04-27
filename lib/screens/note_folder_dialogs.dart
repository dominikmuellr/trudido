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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note_folder.dart';
import '../repositories/note_folder_repository.dart';
import '../services/biometric_auth_service.dart';
import '../services/vault_password_service.dart';
import '../theme/spacing_tokens.dart';
import '../widgets/common/common.dart';

const int _defaultNoteFolderColor = 0xFF2196F3;
const int _defaultVaultFolderColor = 0xFFFFC107;
const List<int> _noteFolderColorPalette = [
  0xFF2196F3, // Blue
  0xFF4CAF50, // Green
  0xFFFF9800, // Orange
  0xFFF44336, // Red
  0xFF9C27B0, // Purple
  0xFF00BCD4, // Cyan
  0xFF795548, // Brown
  0xFF607D8B, // Blue Grey
  0xFFE91E63, // Pink
  0xFFFFC107, // Amber
];

Widget _buildNoteFolderColorPicker({
  required BuildContext context,
  required int selectedColor,
  required ValueChanged<int> onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Folder Color', style: Theme.of(context).textTheme.titleSmall),
      SpacingGap.gapV8,
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _noteFolderColorPalette.map((value) {
          final isSelected = value == selectedColor;
          return ExpressiveGestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Color(value),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: isSelected ? 2.5 : 1,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: Color(value).computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    )
                  : null,
            ),
          );
        }).toList(),
      ),
    ],
  );
}

/// Shows password setup dialog for vault folders
/// Returns a map with 'password' and 'useBiometric' keys, or null if cancelled
Future<Map<String, dynamic>?> showPasswordSetupDialogForFolder(
  BuildContext context,
  String folderName,
) async {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool useBiometric = true;

  // Check if biometric is available
  final biometricAvailable = await BiometricAuthService.isBiometricsAvailable();

  if (!context.mounted) return null;
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Setup Password for $folderName'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a password/PIN to protect this vault folder',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SpacingGap.gapV16,
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password/PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: ExpressiveIconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                SpacingGap.gapV16,
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: ExpressiveIconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (biometricAvailable) ...[
                  SpacingGap.gapV16,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use Biometric Shortcut'),
                    subtitle: const Text(
                      'Skip password with fingerprint/face recognition',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: useBiometric,
                    onChanged: (value) {
                      setState(() {
                        useBiometric = value ?? true;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'password': passwordController.text,
                  'useBiometric': useBiometric,
                });
              }
            },
            child: const Text('Setup'),
          ),
        ],
      ),
    ),
  );
}

/// Shows dialog to create a new note folder
/// Returns true if folder was created successfully
Future<bool> showCreateNoteFolderDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isVault = false;
  int selectedColor = _defaultNoteFolderColor;
  String noteFormat = 'markdown'; // Default to markdown
  bool created = false;

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Create Note Folder'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Folder Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a folder name';
                    }
                    return null;
                  },
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                ),
                SpacingGap.gapV16,
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                SpacingGap.gapV16,
                _buildNoteFolderColorPicker(
                  context: dialogContext,
                  selectedColor: selectedColor,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedColor = value;
                    });
                  },
                ),
                SpacingGap.gapV16,
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Encrypted Vault Folder'),
                  subtitle: const Text(
                    'Notes will be encrypted with AES-256',
                    style: TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(
                    isVault ? Icons.lock : Icons.lock_open,
                    color: isVault ? Colors.amber : null,
                  ),
                  value: isVault,
                  onChanged: (value) {
                    setDialogState(() {
                      final nextIsVault = value ?? false;
                      if (nextIsVault &&
                          selectedColor == _defaultNoteFolderColor) {
                        selectedColor = _defaultVaultFolderColor;
                      } else if (!nextIsVault &&
                          selectedColor == _defaultVaultFolderColor) {
                        selectedColor = _defaultNoteFolderColor;
                      }
                      isVault = nextIsVault;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(dialogContext);

                // If vault, setup password and biometric preferences
                String? vaultPassword;
                bool useBiometric = true;

                if (isVault) {
                  // Show password setup dialog
                  final passwordResult = await showPasswordSetupDialogForFolder(
                    dialogContext,
                    name,
                  );

                  if (passwordResult == null) {
                    return; // User cancelled
                  }

                  vaultPassword = passwordResult['password'] as String;
                  useBiometric = passwordResult['useBiometric'] as bool;
                }

                // Create the folder first
                final result = await ref
                    .read(noteFoldersProvider.notifier)
                    .createFolder(
                      name: name,
                      description: description.isEmpty ? null : description,
                      isVault: isVault,
                      hasPassword: isVault && vaultPassword != null,
                      useBiometric: useBiometric,
                      noteFormat: noteFormat,
                      color: selectedColor,
                    );

                if (context.mounted) {
                  if (result != null) {
                    // Store the password if vault
                    if (isVault && vaultPassword != null) {
                      await VaultPasswordService.setVaultPassword(
                        result.id,
                        vaultPassword,
                      );
                    }

                    navigator.pop();
                    created = true;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Folder "$name" created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Failed to create folder. Name may already exist.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );

  return created;
}

/// Shows vault setup dialog for first-time vault access
/// Returns true if vault was setup successfully
Future<bool> showVaultSetupDialogWithPassword(
  BuildContext context,
  WidgetRef ref,
  NoteFolder folder,
) async {
  // Check if biometric is available
  final biometricAvailable = await BiometricAuthService.isBiometricsAvailable();

  if (!context.mounted) return false;
  // Show the setup screen using the extracted helper
  final result = await showVaultSetup(
    context,
    folderName: folder.name,
    biometricAvailable: biometricAvailable,
  );

  // Process the result outside the dialog
  if (result != null) {
    try {
      // Save the password
      await VaultPasswordService.setVaultPassword(
        folder.id,
        result['password'] as String,
      );

      // Update the folder to mark it has a password
      final updatedFolder = folder.copyWith(
        hasPassword: true,
        useBiometric: result['useBiometric'] as bool,
      );

      await ref.read(noteFoldersProvider.notifier).updateFolder(updatedFolder);

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup vault: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  return false;
}

/// Helper function to show vault setup UI
/// Returns a map with 'password' and 'useBiometric' keys, or null if cancelled
Future<Map<String, dynamic>?> showVaultSetup(
  BuildContext context, {
  required String folderName,
  required bool biometricAvailable,
}) async {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool useBiometric = true;

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Setup Vault: $folderName'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This vault folder needs a password to encrypt your notes.',
                ),
                SpacingGap.gapV16,
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password/PIN',
                    border: const OutlineInputBorder(),
                    suffixIcon: ExpressiveIconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                SpacingGap.gapV16,
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: ExpressiveIconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureConfirm = !obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                if (biometricAvailable) ...[
                  SpacingGap.gapV16,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use Biometric Shortcut'),
                    subtitle: const Text(
                      'Skip password with fingerprint/face recognition',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: useBiometric,
                    onChanged: (value) {
                      setState(() {
                        useBiometric = value ?? true;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ExpressiveTextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, {
                  'password': passwordController.text,
                  'useBiometric': useBiometric,
                });
              }
            },
            child: const Text('Setup Vault'),
          ),
        ],
      ),
    ),
  );
}
