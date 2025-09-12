import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Demo screen to test markdown functionality
class MarkdownDemo extends StatelessWidget {
  const MarkdownDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const demoMarkdown = '''
# Welcome to Flutter Markdown

This is a **demo** of the markdown notes feature.

## Features

- **Bold** and *italic* text
- [Links](https://flutter.dev)
- Code blocks:

```dart
void main() {
  print('Hello, World!');
}
```

### Lists

1. Numbered item
2. Another item
3. Third item

- Bullet point
- Another bullet
- Third bullet

> This is a blockquote with **formatted** text.

## Code

Inline `code` is also supported.

---

That's it! Happy note-taking! 📝
''';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Demo'),
      ),
      body: const Markdown(
        data: demoMarkdown,
        selectable: true,
      ),
    );
  }
}
