/// Tests for core SurrealDB type definitions.
///
/// This test file covers the core type definitions for Task Group 1.1:
/// - RecordId parsing and serialization
/// - Datetime conversion to/from Dart DateTime
/// - Duration parsing
/// - PatchOp JSON serialization
///
/// These tests focus on critical conversion paths only.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('RecordId', () {
    test('parses table:id format correctly', () {
      final rid = RecordId.parse('person:alice');
      expect(rid.table, equals('person'));
      expect(rid.id, equals('alice'));
      expect(rid.toString(), equals('person:alice'));
    });

    test('parses numeric IDs correctly', () {
      final rid = RecordId.parse('user:123');
      expect(rid.table, equals('user'));
      expect(rid.id, equals(123));
      expect(rid.toString(), equals('user:123'));
    });

    test('serializes to JSON correctly', () {
      final rid = RecordId('person', 'alice');
      expect(rid.toJson(), equals('person:alice'));
    });

    test('validates table name format', () {
      expect(
        () => RecordId('', 'id'),
        throwsArgumentError,
      );
      expect(
        () => RecordId('invalid-table', 'id'),
        throwsArgumentError,
      );
    });
  });

  group('Datetime', () {
    test('converts to/from Dart DateTime', () {
      final dartDt = DateTime(2023, 10, 21, 12, 0, 0);
      final surrealDt = Datetime(dartDt);
      final converted = surrealDt.toDateTime();

      expect(converted, equals(dartDt));
    });

    test('parses ISO 8601 strings', () {
      final dt = Datetime.parse('2023-10-21T12:00:00Z');
      final dartDt = dt.toDateTime();

      expect(dartDt.year, equals(2023));
      expect(dartDt.month, equals(10));
      expect(dartDt.day, equals(21));
    });

    test('serializes to ISO 8601 JSON', () {
      final dt = Datetime(DateTime.utc(2023, 10, 21, 12, 0, 0));
      final json = dt.toJson();

      expect(json, contains('2023-10-21'));
      expect(json, contains('12:00:00'));
    });
  });

  group('SurrealDuration', () {
    test('parses simple duration strings', () {
      final dur = SurrealDuration.parse('2h30m');
      final dartDur = dur.toDuration();

      expect(dartDur.inHours, equals(2));
      expect(dartDur.inMinutes, equals(150));
    });

    test('parses complex duration strings', () {
      final dur = SurrealDuration.parse('1w3d5h');
      final dartDur = dur.toDuration();

      // 1 week = 7 days, so 1w3d = 10 days = 240 hours
      // Plus 5 hours = 245 hours
      expect(dartDur.inHours, equals(245));
    });

    test('converts from Dart Duration', () {
      final dartDur = Duration(hours: 2, minutes: 30);
      final surrealDur = SurrealDuration(dartDur);

      expect(surrealDur.toString(), equals('2h30m'));
    });

    test('serializes to JSON correctly', () {
      final dur = SurrealDuration(Duration(hours: 5));
      expect(dur.toJson(), equals('5h'));
    });
  });

  group('PatchOp', () {
    test('creates add operation with correct JSON', () {
      final op = PatchOp.add('/email', 'user@example.com');
      final json = op.toJson();

      expect(json['op'], equals('add'));
      expect(json['path'], equals('/email'));
      expect(json['value'], equals('user@example.com'));
    });

    test('creates remove operation without value', () {
      final op = PatchOp.remove('/temp_field');
      final json = op.toJson();

      expect(json['op'], equals('remove'));
      expect(json['path'], equals('/temp_field'));
      expect(json.containsKey('value'), isFalse);
    });

    test('creates replace operation correctly', () {
      final op = PatchOp.replace('/age', 26);
      final json = op.toJson();

      expect(json['op'], equals('replace'));
      expect(json['path'], equals('/age'));
      expect(json['value'], equals(26));
    });

    test('validates path format', () {
      expect(
        () => PatchOp.add('invalid', 'value'),
        throwsArgumentError,
      );
      expect(
        () => PatchOp.add('', 'value'),
        throwsArgumentError,
      );
    });
  });
}
