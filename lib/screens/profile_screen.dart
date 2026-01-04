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

import 'dart:io';
import 'package:flutter/material.dart';
import '../services/avatar_service.dart';
import '../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  File? _avatarFile;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final currentName = StorageService.getUserName();
    _nameController = TextEditingController(
      text: (currentName == '_SKIP_NAME_' || currentName == '_CLEARED_NAME_')
          ? ''
          : currentName,
    );
    _avatarFile = AvatarService.getAvatarFile();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await StorageService.setUserName('_CLEARED_NAME_');
    } else {
      await StorageService.setUserName(name);
    }
    setState(() {
      _hasChanges = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showAvatarOptions() async {
    final colorScheme = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: colorScheme.primary),
              title: const Text('Take a Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _takePhoto();
              },
            ),
            if (_avatarFile != null)
              ListTile(
                leading: Icon(Icons.delete, color: colorScheme.error),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final path = await AvatarService.pickAndSaveAvatar();
    if (path != null) {
      setState(() {
        _avatarFile = File(path);
      });
    }
  }

  Future<void> _takePhoto() async {
    final path = await AvatarService.takeAndSaveAvatar();
    if (path != null) {
      setState(() {
        _avatarFile = File(path);
      });
    }
  }

  Future<void> _removeAvatar() async {
    await AvatarService.deleteAvatar();
    setState(() {
      _avatarFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = _nameController.text.trim();
    final hasName = userName.isNotEmpty;

    final initials = hasName ? AvatarService.getInitials(userName) : null;
    final backgroundColor = hasName
        ? AvatarService.getColorFromName(userName, colorScheme)
        : colorScheme.primaryContainer;
    final foregroundColor = AvatarService.getForegroundColor(
      backgroundColor,
      colorScheme,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Section
            GestureDetector(
              onTap: _showAvatarOptions,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: _avatarFile != null
                        ? null
                        : backgroundColor,
                    backgroundImage: _avatarFile != null
                        ? FileImage(_avatarFile!)
                        : null,
                    child: _avatarFile != null
                        ? null
                        : initials != null
                        ? Text(
                            initials,
                            style: TextStyle(
                              color: foregroundColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 40,
                            ),
                          )
                        : Icon(Icons.person, size: 64, color: foregroundColor),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to change photo',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // Name Field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'Enter your name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: _hasChanges
                    ? IconButton(
                        icon: Icon(Icons.check, color: colorScheme.primary),
                        onPressed: _saveName,
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: 16),
            Text(
              'Your name will appear in the greeting on the home screen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Save Button
            if (_hasChanges)
              FilledButton.icon(
                onPressed: _saveName,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
          ],
        ),
      ),
    );
  }
}
