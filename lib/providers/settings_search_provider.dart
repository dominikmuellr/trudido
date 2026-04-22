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
import '../utils/date_search_parser.dart';
import '../utils/state_notifiers.dart';

class SettingsItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String keywords;
  final String route;

  /// If non-null, this setting is a boolean toggle that can be changed inline.
  /// The key maps to a specific provider read/write in the search results UI.
  final String? toggleKey;

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
    required this.route,
    this.toggleKey,
  });
}

/// All available settings items with their metadata for searching.
/// Includes both top-level categories and individual settings within them.
final settingsItemsProvider = Provider<List<SettingsItem>>((ref) {
  return [
    // ── Top-level categories ──────────────────────────────────────────
    const SettingsItem(
      title: 'Personalization',
      subtitle: 'Profile, colors, layout, and visual preferences',
      icon: Icons.palette_outlined,
      keywords:
          'appearance personalization profile colors layout visual preferences theme dark light',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Notifications',
      subtitle: 'Permissions, settings, and reliability',
      icon: Icons.notifications_outlined,
      keywords:
          'notifications alerts permissions settings reliability reminders',
      route: 'notifications',
    ),
    const SettingsItem(
      title: 'App Lock',
      subtitle: 'Protect app with PIN or fingerprint',
      icon: Icons.lock_outline,
      keywords:
          'security app lock pin fingerprint protect biometric authentication',
      route: 'app_lock',
    ),
    const SettingsItem(
      title: 'Data Management',
      subtitle: 'Calendar sync, import, backup, and data',
      icon: Icons.storage_outlined,
      keywords: 'data management calendar sync import backup export restore',
      route: 'data_management',
    ),
    const SettingsItem(
      title: 'About & Licenses',
      subtitle: 'App license, package licenses and repository',
      icon: Icons.info_outline,
      keywords:
          'about licenses app license package repository version info information',
      route: 'about',
    ),
    const SettingsItem(
      title: 'Support Development',
      subtitle: 'Buy me a coffee or donate',
      icon: Icons.favorite_outline,
      keywords: 'support development buy coffee donate contribute funding',
      route: 'support',
    ),
    const SettingsItem(
      title: 'Experimental Features',
      subtitle: 'Try new and experimental features',
      icon: Icons.science_outlined,
      keywords: 'experimental features try new beta testing preview',
      route: 'experimental',
    ),

    // ── Personalization: individual settings ──────────────────────────
    const SettingsItem(
      title: 'Theme Mode',
      subtitle: 'Personalization · Light, Dark, or System theme',
      icon: Icons.brightness_6_outlined,
      keywords: 'theme mode light dark system appearance',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Dynamic Color',
      subtitle: 'Personalization · Use Material You colors',
      icon: Icons.color_lens_outlined,
      keywords: 'dynamic color material you wallpaper accent',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Accent Color',
      subtitle: 'Personalization · Choose your accent color',
      icon: Icons.colorize_outlined,
      keywords: 'accent color picker primary custom',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Font',
      subtitle: 'Personalization · Choose your font family',
      icon: Icons.font_download_outlined,
      keywords: 'font family typography text',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Font Size',
      subtitle: 'Personalization · Adjust text size',
      icon: Icons.format_size_outlined,
      keywords: 'font size text scale large small',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Haptic Feedback',
      subtitle: 'Personalization · Vibrate on interactions',
      icon: Icons.vibration_outlined,
      keywords: 'haptic feedback vibration vibrate touch',
      route: 'personalization',
      toggleKey: 'hapticsEnabled',
    ),
    const SettingsItem(
      title: 'Show Search Bar',
      subtitle: 'Personalization · Display search bar in header',
      icon: Icons.search_outlined,
      keywords: 'search bar header show hide display',
      route: 'personalization',
      toggleKey: 'showSearchBar',
    ),
    const SettingsItem(
      title: 'Floating Navigation Bar',
      subtitle: 'Personalization · Frosted-glass navigation bar',
      icon: Icons.dock_outlined,
      keywords: 'floating navigation bar bottom frosted glass',
      route: 'personalization',
      toggleKey: 'floatingNavBar',
    ),
    const SettingsItem(
      title: 'Custom Themes',
      subtitle: 'Personalization · Create and manage themes',
      icon: Icons.palette_outlined,
      keywords: 'custom themes create manage color scheme',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Profile',
      subtitle: 'Personalization · Set your avatar and name',
      icon: Icons.person_outlined,
      keywords: 'profile avatar name picture photo',
      route: 'personalization',
    ),

    // ── Defaults (sub-screen of Personalization) ─────────────────────
    const SettingsItem(
      title: 'Default Starting Tab',
      subtitle: 'Personalization · Defaults · Overview, Tasks, or Notes',
      icon: Icons.tab_outlined,
      keywords: 'default starting tab overview tasks notes home',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Show Overview Tab',
      subtitle: 'Personalization · Defaults · Display overview in nav bar',
      icon: Icons.dashboard_outlined,
      keywords: 'overview tab show hide navigation',
      route: 'personalization',
      toggleKey: 'showOverviewTab',
    ),
    const SettingsItem(
      title: 'Default Task View',
      subtitle: 'Personalization · Defaults · List or Calendar',
      icon: Icons.view_list_outlined,
      keywords: 'default task view list calendar',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Time Format',
      subtitle: 'Personalization · Defaults · 12h or 24h clock',
      icon: Icons.access_time_outlined,
      keywords: 'time format 12 24 hour clock am pm',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Week Starts On',
      subtitle: 'Personalization · Defaults · First day of week',
      icon: Icons.calendar_today_outlined,
      keywords: 'week starts monday sunday first day',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Swipe Actions',
      subtitle: 'Personalization · Defaults · Left and right swipe',
      icon: Icons.swipe_outlined,
      keywords: 'swipe actions left right gesture delete complete',
      route: 'personalization',
    ),
    const SettingsItem(
      title: 'Compact Mode',
      subtitle: 'Personalization · Defaults · Reduce spacing and padding',
      icon: Icons.density_small_outlined,
      keywords: 'compact mode dense spacing padding',
      route: 'personalization',
      toggleKey: 'compactDensity',
    ),
    const SettingsItem(
      title: 'Hide Navigation Labels',
      subtitle: 'Personalization · Defaults · Show only icons',
      icon: Icons.label_off_outlined,
      keywords: 'hide navigation labels icons only bottom bar',
      route: 'personalization',
      toggleKey: 'hideNavLabels',
    ),
    const SettingsItem(
      title: 'Black Out Recents',
      subtitle: 'Personalization · Defaults · Hide app in recents',
      icon: Icons.visibility_off_outlined,
      keywords: 'black out recents privacy hide app switcher',
      route: 'personalization',
      toggleKey: 'blackoutRecents',
    ),
    const SettingsItem(
      title: 'Contrast Level',
      subtitle: 'Personalization · Defaults · Adjust UI contrast',
      icon: Icons.contrast_outlined,
      keywords: 'contrast level high low normal accessibility',
      route: 'personalization',
    ),

    // ── Notifications: individual settings ────────────────────────────
    const SettingsItem(
      title: 'Notification Permission',
      subtitle: 'Notifications · Allow app to show notifications',
      icon: Icons.notifications_active_outlined,
      keywords: 'notification permission allow grant',
      route: 'notifications',
    ),
    const SettingsItem(
      title: 'Exact Alarms',
      subtitle: 'Notifications · Precise timing for reminders',
      icon: Icons.alarm_outlined,
      keywords: 'exact alarms precise timing reminders schedule',
      route: 'notifications',
    ),
    const SettingsItem(
      title: 'Battery Optimization',
      subtitle: 'Notifications · Disable to ensure notifications work',
      icon: Icons.battery_saver_outlined,
      keywords: 'battery optimization doze background restrict',
      route: 'notifications',
    ),
    const SettingsItem(
      title: 'Persistent Notifications',
      subtitle: 'Notifications · Notifications reappear if dismissed',
      icon: Icons.notification_important_outlined,
      keywords: 'persistent notifications sticky dismiss reappear',
      route: 'notifications',
    ),

    // ── App Lock: individual settings ─────────────────────────────────
    const SettingsItem(
      title: 'Enable App Lock',
      subtitle: 'App Lock · Require PIN to open the app',
      icon: Icons.pin_outlined,
      keywords: 'enable app lock pin code require',
      route: 'app_lock',
    ),
    const SettingsItem(
      title: 'Fingerprint Unlock',
      subtitle: 'App Lock · Use fingerprint to unlock',
      icon: Icons.fingerprint_outlined,
      keywords: 'fingerprint biometric unlock touch face',
      route: 'app_lock',
    ),
    const SettingsItem(
      title: 'Lock Timeout',
      subtitle: 'App Lock · Auto-lock delay',
      icon: Icons.timer_outlined,
      keywords: 'lock timeout delay auto immediately',
      route: 'app_lock',
    ),

    // ── Data Management: individual settings ──────────────────────────
    const SettingsItem(
      title: 'Calendar Sync',
      subtitle: 'Data Management · Sync tasks with device calendar',
      icon: Icons.sync_outlined,
      keywords: 'calendar sync device davx5 android',
      route: 'data_management',
    ),
    const SettingsItem(
      title: 'Import Calendar',
      subtitle: 'Data Management · Import events from .ics file',
      icon: Icons.upload_file_outlined,
      keywords: 'import calendar ics file events holidays',
      route: 'data_management',
    ),
    const SettingsItem(
      title: 'Export Calendar',
      subtitle: 'Data Management · Export events as .ics file',
      icon: Icons.download_outlined,
      keywords: 'export calendar ics file events',
      route: 'data_management',
    ),
    const SettingsItem(
      title: 'Backup & Data',
      subtitle: 'Data Management · Export, import and automatic backups',
      icon: Icons.backup_outlined,
      keywords: 'backup data export import json auto automatic restore',
      route: 'data_management',
    ),
    const SettingsItem(
      title: 'Bin',
      subtitle: 'Data Management · Enable or disable the bin',
      icon: Icons.delete_outline,
      keywords: 'bin trash recycle auto delete permanently enable disable',
      route: 'data_management',
      toggleKey: 'enableBin',
    ),
    const SettingsItem(
      title: 'Clear Data',
      subtitle: 'Data Management · Clear tasks and reset data',
      icon: Icons.warning_amber_outlined,
      keywords: 'clear data reset danger zone remove all',
      route: 'data_management',
    ),

    // ── Experimental: individual settings ─────────────────────────────
    const SettingsItem(
      title: 'Folder Templates',
      subtitle: 'Experimental · Manage templates for smart folder creation',
      icon: Icons.snippet_folder_outlined,
      keywords: 'folder templates smart create manage',
      route: 'experimental',
    ),
    const SettingsItem(
      title: 'Quick Input Bar',
      subtitle: 'Experimental · Bottom bar for quick task/note creation',
      icon: Icons.edit_note_outlined,
      keywords: 'quick input bar bottom floating action button fab',
      route: 'experimental',
      toggleKey: 'useQuickInputBar',
    ),
    const SettingsItem(
      title: 'Note History',
      subtitle: 'Experimental · Undo/redo and version browsing',
      icon: Icons.history_outlined,
      keywords: 'note history undo redo version browse',
      route: 'experimental',
      toggleKey: 'enableNoteHistory',
    ),
    const SettingsItem(
      title: 'Spatial Canvas',
      subtitle: 'Experimental · Zoomable notes canvas view',
      icon: Icons.space_dashboard_outlined,
      keywords: 'spatial canvas notes zoom pan view',
      route: 'experimental',
      toggleKey: 'enableSpatialCanvas',
    ),
    const SettingsItem(
      title: 'Auto-complete Events',
      subtitle: 'Experimental · Mark events complete after end time',
      icon: Icons.event_available_outlined,
      keywords: 'auto complete events automatic mark done',
      toggleKey: 'autoCompleteEvents',
      route: 'experimental',
    ),
  ];
});

/// Filtered settings based on search query
final filteredSettingsProvider = Provider<List<SettingsItem>>((ref) {
  final items = ref.watch(settingsItemsProvider);
  final query = ref.watch(settingsSearchQueryProvider);

  if (query.isEmpty) {
    return [];
  }

  return FuzzySearch.filter(
    items: items,
    query: query,
    getText: (item) => '${item.title} ${item.subtitle} ${item.keywords}',
    minSimilarity: 0.6,
  );
});

/// Search query for settings
final settingsSearchQueryProvider = stateProvider<String>('');
