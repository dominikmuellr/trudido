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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Licenses'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Trudido', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('v.1.2.0-2', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.code),
            label: const Text('View repository on GitHub'),
            onPressed: _openGitHub,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.article_outlined),
            label: const Text('View bundled LICENSE'),
            onPressed: () => _showLicenseDialog(),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.list),
            label: const Text('Open package licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Trudido',
              applicationVersion: 'v.1.2.0-2',
            ),
          ),
        ],
      ),
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
              ? const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()))
              : SingleChildScrollView(child: Text(_licenseText)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
