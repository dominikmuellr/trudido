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
import 'package:url_launcher/url_launcher.dart';
import '../config/flavor_config.dart';
import '../providers/app_providers.dart';
import '../utils/responsive_size.dart';
import 'about_screen.dart';
import 'personalization_screen.dart';
import 'comprehensive_notification_settings.dart';
import 'app_lock_settings_page.dart';
import 'data_management_screen.dart';
import 'experimental_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lazy ensure preferences initialized if user navigates directly before main init completes.
    final svc = ref.read(preferencesServiceProvider);
    if (!svc.isReady) {
      svc.ensureInitialized().then((_) {
        // Only update if still on settings screen.
        if (context.mounted) {
          ref.read(preferencesStateProvider.notifier).state = svc.snapshot;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(children: _buildFilteredSettings()),
    );
  }

  List<Widget> _buildFilteredSettings() {
    final List<Widget> allSettings = [
      // Appearance Section
      if (_matchesSearch(
        'appearance personalization profile colors layout visual preferences',
      )) ...[
        _buildSectionHeader(context, 'Appearance'),
        _buildPersonalizationTile(),
      ],

      // Notifications & Alerts Section
      if (_matchesSearch(
        'notifications alerts permissions settings reliability',
      )) ...[
        _buildSectionHeader(context, 'Notifications & Alerts'),
        _buildNotificationsTile(),
      ],

      // Security Section
      if (_matchesSearch('security app lock pin fingerprint protect')) ...[
        _buildSectionHeader(context, 'Security'),
        _buildAppLockTile(),
      ],

      // Data Management Section
      if (_matchesSearch('data management calendar sync import backup')) ...[
        _buildSectionHeader(context, 'Data Management'),
        _buildDataManagementTile(),
      ],

      // About Section
      if (_matchesSearch('about licenses app license package repository')) ...[
        _buildSectionHeader(context, 'About'),
        _buildAboutTile(),
      ],

      // Support Section (FDroid only - hidden on PlayStore)
      if (FlavorConfig.showDonations &&
          _matchesSearch('support development buy coffee donate')) ...[
        _buildSectionHeader(context, 'Support'),
        _buildSupportTile(),
      ],

      // Experimental Section
      if (_matchesSearch('experimental features try new')) ...[
        _buildSectionHeader(context, 'Experimental'),
        _buildExperimentalTile(),
      ],
    ];

    if (allSettings.isEmpty && _searchQuery.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(48),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No settings found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_searchQuery.isEmpty) {
      allSettings.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Made with ❤️ in Europe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return allSettings;
  }

  bool _matchesSearch(String keywords) {
    if (_searchQuery.isEmpty) return true;
    return keywords.toLowerCase().contains(_searchQuery);
  }

  Widget _buildPersonalizationTile() {
    return ListTile(
      leading: ScaledIcon(Icons.palette_outlined),
      title: const Text('Personalization'),
      subtitle: const Text('Profile, colors, layout, and visual preferences'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PersonalizationScreen(),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsTile() {
    return ListTile(
      leading: ScaledIcon(Icons.notifications_outlined),
      title: const Text('Notifications'),
      subtitle: const Text('Permissions, settings, and reliability'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ComprehensiveNotificationSettings(),
          ),
        );
      },
    );
  }

  Widget _buildAppLockTile() {
    return ListTile(
      leading: ScaledIcon(Icons.lock_outline),
      title: const Text('App Lock'),
      subtitle: const Text('Protect app with PIN or fingerprint'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AppLockSettingsPage()),
        );
      },
    );
  }

  Widget _buildDataManagementTile() {
    return ListTile(
      leading: ScaledIcon(Icons.storage_outlined),
      title: const Text('Data Management'),
      subtitle: const Text('Calendar sync, import, backup, and data'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DataManagementScreen()),
        );
      },
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: ScaledIcon(Icons.info_outline),
      title: const Text('About & Licenses'),
      subtitle: const Text('App license, package licenses and repository'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const AboutScreen()));
      },
    );
  }

  Widget _buildSupportTile() {
    return ListTile(
      leading: ScaledIcon(Icons.favorite_outline),
      title: const Text('Support Development'),
      subtitle: const Text('Buy me a coffee or donate'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () => _showSupportSheet(context),
    );
  }

  Widget _buildExperimentalTile() {
    return ListTile(
      leading: ScaledIcon(Icons.science_outlined),
      title: const Text('Experimental Features'),
      subtitle: const Text('Try new and experimental features'),
      trailing: ScaledIcon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ExperimentalSettingsScreen(),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showSupportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support Development',
                style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If you enjoy using Trudido, consider supporting its development!',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildDonationButton(
                context: ctx,
                label: 'Support on Ko-fi',
                icon: Icons.coffee_outlined,
                url: 'https://ko-fi.com/dominikmuellr',
                color: const Color(0xFFFF5E5B),
              ),
              const SizedBox(height: 12),
              _buildDonationButton(
                context: ctx,
                label: 'Donate on Liberapay',
                icon: Icons.favorite_outline,
                url: 'https://liberapay.com/dominikmuellr/donate',
                color: const Color(0xFFF6C915),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonationButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String url,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(url);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (e) {
            // URL couldn't be launched
          }
        },
        icon: Icon(icon, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
