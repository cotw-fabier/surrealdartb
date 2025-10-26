/// Unit tests for ORM WhereCondition classes (Part of Task Group 17).
///
/// These strategic tests verify the ORM foundation's where condition system:
/// - WhereCondition base class and operator overloading
/// - Logical operators (AND, OR) with proper precedence
/// - Concrete condition implementations (Equals, Between, etc.)
/// - SurrealQL generation for various condition types
///
/// These tests fill critical gaps in testing the ORM query building foundation.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:surrealdartb/src/orm/where_condition.dart';

void main() {
  late Database db;

  setUp(() async {
    // Create in-memory database for testing
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Task Group 17: ORM WhereCondition Foundation Tests', () {
    // Test 1: AND operator combines conditions correctly
    test('Test 1: AND operator (&) combines two conditions', () {
      // Arrange
      final condition1 = EqualsCondition('status', 'active');
      final condition2 = GreaterThanCondition('age', 18);

      // Act
      final combined = condition1 & condition2;

      // Assert
      expect(combined, isA<AndCondition>());
      expect((combined as AndCondition).left, equals(condition1));
      expect(combined.right, equals(condition2));
    });

    // Test 2: OR operator combines conditions correctly
    test('Test 2: OR operator (|) combines two conditions', () {
      // Arrange
      final condition1 = EqualsCondition('role', 'admin');
      final condition2 = EqualsCondition('role', 'moderator');

      // Act
      final combined = condition1 | condition2;

      // Assert
      expect(combined, isA<OrCondition>());
      expect((combined as OrCondition).left, equals(condition1));
      expect(combined.right, equals(condition2));
    });

    // Test 3: Complex nested conditions with precedence
    test('Test 3: Complex nested conditions maintain precedence', () {
      // Arrange
      final age1 = BetweenCondition('age', 0, 10);
      final age2 = BetweenCondition('age', 90, 100);
      final status = EqualsCondition('status', 'verified');

      // Act - (age 0-10 OR age 90-100) AND verified
      final complex = (age1 | age2) & status;

      // Assert
      expect(complex, isA<AndCondition>());
      final andCond = complex as AndCondition;
      expect(andCond.left, isA<OrCondition>());
      expect(andCond.right, isA<EqualsCondition>());
    });

    // Test 4: EqualsCondition generates correct SurrealQL
    test('Test 4: EqualsCondition generates correct SurrealQL', () {
      // Arrange
      final condition = EqualsCondition('name', 'Alice');

      // Act
      final sql = condition.toSurrealQL(db);

      // Assert
      expect(sql, contains('name'));
      expect(sql, contains('='));
      expect(sql, contains('Alice'));
    });

    // Test 5: BetweenCondition generates correct SurrealQL
    test('Test 5: BetweenCondition generates correct SurrealQL with range', () {
      // Arrange
      final condition = BetweenCondition('age', 18, 65);

      // Act
      final sql = condition.toSurrealQL(db);

      // Assert
      expect(sql, contains('age'));
      expect(sql, contains('>='));
      expect(sql, contains('18'));
      expect(sql, contains('AND'));
      expect(sql, contains('<='));
      expect(sql, contains('65'));
    });

    // Test 6: AndCondition generates SurrealQL with parentheses
    test('Test 6: AndCondition generates SurrealQL with parentheses', () {
      // Arrange
      final combined = EqualsCondition('status', 'active') &
          GreaterThanCondition('count', 10);

      // Act
      final sql = combined.toSurrealQL(db);

      // Assert
      expect(sql, startsWith('('));
      expect(sql, endsWith(')'));
      expect(sql, contains('AND'));
      expect(sql, contains('status'));
      expect(sql, contains('count'));
    });

    // Test 7: OrCondition generates SurrealQL with parentheses
    test('Test 7: OrCondition generates SurrealQL with parentheses', () {
      // Arrange
      final combined =
          EqualsCondition('type', 'A') | EqualsCondition('type', 'B');

      // Act
      final sql = combined.toSurrealQL(db);

      // Assert
      expect(sql, startsWith('('));
      expect(sql, endsWith(')'));
      expect(sql, contains('OR'));
      expect(sql, contains('type'));
    });

    // Test 8: ContainsCondition generates correct SurrealQL
    test('Test 8: ContainsCondition generates correct SurrealQL for strings',
        () {
      // Arrange
      final condition = ContainsCondition('description', 'urgent');

      // Act
      final sql = condition.toSurrealQL(db);

      // Assert
      expect(sql, contains('description'));
      expect(sql, contains('CONTAINS'));
      expect(sql, contains('urgent'));
    });

    // Test 9: Condition toString() provides debugging info
    test('Test 9: Condition classes have descriptive toString()', () {
      // Arrange
      final equals = EqualsCondition('field', 'value');
      final between = BetweenCondition('age', 1, 100);
      final and = equals & between;
      final or = equals | between;

      // Act & Assert
      expect(equals.toString(), contains('EqualsCondition'));
      expect(equals.toString(), contains('field'));
      expect(between.toString(), contains('BetweenCondition'));
      expect(and.toString(), contains('AndCondition'));
      expect(or.toString(), contains('OrCondition'));
    });

    // Test 10: Multiple operators chain correctly
    test('Test 10: Multiple operators chain correctly', () {
      // Arrange
      final c1 = EqualsCondition('a', 1);
      final c2 = EqualsCondition('b', 2);
      final c3 = EqualsCondition('c', 3);

      // Act - Test associativity: (c1 & c2) & c3
      final chained = c1 & c2 & c3;

      // Assert - Should create nested AndConditions
      expect(chained, isA<AndCondition>());
      final outer = chained as AndCondition;
      expect(outer.left, isA<AndCondition>());
      expect(outer.right, equals(c3));
    });
  });
}
