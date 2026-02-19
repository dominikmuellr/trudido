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

  const SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.keywords,
    required this.route,
  });
}

/// All available settings items with their metadata for searching
final settingsItemsProvider = Provider<List<SettingsItem>>((ref) {
  return [
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
    minSimilarity: 0.4,
  );
});

/// Search query for settings
final settingsSearchQueryProvider = stateProvider<String>('');
