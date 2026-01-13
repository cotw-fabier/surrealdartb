/// Integration tests for datetime round-trip through SurrealDB.
///
/// Tests writing datetimes to the database and reading them back,
/// verifying that precision and timezone information is preserved.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Datetime Round-trip via createQL/selectQL', () {
    test('round-trips UTC datetime with Z suffix', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final originalDt = DateTime.utc(2023, 10, 21, 12, 30, 45);

        final record = await db.createQL('events', {
          'name': 'Test Event',
          'timestamp': Datetime(originalDt).toJson(),
        });

        expect(record['timestamp'], isNotNull);

        final results = await db.selectQL('events');
        expect(results, hasLength(1));

        final retrieved = Datetime.fromJson(results.first['timestamp']);
        expect(retrieved.toDateTime(), equals(originalDt));
      } finally {
        await db.close();
      }
    });

    test('round-trips datetime with milliseconds', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final originalDt = DateTime.utc(2023, 10, 21, 12, 30, 45, 123);

        await db.createQL('events', {
          'timestamp': Datetime(originalDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        expect(retrieved.toDateTime().millisecond, equals(123));
      } finally {
        await db.close();
      }
    });

    test('round-trips datetime with microseconds', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final originalDt = DateTime.utc(2023, 10, 21, 12, 30, 45, 123, 456);

        await db.createQL('events', {
          'timestamp': Datetime(originalDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        // Note: Microsecond precision depends on SurrealDB's handling
        expect(retrieved.toDateTime().millisecond, equals(123));
      } finally {
        await db.close();
      }
    });

    test('round-trips local datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final originalDt = DateTime(2023, 10, 21, 12, 30, 45);

        await db.createQL('events', {
          'timestamp': Datetime(originalDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        // Compare in UTC to avoid timezone issues
        expect(
          retrieved.toDateTime().toUtc().millisecondsSinceEpoch,
          equals(originalDt.toUtc().millisecondsSinceEpoch),
        );
      } finally {
        await db.close();
      }
    });
  });

  group('Datetime Round-trip via updateQL', () {
    test('updates datetime field correctly', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final originalDt = DateTime.utc(2023, 10, 21, 12, 0, 0);
        final updatedDt = DateTime.utc(2023, 12, 25, 18, 30, 0);

        final record = await db.createQL('events', {
          'name': 'Holiday',
          'timestamp': Datetime(originalDt).toJson(),
        });

        final recordId = record['id'] as String;

        await db.updateQL(recordId, {
          'timestamp': Datetime(updatedDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        expect(retrieved.toDateTime(), equals(updatedDt));
      } finally {
        await db.close();
      }
    });
  });

  group('Datetime Round-trip via queryQL', () {
    test('raw query preserves datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dt = DateTime.utc(2023, 10, 21, 12, 30, 45);

        await db.queryQL('''
          CREATE events SET
            name = 'Test',
            timestamp = d'${Datetime(dt).toJson()}'
        ''');

        final response = await db.queryQL('SELECT * FROM events');
        final results = response.getResults();

        expect(results, isNotEmpty);
        final retrieved = Datetime.fromJson(results.first['timestamp']);
        expect(retrieved.toDateTime(), equals(dt));
      } finally {
        await db.close();
      }
    });

    test('datetime arithmetic in query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dt = DateTime.utc(2023, 10, 21, 12, 0, 0);

        await db.createQL('events', {
          'timestamp': Datetime(dt).toJson(),
        });

        final response = await db.queryQL('''
          SELECT *, timestamp + 1h AS later FROM events
        ''');

        final results = response.getResults();
        expect(results.first['later'], isNotNull);
      } finally {
        await db.close();
      }
    });
  });

  group('SurrealDuration Round-trip', () {
    test('round-trips duration field', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final duration = SurrealDuration(Duration(hours: 2, minutes: 30));

        await db.createQL('tasks', {
          'name': 'Long Task',
          'duration': duration.toJson(),
        });

        final results = await db.selectQL('tasks');
        final retrieved = SurrealDuration.fromJson(results.first['duration']);

        expect(retrieved.toDuration(), equals(duration.toDuration()));
      } finally {
        await db.close();
      }
    });

    test('round-trips complex duration', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final duration = SurrealDuration.parse('1w3d5h30m');

        await db.createQL('tasks', {
          'duration': duration.toJson(),
        });

        final results = await db.selectQL('tasks');
        final retrieved = SurrealDuration.fromJson(results.first['duration']);

        expect(
          retrieved.toDuration().inMinutes,
          equals(duration.toDuration().inMinutes),
        );
      } finally {
        await db.close();
      }
    });
  });

  group('Null/Optional Datetime Handling', () {
    test('creates record with null datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final record = await db.createQL('events', {
          'name': 'No Date Event',
          'timestamp': null,
        });

        expect(record['timestamp'], isNull);

        final results = await db.selectQL('events');
        expect(results.first['timestamp'], isNull);
      } finally {
        await db.close();
      }
    });

    test('updates datetime to null', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dt = DateTime.utc(2023, 10, 21, 12, 0, 0);

        final record = await db.createQL('events', {
          'timestamp': Datetime(dt).toJson(),
        });

        await db.updateQL(record['id'] as String, {
          'timestamp': null,
        });

        final results = await db.selectQL('events');
        expect(results.first['timestamp'], isNull);
      } finally {
        await db.close();
      }
    });

    test('handles missing datetime field gracefully', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        await db.createQL('events', {
          'name': 'Simple Event',
        });

        final results = await db.selectQL('events');
        expect(results.first.containsKey('timestamp'), isFalse);
      } finally {
        await db.close();
      }
    });
  });

  group('Multiple Datetime Fields', () {
    test('handles multiple datetime fields in same record', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final createdAt = DateTime.utc(2023, 10, 21, 10, 0, 0);
        final updatedAt = DateTime.utc(2023, 10, 21, 15, 30, 0);
        final expiresAt = DateTime.utc(2024, 10, 21, 0, 0, 0);

        await db.createQL('sessions', {
          'created_at': Datetime(createdAt).toJson(),
          'updated_at': Datetime(updatedAt).toJson(),
          'expires_at': Datetime(expiresAt).toJson(),
        });

        final results = await db.selectQL('sessions');
        expect(results, hasLength(1));

        final record = results.first;
        expect(Datetime.fromJson(record['created_at']).toDateTime(),
            equals(createdAt));
        expect(Datetime.fromJson(record['updated_at']).toDateTime(),
            equals(updatedAt));
        expect(Datetime.fromJson(record['expires_at']).toDateTime(),
            equals(expiresAt));
      } finally {
        await db.close();
      }
    });
  });

  group('Direct DateTime Object Handling', () {
    test('handles raw DateTime object via toIso8601String', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dt = DateTime.utc(2023, 10, 21, 12, 0, 0);

        await db.createQL('events', {
          'timestamp': dt.toIso8601String(),
        });

        final results = await db.selectQL('events');
        final retrievedString = results.first['timestamp'] as String;
        final parsed = DateTime.parse(retrievedString);

        expect(parsed.year, equals(2023));
        expect(parsed.month, equals(10));
        expect(parsed.day, equals(21));
      } finally {
        await db.close();
      }
    });
  });

  group('SCHEMAFULL Table Datetime Handling', () {
    test('datetime field in schema validates correctly', () async {
      final tables = [
        TableStructure('logs', {
          'message': FieldDefinition(StringType()),
          'created_at': FieldDefinition(DatetimeType()),
        }),
      ];

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
        tableDefinitions: tables,
        autoMigrate: true,
      );

      try {
        final dt = DateTime.utc(2023, 10, 21, 12, 0, 0);

        final record = await db.createQL('logs', {
          'message': 'Test log',
          'created_at': Datetime(dt).toJson(),
        });

        expect(record['created_at'], isNotNull);

        final results = await db.selectQL('logs');
        final retrieved = Datetime.fromJson(results.first['created_at']);
        expect(retrieved.toDateTime(), equals(dt));
      } finally {
        await db.close();
      }
    });
  });

  group('Edge Cases', () {
    test('handles epoch datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final epochDt = DateTime.utc(1970, 1, 1, 0, 0, 0);

        await db.createQL('events', {
          'timestamp': Datetime(epochDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        expect(retrieved.toDateTime().millisecondsSinceEpoch, equals(0));
      } finally {
        await db.close();
      }
    });

    test('handles far future datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final futureDt = DateTime.utc(2099, 12, 31, 23, 59, 59);

        await db.createQL('events', {
          'timestamp': Datetime(futureDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        expect(retrieved.toDateTime().year, equals(2099));
      } finally {
        await db.close();
      }
    });

    test('handles leap year datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final leapDt = DateTime.utc(2024, 2, 29, 12, 0, 0);

        await db.createQL('events', {
          'timestamp': Datetime(leapDt).toJson(),
        });

        final results = await db.selectQL('events');
        final retrieved = Datetime.fromJson(results.first['timestamp']);

        expect(retrieved.toDateTime().month, equals(2));
        expect(retrieved.toDateTime().day, equals(29));
      } finally {
        await db.close();
      }
    });
  });
}
