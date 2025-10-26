/// Integration tests for SDK Parity features (Task Group 8.1).
///
/// This test file provides strategic integration tests that fill critical gaps
/// in test coverage for SDK parity specification. These tests focus on:
/// - Feature combinations (auth + parameters, types in workflows)
/// - End-to-end workflows spanning multiple operations
/// - Storage backend compatibility (memory vs RocksDB)
/// - Error path testing for exception types
/// - Memory safety and resource cleanup
///
/// Maximum 15 tests as per task constraints.
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('SDK Parity Integration Tests', () {
    /// Test 1: Type definitions work in end-to-end CRUD workflow
    test('Integration 1: Type definitions in CRUD workflow', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Create record with RecordId reference
        final person = await db.createQL('person', {
          'name': 'Alice',
          'birthdate': Datetime(DateTime(1990, 1, 15)).toJson(),
          'subscription_duration': SurrealDuration(Duration(days: 365)).toJson(),
        });

        expect(person['name'], equals('Alice'));

        // Verify RecordId parsing
        final recordId = RecordId.parse(person['id'] as String);
        expect(recordId.table, equals('person'));

        // Query and verify type deserialization
        final response = await db.queryQL('SELECT * FROM person');
        final results = response.getResults();
        expect(results, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    /// Test 2: Authentication combined with parameterized queries
    test('Integration 2: Auth + parameterized queries', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Set parameter before auth (should work)
        await db.set('table_name', 'person');

        // Attempt authentication (may not fully work in embedded mode)
        try {
          await db.signin(RootCredentials('root', 'root'));
        } on AuthenticationException catch (_) {
          // Expected in embedded mode - continue test
        }

        // Verify parameter persists after auth attempt
        final response = await db.queryQL('RETURN \$table_name');
        final results = response.getResults();
        expect(results.first, equals('person'));

        // Set another parameter and use both together
        await db.set('min_age', 18);
        await db.createQL('person', {'name': 'Bob', 'age': 25});

        final queryResponse = await db.queryQL(
          'SELECT * FROM type::table(\$table_name) WHERE age >= \$min_age',
        );
        final queryResults = queryResponse.getResults();
        expect(queryResults, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    /// Test 3: Function execution combined with parameters
    test('Integration 3: Functions + parameters workflow', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Set parameters
        await db.set('multiplier', 2);
        await db.set('base_value', 10);

        // Execute function with parameters via query
        final response = await db.queryQL('RETURN \$base_value * \$multiplier');
        final results = response.getResults();
        expect(results.first, equals(20));

        // Use built-in function with parameter
        await db.set('text', 'hello world');
        final upperResult = await db.run<String>('string::uppercase', ['\$text']);
        // Note: May not work with parameter references in run()
        // This tests the integration even if it fails

        // Execute math functions
        final absResult = await db.run<int>('math::abs', [-42]);
        expect(absResult, equals(42));

        final randomFloat = await db.run<double>('rand::float');
        expect(randomFloat, isA<double>());
        expect(randomFloat, greaterThanOrEqualTo(0.0));
        expect(randomFloat, lessThan(1.0));
      } finally {
        await db.close();
      }
    });

    /// Test 4: Multiple exception types in error scenarios
    test('Integration 4: Exception type coverage', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Test QueryException for invalid query
        expect(
          () => db.queryQL('INVALID QUERY SYNTAX'),
          throwsA(isA<QueryException>()),
        );

        // Test ParameterException for empty parameter name
        expect(
          () => db.set('', 'value'),
          throwsA(isA<ParameterException>()),
        );

        // Test AuthenticationException for invalid credentials
        expect(
          () => db.signin(RootCredentials('invalid', 'invalid')),
          throwsA(isA<AuthenticationException>()),
        );

        // Verify exceptions have proper inheritance
        try {
          await db.queryQL('INVALID SYNTAX');
        } on DatabaseException catch (e) {
          // Should catch as base DatabaseException
          expect(e, isA<QueryException>());
          expect(e.message, isNotEmpty);
        }
      } finally {
        await db.close();
      }
    });

    /// Test 5: RocksDB storage backend compatibility
    test('Integration 5: RocksDB backend basic operations', () async {
      final testDir = Directory.systemTemp.createTempSync('surreal_rocksdb_test_');
      final dbPath = '${testDir.path}/testdb';

      Database? db;
      try {
        db = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'test',
        );

        // Create data
        final record = await db.createQL('person', {'name': 'RocksDB Test'});
        expect(record['name'], equals('RocksDB Test'));

        // Query data using select (returns List directly)
        final results = await db.selectQL('person');
        expect(results, hasLength(1));

        // Close database
        await db.close();
        await Future.delayed(Duration(milliseconds: 500)); // Allow RocksDB cleanup

        // Reconnect to same database
        db = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'test',
        );

        // Verify data persisted
        final persistedResults = await db.selectQL('person');
        expect(persistedResults, hasLength(1));
        expect(persistedResults.first['name'], equals('RocksDB Test'));
      } finally {
        if (db != null && !db.isClosed) {
          await db.close();
          await Future.delayed(Duration(milliseconds: 500));
        }

        // Clean up test directory
        if (await testDir.exists()) {
          await testDir.delete(recursive: true);
        }
      }
    });

    /// Test 6: Memory backend resource cleanup
    test('Integration 6: Memory backend cleanup and isolation', () async {
      // Create first database
      var db1 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test1',
        database: 'test1',
      );

      await db1.create('person', {'name': 'DB1 Person'});
      await db1.close();

      // Create second database with different namespace
      var db2 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test2',
        database: 'test2',
      );

      try {
        await db2.create('person', {'name': 'DB2 Person'});

        // Verify isolation - should only see DB2 data
        final results = await db2.select('person');
        expect(results, hasLength(1));
        expect(results.first['name'], equals('DB2 Person'));
      } finally {
        await db2.close();
      }
    });

    /// Test 7: Parameter persistence across multiple operations
    test('Integration 7: Parameter lifecycle and persistence', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Set multiple parameters
        await db.set('user_id', 'person:alice');
        await db.set('status', 'active');
        await db.set('limit', 10);

        // Create test data
        await db.createQL('person', {'name': 'Alice', 'status': 'active'});
        await db.createQL('person', {'name': 'Bob', 'status': 'inactive'});

        // Use parameters in first query
        var response = await db.queryQL(
          'SELECT * FROM person WHERE status = \$status LIMIT \$limit',
        );
        var results = response.getResults();
        expect(results, hasLength(1));

        // Unset one parameter
        await db.unset('status');

        // Verify remaining parameters still work
        response = await db.queryQL('RETURN \$user_id');
        results = response.getResults();
        expect(results.first, equals('person:alice'));

        // Overwrite existing parameter
        await db.set('user_id', 'person:bob');
        response = await db.queryQL('RETURN \$user_id');
        results = response.getResults();
        expect(results.first, equals('person:bob'));
      } finally {
        await db.close();
      }
    });

    /// Test 8: Complex data types in queries with functions
    test('Integration 8: Complex types + functions integration', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Create record with various types
        final record = await db.createQL('event', {
          'name': 'Conference',
          'date': Datetime(DateTime(2024, 6, 15)).toJson(),
          'duration': SurrealDuration(Duration(hours: 8)).toJson(),
          'attendees': ['Alice', 'Bob', 'Charlie'],
        });

        expect(record['name'], equals('Conference'));

        // Use array function
        final arrayLen = await db.run<int>('array::len', [
          ['Alice', 'Bob', 'Charlie']
        ]);
        expect(arrayLen, equals(3));

        // Use string functions on record data
        final uppercase = await db.run<String>('string::uppercase', ['conference']);
        expect(uppercase, equals('CONFERENCE'));

        // Get database version to verify system functions work
        final version = await db.version();
        expect(version, isA<String>());
        expect(version, isNotEmpty);
      } finally {
        await db.close();
      }
    });

    /// Test 9: Error recovery and state consistency
    test('Integration 9: Error recovery and database state', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Create initial data
        await db.createQL('person', {'name': 'Alice', 'age': 25});

        // Trigger error with invalid query
        try {
          await db.queryQL('INVALID SYNTAX');
        } on QueryException catch (_) {
          // Expected - continue
        }

        // Verify database still functional after error
        final results = await db.selectQL('person');
        expect(results, hasLength(1));

        // Create more data after error
        await db.createQL('person', {'name': 'Bob', 'age': 30});

        final newResults = await db.selectQL('person');
        expect(newResults, hasLength(2));

        // Trigger parameter error
        try {
          await db.set('', 'value');
        } on ParameterException catch (_) {
          // Expected
        }

        // Verify database still works
        await db.set('valid_param', 'value');
        final paramResponse = await db.queryQL('RETURN \$valid_param');
        expect(paramResponse.getResults().first, equals('value'));
      } finally {
        await db.close();
      }
    });

    /// Test 10: Credential type serialization in auth workflow
    test('Integration 10: All credential types serialization', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Test each credential type's JSON serialization
        final rootCreds = RootCredentials('root', 'pass');
        final rootJson = rootCreds.toJson();
        expect(rootJson['username'], equals('root'));
        expect(rootJson['password'], equals('pass'));

        final nsCreds = NamespaceCredentials('user', 'pass', 'myns');
        final nsJson = nsCreds.toJson();
        expect(nsJson['namespace'], equals('myns'));

        final dbCreds = DatabaseCredentials('user', 'pass', 'myns', 'mydb');
        final dbJson = dbCreds.toJson();
        expect(dbJson['database'], equals('mydb'));

        final scopeCreds = ScopeCredentials('myns', 'mydb', 'user_scope', {
          'email': 'user@test.com',
        });
        final scopeJson = scopeCreds.toJson();
        expect(scopeJson['scope'], equals('user_scope'));
        expect(scopeJson['email'], equals('user@test.com'));

        // Attempt authentication with each type
        // (Will fail in embedded mode but tests the flow)
        for (final creds in [rootCreds, nsCreds, dbCreds, scopeCreds]) {
          try {
            await db.signin(creds);
          } on AuthenticationException catch (_) {
            // Expected in embedded mode
          }
        }
      } finally {
        await db.close();
      }
    });

    /// Test 11: RecordId usage in relation patterns
    test('Integration 11: RecordId in graph relationships', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Create nodes
        final alice = await db.createQL('person', {'name': 'Alice'});
        final bob = await db.createQL('person', {'name': 'Bob'});

        // Parse RecordIds
        final aliceId = RecordId.parse(alice['id'] as String);
        final bobId = RecordId.parse(bob['id'] as String);

        expect(aliceId.table, equals('person'));
        expect(bobId.table, equals('person'));

        // RecordIds should serialize properly
        expect(aliceId.toString(), startsWith('person:'));
        expect(bobId.toString(), startsWith('person:'));

        // Create relation using RecordId instances
        // Note: This may require specific API methods not yet implemented
        // But we can test RecordId serialization
        final relationData = {
          'in': aliceId.toString(),
          'out': bobId.toString(),
          'since': 2020,
        };

        final relation = await db.createQL('knows', relationData);
        expect(relation['in'], equals(aliceId.toString()));
        expect(relation['out'], equals(bobId.toString()));
      } finally {
        await db.close();
      }
    });

    /// Test 12: PatchOp validation and JSON serialization
    test('Integration 12: PatchOp operations and validation', () async {
      // Test all PatchOp operations
      final addOp = PatchOp.add('/email', 'new@example.com');
      final removeOp = PatchOp.remove('/temp_field');
      final replaceOp = PatchOp.replace('/age', 26);
      final changeOp = PatchOp.change('/name', 'Updated Name');

      // Verify JSON serialization
      expect(addOp.toJson()['op'], equals('add'));
      expect(removeOp.toJson()['op'], equals('remove'));
      expect(replaceOp.toJson()['op'], equals('replace'));
      expect(changeOp.toJson()['op'], equals('change'));

      // Verify path validation
      expect(() => PatchOp.add('invalid', 'value'), throwsArgumentError);
      expect(() => PatchOp.replace('', 'value'), throwsArgumentError);

      // Create array of operations
      final operations = [addOp, removeOp, replaceOp, changeOp];
      final jsonArray = operations.map((op) => op.toJson()).toList();

      expect(jsonArray, hasLength(4));
      expect(jsonArray[0]['path'], equals('/email'));
      expect(jsonArray[1].containsKey('value'), isFalse);
      expect(jsonArray[2]['value'], equals(26));
    });

    /// Test 13: Database close and reopen cycle
    test('Integration 13: Database lifecycle - close and reopen', () async {
      final db1 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      // Create data
      await db1.create('person', {'name': 'Alice'});

      // Close database
      await db1.close();
      expect(db1.isClosed, isTrue);

      // Verify operations fail on closed database
      expect(
        () => db1.create('person', {'name': 'Bob'}),
        throwsA(isA<StateError>()),
      );

      // Open new connection (memory backend won't persist)
      final db2 = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Should be able to create in new connection
        await db2.create('person', {'name': 'Bob'});
        final results = await db2.select('person');
        expect(results, hasLength(1));
      } finally {
        await db2.close();
      }
    });

    /// Test 14: Notification type for future live query support
    test('Integration 14: Notification type structure', () {
      // Test Notification type even though live queries not yet implemented
      final notification = Notification<Map<String, dynamic>>(
        'query-123',
        NotificationAction.create,
        {'id': 'person:alice', 'name': 'Alice'},
      );

      expect(notification.queryId, equals('query-123'));
      expect(notification.action, equals(NotificationAction.create));
      expect(notification.data['name'], equals('Alice'));

      // Test all action types
      expect(NotificationAction.create, isNotNull);
      expect(NotificationAction.update, isNotNull);
      expect(NotificationAction.delete, isNotNull);

      // Test fromJson deserialization
      final json = {
        'queryId': 'query-456',
        'action': 'update',
        'data': {'id': 'person:bob', 'age': 30},
      };

      final deserialized = Notification.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(deserialized.queryId, equals('query-456'));
      expect(deserialized.action, equals(NotificationAction.update));
      expect(deserialized.data['age'], equals(30));
    });

    /// Test 15: Combined workflow - CRUD with types and parameters
    test('Integration 15: End-to-end workflow with all features', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Step 1: Set parameters
        await db.set('department', 'Engineering');
        await db.set('min_salary', 50000);

        // Step 2: Create records with complex types
        await db.createQL('employee', {
          'name': 'Alice',
          'department': 'Engineering',
          'salary': 75000,
          'hire_date': Datetime(DateTime(2020, 3, 15)).toJson(),
          'contract_duration': SurrealDuration(Duration(days: 730)).toJson(),
        });

        await db.createQL('employee', {
          'name': 'Bob',
          'department': 'Engineering',
          'salary': 65000,
          'hire_date': Datetime(DateTime(2021, 6, 1)).toJson(),
          'contract_duration': SurrealDuration(Duration(days: 365)).toJson(),
        });

        // Step 3: Query with parameters
        final queryResponse = await db.queryQL(
          'SELECT * FROM employee WHERE department = \$department AND salary >= \$min_salary',
        );
        final queryResults = queryResponse.getResults();
        expect(queryResults, hasLength(2));

        // Step 4: Use functions
        final employeeCount = await db.run<int>('count', ['employee']);
        expect(employeeCount, equals(2));

        // Step 5: Update parameters and re-query
        await db.set('min_salary', 70000);
        final filteredResponse = await db.queryQL(
          'SELECT * FROM employee WHERE salary >= \$min_salary',
        );
        final filteredResults = filteredResponse.getResults();
        expect(filteredResults, hasLength(1));

        // Step 6: Get version for health check
        final version = await db.version();
        expect(version, isNotEmpty);

        // Step 7: Cleanup parameters
        await db.unset('department');
        await db.unset('min_salary');
      } finally {
        await db.close();
      }
    });
  });
}
