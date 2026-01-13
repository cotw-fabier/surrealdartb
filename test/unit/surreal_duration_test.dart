/// Comprehensive tests for the SurrealDuration class.
///
/// Tests cover parsing of SurrealDB duration strings, conversion to/from
/// Dart Duration, string serialization, and round-trip behavior.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Parsing Simple Duration Strings', () {
    test('parses seconds', () {
      final dur = SurrealDuration.parse('30s');
      expect(dur.toDuration().inSeconds, equals(30));
    });

    test('parses minutes', () {
      final dur = SurrealDuration.parse('15m');
      expect(dur.toDuration().inMinutes, equals(15));
    });

    test('parses hours', () {
      final dur = SurrealDuration.parse('2h');
      expect(dur.toDuration().inHours, equals(2));
    });

    test('parses days', () {
      final dur = SurrealDuration.parse('5d');
      expect(dur.toDuration().inDays, equals(5));
    });

    test('parses weeks', () {
      final dur = SurrealDuration.parse('2w');
      expect(dur.toDuration().inDays, equals(14));
    });

    test('parses milliseconds', () {
      final dur = SurrealDuration.parse('500ms');
      expect(dur.toDuration().inMilliseconds, equals(500));
    });

    test('parses microseconds (us)', () {
      final dur = SurrealDuration.parse('1000us');
      expect(dur.toDuration().inMicroseconds, equals(1000));
    });

    test('parses microseconds (micro symbol)', () {
      final dur = SurrealDuration.parse('1000\u00b5s');
      expect(dur.toDuration().inMicroseconds, equals(1000));
    });

    test('parses nanoseconds (rounded to microseconds)', () {
      final dur = SurrealDuration.parse('5000ns');
      // 5000ns = 5us
      expect(dur.toDuration().inMicroseconds, equals(5));
    });

    test('parses nanoseconds with rounding', () {
      // 1500ns should round to 2us (1.5us rounds to 2us based on implementation)
      final dur = SurrealDuration.parse('1500ns');
      // 1500ns / 1000 = 1.5us, which rounds to 2us
      expect(dur.toDuration().inMicroseconds, equals(2));
    });
  });

  group('Parsing Complex Duration Strings', () {
    test('parses hours and minutes', () {
      final dur = SurrealDuration.parse('2h30m');
      expect(dur.toDuration().inMinutes, equals(150));
    });

    test('parses weeks, days, hours', () {
      final dur = SurrealDuration.parse('1w3d5h');
      // 1w = 7d, so 7+3 = 10d = 240h, + 5h = 245h
      expect(dur.toDuration().inHours, equals(245));
    });

    test('parses full complex duration', () {
      final dur = SurrealDuration.parse('1w2d3h4m5s');
      final dartDur = dur.toDuration();
      final expectedSeconds =
          7 * 24 * 60 * 60 + // 1w
              2 * 24 * 60 * 60 + // 2d
              3 * 60 * 60 + // 3h
              4 * 60 + // 4m
              5; // 5s
      expect(dartDur.inSeconds, equals(expectedSeconds));
    });

    test('parses duration with floating point values', () {
      final dur = SurrealDuration.parse('1.5h');
      expect(dur.toDuration().inMinutes, equals(90));
    });

    test('parses multiple same units (adds up)', () {
      final dur = SurrealDuration.parse('1h1h');
      expect(dur.toDuration().inHours, equals(2));
    });

    test('parses with sub-millisecond precision', () {
      final dur = SurrealDuration.parse('1s500ms250us');
      final dartDur = dur.toDuration();
      expect(dartDur.inMicroseconds, equals(1500250));
    });
  });

  group('Parsing Error Handling', () {
    test('throws FormatException for empty string', () {
      expect(() => SurrealDuration.parse(''), throwsFormatException);
    });

    test('throws FormatException for invalid format', () {
      expect(() => SurrealDuration.parse('abc'), throwsFormatException);
      expect(() => SurrealDuration.parse('5'), throwsFormatException);
      expect(() => SurrealDuration.parse('5x'), throwsFormatException);
      expect(() => SurrealDuration.parse('invalid'), throwsFormatException);
    });
  });

  group('Duration to String Conversion', () {
    test('converts zero duration', () {
      final dur = SurrealDuration(Duration.zero);
      expect(dur.toString(), equals('0s'));
    });

    test('converts hours and minutes', () {
      final dur = SurrealDuration(Duration(hours: 2, minutes: 30));
      expect(dur.toString(), equals('2h30m'));
    });

    test('converts weeks and days', () {
      final dur = SurrealDuration(Duration(days: 10));
      expect(dur.toString(), equals('1w3d'));
    });

    test('converts complex duration', () {
      final dur = SurrealDuration(
        Duration(
          days: 9, // 1w2d
          hours: 3,
          minutes: 4,
          seconds: 5,
        ),
      );
      expect(dur.toString(), equals('1w2d3h4m5s'));
    });

    test('includes milliseconds when present', () {
      final dur = SurrealDuration(Duration(seconds: 1, milliseconds: 500));
      expect(dur.toString(), equals('1s500ms'));
    });

    test('includes microseconds when present', () {
      final dur = SurrealDuration(Duration(milliseconds: 1, microseconds: 500));
      expect(dur.toString(), equals('1ms500us'));
    });

    test('converts only microseconds', () {
      final dur = SurrealDuration(Duration(microseconds: 250));
      expect(dur.toString(), equals('250us'));
    });

    test('converts only seconds', () {
      final dur = SurrealDuration(Duration(seconds: 45));
      expect(dur.toString(), equals('45s'));
    });
  });

  group('Round-trip Parsing', () {
    test('round-trip simple duration', () {
      final original = '2h30m';
      final dur = SurrealDuration.parse(original);
      expect(dur.toString(), equals(original));
    });

    test('round-trip complex duration', () {
      final original = '1w3d5h30m15s';
      final dur = SurrealDuration.parse(original);
      expect(dur.toString(), equals(original));
    });

    test('round-trip from Dart Duration', () {
      final dartDur = Duration(hours: 5, minutes: 45);
      final surreal = SurrealDuration(dartDur);
      final parsed = SurrealDuration.parse(surreal.toString());
      expect(parsed.toDuration(), equals(dartDur));
    });

    test('round-trip with milliseconds', () {
      final original = '1s500ms';
      final dur = SurrealDuration.parse(original);
      expect(dur.toString(), equals(original));
    });

    test('round-trip with microseconds', () {
      final original = '1ms500us';
      final dur = SurrealDuration.parse(original);
      expect(dur.toString(), equals(original));
    });
  });

  group('fromJson Factory', () {
    test('fromJson accepts valid duration string', () {
      final dur = SurrealDuration.fromJson('2h30m');
      expect(dur.toDuration().inMinutes, equals(150));
    });

    test('fromJson throws ArgumentError for non-string', () {
      expect(() => SurrealDuration.fromJson(123), throwsArgumentError);
      expect(() => SurrealDuration.fromJson(null), throwsArgumentError);
      expect(() => SurrealDuration.fromJson([]), throwsArgumentError);
      expect(() => SurrealDuration.fromJson({}), throwsArgumentError);
    });

    test('fromJson throws FormatException for invalid string', () {
      expect(() => SurrealDuration.fromJson('invalid'), throwsFormatException);
    });
  });

  group('toJson Method', () {
    test('toJson returns duration string', () {
      final dur = SurrealDuration(Duration(hours: 2));
      expect(dur.toJson(), equals('2h'));
    });

    test('toJson equals toString', () {
      final dur = SurrealDuration(Duration(hours: 5, minutes: 30));
      expect(dur.toJson(), equals(dur.toString()));
    });
  });

  group('Equality and HashCode', () {
    test('equal durations are equal', () {
      final dur1 = SurrealDuration(Duration(hours: 2, minutes: 30));
      final dur2 = SurrealDuration(Duration(hours: 2, minutes: 30));

      expect(dur1, equals(dur2));
      expect(dur1.hashCode, equals(dur2.hashCode));
    });

    test('different durations are not equal', () {
      final dur1 = SurrealDuration(Duration(hours: 2));
      final dur2 = SurrealDuration(Duration(hours: 3));

      expect(dur1, isNot(equals(dur2)));
    });

    test('same total from different units are equal', () {
      final dur1 = SurrealDuration.parse('2h');
      final dur2 = SurrealDuration.parse('120m');

      expect(dur1.toDuration(), equals(dur2.toDuration()));
      expect(dur1, equals(dur2));
    });
  });

  group('Edge Cases', () {
    test('handles very large durations', () {
      final dur = SurrealDuration(Duration(days: 365 * 10)); // 10 years
      final parsed = SurrealDuration.parse(dur.toString());
      expect(parsed.toDuration().inDays, equals(365 * 10));
    });

    test('handles single microsecond', () {
      final dur = SurrealDuration(Duration(microseconds: 1));
      expect(dur.toString(), equals('1us'));
      expect(dur.toDuration().inMicroseconds, equals(1));
    });

    test('floating point seconds', () {
      final dur = SurrealDuration.parse('1.5s');
      expect(dur.toDuration().inMilliseconds, equals(1500));
    });

    test('floating point minutes', () {
      final dur = SurrealDuration.parse('2.5m');
      expect(dur.toDuration().inSeconds, equals(150));
    });
  });
}
