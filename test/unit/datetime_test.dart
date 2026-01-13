/// Comprehensive tests for the Datetime class.
///
/// Tests cover ISO 8601 format parsing, construction, serialization,
/// fromJson factory, and equality/hashCode behavior.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('ISO 8601 Format Parsing', () {
    test('parses UTC datetime with Z suffix', () {
      final dt = Datetime.parse('2023-10-21T12:00:00Z');
      final dartDt = dt.toDateTime();

      expect(dartDt.isUtc, isTrue);
      expect(dartDt.year, equals(2023));
      expect(dartDt.month, equals(10));
      expect(dartDt.day, equals(21));
      expect(dartDt.hour, equals(12));
      expect(dartDt.minute, equals(0));
      expect(dartDt.second, equals(0));
    });

    test('parses datetime with positive timezone offset', () {
      final dt = Datetime.parse('2023-10-21T12:00:00+05:30');
      final dartDt = dt.toDateTime();

      // Dart converts to UTC: 12:00 IST (+05:30) = 06:30 UTC
      expect(dartDt.isUtc, isTrue);
      expect(dartDt.hour, equals(6));
      expect(dartDt.minute, equals(30));
    });

    test('parses datetime with negative timezone offset', () {
      final dt = Datetime.parse('2023-10-21T12:00:00-08:00');
      final dartDt = dt.toDateTime();

      // Dart converts to UTC: 12:00 PST (-08:00) = 20:00 UTC
      expect(dartDt.isUtc, isTrue);
      expect(dartDt.hour, equals(20));
    });

    test('parses datetime with milliseconds', () {
      final dt = Datetime.parse('2023-10-21T12:00:00.123Z');
      final dartDt = dt.toDateTime();

      expect(dartDt.millisecond, equals(123));
      expect(dartDt.microsecond, equals(0));
    });

    test('parses datetime with microseconds', () {
      final dt = Datetime.parse('2023-10-21T12:00:00.123456Z');
      final dartDt = dt.toDateTime();

      expect(dartDt.millisecond, equals(123));
      expect(dartDt.microsecond, equals(456));
    });

    test('parses date-only format', () {
      final dt = Datetime.parse('2023-10-21');
      final dartDt = dt.toDateTime();

      expect(dartDt.year, equals(2023));
      expect(dartDt.month, equals(10));
      expect(dartDt.day, equals(21));
      // Defaults to midnight
      expect(dartDt.hour, equals(0));
      expect(dartDt.minute, equals(0));
    });

    test('parses datetime with space separator', () {
      final dt = Datetime.parse('2023-10-21 12:30:45');
      final dartDt = dt.toDateTime();

      expect(dartDt.year, equals(2023));
      expect(dartDt.hour, equals(12));
      expect(dartDt.minute, equals(30));
      expect(dartDt.second, equals(45));
    });

    test('throws FormatException for invalid formats', () {
      expect(() => Datetime.parse('invalid'), throwsFormatException);
      expect(() => Datetime.parse('2023/10/21'), throwsFormatException);
      expect(() => Datetime.parse(''), throwsFormatException);
      expect(() => Datetime.parse('not-a-date'), throwsFormatException);
      expect(() => Datetime.parse('21-10-2023'), throwsFormatException);
    });
  });

  group('Construction and Conversion', () {
    test('creates from Dart DateTime (local)', () {
      final dartDt = DateTime(2023, 10, 21, 12, 30, 45);
      final surrealDt = Datetime(dartDt);

      expect(surrealDt.toDateTime(), equals(dartDt));
      expect(surrealDt.toDateTime().isUtc, isFalse);
    });

    test('creates from Dart DateTime (UTC)', () {
      final dartDt = DateTime.utc(2023, 10, 21, 12, 30, 45);
      final surrealDt = Datetime(dartDt);

      expect(surrealDt.toDateTime(), equals(dartDt));
      expect(surrealDt.toDateTime().isUtc, isTrue);
    });

    test('preserves milliseconds in round-trip', () {
      final dartDt = DateTime.utc(2023, 10, 21, 12, 30, 45, 123);
      final surrealDt = Datetime(dartDt);

      expect(surrealDt.toDateTime().millisecond, equals(123));
    });

    test('preserves microseconds in round-trip', () {
      final dartDt = DateTime.utc(2023, 10, 21, 12, 30, 45, 123, 456);
      final surrealDt = Datetime(dartDt);

      expect(surrealDt.toDateTime().millisecond, equals(123));
      expect(surrealDt.toDateTime().microsecond, equals(456));
    });
  });

  group('Serialization', () {
    test('toJson returns ISO 8601 string', () {
      final dt = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));
      final json = dt.toJson();

      expect(json, isA<String>());
      expect(json, contains('2023-10-21'));
      expect(json, contains('12:00:00'));
    });

    test('toIso8601String includes milliseconds', () {
      final dt = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0, 123));
      final str = dt.toIso8601String();

      expect(str, contains('.123'));
    });

    test('toString equals toIso8601String', () {
      final dt = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));

      expect(dt.toString(), equals(dt.toIso8601String()));
    });
  });

  group('fromJson Factory', () {
    test('fromJson accepts valid ISO 8601 string', () {
      final dt = Datetime.fromJson('2023-10-21T12:00:00Z');

      expect(dt.toDateTime().year, equals(2023));
      expect(dt.toDateTime().month, equals(10));
      expect(dt.toDateTime().day, equals(21));
    });

    test('fromJson throws ArgumentError for non-string types', () {
      expect(() => Datetime.fromJson(123), throwsArgumentError);
      expect(() => Datetime.fromJson(null), throwsArgumentError);
      expect(() => Datetime.fromJson([]), throwsArgumentError);
      expect(() => Datetime.fromJson({}), throwsArgumentError);
      expect(() => Datetime.fromJson(true), throwsArgumentError);
    });

    test('fromJson throws FormatException for invalid string', () {
      expect(() => Datetime.fromJson('not-a-date'), throwsFormatException);
      expect(() => Datetime.fromJson('invalid'), throwsFormatException);
    });
  });

  group('Equality and HashCode', () {
    test('equal datetimes are equal', () {
      final dt1 = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));
      final dt2 = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));

      expect(dt1, equals(dt2));
      expect(dt1.hashCode, equals(dt2.hashCode));
    });

    test('different datetimes are not equal', () {
      final dt1 = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));
      final dt2 = Datetime(DateTime.utc(2023, 10, 21, 13, 0, 0));

      expect(dt1, isNot(equals(dt2)));
    });

    test('millisecond difference makes datetimes unequal', () {
      final dt1 = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0, 0));
      final dt2 = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0, 1));

      expect(dt1, isNot(equals(dt2)));
    });
  });

  group('Edge Cases', () {
    test('handles epoch time', () {
      final dt = Datetime(DateTime.utc(1970, 1, 1, 0, 0, 0));
      final dartDt = dt.toDateTime();

      expect(dartDt.millisecondsSinceEpoch, equals(0));
    });

    test('handles far future dates', () {
      final dt = Datetime(DateTime.utc(2099, 12, 31, 23, 59, 59));
      final dartDt = dt.toDateTime();

      expect(dartDt.year, equals(2099));
      expect(dartDt.month, equals(12));
      expect(dartDt.day, equals(31));
    });

    test('handles leap year date', () {
      final dt = Datetime.parse('2024-02-29T12:00:00Z');
      final dartDt = dt.toDateTime();

      expect(dartDt.year, equals(2024));
      expect(dartDt.month, equals(2));
      expect(dartDt.day, equals(29));
    });

    test('preserves precision through string round-trip', () {
      final original = DateTime.utc(2023, 10, 21, 12, 30, 45, 123, 456);
      final surrealDt = Datetime(original);
      final isoString = surrealDt.toIso8601String();
      final parsed = Datetime.parse(isoString);

      // Verify millisecond precision is preserved
      expect(parsed.toDateTime().millisecond, equals(123));
      // Note: microsecond precision depends on ISO string format
    });
  });
}
