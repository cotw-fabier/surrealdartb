/// Tests for the direct parameter query API (Task Group 16).
///
/// This test file validates the direct parameter API for querying with
/// where clauses, includes, and other query parameters.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Direct Parameter Query API', () {
    late Database db;

    setUp(() async {
      // Create an in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('simple query with table parameter only', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25});
      await db.createQL('users', {'name': 'Bob', 'age': 30});
      await db.createQL('users', {'name': 'Charlie', 'age': 35});

      // Execute simple query
      final results = await db.query(table: 'users');

      // Verify results
      expect(results, hasLength(3));
      expect(results.every((r) => r.containsKey('id')), isTrue);
      expect(results.every((r) => r.containsKey('name')), isTrue);
    });

    test('query with limit parameter', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25});
      await db.createQL('users', {'name': 'Bob', 'age': 30});
      await db.createQL('users', {'name': 'Charlie', 'age': 35});

      // Execute query with limit
      final results = await db.query(table: 'users', limit: 2);

      // Verify results
      expect(results, hasLength(2));
    });

    test('query with orderBy parameter', () async {
      // Create test data
      await db.createQL('users', {'name': 'Charlie', 'age': 35});
      await db.createQL('users', {'name': 'Alice', 'age': 25});
      await db.createQL('users', {'name': 'Bob', 'age': 30});

      // Execute query with orderBy
      final results = await db.query(
        table: 'users',
        orderBy: 'name',
        ascending: true,
      );

      // Verify results are ordered by name
      expect(results, hasLength(3));
      expect(results[0]['name'], equals('Alice'));
      expect(results[1]['name'], equals('Bob'));
      expect(results[2]['name'], equals('Charlie'));
    });

    test('query with orderBy descending', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25});
      await db.createQL('users', {'name': 'Bob', 'age': 30});
      await db.createQL('users', {'name': 'Charlie', 'age': 35});

      // Execute query with orderBy descending
      final results = await db.query(
        table: 'users',
        orderBy: 'age',
        ascending: false,
      );

      // Verify results are ordered by age descending
      expect(results, hasLength(3));
      expect(results[0]['age'], equals(35));
      expect(results[1]['age'], equals(30));
      expect(results[2]['age'], equals(25));
    });

    test('query with simple where condition', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'status': 'active'});
      await db.createQL('users', {'name': 'Bob', 'status': 'inactive'});
      await db.createQL('users', {'name': 'Charlie', 'status': 'active'});

      // Execute query with where condition
      final results = await db.query(
        table: 'users',
        where: EqualsCondition('status', 'active'),
      );

      // Verify results
      expect(results, hasLength(2));
      expect(results.every((r) => r['status'] == 'active'), isTrue);
    });

    test('query with AND condition using & operator', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25, 'status': 'active'});
      await db.createQL('users', {'name': 'Bob', 'age': 30, 'status': 'inactive'});
      await db.createQL('users', {'name': 'Charlie', 'age': 35, 'status': 'active'});

      // Execute query with AND condition
      final results = await db.query(
        table: 'users',
        where: EqualsCondition('status', 'active') &
            GreaterThanCondition('age', 30),
      );

      // Verify results
      expect(results, hasLength(1));
      expect(results[0]['name'], equals('Charlie'));
      expect(results[0]['age'], equals(35));
      expect(results[0]['status'], equals('active'));
    });

    test('query with OR condition using | operator', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25});
      await db.createQL('users', {'name': 'Bob', 'age': 30});
      await db.createQL('users', {'name': 'Charlie', 'age': 95});

      // Execute query with OR condition (young or very old)
      final results = await db.query(
        table: 'users',
        where: LessThanCondition('age', 26) | GreaterThanCondition('age', 90),
      );

      // Verify results
      expect(results, hasLength(2));
      final names = results.map((r) => r['name']).toList();
      expect(names, containsAll(['Alice', 'Charlie']));
    });

    test('query with complex combined conditions', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 8, 'verified': true});
      await db.createQL('users', {'name': 'Bob', 'age': 30, 'verified': false});
      await db.createQL('users', {'name': 'Charlie', 'age': 95, 'verified': true});
      await db.createQL('users', {'name': 'David', 'age': 40, 'verified': false});

      // Execute query: (age < 10 OR age > 90) AND verified == true
      final results = await db.query(
        table: 'users',
        where: (LessThanCondition('age', 10) | GreaterThanCondition('age', 90)) &
            EqualsCondition('verified', true),
      );

      // Verify results
      expect(results, hasLength(2));
      final names = results.map((r) => r['name']).toList();
      expect(names, containsAll(['Alice', 'Charlie']));
    });

    test('query with all parameters combined', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'age': 25, 'status': 'active'});
      await db.createQL('users', {'name': 'Bob', 'age': 30, 'status': 'active'});
      await db.createQL('users', {'name': 'Charlie', 'age': 35, 'status': 'active'});
      await db.createQL('users', {'name': 'David', 'age': 40, 'status': 'inactive'});

      // Execute complex query
      final results = await db.query(
        table: 'users',
        where: EqualsCondition('status', 'active') &
            GreaterThanCondition('age', 20),
        orderBy: 'age',
        ascending: false,
        limit: 2,
      );

      // Verify results
      expect(results, hasLength(2));
      expect(results[0]['name'], equals('Charlie')); // age 35
      expect(results[1]['name'], equals('Bob')); // age 30
    });

    test('query with offset parameter', () async {
      // Create test data
      await db.createQL('users', {'name': 'Alice', 'position': 1});
      await db.createQL('users', {'name': 'Bob', 'position': 2});
      await db.createQL('users', {'name': 'Charlie', 'position': 3});
      await db.createQL('users', {'name': 'David', 'position': 4});

      // Execute query with offset
      final results = await db.query(
        table: 'users',
        orderBy: 'position',
        ascending: true,
        offset: 2,
      );

      // Verify results (should skip first 2)
      expect(results, hasLength(2));
      expect(results[0]['name'], equals('Charlie'));
      expect(results[1]['name'], equals('David'));
    });

    test('query with empty table name throws ArgumentError', () async {
      // Attempt to query with empty table name
      expect(
        () => db.query(table: ''),
        throwsArgumentError,
      );
    });

    test('query returns empty list for non-existent table', () async {
      // Query a table that doesn't exist
      final results = await db.query(table: 'non_existent_table');

      // Verify empty results
      expect(results, isEmpty);
    });

    test('query with IncludeSpec placeholder', () async {
      // Create test data (includes will be ignored in this implementation)
      await db.createQL('users', {'name': 'Alice'});

      // Execute query with include (should work but ignore includes)
      final results = await db.query(
        table: 'users',
        include: [IncludeSpec('posts', limit: 5)],
      );

      // Verify results (includes are ignored for now)
      expect(results, hasLength(1));
      expect(results[0]['name'], equals('Alice'));
    });
  });
}
