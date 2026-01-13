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
import '../providers/app_providers.dart';
import '../utils/responsive_size.dart';
import 'about_screen.dart';
import 'personalization_screen.dart';
import 'comprehensive_notification_settings.dart';
import 'template_management_screen.dart';
import 'app_lock_settings_page.dart';
import 'data_management_screen.dart';
import 'experimental_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: ScaledIcon(Icons.palette_outlined),
            title: const Text('Personalization'),
            subtitle: const Text(
              'Profile, colors, layout, and visual preferences',
            ),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PersonalizationScreen(),
                ),
              );
            },
          ),

          // Notifications & Alerts Section
          _buildSectionHeader(context, 'Notifications & Alerts'),
          ListTile(
            leading: ScaledIcon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Permissions, settings, and reliability'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      const ComprehensiveNotificationSettings(),
                ),
              );
            },
          ),

          // Security Section
          _buildSectionHeader(context, 'Security'),
          ListTile(
            leading: ScaledIcon(Icons.lock_outline),
            title: const Text('App Lock'),
            subtitle: const Text('Protect app with PIN or fingerprint'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AppLockSettingsPage(),
                ),
              );
            },
          ),

          // Data Management Section
          _buildSectionHeader(context, 'Data Management'),
          ListTile(
            leading: ScaledIcon(Icons.storage_outlined),
            title: const Text('Data Management'),
            subtitle: const Text('Calendar sync, import, backup, and data'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DataManagementScreen(),
                ),
              );
            },
          ),

          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: ScaledIcon(Icons.info_outline),
            title: const Text('About & Licenses'),
            subtitle: const Text(
              'App license, package licenses and repository',
            ),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),

          // Support Section
          _buildSectionHeader(context, 'Support'),
          ListTile(
            leading: ScaledIcon(Icons.favorite_outline),
            title: const Text('Support Development'),
            subtitle: const Text('Buy me a coffee or donate'),
            trailing: ScaledIcon(Icons.arrow_forward_ios),
            onTap: () => _showSupportSheet(context),
          ),

          // Experimental Section
          _buildSectionHeader(context, 'Experimental'),
          ListTile(
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
          ),
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
        ],
      ),
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
