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
import '../providers/app_providers.dart';
import '../controllers/preferences_controller.dart';
import '../utils/responsive_size.dart';
import 'template_management_screen.dart';

class ExperimentalSettingsScreen extends ConsumerWidget {
  const ExperimentalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Experimental'),
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: ScaledIcon(Icons.widgets_outlined),
            title: const Text('Folder Templates'),
            subtitle: const Text('Manage templates for smart folder creation'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TemplateManagementScreen(),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.touch_app_outlined),
                title: const Text('Floating Note Toolbar'),
                subtitle: const Text(
                  'Replace top toolbar with a thumb-friendly floating button',
                ),
                value: preferences.useFloatingNoteToolbar,
                onChanged: (v) => controller.toggleFloatingNoteToolbar(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
