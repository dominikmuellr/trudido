import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/utils/todo_txt_converter.dart';

void main() {
  group('TodoTxtConverter', () {
    test('converts todo.txt to markdown', () {
      const todoTxt = '''
x Buy milk +Shopping @Home
(A) Call dentist @Phone
Finish report +Work
''';

      final markdown = TodoTxtConverter.todoTxtToMarkdown(todoTxt);
      print('Input:\n$todoTxt');
      print('\nOutput:\n$markdown');

      expect(markdown, contains('- [x] Buy milk'));
      expect(markdown, contains('- [ ] (A) Call dentist'));
      expect(markdown, contains('- [ ] Finish report'));
    });

    test('converts markdown to todo.txt', () {
      const markdown = '''
My Tasks

- [x] Buy milk +Shopping @Home
- [ ] (A) Call dentist @Phone
- [ ] Finish report +Work
''';

      final todoTxt = TodoTxtConverter.markdownToTodoTxt(markdown);
      print('Input:\n$markdown');
      print('\nOutput:\n$todoTxt');

      expect(todoTxt, contains('x Buy milk'));
      expect(todoTxt, contains('(A) Call dentist'));
      expect(todoTxt, contains('Finish report'));
    });

    test('round-trip conversion', () {
      const originalTodoTxt = '''(A) Task one +Project @Context
x Task two
Task three +Work''';

      // Convert to markdown and back
      final markdown = TodoTxtConverter.todoTxtToMarkdown(originalTodoTxt);
      final backToTodoTxt = TodoTxtConverter.markdownToTodoTxt(markdown);

      print('Original:\n$originalTodoTxt');
      print('\nTo Markdown:\n$markdown');
      print('\nBack to Todo.txt:\n$backToTodoTxt');

      expect(backToTodoTxt, contains('(A) Task one'));
      expect(backToTodoTxt, contains('x Task two'));
      expect(backToTodoTxt, contains('Task three'));
    });

    test('sorts todo.txt by priority', () {
      const todoTxt = '''Task no priority
x Completed task
(C) Low priority
(A) High priority
(B) Medium priority''';

      final sorted = TodoTxtConverter.sortTodoTxt(todoTxt);
      print('Original:\n$todoTxt');
      print('\nSorted:\n$sorted');

      final lines = sorted.split('\n');
      expect(lines[0], contains('(A) High priority'));
      expect(lines[1], contains('(B) Medium priority'));
      expect(lines[2], contains('(C) Low priority'));
    });
  });
}
