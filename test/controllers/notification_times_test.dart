import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/controllers/task_controller.dart';

void main() {
  test('computeReminderTimes filters past and sorts', () {
    final now = DateTime(2025, 9, 2, 12, 0);
    final due = DateTime(2025, 9, 2, 15, 0); // 3 hours ahead
    final result = computeReminderTimes(due, [60, 10, 200, 60, -5], now);
    // 200 minutes before due is 11:40 same day (which is before now 12:00) -> filtered out
    // 60 minutes -> 14:00, 10 minutes -> 14:50
    expect(result.keys.toList(), [60, 10]);
    expect(result[60], DateTime(2025, 9, 2, 14, 0));
    expect(result[10], DateTime(2025, 9, 2, 14, 50));
  });
}
