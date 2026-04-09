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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'These features are in development and may contain bugs. Use at your own risk.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
                secondary: const Icon(Icons.edit_note_outlined),
                title: const Text('Quick Input Bar'),
                subtitle: const Text(
                  'Replace floating action button with a bottom input bar for quick task/note creation',
                ),
                value: preferences.useQuickInputBar,
                onChanged: (v) => controller.toggleQuickInputBar(),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.history),
                title: const Text('Note History'),
                subtitle: const Text(
                  'Enable note history with undo/redo and version browsing',
                ),
                value: preferences.enableNoteHistory,
                onChanged: (v) => controller.toggleNoteHistory(),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final preferences = ref.watch(preferencesStateProvider);
              final controller = ref.read(preferencesControllerProvider);

              return SwitchListTile(
                secondary: const Icon(Icons.event_available_outlined),
                title: const Text('Auto-complete Events'),
                subtitle: const Text(
                  'Automatically mark events as complete when their end time has passed',
                ),
                value: preferences.autoCompleteEvents,
                onChanged: (v) => controller.toggleAutoCompleteEvents(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
