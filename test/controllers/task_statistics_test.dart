import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trudido/controllers/task_controller.dart';
import 'package:trudido/models/todo.dart';
import 'package:trudido/providers/clock.dart';

void main() {
  group('TaskStatistics', () {
    test('computes counts, overdue, today, soon and completion rate', () async {
      final now = DateTime.now();
      final seed = [
        Todo(
          id: '1',
          text: 'overdue',
          createdAt: now.subtract(const Duration(days: 2)),
          dueDate: now.subtract(const Duration(days: 1)),
          priority: 'high',
        ),
        Todo(
          id: '2',
          text: 'today',
          createdAt: now,
          dueDate: DateTime(now.year, now.month, now.day, 23),
          priority: 'medium',
        ),
        Todo(
          id: '3',
          text: 'soon',
          createdAt: now,
          dueDate: now.add(const Duration(days: 2)),
          priority: 'low',
        ),
        Todo(
          id: '4',
          text: 'done',
          createdAt: now.subtract(const Duration(days: 1)),
          isCompleted: true,
          completedAt: now.subtract(const Duration(hours: 3)),
          priority: 'high',
        ),
      ];
      final container = ProviderContainer(
        overrides: [
          rawTasksProvider.overrideWithValue(seed),

          clockProvider.overrideWithValue(FixedClock(now)),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(taskStatisticsProvider);
      expect(stats.total, 4);
      expect(stats.completed, 1);
      expect(stats.pending, 3);
      expect(stats.overdue, 1);
      expect(stats.dueToday, 1);
      expect(stats.dueSoon, 1);
      expect(stats.byPriority['high'], 2);
      expect((stats.completionRate * 100).round(), 25);
    });

    test('streak and motivationalMessage thresholds', () async {
      final now = DateTime.now();
      final seed = [
        for (int i = 0; i < 3; i++)
          Todo(
            id: 'c$i',
            text: 'done $i',
            createdAt: now.subtract(Duration(days: i)),
            isCompleted: true,
            completedAt: DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: i)),
          ),

        Todo(id: 'p1', text: 'pending1', createdAt: now),
        Todo(id: 'p2', text: 'pending2', createdAt: now),
      ];
      final container = ProviderContainer(
        overrides: [
          rawTasksProvider.overrideWithValue(seed),
          clockProvider.overrideWithValue(FixedClock(now)),
        ],
      );
      addTearDown(container.dispose);
      final stats = container.read(taskStatisticsProvider);
      expect(stats.streakDays, greaterThanOrEqualTo(3));

      expect(stats.completionRate, closeTo(0.6, 0.0001));
      final msg = stats.motivationalMessage;
      expect(msg.contains('Great progress'), isTrue);
    });
  });
}
