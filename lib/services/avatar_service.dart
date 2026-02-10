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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'storage_service.dart';

class AvatarService {
  static final ImagePicker _picker = ImagePicker();
  static const String _avatarFileName = 'user_avatar.jpg';

  /// Pick an image from gallery and save it as the user's avatar
  static Future<String?> pickAndSaveAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _saveAvatar(File(image.path));
    } catch (e) {
      // Silently return null - image picker cancelled or permission denied
      if (kDebugMode) {
        debugPrint('Error picking avatar: $e');
      }
      return null;
    }
  }

  /// Take a photo with camera and save it as the user's avatar
  static Future<String?> takeAndSaveAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image == null) return null;

      return await _saveAvatar(File(image.path));
    } catch (e) {
      // Silently return null - camera unavailable or permission denied
      if (kDebugMode) {
        debugPrint('Error taking avatar photo: $e');
      }
      return null;
    }
  }

  static Future<String?> _saveAvatar(File imageFile) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String avatarPath = path.join(appDir.path, _avatarFileName);

      // Copy the image to app directory
      await imageFile.copy(avatarPath);

      await StorageService.setUserAvatarPath(avatarPath);

      return avatarPath;
    } catch (e) {
      // Silently return null - directory access or file system error
      if (kDebugMode) {
        debugPrint('Error saving avatar: $e');
      }
      return null;
    }
  }

  /// Get the current avatar file if it exists
  static File? getAvatarFile() {
    final String? avatarPath = StorageService.getUserAvatarPath();
    if (avatarPath == null || avatarPath.isEmpty) return null;

    final file = File(avatarPath);
    if (file.existsSync()) {
      return file;
    }
    return null;
  }

  static Future<void> deleteAvatar() async {
    final String? avatarPath = StorageService.getUserAvatarPath();
    if (avatarPath != null && avatarPath.isNotEmpty) {
      try {
        final file = File(avatarPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Silently continue - avatar file may already be deleted
        if (kDebugMode) {
          debugPrint('Error deleting avatar file: $e');
        }
      }
    }
    await StorageService.setUserAvatarPath('');
  }

  static String getInitials(String name) {
    if (name.isEmpty) return '?';

    final trimmed = name.trim();
    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      // First letter of first name + first letter of last name
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    } else if (trimmed.length >= 2) {
      // First two letters of name
      return trimmed.substring(0, 2).toUpperCase();
    } else {
      // Single letter
      return trimmed[0].toUpperCase();
    }
  }

  /// Generate a consistent color from user name.
  /// Uses subtle elevated surface color for better integration with theme.
  static Color getColorFromName(String name, ColorScheme colorScheme) {
    return colorScheme.surfaceContainerHighest;
  }

  /// Get the foreground color (text) based on background color.
  /// Uses standard text color for optimal readability.
  static Color getForegroundColor(
    Color backgroundColor,
    ColorScheme colorScheme,
  ) {
    return colorScheme.onSurface;
  }
}
