// Test for the _nextSelectedDay logic used in task/event controllers.
// Since _nextSelectedDay is private, we test the equivalent logic directly.

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the _nextSelectedDay logic from the controllers.
DateTime nextSelectedDay(DateTime current, List<int> days, int interval) {
  final sorted = List<int>.from(days)..sort();
  final currentWeekday = current.weekday;

  for (final day in sorted) {
    if (day > currentWeekday) {
      return current.add(Duration(days: day - currentWeekday));
    }
  }

  final daysUntilEndOfWeek = 7 - currentWeekday;
  return current.add(
    Duration(days: daysUntilEndOfWeek + (interval - 1) * 7 + sorted.first),
  );
}

void main() {
  // March 2026 calendar:
  // Mon=2,9,16,23  Tue=3,10,17  Wed=4,11,18  Thu=5,12,19  Fri=6,13,20
  // Sat=7,14,21  Sun=1,8,15

  group('nextSelectedDay', () {
    test('Mon with Mon-Fri selected → next is Tue', () {
      final monday = DateTime(2026, 3, 9);
      expect(monday.weekday, 1);
      final next = nextSelectedDay(monday, [1, 2, 3, 4, 5], 1);
      expect(next, DateTime(2026, 3, 10)); // Tuesday
      expect(next.weekday, 2);
    });

    test('Fri with Mon-Fri selected, interval=1 → next is Mon', () {
      final friday = DateTime(2026, 3, 6);
      expect(friday.weekday, 5);
      final next = nextSelectedDay(friday, [1, 2, 3, 4, 5], 1);
      expect(next, DateTime(2026, 3, 9)); // next Monday
      expect(next.weekday, 1);
    });

    test('Wed with Mon/Wed/Fri selected → next is Fri', () {
      final wed = DateTime(2026, 3, 4);
      expect(wed.weekday, 3);
      final next = nextSelectedDay(wed, [1, 3, 5], 1);
      expect(next, DateTime(2026, 3, 6)); // Friday
      expect(next.weekday, 5);
    });

    test('Fri with Mon/Wed/Fri selected, interval=2 → skip one week to Mon', () {
      final friday = DateTime(2026, 3, 6);
      expect(friday.weekday, 5);
      final next = nextSelectedDay(friday, [1, 3, 5], 2);
      // Fri→Sun(+2) + 7 (skip 1 week) + Mon(+1) = +10
      expect(next, DateTime(2026, 3, 16)); // Monday 2 weeks later
      expect(next.weekday, 1);
    });

    test('Sun with Mon-Wed selected, interval=1 → next is Mon', () {
      final sunday = DateTime(2026, 3, 8);
      expect(sunday.weekday, 7);
      final next = nextSelectedDay(sunday, [1, 2, 3], 1);
      expect(next, DateTime(2026, 3, 9)); // Monday
      expect(next.weekday, 1);
    });

    test('Thu with Mon-Fri selected → next is Fri', () {
      final thu = DateTime(2026, 3, 5);
      expect(thu.weekday, 4);
      final next = nextSelectedDay(thu, [1, 2, 3, 4, 5], 1);
      expect(next, DateTime(2026, 3, 6)); // Friday
      expect(next.weekday, 5);
    });
  });
}
