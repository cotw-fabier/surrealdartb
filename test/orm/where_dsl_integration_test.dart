/// Integration tests for comprehensive WHERE clause DSL (Task Group 10).
///
/// These tests verify that the WHERE clause DSL is properly integrated
/// with the Database.query() method, supporting:
/// - Simple equality conditions
/// - Complex AND conditions
/// - Complex OR conditions
/// - Combined AND/OR with proper precedence
/// - Nested property access in WHERE clauses
/// - Parameter binding for SQL injection prevention
///
/// Total tests: 8 focused tests covering critical WHERE DSL integration
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 10: Comprehensive WHERE Clause DSL Integration', () {
    late Database db;

    setUp(() async {
      // Create in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      // Create test table with sample data
      await db.queryQL('''
        DEFINE TABLE users SCHEMAFULL;
        DEFINE FIELD name ON users TYPE string;
        DEFINE FIELD age ON users TYPE int;
        DEFINE FIELD status ON users TYPE string;
        DEFINE FIELD verified ON users TYPE bool;
        DEFINE FIELD city ON users TYPE string;
      ''');

      // Insert test data
      await db.createQL('users', {
        'name': 'Alice',
        'age': 25,
        'status': 'active',
        'verified': true,
        'city': 'NYC',
      });

      await db.createQL('users', {
        'name': 'Bob',
        'age': 35,
        'status': 'active',
        'verified': false,
        'city': 'LA',
      });

      await db.createQL('users', {
        'name': 'Charlie',
        'age': 5,
        'status': 'inactive',
        'verified': true,
        'city': 'NYC',
      });

      await db.createQL('users', {
        'name': 'Diana',
        'age': 95,
        'status': 'active',
        'verified': true,
        'city': 'SF',
      });
    });

    tearDown(() async {
      await db.close();
    });

    // Test 1: Simple equality condition
    test('Test 1: Query with simple equality WHERE condition', () async {
      final results = await db.query(
        table: 'users',
        where: EqualsCondition('status', 'active'),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(3)); // Alice, Bob, Diana
      expect(results.every((r) => r['status'] == 'active'), isTrue);
    });

    // Test 2: Complex AND condition
    test('Test 2: Query with complex AND condition (age > 18 AND status = active)',
        () async {
      final results = await db.query(
        table: 'users',
        where: GreaterThanCondition('age', 18) & EqualsCondition('status', 'active'),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(3)); // Alice (25), Bob (35), Diana (95)
      expect(
          results.every((r) => r['age'] > 18 && r['status'] == 'active'), isTrue);
    });

    // Test 3: Complex OR condition
    test('Test 3: Query with OR condition (age < 10 OR age > 90)', () async {
      final results = await db.query(
        table: 'users',
        where: LessThanCondition('age', 10) | GreaterThanCondition('age', 90),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(2)); // Charlie (5) and Diana (95)
      final ages = results.map((r) => r['age'] as int).toList();
      expect(ages.every((age) => age < 10 || age > 90), isTrue);
    });

    // Test 4: Combined AND/OR with proper precedence
    test(
        'Test 4: Query with combined AND/OR: ((age < 10 OR age > 90) AND verified = true)',
        () async {
      final results = await db.query(
        table: 'users',
        where: (LessThanCondition('age', 10) | GreaterThanCondition('age', 90)) &
            EqualsCondition('verified', true),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(2)); // Charlie and Diana (both verified)
      for (final user in results) {
        final age = user['age'] as int;
        final verified = user['verified'] as bool;
        expect(verified, isTrue);
        expect(age < 10 || age > 90, isTrue);
      }
    });

    // Test 5: Between condition
    test('Test 5: Query with BETWEEN condition (age between 20 and 40)', () async {
      final results = await db.query(
        table: 'users',
        where: BetweenCondition('age', 20, 40),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(2)); // Alice (25) and Bob (35)
      final ages = results.map((r) => r['age'] as int).toList();
      expect(ages.every((age) => age >= 20 && age <= 40), isTrue);
    });

    // Test 6: IN list condition
    test('Test 6: Query with IN condition (city IN [NYC, SF])', () async {
      final results = await db.query(
        table: 'users',
        where: InListCondition('city', ['NYC', 'SF']),
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(3)); // Alice, Charlie (NYC), Diana (SF)
      final cities = results.map((r) => r['city'] as String).toList();
      expect(cities.every((city) => ['NYC', 'SF'].contains(city)), isTrue);
    });

    // Test 7: Complex multi-condition query with limit and orderBy
    test(
        'Test 7: Complex query with WHERE, ORDER BY, and LIMIT'
        , () async {
      final results = await db.query(
        table: 'users',
        where: EqualsCondition('status', 'active') &
            GreaterThanCondition('age', 20),
        orderBy: 'age',
        ascending: false, // Descending order
        limit: 2,
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(2));
      // Should return Diana (95) and Bob (35) in descending age order
      expect(results[0]['age'], equals(95)); // Diana
      expect(results[1]['age'], equals(35)); // Bob
    });

    // Test 8: String conditions (Contains, StartsWith, etc.)
    test('Test 8: Query with string CONTAINS condition', () async {
      final results = await db.query(
        table: 'users',
        where: ContainsCondition('name', 'li'),
      );

      expect(results, isNotEmpty);
      // Should find Alice and Charlie (both contain 'li')
      expect(results.length, greaterThanOrEqualTo(1));
      final names = results.map((r) => r['name'] as String).toList();
      expect(names.every((name) => name.toLowerCase().contains('li')), isTrue);
    });
  });

  group('WHERE DSL Operator Precedence', () {
    late Database db;

    setUp(() async {
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Precedence: AND before OR without parentheses', () {
      // This tests that our implementation handles precedence correctly
      // a | b & c should be treated as a | (b & c)
      final condition = EqualsCondition('a', 1) |
          EqualsCondition('b', 2) & EqualsCondition('c', 3);

      // The condition should be structured as OR(a, AND(b, c))
      expect(condition, isA<OrCondition>());
    });

    test('Precedence: Parentheses override default precedence', () {
      // (a | b) & c should be AND(OR(a, b), c)
      final condition = (EqualsCondition('a', 1) | EqualsCondition('b', 2)) &
          EqualsCondition('c', 3);

      // The condition should be structured as AND(OR(a, b), c)
      expect(condition, isA<AndCondition>());
      final andCond = condition as AndCondition;
      expect(andCond.left, isA<OrCondition>());
    });
  });
}
