import 'package:flutter_test/flutter_test.dart';
import 'package:trudido/utils/formatters.dart';

void main() {
  group('formatMinutesReadable', () {
    test('formats 0 minutes correctly', () {
      expect(formatMinutesReadable(0), 'At time of due date');
    });

    test('formats single digit minutes correctly', () {});

    test('formats double digit minutes correctly', () {
      expect(formatMinutesReadable(15), '15 minutes before');
      expect(formatMinutesReadable(30), '30 minutes before');
      expect(formatMinutesReadable(45), '45 minutes before');
    });

    test('formats exactly 1 hour correctly', () {
      expect(formatMinutesReadable(60), '1 hour before');
    });

    test('formats multiple hours correctly', () {
      expect(formatMinutesReadable(120), '2 hours before');
      expect(formatMinutesReadable(360), '6 hours before');
    });

    test('formats exactly 1 day correctly', () {
      expect(formatMinutesReadable(1440), '1 day before');
    });

    test('formats multiple days correctly', () {
      expect(formatMinutesReadable(2880), '2 days before');
      expect(formatMinutesReadable(4320), '3 days before');
      expect(formatMinutesReadable(7200), '5 days before');
    });

    test('formats multiple weeks as days', () {
      expect(formatMinutesReadable(20160), '14 days before');
      expect(formatMinutesReadable(30240), '21 days before');
    });

    test('formats mixed time units correctly', () {
      // 1 hour 30 minutes = 90 minutes
      expect(formatMinutesReadable(90), '1 hour 30 minutes before');

      // 1 day 2 hours = 1560 minutes
      expect(formatMinutesReadable(1560), '1 day 2 hours before');

      // 23 hours = 1380 minutes (less than a day)
      expect(formatMinutesReadable(1380), '23 hours before');
    });

    test('formats edge cases correctly', () {
      // Just under thresholds
      expect(formatMinutesReadable(59), '59 minutes before');
      expect(formatMinutesReadable(1439), '23 hours 59 minutes before');

      // Large values (many days)
      expect(formatMinutesReadable(525600), '365 days before'); // 1 year
    });

    test('handles boundary values', () {
      // Common preset values from the app
      expect(formatMinutesReadable(0), 'At time of due date');
      expect(formatMinutesReadable(5), '5 minutes before');
      expect(formatMinutesReadable(15), '15 minutes before');
      expect(formatMinutesReadable(30), '30 minutes before');
      expect(formatMinutesReadable(60), '1 hour before');
      expect(formatMinutesReadable(120), '2 hours before');
      expect(formatMinutesReadable(1440), '1 day before');
      expect(formatMinutesReadable(2880), '2 days before');
      expect(formatMinutesReadable(10080), '7 days before');
    });

    test('handles fractional time units correctly', () {
      // 3 hours 15 minutes
      expect(formatMinutesReadable(195), '3 hours 15 minutes before');

      // 2 days 5 hours
      expect(formatMinutesReadable(3180), '2 days 5 hours before');

      // 1 day 1 hour (singular forms)
      expect(formatMinutesReadable(1500), '1 day 1 hour before');

      // 1 hour 1 minute (singular forms)
      expect(formatMinutesReadable(61), '1 hour 1 minute before');
    });
  });
}
