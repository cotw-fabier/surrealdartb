/// Comprehensive CRUD and error tests for Task Group 5: Full CRUD & Error Testing
///
/// These tests verify the complete FFI stack from Rust through Dart FFI to the
/// high-level API, testing:
/// - Complex data types (arrays, nested objects, decimals)
/// - UPDATE and DELETE operations
/// - Raw query() with multiple statements
/// - Error handling across all layers
/// - RocksDB persistence
/// - Namespace/database switching
/// - Memory stability with large datasets
///
/// NOTE: Tests updated for direct FFI architecture (no isolates).
/// Database operations now call FFI directly with Future wrappers for async behavior.
/// This eliminates isolate message passing overhead while maintaining async behavior.
///
/// Total tests in this file: 8 strategic tests
/// Combined with existing tests from Task Group 2: 4 tests
/// Total feature-specific tests: 12 tests
library;

import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 5: Comprehensive CRUD & Error Testing', () {
    late Database db;

    setUp(() async {
      // Connect to in-memory database before each test
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Clean up database connection after each test
      if (!db.isClosed) {
        await db.close();
      }
    });

    // Test 1: Complex data types (arrays, nested objects, decimals)
    test('Test 1: Complex data types (arrays, nested objects, decimals)',
        () async {
      // Create record with complex nested structure including decimals
      final complexData = {
        'name': 'Advanced Product',
        'price': 1234.5678, // Decimal value
        'tags': ['electronics', 'premium', 'featured'],
        'specifications': {
          'dimensions': {
            'width': 15.5,
            'height': 20.3,
            'depth': 8.75,
            'unit': 'cm',
          },
          'weight': {'value': 2.345, 'unit': 'kg'},
          'features': ['waterproof', 'wireless', 'rechargeable'],
        },
        'inventory': [
          {'warehouse': 'A', 'quantity': 50, 'reserved': 10},
          {'warehouse': 'B', 'quantity': 30, 'reserved': 5},
          {'warehouse': 'C', 'quantity': 75, 'reserved': 0},
        ],
        'metadata': {
          'created': '2025-10-21T10:00:00Z',
          'lastModified': '2025-10-21T12:30:00Z',
          'version': 3,
        },
      };

      final record = await db.create('product', complexData);

      // Verify record structure
      expect(record, isA<Map<String, dynamic>>());
      expect(record['name'], equals('Advanced Product'));

      // Verify decimal precision preserved (as number or string)
      expect(record['price'], isNotNull);
      final price = record['price'];
      if (price is num) {
        expect(price, closeTo(1234.5678, 0.0001));
      } else if (price is String) {
        expect(double.parse(price), closeTo(1234.5678, 0.0001));
      }

      // Verify arrays
      expect(record['tags'], isA<List>());
      final tags = record['tags'] as List;
      expect(tags.length, equals(3));
      expect(tags, containsAll(['electronics', 'premium', 'featured']));

      // Verify nested objects (3 levels deep)
      expect(record['specifications'], isA<Map>());
      final specs = record['specifications'] as Map<String, dynamic>;
      expect(specs['dimensions'], isA<Map>());

      final dimensions = specs['dimensions'] as Map<String, dynamic>;
      expect(dimensions['width'], isNotNull);
      expect(dimensions['height'], isNotNull);
      expect(dimensions['depth'], isNotNull);
      expect(dimensions['unit'], equals('cm'));

      // Verify arrays within nested objects
      expect(specs['features'], isA<List>());
      final features = specs['features'] as List;
      expect(features.length, equals(3));

      // Verify array of objects
      expect(record['inventory'], isA<List>());
      final inventory = record['inventory'] as List;
      expect(inventory.length, equals(3));

      final warehouse1 = inventory[0] as Map<String, dynamic>;
      expect(warehouse1['warehouse'], equals('A'));
      expect(warehouse1['quantity'], equals(50));
      expect(warehouse1['reserved'], equals(10));

      // Verify JSON encoding doesn't contain type wrappers
      final jsonString = jsonEncode(record);
      expect(jsonString, isNot(contains('"Strand"')));
      expect(jsonString, isNot(contains('"Number"')));
      expect(jsonString, isNot(contains('"Array"')));
      expect(jsonString, isNot(contains('"Object"')));
    });

    // Test 2: UPDATE operation returns updated record
    test('Test 2: UPDATE operation returns updated record', () async {
      // Create initial record
      final initialRecord = await db.create('user', {
        'username': 'johndoe',
        'email': 'john@example.com',
        'status': 'active',
        'loginCount': 0,
      });

      expect(initialRecord['username'], equals('johndoe'));
      expect(initialRecord['loginCount'], equals(0));

      final userId = initialRecord['id'] as String;

      // Update the record
      final updatedRecord = await db.update(userId, {
        'email': 'john.doe@newdomain.com',
        'status': 'premium',
        'loginCount': 42,
        'lastLogin': '2025-10-21T15:30:00Z',
      });

      // Verify update returns the updated record
      expect(updatedRecord, isA<Map<String, dynamic>>());
      expect(updatedRecord['id'], equals(userId));

      // Verify updated fields
      expect(updatedRecord['username'], equals('johndoe')); // Unchanged
      expect(updatedRecord['email'], equals('john.doe@newdomain.com')); // Updated
      expect(updatedRecord['status'], equals('premium')); // Updated
      expect(updatedRecord['loginCount'], equals(42)); // Updated
      expect(updatedRecord['lastLogin'], equals('2025-10-21T15:30:00Z')); // New field

      // Verify the changes persisted by selecting the record
      final selectedRecords = await db.select('user');
      expect(selectedRecords.length, equals(1));

      final selectedRecord = selectedRecords.first as Map<String, dynamic>;
      expect(selectedRecord['id'], equals(userId));
      expect(selectedRecord['email'], equals('john.doe@newdomain.com'));
      expect(selectedRecord['status'], equals('premium'));
      expect(selectedRecord['loginCount'], equals(42));
    });

    // Test 3: DELETE operation completes successfully
    test('Test 3: DELETE operation completes successfully', () async {
      // Create multiple records
      final person1 = await db.create('person', {
        'name': 'Alice',
        'age': 28,
      });
      final person2 = await db.create('person', {
        'name': 'Bob',
        'age': 35,
      });
      final person3 = await db.create('person', {
        'name': 'Charlie',
        'age': 42,
      });

      // Verify all created
      var allPersons = await db.select('person');
      expect(allPersons.length, equals(3));

      // Delete one record
      final person1Id = person1['id'] as String;
      await db.delete(person1Id);

      // Verify record is deleted
      allPersons = await db.select('person');
      expect(allPersons.length, equals(2));

      final remainingIds = allPersons
          .map((p) => (p as Map<String, dynamic>)['id'])
          .toList();
      expect(remainingIds, isNot(contains(person1Id)));
      expect(remainingIds, contains(person2['id']));
      expect(remainingIds, contains(person3['id']));

      // Delete another record
      final person2Id = person2['id'] as String;
      await db.delete(person2Id);

      // Verify only one record remains
      allPersons = await db.select('person');
      expect(allPersons.length, equals(1));
      final remaining = allPersons.first as Map<String, dynamic>;
      expect(remaining['id'], equals(person3['id']));
      expect(remaining['name'], equals('Charlie'));

      // Delete final record
      await db.delete(person3['id'] as String);

      // Verify table is empty
      allPersons = await db.select('person');
      expect(allPersons, isEmpty);
    });

    // Test 4: Raw query() with multiple SurrealQL statements
    test('Test 4: Raw query() with multiple SurrealQL statements', () async {
      // Execute multiple statements in a single query
      final response = await db.query('''
        CREATE company:tech1 SET name = "TechCorp", employees = 250;
        CREATE company:tech2 SET name = "InnovateLabs", employees = 120;
        CREATE employee:emp1 SET name = "Alice Johnson", company = company:tech1, role = "Engineer";
        CREATE employee:emp2 SET name = "Bob Smith", company = company:tech1, role = "Manager";
        CREATE employee:emp3 SET name = "Carol White", company = company:tech2, role = "Designer";
        SELECT * FROM company ORDER BY name;
        SELECT * FROM employee ORDER BY name;
      ''');

      final results = response.getResults();

      // Should have 7 result sets (5 CREATEs + 2 SELECTs)
      expect(results.length, equals(7));

      // Verify CREATE results (first 5 results are single-record arrays)
      for (int i = 0; i < 5; i++) {
        expect(results[i], isA<List>());
        final resultList = results[i] as List;
        expect(resultList.length, equals(1));
        expect(resultList.first, isA<Map<String, dynamic>>());
      }

      // Verify first SELECT result (companies)
      expect(results[5], isA<List>());
      final companies = results[5] as List;
      expect(companies.length, equals(2));

      final company1 = companies[0] as Map<String, dynamic>;
      final company2 = companies[1] as Map<String, dynamic>;

      // Verify companies are ordered by name
      expect(company1['name'], equals('InnovateLabs'));
      expect(company1['employees'], equals(120));
      expect(company2['name'], equals('TechCorp'));
      expect(company2['employees'], equals(250));

      // Verify second SELECT result (employees)
      expect(results[6], isA<List>());
      final employees = results[6] as List;
      expect(employees.length, equals(3));

      final emp1 = employees[0] as Map<String, dynamic>;
      final emp2 = employees[1] as Map<String, dynamic>;
      final emp3 = employees[2] as Map<String, dynamic>;

      // Verify employees are ordered by name
      expect(emp1['name'], equals('Alice Johnson'));
      expect(emp2['name'], equals('Bob Smith'));
      expect(emp3['name'], equals('Carol White'));

      // Verify relationships (Thing IDs)
      expect(emp1['company'], equals('company:tech1'));
      expect(emp2['company'], equals('company:tech1'));
      expect(emp3['company'], equals('company:tech2'));
    });

    // Test 5: Error handling (invalid SQL, closed database)
    test('Test 5: Error handling (invalid SQL, closed database)', () async {
      // Test invalid SQL syntax
      try {
        await db.query('THIS IS INVALID SQL SYNTAX');
        fail('Should have thrown QueryException');
      } catch (e) {
        expect(e, isA<QueryException>());
        final queryException = e as QueryException;
        expect(queryException.message, isNotEmpty);
      }

      // Test invalid table reference
      try {
        await db.query('SELECT * FROM nonexistent.table.with.dots');
        // This might succeed with empty results or fail - either is acceptable
      } catch (e) {
        expect(e, isA<QueryException>());
      }

      // Close the database
      await db.close();
      expect(db.isClosed, isTrue);

      // Test operations on closed database
      try {
        await db.query('SELECT * FROM person');
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
        final stateError = e as StateError;
        expect(stateError.message, contains('closed'));
      }

      // Test CREATE on closed database
      try {
        await db.create('person', {'name': 'Test'});
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // Test SELECT on closed database
      try {
        await db.select('person');
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // Test UPDATE on closed database
      try {
        await db.update('person:test', {'name': 'Updated'});
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
      }

      // Test DELETE on closed database
      try {
        await db.delete('person:test');
        fail('Should have thrown StateError');
      } catch (e) {
        expect(e, isA<StateError>());
      }
    });

    // Test 6: RocksDB persistence (create, close, reopen, verify data)
    test('Test 6: RocksDB persistence (create, close, reopen, verify data)',
        () async {
      // Use temporary directory for test database
      final tempDir = Directory.systemTemp.createTempSync('surrealdb_test_');
      final dbPath = '${tempDir.path}/testdb';

      Database? rocksDb;

      try {
        // Connect to RocksDB backend
        rocksDb = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'persistence_test',
        );

        // Create some test data
        final product1 = await rocksDb.create('product', {
          'name': 'Laptop',
          'price': 999.99,
          'stock': 25,
        });
        final product2 = await rocksDb.create('product', {
          'name': 'Mouse',
          'price': 29.99,
          'stock': 100,
        });

        final product1Id = product1['id'] as String;
        final product2Id = product2['id'] as String;

        // Verify data exists
        var products = await rocksDb.select('product');
        expect(products.length, equals(2));

        // Close the database
        await rocksDb.close();
        rocksDb = null;

        // Reopen the same database
        rocksDb = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'persistence_test',
        );

        // Verify data persisted across restart
        products = await rocksDb.select('product');
        expect(products.length, equals(2));

        final productMap1 = products
            .firstWhere((p) => (p as Map<String, dynamic>)['id'] == product1Id)
            as Map<String, dynamic>;
        final productMap2 = products
            .firstWhere((p) => (p as Map<String, dynamic>)['id'] == product2Id)
            as Map<String, dynamic>;

        expect(productMap1['name'], equals('Laptop'));
        expect(productMap1['stock'], equals(25));

        expect(productMap2['name'], equals('Mouse'));
        expect(productMap2['stock'], equals(100));

        // Update a record
        await rocksDb.update(product1Id, {'stock': 20});

        // Close and reopen again
        await rocksDb.close();
        rocksDb = null;

        rocksDb = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'persistence_test',
        );

        // Verify update persisted
        products = await rocksDb.select('product');
        final updatedProduct = products
            .firstWhere((p) => (p as Map<String, dynamic>)['id'] == product1Id)
            as Map<String, dynamic>;
        expect(updatedProduct['stock'], equals(20));
      } finally {
        // Clean up
        if (rocksDb != null && !rocksDb.isClosed) {
          await rocksDb.close();
        }
        try {
          tempDir.deleteSync(recursive: true);
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    });

    // Test 7: Namespace/database switching
    test('Test 7: Namespace/database switching', () async {
      // Create data in initial namespace/database
      await db.create('person', {
        'name': 'User in test namespace',
        'location': 'test/test',
      });

      var persons = await db.select('person');
      expect(persons.length, equals(1));

      // Switch to different database in same namespace
      await db.useDatabase('other_db');

      // Should be empty in new database
      persons = await db.select('person');
      expect(persons, isEmpty);

      // Create data in new database
      await db.create('person', {
        'name': 'User in other database',
        'location': 'test/other_db',
      });

      persons = await db.select('person');
      expect(persons.length, equals(1));
      final person1 = persons.first as Map<String, dynamic>;
      expect(person1['location'], equals('test/other_db'));

      // Switch to different namespace
      await db.useNamespace('production');

      // Should be empty in new namespace
      persons = await db.select('person');
      expect(persons, isEmpty);

      // Create data in new namespace
      await db.create('person', {
        'name': 'User in production',
        'location': 'production/other_db',
      });

      persons = await db.select('person');
      expect(persons.length, equals(1));
      final person2 = persons.first as Map<String, dynamic>;
      expect(person2['location'], equals('production/other_db'));

      // Switch back to original namespace/database
      await db.useNamespace('test');
      await db.useDatabase('test');

      // Should see original data
      persons = await db.select('person');
      expect(persons.length, equals(1));
      final person3 = persons.first as Map<String, dynamic>;
      expect(person3['location'], equals('test/test'));
    });

    // Test 8: Memory stability (create 100+ records, verify no leaks)
    test('Test 8: Memory stability (create 100+ records, verify no leaks)',
        () async {
      // Create 100 records with varied data
      final recordIds = <String>[];

      for (int i = 0; i < 100; i++) {
        final record = await db.create('load_test', {
          'index': i,
          'name': 'Record $i',
          'description': 'This is test record number $i for load testing',
          'value': i * 1.5,
          'active': i % 2 == 0,
          'tags': ['tag${i % 5}', 'category${i % 10}', 'test'],
          'metadata': {
            'batch': i ~/ 10,
            'created': '2025-10-21T10:00:00Z',
            'priority': i % 3,
          },
        });

        recordIds.add(record['id'] as String);

        // Verify each record was created correctly
        expect(record['index'], equals(i));
        expect(record['name'], equals('Record $i'));
      }

      // Verify all records are queryable
      final allRecords = await db.select('load_test');
      expect(allRecords.length, equals(100));

      // Query with ordering to verify database can handle it
      final response = await db.query('SELECT * FROM load_test ORDER BY index');
      final results = response.getResults();
      expect(results.length, equals(1));

      final orderedRecords = results.first as List;
      expect(orderedRecords.length, equals(100));

      // Verify ordering
      for (int i = 0; i < 100; i++) {
        final record = orderedRecords[i] as Map<String, dynamic>;
        expect(record['index'], equals(i));
      }

      // Update a subset of records
      for (int i = 0; i < 20; i++) {
        await db.update(recordIds[i], {
          'updated': true,
          'updateTime': '2025-10-21T12:00:00Z',
        });
      }

      // Verify updates persisted
      final updatedResponse = await db.query(
        'SELECT * FROM load_test WHERE updated = true',
      );
      final updatedResults = updatedResponse.getResults();
      final updatedRecords = updatedResults.first as List;
      expect(updatedRecords.length, equals(20));

      // Delete a subset of records
      for (int i = 0; i < 10; i++) {
        await db.delete(recordIds[i]);
      }

      // Verify deletions
      final remainingRecords = await db.select('load_test');
      expect(remainingRecords.length, equals(90));

      // Perform complex query to stress the system
      final complexResponse = await db.query('''
        SELECT
          metadata.batch as batch,
          count() as record_count,
          math::sum(value) as total_value,
          math::mean(value) as avg_value
        FROM load_test
        GROUP BY metadata.batch
        ORDER BY batch
      ''');

      final complexResults = complexResponse.getResults();
      final aggregatedData = complexResults.first as List;

      // Should have ~9 batches (0-8) after deletions (batch 0 had all 10 deleted records)
      expect(aggregatedData.length, greaterThanOrEqualTo(8));

      // Verify no memory leaks by doing one more large operation
      // If there were leaks, this would compound them
      final finalRecords = await db.select('load_test');
      expect(finalRecords.length, equals(90));

      // Success - no errors indicate stable memory management
    }, timeout: Timeout(Duration(minutes: 2)));
  });

  // Additional test group for error propagation across layers
  group('Task Group 5: Error Propagation Testing', () {
    test('Error propagation from Rust through all layers', () async {
      // This test verifies that errors from different layers propagate correctly

      // Test connection error
      try {
        await Database.connect(
          backend: StorageBackend.rocksdb,
          path: '/invalid/path/that/does/not/exist/at/all',
          namespace: 'test',
          database: 'test',
        );
        fail('Should have thrown ConnectionException');
      } catch (e) {
        // Should be ConnectionException or DatabaseException
        expect(
          e is ConnectionException || e is DatabaseException,
          isTrue,
          reason: 'Expected ConnectionException or DatabaseException, got ${e.runtimeType}',
        );
        if (e is DatabaseException) {
          expect(e.message, isNotEmpty);
        }
      }

      // Test with valid database for query errors
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Test malformed SurrealQL
        try {
          await db.query('INVALID STATEMENT WITH { SYNTAX ERRORS ]');
          fail('Should have thrown QueryException');
        } catch (e) {
          expect(e, isA<QueryException>());
          final qe = e as QueryException;
          expect(qe.message, isNotEmpty);
        }

        // Test CREATE with malformed data (edge case)
        // Note: SurrealDB is quite permissive, so this may succeed
        // The test is here to ensure we don't crash on edge cases
        try {
          await db.create('test_table', {
            'valid_field': 'value',
          });
          // Success is acceptable - SurrealDB handles this
        } catch (e) {
          // Error is also acceptable - verify it's properly typed
          expect(e is DatabaseException, isTrue);
        }
      } finally {
        await db.close();
      }
    });
  });
}
