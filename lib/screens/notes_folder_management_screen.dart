import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/note_folder_repository.dart';
import '../models/note_folder.dart';
import '../services/biometric_auth_service.dart';
import '../services/vault_password_service.dart';
import '../services/vault_auth_service.dart';

/// Folder management screen specifically for Notes (with vault support)
class NotesFolderManagementScreen extends ConsumerStatefulWidget {
  const NotesFolderManagementScreen({super.key});

  @override
  ConsumerState<NotesFolderManagementScreen> createState() =>
      _NotesFolderManagementScreenState();
}

class _NotesFolderManagementScreenState
    extends ConsumerState<NotesFolderManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final foldersAsync = ref.watch(noteFoldersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Note Folders'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: foldersAsync.when(
        data: (folders) {
          if (folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No folders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Create a folder to organize your notes'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateFolderDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Folder'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: folders.length,
            itemBuilder: (context, index) {
              final folder = folders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    folder.isVault ? Icons.lock : Icons.folder,
                    color: folder.isVault ? Colors.amber : Colors.blue,
                    size: 32,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (folder.description != null &&
                          folder.description!.isNotEmpty)
                        Text(folder.description!),
                      if (folder.isVault)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.lock, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'Encrypted Vault',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditFolderDialog(folder),
                        tooltip: 'Edit folder',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteFolder(folder),
                        tooltip: 'Delete folder',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error loading folders'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.refresh(noteFoldersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isVault = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
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
                        isVault = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();

                  // If vault, setup password and biometric preferences
                  String? vaultPassword;
                  bool useBiometric = true;

                  if (isVault) {
                    // Show password setup dialog
                    final passwordResult = await _showPasswordSetupDialog(
                      context,
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
                      );

                  if (mounted) {
                    if (result != null) {
                      // Store the password if vault
                      if (isVault && vaultPassword != null) {
                        await VaultPasswordService.setVaultPassword(
                          result.id,
                          vaultPassword,
                        );
                      }

                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Folder "$name" created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
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
  }

  Future<void> _showEditFolderDialog(NoteFolder folder) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: folder.name);
    final descriptionController = TextEditingController(
      text: folder.description ?? '',
    );

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Folder'),
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
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  // Show vault status but don't allow editing
                  if (folder.isVault)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Encrypted Vault Folder - Encryption cannot be disabled after creation',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();

                  final updated = folder.copyWith(
                    name: name,
                    description: description.isEmpty ? null : description,
                    // Keep existing vault status - cannot be changed
                  );

                  final result = await ref
                      .read(noteFoldersProvider.notifier)
                      .updateFolder(updated);

                  if (mounted) {
                    Navigator.pop(context);
                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Folder "$name" updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Failed to update folder. Name may already exist.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    // If it's a vault folder, require authentication first
    if (folder.isVault) {
      final authenticated = await VaultAuthService.authenticate(
        context: context,
        folderId: folder.id,
        folderName: folder.name,
        useBiometric: folder.useBiometric,
        hasPassword: folder.hasPassword,
      );

      if (!authenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required to delete vault folder'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Delete "${folder.name}"?\n\nNotes in this folder will not be deleted, but they will no longer be associated with this folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref
          .read(noteFoldersProvider.notifier)
          .deleteFolder(folder.id);

      if (mounted) {
        if (success) {
          // Delete the vault password if it was a vault folder
          if (folder.isVault && folder.hasPassword) {
            await VaultPasswordService.removeVaultPassword(folder.id);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Folder "${folder.name}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  /// Shows password setup dialog for vault folders
  Future<Map<String, dynamic>?> _showPasswordSetupDialog(
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
    final biometricAvailable =
        await BiometricAuthService.isBiometricsAvailable();

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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password/PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
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
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
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
                    const SizedBox(height: 16),
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
            TextButton(
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
}
