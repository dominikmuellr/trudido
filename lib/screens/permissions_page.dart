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

/// (Legacy stub) This page was replaced by UnifiedSettingsPage.
@Deprecated('Use UnifiedSettingsPage instead. Will be removed after v1.1.0.')
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});
  @override
  Widget build(BuildContext context) {
    assert(() {
      debugPrint(
        '[PermissionsPage] This legacy page is deprecated. Use UnifiedSettingsPage instead.',
      );
      return true;
    }());
    return const SizedBox.shrink();
  }
}
