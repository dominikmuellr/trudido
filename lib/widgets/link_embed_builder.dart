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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common/common.dart';

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

    return ExpressiveInkWell(
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

      // Use url_launcher to open the link in external browser
      final uri = Uri.parse(urlString);

      // Open in external browser app (not in-app webview)
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      debugPrint('Error opening link: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error opening link')));
      }
    }
  }
}
