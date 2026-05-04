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

/// The current app version string – update this with each release.
const String kCurrentAppVersion = '1.3.5';

/// One entry in the changelog.
class _ChangelogEntry {
  final String version;
  final List<String> changes;
  const _ChangelogEntry({required this.version, required this.changes});
}

/// Full changelog list, newest first.
const List<_ChangelogEntry> _changelog = [
  _ChangelogEntry(
    version: '1.3.5',
    changes: [
      'Spatial Canvas: new graph/visualization view for notes - explore notes as an interactive spatial map (Settings → Experimental)',
      'Tag bar in note editor: assign and manage tags directly while editing a note',
      'Default note editor settings: configure default formatting, text size, and behavior for new notes in one place',
      'Search bar is now always active - the option to hide or remove it has been removed',
      'Mutual exclusion dialog: confirmation dialog when toggling between quick input bar and floating navbar',
      'Various search bar fixes and stability improvements',
    ],
  ),
  _ChangelogEntry(
    version: '1.3.4',
    changes: [
      'Overhauled search: multi-word AND matching, date keywords (today/tomorrow/yesterday), overdue search, category scope filtering, and result count summary',
      'Search now highlights matches across all result types and shows note content snippets around matches',
      'Search history is now persisted between sessions',
      'Export calendar: share your events as a standard .ics file via Settings → Data Management',
      'Compact notes view: show only titles, hiding content previews - toggle under Settings → Defaults',
      'Auto-complete events: automatically mark events as done when their end time passes - Settings → Experimental',
      'Fixed: Calendar events imported as events instead of tasks (Issue #98)',
      'Fixed: Default Task View setting not persisting on app restart',
      'Various search bar UI fixes and improvements',
    ],
  ),
  _ChangelogEntry(
    version: '1.3.3',
    changes: [
      'New Overview tab with clock, greeting and recent content snapshot - disable it under Settings → Defaults',
      'Configurable drawer modules on the Overview tab: calendar with task markers in slot 1, add/remove slots via the × / + buttons',
      'Floating navigation bar: optional frosted-glass pill-shaped navbar - toggle it under Settings → Personalization',
      'Note accent colors: assign a color via the editor toolbar; it shows as an accent on the preview card - via long-press on a note card',
      'Tables in the slash menu: type / in the note editor to insert a table; table rendering reworked throughout',
      'Multi-select for notes: long-press a note card to enter selection mode, then tap more cards',
      'Syntax highlighting in code blocks: language auto-detected, overridable via the language picker in the block',
      'Inter is now the default font - change it under Settings → Personalization',
      'Colored @mentions in note preview cards',
      'Priority chips now use vivid colors instead of muted container tones',
      'In-app changelog dialog - Settings → About',
      'Fixed: markdown not converting back to view mode when opening a note',
      'Fixed: note color selector not applying correctly',
      'Fixed: inline code block rendering broken in note previews',
      'Fixed: deleted default folders reappearing after a restart',
    ],
  ),
  _ChangelogEntry(
    version: '1.3.2',
    changes: [
      'Floating Note Toolbar: detachable, freely draggable overlay with persistent state',
      'Bin / Trash System: configurable auto-deletion per day count, new Bin Settings screen',
      'Compact Mode: new display density option for task and note lists',
      'Mentions & Backlinks (experimental): @mention autocomplete and backlinks section in notes',
      'Toggle between write mode and read mode in notes',
      'Inline clear (×) buttons on task scheduling chips',
      'Images in note preview cards expand to full-screen on tap',
      '"Don\'t show again" option on battery optimization reminder',
      'Setting to choose your default notes folder',
      'Setting to black out the app in the Android recent apps view',
      'Fixed PDF export losing formatting and content',
      'Fixed edge-to-edge display rendering issues on Android 15',
      'Fixed auto-backup export failures',
      'Fixed rich text editor checkbox and strikethrough rendering glitches',
    ],
  ),
  _ChangelogEntry(
    version: '1.3.1',
    changes: [
      'Fixed tasks without a due date not showing in the task list',
      'Added "Overdue" section for past-due tasks in list view',
      'Added "No Date" section for tasks without a due date',
      'Task list now groups: Overdue → Today → Tomorrow → Upcoming → No Date',
      'Now also available on the Play Store',
    ],
  ),
  _ChangelogEntry(
    version: '1.3.0',
    changes: [
      'Biometric unlock for the app lock screen',
      'Task duration time support',
      'Swipe gesture to open navigation drawer',
      'Simple theme creator with Material You colors',
      '12h / 24h time format toggle',
      'Font customization with 4 variable fonts (Open Sans, Lexend, JetBrains Mono, …)',
      'Bulk mark-complete for past imported calendar tasks',
      'Notification tap-to-open functionality',
      'Auto-backup with optional password encryption',
      'Fixed locked folder notes not decrypting properly after import',
      'Fixed tasks not showing due to filter state initialization race conditions',
      'Migrated to Riverpod 3.x',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.7',
    changes: [
      'Material 3 modernization: spring animations, updated 70+ UI components',
      'Google Sans font (4 weights) throughout the app',
      'Haptic feedback on all interactive elements with global toggle',
      'Play Store build configuration (F-Droid builds unchanged)',
      'Fixed: removed unnecessary REQUEST_INSTALL_PACKAGES permission',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.6',
    changes: [
      'Universal Search Bar: searches tasks, notes, folders and settings simultaneously',
      'Fuzzy search algorithm with typo tolerance',
      'Date search with natural language and multiple format support',
      'Calendar Import: parse and import ICS calendar files',
      'Note History & Version Control (experimental)',
      'Notes Grid / List view toggle',
      'Notifications working again',
      'Vault folders completely excluded from all search results',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.5',
    changes: [
      'Home screen widgets with real-time task synchronization',
      'Calendar widget with date selection and pre-filled task creation',
      'Material 3 January 2026 design system update',
      'Semantic spacing system (214 hardcoded values replaced)',
      'Personalization hub with profile photo and name',
      'Fixed note sharing and PDF export with images',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.4',
    changes: [
      'Material 3 chips for task sorting',
      'Improved filter UI with visual indicators and fixed FAB overlap',
      'Null-safety enhancements and Dart 3.9.2 compatibility',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.3',
    changes: [
      '"Week Starts On" setting for all calendar widgets',
      'App-wide lock with PIN and biometric authentication',
      'Removed internet permission for enhanced privacy',
      'Floating toolbar for note formatting (experimental)',
      'Fixed Android navigation bar overlapping note content',
      'Switched to device_calendar_plus for better compatibility',
      'Added GPL-3.0-or-later license headers to all source files',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.2',
    changes: [
      'Connect Trudido calendar/tasks to Android Calendar via DAVx5',
      'Import and export of calendar dates',
      'Two-way calendar sync',
    ],
  ),
  _ChangelogEntry(
    version: '1.2.1',
    changes: ['Share menu in notes (convert to PDF)', 'New app icon'],
  ),
  _ChangelogEntry(
    version: '1.2.0',
    changes: [
      'Full WYSIWYG rich text editor (Flutter Quill) with Markdown shortcuts',
      'PDF export and print for notes',
      'Video recording and playback in notes',
      'Photo fullscreen viewer (pinch-to-zoom)',
      'Voice recording with built-in playback',
      'Inline link support in notes',
      'Relative date display (Today, Yesterday, day names)',
    ],
  ),
  _ChangelogEntry(
    version: '1.1.0',
    changes: [
      'Replaced top menu with navigation drawer for better reachability',
      'Customizable greeting language',
      'Material 3 expandable FAB menu with tab-specific actions',
      'Vault Note creation directly from FAB menu',
      'Cycling theme mode switcher in drawer header (Light → Dark → System)',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.9',
    changes: [
      'Day Timetable View: vertical scrollable single-day calendar format',
      'Fingerprint authentication for vault folders',
      'Calendar format (month / 2 weeks / week / day) persists across restarts',
      'Multi-select "Select All" button for tasks',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.8',
    changes: [
      'Refined Material 3 visuals and unified outlined iconography',
      'Smart date picker suggestions (Today, Tomorrow, Next week, …)',
      'Improved test reliability and deterministic statistics',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.7',
    changes: ['Added Solarized Light & Dark theme'],
  ),
  _ChangelogEntry(
    version: '1.0.6',
    changes: [
      'Vault Folders: AES-256-CBC encrypted notes with SHA-256 password hashing',
      'Auto-lock vaults when switching tabs or backgrounding the app',
      'Repeating Tasks support',
      'Biometric authentication placeholder (PIN always required as fallback)',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.5',
    changes: [
      'Font size slider in settings (overrides system font size)',
      'Long-press or double-tap calendar day to create a task with that date',
      'Optimized priority indicators in calendar view',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.4',
    changes: [
      'Color-coded priority chips (high = red, medium = yellow, low = blue)',
      'Date and time shown in due date chips',
      'Default task priority changed from "medium" to "none"',
      'Draggable / expandable bottom sheets for theme and language selectors',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.3',
    changes: [
      'Authentic Dracula theme',
      'Discoverable name input: tap greeting to set your name',
      'Organized theme picker (Standard vs Special themes)',
      'Fixed French / German language mapping swap',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.2',
    changes: ['Fixed theme switching issues', 'App prepared for translations'],
  ),
  _ChangelogEntry(
    version: '1.0.1',
    changes: [
      '15 Material 3 accent colors',
      'Monochrome, Grey and Hack (cyberpunk green) themes',
      'Reorganized settings: Danger Zone moved under Data & Storage',
    ],
  ),
  _ChangelogEntry(
    version: '1.0.0',
    changes: [
      'Initial release',
      'Task management with folders, priorities, due dates and calendar view',
      'Markdown notes with full formatting support',
      'Material 3 design with dynamic theming (Material You on Android 12+)',
      '100% offline – no tracking, no ads, no accounts',
    ],
  ),
];

/// Shows a "What's new" bottom sheet dialog when the app is updated.
/// [context] must have a [Navigator] and [Material] ancestor.
Future<void> showChangelogDialog(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _ChangelogSheet(),
  );
}

class _ChangelogSheet extends StatefulWidget {
  const _ChangelogSheet();

  @override
  State<_ChangelogSheet> createState() => _ChangelogSheetState();
}

class _ChangelogSheetState extends State<_ChangelogSheet> {
  bool _showPrevious = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final newest = _changelog.first;
    final previous = _changelog.skip(1).toList();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => Column(
          children: [
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.new_releases_outlined,
                        color: cs.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "What's new in v${newest.version}",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Latest changelog entries
                  ..._buildChangeItems(newest.changes, theme, cs),

                  // Previous versions section
                  if (previous.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          setState(() => _showPrevious = !_showPrevious),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Previous versions',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _showPrevious ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: cs.primary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showPrevious)
                      ...previous.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 20),
                              Text(
                                'v${entry.version}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._buildChangeItems(
                                entry.changes,
                                theme,
                                cs,
                                muted: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Dismiss button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChangeItems(
    List<String> items,
    ThemeData theme,
    ColorScheme cs, {
    bool muted = false,
  }) {
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: muted ? cs.onSurfaceVariant : cs.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: muted ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
