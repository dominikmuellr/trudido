import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../utils/smart_markdown_helper.dart';

/// Quick demo of smart blockquote colors in action
class SmartBlockquoteDemo extends StatelessWidget {
  const SmartBlockquoteDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const markdownContent = '''
# Smart Blockquote Demo

This demo shows how blockquotes automatically get the best text color based on their background.

> This is a sample blockquote with **bold text** and *italic text*.
> The text color is automatically chosen to have optimal contrast
> against the blockquote background.

## Another Example

> "The only way to do great work is to love what you do."
> *- Steve Jobs*

Normal paragraph text continues here with regular styling.

> Here's a longer blockquote that might span multiple lines 
> and contains various formatting elements like `inline code`,
> **bold emphasis**, and *italic text*.

### Third Example

> Short quote here.

The end of the demonstration.
''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Blockquote Colors'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Theme toggle buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Switch to light theme
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => MaterialApp(
                          theme: ThemeData.light(),
                          home: const SmartBlockquoteDemo(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.light_mode),
                  label: const Text('Light'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // Switch to dark theme
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => MaterialApp(
                          theme: ThemeData.dark(),
                          home: const SmartBlockquoteDemo(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dark_mode),
                  label: const Text('Dark'),
                ),
              ],
            ),
          ),
          const Divider(),
          
          // Markdown content with smart blockquotes
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: MarkdownBody(
                data: markdownContent,
                styleSheet: SmartMarkdownHelper.createStyleSheet(context),
                selectable: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone app for testing
class SmartBlockquoteDemoApp extends StatelessWidget {
  const SmartBlockquoteDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Blockquote Demo',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const SmartBlockquoteDemo(),
    );
  }
}
