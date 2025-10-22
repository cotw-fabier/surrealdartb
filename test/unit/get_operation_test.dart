/// Tests for get operation (Task Group 2.3).
///
/// This test file covers the get operation:
/// - Get existing record returns typed result
/// - Get non-existent record returns null
/// - Generic type deserialization works
///
/// These tests focus on critical get operation paths only.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  late Database db;

  setUp(() async {
    // Create fresh in-memory database for each test
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Database.get()', () {
    test('returns record for existing resource', () async {
      // Create a record first
      final created = await db.create('person', {
        'name': 'Alice',
        'age': 25,
        'email': 'alice@example.com',
      });

      final id = created['id'] as String;

      // Get the record
      final result = await db.get<Map<String, dynamic>>(id);

      expect(result, isNotNull);
      expect(result!['name'], equals('Alice'));
      expect(result['age'], equals(25));
      expect(result['email'], equals('alice@example.com'));
      expect(result['id'], equals(id));
    });

    test('returns null for non-existent record', () async {
      final result = await db.get<Map<String, dynamic>>('person:nonexistent');
      expect(result, isNull);
    });

    test('returns null for non-existent table', () async {
      final result = await db.get<Map<String, dynamic>>('unknown_table:some_id');
      expect(result, isNull);
    });

    test('deserializes to generic type correctly', () async {
      // Create a record
      final created = await db.create('user', {
        'username': 'john_doe',
        'active': true,
        'score': 100,
      });

      final id = created['id'] as String;

      // Get and verify type-safe deserialization
      final result = await db.get<Map<String, dynamic>>(id);

      expect(result, isNotNull);
      expect(result!['username'], isA<String>());
      expect(result['active'], isA<bool>());
      expect(result['score'], isA<int>());
    });

    test('throws exception on invalid resource format', () async {
      expect(
        () => db.get<Map<String, dynamic>>(''),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('handles records with complex nested data', () async {
      final created = await db.create('document', {
        'title': 'Test Doc',
        'metadata': {
          'author': 'Alice',
          'tags': ['test', 'example'],
        },
      });

      final id = created['id'] as String;
      final result = await db.get<Map<String, dynamic>>(id);

      expect(result, isNotNull);
      expect(result!['title'], equals('Test Doc'));
      expect(result['metadata'], isA<Map>());
      expect(result['metadata']['author'], equals('Alice'));
      expect(result['metadata']['tags'], isA<List>());
      expect(result['metadata']['tags'].length, equals(2));
    });
  });
}
