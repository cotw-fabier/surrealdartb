/// Tests for async behavior with direct FFI architecture.
///
/// These tests verify that the new direct FFI implementation maintains
/// proper async behavior without blocking, even though isolates have been removed.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Direct FFI Async Behavior', () {
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

    test('Database operations are non-blocking', () async {
      // This test verifies that multiple database operations can be initiated
      // concurrently without blocking each other, even with direct FFI calls.
      // The Rust layer uses runtime.block_on() which allows this to work.

      // Start a create operation
      final future1 = db.create('person', {'name': 'Person1'});

      // Start another immediately (should not block)
      final future2 = db.create('person', {'name': 'Person2'});

      // Both should complete
      final results = await Future.wait([future1, future2]);

      expect(results, hasLength(2));
      expect(results[0]['name'], equals('Person1'));
      expect(results[1]['name'], equals('Person2'));
    });

    test('Multiple concurrent queries execute correctly', () async {
      // Create some test data first
      await db.create('product', {'name': 'Laptop', 'price': 999.99});
      await db.create('product', {'name': 'Mouse', 'price': 29.99});
      await db.create('product', {'name': 'Keyboard', 'price': 79.99});

      // Execute multiple queries concurrently
      final future1 = db.query('SELECT * FROM product WHERE price > 50');
      final future2 = db.query('SELECT * FROM product WHERE price < 50');
      final future3 = db.select('product');

      final results = await Future.wait([future1, future2, future3]);

      // Verify all queries completed successfully
      expect(results, hasLength(3));

      // Query 1: Products with price > 50
      final expensive = results[0].getResults().first as List;
      expect(expensive.length, greaterThanOrEqualTo(2)); // Laptop and Keyboard

      // Query 2: Products with price < 50
      final cheap = results[1].getResults().first as List;
      expect(cheap.length, greaterThanOrEqualTo(1)); // Mouse

      // Query 3: All products
      expect(results[2], hasLength(3));
    });

    test('CRUD operations can be interleaved', () async {
      // This test verifies that different types of operations
      // (CREATE, SELECT, UPDATE, DELETE) can be executed in quick succession
      // without issues from the direct FFI architecture.

      // Create a record
      final person1 = await db.create('person', {
        'name': 'Alice',
        'age': 30,
      });
      final person1Id = person1['id'] as String;

      // Start multiple operations without awaiting
      final createFuture = db.create('person', {'name': 'Bob', 'age': 25});
      final selectFuture = db.select('person');
      final updateFuture = db.update(person1Id, {'age': 31});

      // Wait for all to complete
      await Future.wait([createFuture, selectFuture, updateFuture]);

      // Verify final state
      final allPersons = await db.select('person');
      expect(allPersons.length, equals(2));

      final alice = allPersons.firstWhere(
        (p) => (p as Map<String, dynamic>)['name'] == 'Alice',
      ) as Map<String, dynamic>;
      expect(alice['age'], equals(31)); // Should be updated
    });

    test('Error handling works correctly with concurrent operations', () async {
      // Create a valid record
      final validFuture = db.create('person', {'name': 'Valid'});

      // Try to execute invalid query concurrently
      final invalidFuture = db.query('INVALID SYNTAX HERE');

      // Valid operation should succeed
      final validResult = await validFuture;
      expect(validResult['name'], equals('Valid'));

      // Invalid operation should throw exception
      try {
        await invalidFuture;
        fail('Should have thrown QueryException');
      } catch (e) {
        expect(e, isA<QueryException>());
      }

      // Database should still be usable after error
      final persons = await db.select('person');
      expect(persons, isNotEmpty);
    });

    test('Namespace switching is non-blocking', () async {
      // Create data in initial namespace
      await db.create('person', {'name': 'User1'});

      // Switch namespace while creating more data
      final switchFuture = db.useNamespace('other_ns');
      final createFuture = db.create('person', {'name': 'User2'});

      await switchFuture;

      // User2 might be in original or new namespace depending on timing
      // Just verify no errors occurred
      await createFuture;

      // Verify we can continue operations
      final result = await db.select('person');
      expect(result, isA<List>());
    });

    test('Database operations complete in reasonable time', () async {
      // This test ensures that direct FFI calls complete quickly
      // without the overhead of isolate message passing.

      final stopwatch = Stopwatch()..start();

      // Perform a batch of operations
      for (int i = 0; i < 10; i++) {
        await db.create('test', {
          'index': i,
          'data': 'Test data $i',
        });
      }

      stopwatch.stop();

      // Operations should complete quickly (under 5 seconds for 10 creates)
      // This is a generous threshold - actual time should be much less
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason: 'Direct FFI should be fast',
      );

      // Verify all records were created
      final records = await db.select('test');
      expect(records.length, equals(10));
    });

    test('Resources are properly cleaned up after operations', () async {
      // Create and delete many records to test resource cleanup
      final recordIds = <String>[];

      // Create 20 records
      for (int i = 0; i < 20; i++) {
        final record = await db.create('cleanup_test', {
          'index': i,
          'data': 'Test $i',
        });
        recordIds.add(record['id'] as String);
      }

      // Delete all records
      for (final id in recordIds) {
        await db.delete(id);
      }

      // Verify cleanup
      final remaining = await db.select('cleanup_test');
      expect(remaining, isEmpty);

      // Database should still be functional
      final newRecord = await db.create('cleanup_test', {'test': 'new'});
      expect(newRecord['test'], equals('new'));
    });
  });

  group('Direct FFI Architecture Validation', () {
    test('No isolate startup delay', () async {
      // With direct FFI, there should be no isolate startup overhead.
      // Connect and execute operation immediately.

      final stopwatch = Stopwatch()..start();

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        await db.create('person', {'name': 'Fast'});
        stopwatch.stop();

        // Should be very fast without isolate startup
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(2000),
          reason: 'Direct FFI should have minimal connection overhead',
        );
      } finally {
        await db.close();
      }
    });

    test('Multiple database instances work independently', () async {
      // Create two separate database instances
      final db1 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'ns1',
        database: 'db1',
      );

      final db2 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'ns2',
        database: 'db2',
      );

      try {
        // Create data in each database
        await db1.create('person', {'name': 'Person1'});
        await db2.create('person', {'name': 'Person2'});

        // Each should only see their own data
        final db1Records = await db1.select('person');
        final db2Records = await db2.select('person');

        expect(db1Records.length, equals(1));
        expect(db2Records.length, equals(1));

        expect(
          (db1Records.first as Map<String, dynamic>)['name'],
          equals('Person1'),
        );
        expect(
          (db2Records.first as Map<String, dynamic>)['name'],
          equals('Person2'),
        );
      } finally {
        await db1.close();
        await db2.close();
      }
    });
  });
}
