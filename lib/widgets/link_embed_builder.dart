import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';

/// Custom embed builder for rendering clickable links in Quill editor
class LinkEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'link';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;

    // Get data - it could be a map or a JSON string
    Map<String, dynamic> data;
    if (node.value.data is Map) {
      data = node.value.data as Map<String, dynamic>;
    } else {
      // Parse JSON string to map if it's a string
      data = jsonDecode(node.value.data as String) as Map<String, dynamic>;
    }

    final url = data['url'] as String;
    final text = data['text'] as String? ?? url;

    return InkWell(
      onTap: () => _openLink(context, url),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    try {
      // Add scheme if not present
      String urlString = url;
      if (!urlString.startsWith('http://') &&
          !urlString.startsWith('https://')) {
        urlString = 'https://$urlString';
      }

      // Use url_launcher to open the link
      final uri = Uri.parse(urlString);

      // Try launching without specifying mode - let the system decide
      final launched = await launchUrl(uri);

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      print('Error opening link: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening link')));
      }
    }
  }
}
