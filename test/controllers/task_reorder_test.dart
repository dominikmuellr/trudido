import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/models/todo.dart';
import 'package:trudido/controllers/task_controller.dart';

void main() {
  test('computeReordered moves first item to end when newIndex == length', () {
    final seed = [
      Todo(id: 'a', text: 'A', createdAt: DateTime.now()),
      Todo(id: 'b', text: 'B', createdAt: DateTime.now()),
      Todo(id: 'c', text: 'C', createdAt: DateTime.now()),
    ];
    final result = computeReordered(seed, seed, 0, 3)!;
    expect(result.map((t) => t.id).toList(), ['b', 'c', 'a']);
  });

  test('computeReordered inserts in middle correctly', () {
    final seed = [
      Todo(id: 'a', text: 'A', createdAt: DateTime.now()),
      Todo(id: 'b', text: 'B', createdAt: DateTime.now()),
      Todo(id: 'c', text: 'C', createdAt: DateTime.now()),
      Todo(id: 'd', text: 'D', createdAt: DateTime.now()),
    ];
    final result = computeReordered(seed, seed, 3, 1)!; // move d before b
    expect(result.map((t) => t.id).toList(), ['a', 'd', 'b', 'c']);
  });
}
