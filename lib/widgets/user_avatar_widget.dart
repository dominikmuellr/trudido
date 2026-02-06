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
import '../services/avatar_service.dart';
import '../services/storage_service.dart';
import '../widgets/common/common.dart';

class UserAvatarWidget extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatarWidget({super.key, this.radius = 20, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userName = StorageService.getUserName();
    final avatarFile = AvatarService.getAvatarFile();

    final hasImage = avatarFile != null;
    final hasName =
        userName.isNotEmpty &&
        userName != '_SKIP_NAME_' &&
        userName != '_CLEARED_NAME_';

    final initials = hasName ? AvatarService.getInitials(userName) : null;

    // Check for custom colors first, fall back to auto-generated
    final customBgColor = StorageService.getAvatarBackgroundColor();
    final customTextColor = StorageService.getAvatarTextColor();

    final backgroundColor = customBgColor != null
        ? Color(customBgColor)
        : hasName
        ? AvatarService.getColorFromName(userName, colorScheme)
        : colorScheme.primaryContainer;
    final foregroundColor = customTextColor != null
        ? Color(customTextColor)
        : AvatarService.getForegroundColor(backgroundColor, colorScheme);

    return ExpressiveGestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: hasImage ? null : backgroundColor,
        backgroundImage: hasImage ? FileImage(avatarFile) : null,
        child: hasImage
            ? null
            : initials != null
            ? Text(
                initials,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                  fontSize: radius * 0.8,
                ),
              )
            : Icon(Icons.person, size: radius * 1.2, color: foregroundColor),
      ),
    );
  }
}
