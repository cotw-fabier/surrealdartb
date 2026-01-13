/// Integration tests for datetime query conditions.
///
/// Tests DateTimeFieldCondition operators (before, after, between, equals)
/// against actual database queries and verifies SQL generation.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:surrealdartb/src/orm/where_builder.dart';

void main() {
  group('DateTimeFieldCondition.before()', () {
    test('filters records before specified date with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Seed test data
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events WHERE date < d"2023-07-01T00:00:00Z"',
        );

        final results = response.getResults();
        expect(results.length, equals(2)); // Jan and Jun 2023 events
      } finally {
        await db.close();
      }
    });

    test('before() condition toSurrealQL generates correct format', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final date = DateTime.utc(2024, 1, 1);
        final field = DateTimeFieldCondition('createdAt');
        final condition = field.before(date);

        final sql = condition.toSurrealQL(db);

        expect(sql, contains('createdAt'));
        expect(sql, contains('<'));
        expect(sql, contains('d"')); // SurrealQL datetime literal format
      } finally {
        await db.close();
      }
    });
  });

  group('DateTimeFieldCondition.after()', () {
    test('filters records after specified date with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events WHERE date > d"2023-07-01T00:00:00Z"',
        );

        final results = response.getResults();
        expect(results.length, equals(2)); // Dec 2023 and Mar 2024 events
      } finally {
        await db.close();
      }
    });

    test('after() condition toSurrealQL generates correct format', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final date = DateTime.utc(2024, 1, 1);
        final field = DateTimeFieldCondition('updatedAt');
        final condition = field.after(date);

        final sql = condition.toSurrealQL(db);

        expect(sql, contains('updatedAt'));
        expect(sql, contains('>'));
        expect(sql, contains('d"'));
      } finally {
        await db.close();
      }
    });
  });

  group('DateTimeFieldCondition.between()', () {
    test('filters records between two dates with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT * FROM events
          WHERE date >= d"2023-06-01T00:00:00Z"
          AND date <= d"2023-12-31T23:59:59Z"
        ''');

        final results = response.getResults();
        expect(results.length, equals(2)); // Jun and Dec 2023 events
      } finally {
        await db.close();
      }
    });

    test('between() condition toSurrealQL generates correct format', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final start = DateTime.utc(2023, 1, 1);
        final end = DateTime.utc(2023, 12, 31);
        final field = DateTimeFieldCondition('date');
        final condition = field.between(start, end);

        final sql = condition.toSurrealQL(db);

        expect(sql, contains('date'));
        expect(sql, contains('>='));
        expect(sql, contains('AND'));
        expect(sql, contains('<='));
        expect(sql, contains('d"'));
      } finally {
        await db.close();
      }
    });
  });

  group('DateTimeFieldCondition.equals()', () {
    test('matches exact datetime with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events WHERE date = d"2023-06-15T00:00:00Z"',
        );

        final results = response.getResults();
        expect(results.length, equals(1));
        expect(results.first['name'], equals('Event 1'));
      } finally {
        await db.close();
      }
    });

    test('equals() condition toSurrealQL generates correct format', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final date = DateTime.utc(2024, 1, 1, 12, 30, 0);
        final field = DateTimeFieldCondition('timestamp');
        final condition = field.equals(date);

        final sql = condition.toSurrealQL(db);

        expect(sql, contains('timestamp'));
        expect(sql, contains('='));
        expect(sql, contains('d"'));
      } finally {
        await db.close();
      }
    });
  });

  group('Combined DateTime Conditions', () {
    test('AND combination of datetime conditions with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT * FROM events
          WHERE date >= d"2023-07-01T00:00:00Z"
          AND date < d"2024-01-01T00:00:00Z"
        ''');

        final results = response.getResults();
        expect(results.length, equals(1)); // Only Dec 2023
      } finally {
        await db.close();
      }
    });

    test('OR combination of datetime conditions with raw query', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT * FROM events
          WHERE (date >= d"2023-01-01T00:00:00Z" AND date < d"2023-02-01T00:00:00Z")
          OR (date >= d"2024-03-01T00:00:00Z" AND date < d"2024-04-01T00:00:00Z")
        ''');

        final results = response.getResults();
        expect(results.length, equals(2)); // Jan 2023 and Mar 2024
      } finally {
        await db.close();
      }
    });
  });

  group('SurrealDB Native Datetime Functions', () {
    test('time::now() returns current time', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final response = await db.queryQL('RETURN time::now()');
        final results = response.getResults();

        expect(results, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    test('datetime comparison with time::now()', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events WHERE date < time::now()',
        );

        final results = response.getResults();
        expect(results.length, equals(4)); // All test events are in the past
      } finally {
        await db.close();
      }
    });

    test('datetime formatting functions', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT *,
            time::year(date) AS year,
            time::month(date) AS month,
            time::day(date) AS day
          FROM events
          WHERE time::year(date) = 2023
        ''');

        final results = response.getResults();
        expect(results.length, equals(3)); // 3 events in 2023

        for (final result in results) {
          expect(result['year'], equals(2023));
        }
      } finally {
        await db.close();
      }
    });
  });

  group('Duration in Query Conditions', () {
    test('datetime + duration arithmetic', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT * FROM events
          WHERE date + 6mo >= d"2024-01-01T00:00:00Z"
        ''');

        final results = response.getResults();
        expect(results.length, greaterThanOrEqualTo(2));
      } finally {
        await db.close();
      }
    });

    test('datetime - duration arithmetic', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL('''
          SELECT * FROM events
          WHERE date - 1y < d"2023-01-01T00:00:00Z"
        ''');

        final results = response.getResults();
        expect(results.length, greaterThanOrEqualTo(1));
      } finally {
        await db.close();
      }
    });
  });

  group('Datetime Ordering', () {
    test('ORDER BY date ASC', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events ORDER BY date ASC',
        );

        final results = response.getResults();
        expect(results.length, equals(4));

        expect(results.first['name'], equals('Event 0'));
        expect(results.last['name'], equals('Event 3'));
      } finally {
        await db.close();
      }
    });

    test('ORDER BY date DESC', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final dates = [
          DateTime.utc(2023, 1, 15),
          DateTime.utc(2023, 6, 15),
          DateTime.utc(2023, 12, 15),
          DateTime.utc(2024, 3, 15),
        ];

        for (var i = 0; i < dates.length; i++) {
          await db.createQL('events', {
            'name': 'Event $i',
            'date': Datetime(dates[i]).toJson(),
          });
        }

        final response = await db.queryQL(
          'SELECT * FROM events ORDER BY date DESC',
        );

        final results = response.getResults();
        expect(results.length, equals(4));

        expect(results.first['name'], equals('Event 3'));
        expect(results.last['name'], equals('Event 0'));
      } finally {
        await db.close();
      }
    });
  });

  group('Null Datetime in Conditions', () {
    test('filters for NULL datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        await db.createQL('nullable_events', {
          'name': 'No Date',
          'date': null,
        });

        await db.createQL('nullable_events', {
          'name': 'Has Date',
          'date': Datetime(DateTime.utc(2023, 1, 1)).toJson(),
        });

        final response = await db.queryQL(
          'SELECT * FROM nullable_events WHERE date IS NULL',
        );

        final results = response.getResults();
        expect(results.length, equals(1));
        expect(results.first['name'], equals('No Date'));
      } finally {
        await db.close();
      }
    });

    test('filters for NOT NULL datetime', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        await db.createQL('check_events', {
          'name': 'No Date',
          'date': null,
        });

        await db.createQL('check_events', {
          'name': 'Has Date',
          'date': Datetime(DateTime.utc(2023, 1, 1)).toJson(),
        });

        final response = await db.queryQL(
          'SELECT * FROM check_events WHERE date IS NOT NULL',
        );

        final results = response.getResults();
        expect(results.length, equals(1));
        expect(results.first['name'], equals('Has Date'));
      } finally {
        await db.close();
      }
    });
  });
}
