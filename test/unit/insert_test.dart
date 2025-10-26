/// Unit tests for insert operations
///
/// These tests verify the insert functionality including:
/// - insertContent() for standard records
/// - insertRelation() for graph relationships
/// - Error handling for invalid inputs
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Insert Operations', () {
    late Database db;

    setUp(() async {
      // Connect to in-memory database for isolated tests
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Clean up database connection
      if (!db.isClosed) {
        await db.close();
      }
    });

    test('insertContent creates a standard record', () async {
      // Create a person record using insertContent
      final result = await db.insertContent('person', {
        'name': 'Alice',
        'age': 25,
        'email': 'alice@example.com',
      });

      // Verify the record was created with proper fields
      expect(result, isA<Map<String, dynamic>>());
      expect(result['id'], isNotNull);
      expect(result['id'], startsWith('person:'));
      expect(result['name'], equals('Alice'));
      expect(result['age'], equals(25));
      expect(result['email'], equals('alice@example.com'));

      // Verify we can query it back
      final persons = await db.selectQL('person');
      expect(persons.length, equals(1));
      expect(persons.first['name'], equals('Alice'));
    });

    test('insertContent with specified record ID', () async {
      // Create a record with a specific ID
      final result = await db.insertContent('person:alice', {
        'name': 'Alice',
        'age': 25,
      });

      // Verify the record has the specified ID
      expect(result['id'], equals('person:alice'));
      expect(result['name'], equals('Alice'));
      expect(result['age'], equals(25));
    });

    test('insertRelation creates graph relationship', () async {
      // First create two person records
      final alice = await db.createQL('person', {'name': 'Alice'});
      final bob = await db.createQL('person', {'name': 'Bob'});

      final aliceId = RecordId.parse(alice['id'] as String);
      final bobId = RecordId.parse(bob['id'] as String);

      // Create a relationship between them
      final relation = await db.insertRelation('knows', {
        'in': aliceId,
        'out': bobId,
        'since': 2020,
      });

      // Verify the relationship was created
      expect(relation, isA<Map<String, dynamic>>());
      expect(relation['id'], isNotNull);
      expect(relation['id'], startsWith('knows:'));
      expect(relation['in'], equals(aliceId.toString()));
      expect(relation['out'], equals(bobId.toString()));
      expect(relation['since'], equals(2020));
    });

    test('insertContent throws on null data', () async {
      // Attempting to insert null data should throw
      expect(
        () => db.insertContent('person', null as dynamic),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('insertContent throws on empty table name', () async {
      // Attempting to insert with empty table should throw
      expect(
        () => db.insertContent('', {'name': 'Test'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('insertRelation throws on missing in field', () async {
      final bob = await db.createQL('person', {'name': 'Bob'});
      final bobId = RecordId.parse(bob['id'] as String);

      // Missing 'in' field should throw
      expect(
        () => db.insertRelation('knows', {
          'out': bobId,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('insertRelation throws on missing out field', () async {
      final alice = await db.createQL('person', {'name': 'Alice'});
      final aliceId = RecordId.parse(alice['id'] as String);

      // Missing 'out' field should throw
      expect(
        () => db.insertRelation('knows', {
          'in': aliceId,
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('multiple insertContent operations in sequence', () async {
      // Create multiple records
      final person1 = await db.insertContent('person', {
        'name': 'Alice',
        'age': 25,
      });
      final person2 = await db.insertContent('person', {
        'name': 'Bob',
        'age': 30,
      });
      final person3 = await db.insertContent('person', {
        'name': 'Charlie',
        'age': 35,
      });

      // Verify all records were created
      expect(person1['name'], equals('Alice'));
      expect(person2['name'], equals('Bob'));
      expect(person3['name'], equals('Charlie'));

      // Verify they're all in the database
      final allPersons = await db.selectQL('person');
      expect(allPersons.length, equals(3));
    });
  });
}
