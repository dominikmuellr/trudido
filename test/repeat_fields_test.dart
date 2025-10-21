import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/models/todo.dart';

void main() {
  group('Todo Repeat Fields', () {
    test('Todo with repeat settings should serialize correctly', () {
      final todo = Todo(
        text: 'Test Task',
        repeatType: 'daily',
        repeatInterval: 2,
        repeatDays: [1, 3, 5],
        repeatEndDate: DateTime(2025, 12, 31),
        dueDate: DateTime(2025, 10, 21),
      );

      // Verify fields are set
      expect(todo.repeatType, 'daily');
      expect(todo.repeatInterval, 2);
      expect(todo.repeatDays, [1, 3, 5]);
      expect(todo.repeatEndDate, DateTime(2025, 12, 31));
      expect(todo.isRecurring, true);

      // Test JSON serialization
      final json = todo.toJson();
      expect(json['repeatType'], 'daily');
      expect(json['repeatInterval'], 2);
      expect(json['repeatDays'], [1, 3, 5]);
      expect(json['repeatEndDate'], isNotNull);

      // Test JSON deserialization
      final fromJson = Todo.fromJson(json);
      expect(fromJson.repeatType, 'daily');
      expect(fromJson.repeatInterval, 2);
      expect(fromJson.repeatDays, [1, 3, 5]);
      expect(fromJson.isRecurring, true);
    });

    test('Todo without repeat should have default repeatType', () {
      final todo = Todo(text: 'Simple Task', dueDate: DateTime(2025, 10, 21));

      expect(todo.repeatType, 'none');
      expect(todo.isRecurring, false);
      expect(todo.repeatInterval, null);
      expect(todo.repeatDays, null);
      expect(todo.repeatEndDate, null);
    });

    test('Todo copyWith should preserve repeat settings', () {
      final original = Todo(
        text: 'Test Task',
        repeatType: 'weekly',
        repeatInterval: 1,
        repeatDays: [1, 3, 5],
        dueDate: DateTime(2025, 10, 21),
      );

      // Copy without changing repeat settings
      final copied = original.copyWith(text: 'Updated Task');
      expect(copied.repeatType, 'weekly');
      expect(copied.repeatInterval, 1);
      expect(copied.repeatDays, [1, 3, 5]);

      // Copy and change repeat settings
      final updated = original.copyWith(repeatType: 'daily', repeatInterval: 2);
      expect(updated.repeatType, 'daily');
      expect(updated.repeatInterval, 2);
    });
  });
}
