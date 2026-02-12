import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/utils/markdown_inline_patterns.dart';
import 'package:trudido/utils/markdown_to_quill_converter.dart';

void main() {
  group('Markdown converter smoke tests', () {
    test('empty markdown produces valid newline-only document', () {
      final doc = MarkdownToQuillConverter.markdownToDocument('');

      expect(doc.toPlainText().trim(), isEmpty);
      expect(doc.toPlainText().startsWith('\n'), isTrue);
      expect(doc.toDelta().toList().isNotEmpty, isTrue);
    });

    test('inline markdown styles are preserved as quill attributes', () {
      const input =
          'Text **bold** *italic* ~~strike~~ `code` <u>under</u> ==highlight==';
      final doc = MarkdownToQuillConverter.markdownToDocument(input);
      final ops = doc.toDelta().toList();

      bool hasAttr(String key, [Object? value]) {
        return ops.any((op) {
          final attrs = op.attributes;
          if (attrs == null || !attrs.containsKey(key)) return false;
          return value == null || attrs[key] == value;
        });
      }

      expect(hasAttr('bold', true), isTrue);
      expect(hasAttr('italic', true), isTrue);
      expect(hasAttr('strike', true), isTrue);
      expect(hasAttr('code', true), isTrue);
      expect(hasAttr('underline', true), isTrue);
      expect(hasAttr('background', '#ffff00'), isTrue);
    });

    test('block markdown syntax maps to quill block attributes', () {
      const input = '''# Header
- [x] Done
- [ ] Todo
- Bullet
1. Ordered
> Quote''';

      final doc = MarkdownToQuillConverter.markdownToDocument(input);
      final ops = doc.toDelta().toList();

      bool hasBlock(String key, Object value) {
        return ops.any((op) {
          final attrs = op.attributes;
          if (attrs == null || !attrs.containsKey(key)) return false;
          return attrs[key] == value;
        });
      }

      expect(hasBlock('header', 1), isTrue);
      expect(hasBlock('list', 'checked'), isTrue);
      expect(hasBlock('list', 'unchecked'), isTrue);
      expect(hasBlock('list', 'bullet'), isTrue);
      expect(hasBlock('list', 'ordered'), isTrue);
      expect(hasBlock('blockquote', true), isTrue);
    });

    test('document to markdown keeps key formatting tokens', () {
      const input = '**bold** and *italic* and ==highlight==';
      final doc = MarkdownToQuillConverter.markdownToDocument(input);
      final markdown = MarkdownToQuillConverter.documentToMarkdown(doc);

      expect(markdown, contains('**bold**'));
      expect(markdown, contains('*italic*'));
      expect(markdown, contains('==highlight=='));
    });
  });

  group('Markdown inline matcher smoke tests', () {
    test('finds non-overlapping matches for normal text', () {
      const input = '**bold** and *italic* and `code`';

      final matches = MarkdownInlinePatterns.findNonOverlappingMatches(
        input,
        MarkdownInlinePatterns.textStyles,
      );

      expect(matches.length, 3);
      expect(
        matches.map((e) => e.value),
        containsAll(['bold', 'italic', 'code']),
      );
    });

    test('filters overlapping matches deterministically', () {
      const input = '~~**nested**~~';

      final matches = MarkdownInlinePatterns.findNonOverlappingMatches(
        input,
        MarkdownInlinePatterns.textStyles,
      );

      expect(matches.length, 1);
      expect(matches.first.value, 'strikethrough');
    });
  });
}
