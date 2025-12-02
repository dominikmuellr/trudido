import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _licenseText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    try {
      final text = await rootBundle.loadString('LICENSE');
      if (mounted) {
        setState(() {
          _licenseText = text;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _licenseText = 'License file not found.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _openGitHub() async {
    const url = 'https://github.com/dominikmuellr/trudido';
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About & Licenses')),
      body: ListView(
        children: [
          // App Information Section
          _buildSectionHeader(context, 'App Information'),
          ListTile(
            leading: Icon(Icons.info_outline, color: cs.primary),
            title: const Text('App Name'),
            subtitle: const Text('Trudido'),
          ),
          ListTile(
            leading: Icon(Icons.tag, color: cs.primary),
            title: const Text('Version'),
            subtitle: const Text('v1.2.2'),
          ),
          ListTile(
            leading: Icon(Icons.code, color: cs.primary),
            title: const Text('GitHub Repository'),
            subtitle: const Text('View source code and contribute'),
            trailing: Icon(
              Icons.open_in_new,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: _openGitHub,
          ),

          // Licenses Section
          _buildSectionHeader(context, 'Licenses'),
          ListTile(
            leading: Icon(Icons.article_outlined, color: cs.primary),
            title: const Text('App License'),
            subtitle: const Text('GPL-3.0 - View full license text'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: _showLicenseDialog,
          ),
          ListTile(
            leading: Icon(Icons.list, color: cs.primary),
            title: const Text('Package Licenses'),
            subtitle: const Text('View licenses of all dependencies'),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Trudido',
              applicationVersion: 'v1.2.2',
            ),
          ),

          // Packages Section
          _buildSectionHeader(context, 'Core Packages'),
          _buildPackageTile('State Management', 'flutter_riverpod', '^2.5.1'),
          _buildPackageTile('Local Database', 'hive', '^2.2.3'),
          _buildPackageTile(
            'Shared Preferences',
            'shared_preferences',
            '^2.3.2',
          ),
          _buildPackageTile('Path Provider', 'path_provider', '^2.1.4'),

          _buildSectionHeader(context, 'UI & Utilities'),
          _buildPackageTile('Material You Colors', 'dynamic_color', '^1.7.0'),
          _buildPackageTile('Slidable Widgets', 'flutter_slidable', '^4.0.1'),
          _buildPackageTile('Calendar', 'table_calendar', '^3.1.2'),
          _buildPackageTile(
            'Staggered Grid',
            'flutter_staggered_grid_view',
            '^0.7.0',
          ),
          _buildPackageTile(
            'Markdown Rendering',
            'flutter_markdown_plus',
            '^1.0.5',
          ),
          _buildPackageTile('Rich Text Editor', 'flutter_quill', '^11.5.0'),
          _buildPackageTile('URL Launcher', 'url_launcher', '^6.1.10'),
          _buildPackageTile('Internationalization', 'intl', '^0.20.2'),
          _buildPackageTile('UUID Generator', 'uuid', '^4.5.0'),

          _buildSectionHeader(context, 'Media & Files'),
          _buildPackageTile('File Picker', 'file_picker', '^10.3.2'),
          _buildPackageTile('Image Picker', 'image_picker', '^1.1.2'),
          _buildPackageTile('Video Player', 'video_player', '^2.9.2'),
          _buildPackageTile('Video Thumbnails', 'video_thumbnail', '^0.5.3'),
          _buildPackageTile('Audio Recording', 'record', '^5.1.2'),
          _buildPackageTile('Audio Playback', 'audioplayers', '^6.0.0'),
          _buildPackageTile('PDF Generation', 'pdf', '^3.11.1'),
          _buildPackageTile('PDF Printing', 'printing', '^5.13.4'),

          _buildSectionHeader(context, 'Security'),
          _buildPackageTile('Encryption', 'encrypt', '^5.0.3'),
          _buildPackageTile(
            'Secure Storage',
            'flutter_secure_storage',
            '^9.2.2',
          ),
          _buildPackageTile('Biometric Auth', 'local_auth', '^2.3.0'),
          _buildPackageTile('Cryptography', 'crypto', '^3.0.3'),
          _buildPackageTile('Permissions', 'permission_handler', '^12.0.1'),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Made with ❤️ in Europe',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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

  Widget _buildPackageTile(String name, String packageName, String version) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        Icons.extension_outlined,
        color: theme.colorScheme.tertiary,
        size: 20,
      ),
      title: Text(name),
      subtitle: Text('$packageName $version', style: theme.textTheme.bodySmall),
      dense: true,
    );
  }

  void _showLicenseDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LICENSE (GPL-3.0)'),
        content: SizedBox(
          width: double.maxFinite,
          child: _loading
              ? const SizedBox(
                  height: 64,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SingleChildScrollView(child: Text(_licenseText)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
