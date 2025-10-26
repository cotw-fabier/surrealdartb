/// Basic integration test to verify direct FFI implementation works correctly.
///
/// This test creates a database connection, performs basic CRUD operations,
/// and verifies the results.
///
/// NOTE: This test uses the new direct FFI architecture (no isolates).
/// Database operations call FFI directly with Future wrappers for async behavior.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Direct FFI Integration Test', () {
    late Database db;

    setUp(() async {
      // Connect to in-memory database
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Always close the database
      if (!db.isClosed) {
        await db.close();
      }
    });

    test('Basic CRUD workflow with direct FFI', () async {
      // Create a record
      final person = await db.createQL('person', {
        'name': 'Test User',
        'age': 30,
        'email': 'test@example.com',
      });

      // Verify the record has an ID
      expect(person['id'], isNotNull);
      expect(person['name'], equals('Test User'));
      expect(person['age'], equals(30));
      expect(person['email'], equals('test@example.com'));

      final personId = person['id'] as String;
      expect(personId, startsWith('person:'));

      // Select all records
      final persons = await db.selectQL('person');
      expect(persons.length, equals(1));
      expect(persons.first['name'], equals('Test User'));

      // Update the record
      final updated = await db.updateQL(personId, {
        'age': 31,
        'email': 'updated@example.com',
      });
      expect(updated['age'], equals(31));
      expect(updated['email'], equals('updated@example.com'));
      expect(updated['name'], equals('Test User')); // Should still be there

      // Query using SurrealQL
      final response = await db.queryQL('SELECT * FROM person WHERE age > 25');
      final results = response.getResults();
      expect(results.length, equals(1));

      final queryResult = results.first as List;
      expect(queryResult.length, equals(1));
      final record = queryResult.first as Map<String, dynamic>;
      expect(record['age'], equals(31));

      // Delete the record
      await db.deleteQL(personId);

      // Verify deletion
      final afterDelete = await db.selectQL('person');
      expect(afterDelete, isEmpty);
    });

    test('Multiple operations in sequence', () async {
      // Create multiple records
      final person1 = await db.createQL('person', {
        'name': 'Alice',
        'age': 25,
      });
      final person2 = await db.createQL('person', {
        'name': 'Bob',
        'age': 30,
      });
      final person3 = await db.createQL('person', {
        'name': 'Charlie',
        'age': 35,
      });

      // Verify all were created
      var allPersons = await db.selectQL('person');
      expect(allPersons.length, equals(3));

      // Update one
      await db.updateQL(person2['id'] as String, {'age': 32});

      // Delete one
      await db.deleteQL(person1['id'] as String);

      // Verify final state
      allPersons = await db.selectQL('person');
      expect(allPersons.length, equals(2));

      final names = allPersons.map((p) => (p as Map<String, dynamic>)['name']).toList();
      expect(names, containsAll(['Bob', 'Charlie']));
      expect(names, isNot(contains('Alice')));

      // Verify update took effect
      final bob = allPersons.firstWhere(
        (p) => (p as Map<String, dynamic>)['name'] == 'Bob',
      ) as Map<String, dynamic>;
      expect(bob['age'], equals(32));
    });

    test('Complex query with direct FFI', () async {
      // Create test data
      await db.queryQL('''
        CREATE company:acme SET name = "Acme Corp", employees = 100;
        CREATE company:tech SET name = "Tech Inc", employees = 50;
        CREATE employee:e1 SET name = "Alice", company = company:acme;
        CREATE employee:e2 SET name = "Bob", company = company:tech;
        CREATE employee:e3 SET name = "Charlie", company = company:acme;
      ''');

      // Query with relationships
      final response = await db.queryQL('''
        SELECT
          *,
          company.name AS company_name
        FROM employee
        ORDER BY name
      ''');

      final results = response.getResults();
      expect(results, isNotEmpty);

      final employees = results.first as List;
      expect(employees.length, equals(3));

      // Verify ordered by name
      expect((employees[0] as Map<String, dynamic>)['name'], equals('Alice'));
      expect((employees[1] as Map<String, dynamic>)['name'], equals('Bob'));
      expect((employees[2] as Map<String, dynamic>)['name'], equals('Charlie'));
    });
  });
}
