/// Unit tests for IncludeSpec and include builder classes (Task Group 14).
///
/// These tests verify:
/// - IncludeSpec class construction and configuration
/// - Basic include without filtering
/// - Include with where clauses
/// - Include with limit and orderBy
/// - Nested include structures
/// - Include builder infrastructure
///
/// Total tests: 8 focused tests covering critical include specification behaviors
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 14: IncludeSpec and Include Builder Classes', () {
    // Test 1: Basic IncludeSpec construction
    test('Test 1: IncludeSpec constructs with relation name only', () {
      final spec = IncludeSpec('posts');

      // Verify basic properties
      expect(spec.relationName, equals('posts'));
      expect(spec.where, isNull);
      expect(spec.limit, isNull);
      expect(spec.orderBy, isNull);
      expect(spec.descending, isNull);
      expect(spec.include, isNull);
    });

    // Test 2: IncludeSpec with where clause
    test('Test 2: IncludeSpec with where clause parameter', () {
      final whereCondition = EqualsCondition('status', 'published');
      final spec = IncludeSpec(
        'posts',
        where: whereCondition,
      );

      // Verify where clause is set
      expect(spec.relationName, equals('posts'));
      expect(spec.where, isNotNull);
      expect(spec.where, equals(whereCondition));
    });

    // Test 3: IncludeSpec with limit and orderBy
    test('Test 3: IncludeSpec with limit and orderBy parameters', () {
      final spec = IncludeSpec(
        'posts',
        limit: 10,
        orderBy: 'createdAt',
        descending: true,
      );

      // Verify limit and orderBy are set
      expect(spec.relationName, equals('posts'));
      expect(spec.limit, equals(10));
      expect(spec.orderBy, equals('createdAt'));
      expect(spec.descending, equals(true));
    });

    // Test 4: IncludeSpec with all parameters
    test('Test 4: IncludeSpec with all parameters configured', () {
      final whereCondition = EqualsCondition('status', 'published');
      final spec = IncludeSpec(
        'posts',
        where: whereCondition,
        limit: 5,
        orderBy: 'createdAt',
        descending: true,
      );

      // Verify all parameters
      expect(spec.relationName, equals('posts'));
      expect(spec.where, equals(whereCondition));
      expect(spec.limit, equals(5));
      expect(spec.orderBy, equals('createdAt'));
      expect(spec.descending, equals(true));
    });

    // Test 5: Nested IncludeSpec structures
    test('Test 5: IncludeSpec with nested includes', () {
      final nestedInclude1 = IncludeSpec('comments', limit: 5);
      final nestedInclude2 = IncludeSpec('tags');

      final spec = IncludeSpec(
        'posts',
        include: [nestedInclude1, nestedInclude2],
      );

      // Verify nested includes
      expect(spec.relationName, equals('posts'));
      expect(spec.include, isNotNull);
      expect(spec.include!.length, equals(2));
      expect(spec.include![0].relationName, equals('comments'));
      expect(spec.include![0].limit, equals(5));
      expect(spec.include![1].relationName, equals('tags'));
    });

    // Test 6: Multi-level nested includes
    test('Test 6: IncludeSpec with multi-level nested includes', () {
      final deepNestedInclude = IncludeSpec('likes', limit: 3);
      final nestedInclude = IncludeSpec(
        'comments',
        limit: 5,
        include: [deepNestedInclude],
      );

      final spec = IncludeSpec(
        'posts',
        include: [nestedInclude],
      );

      // Verify multi-level nesting
      expect(spec.relationName, equals('posts'));
      expect(spec.include, isNotNull);
      expect(spec.include!.length, equals(1));

      final nested = spec.include![0];
      expect(nested.relationName, equals('comments'));
      expect(nested.limit, equals(5));
      expect(nested.include, isNotNull);
      expect(nested.include!.length, equals(1));

      final deepNested = nested.include![0];
      expect(deepNested.relationName, equals('likes'));
      expect(deepNested.limit, equals(3));
    });

    // Test 7: IncludeSpec toString representation
    test('Test 7: IncludeSpec toString provides useful representation', () {
      final spec1 = IncludeSpec('posts');
      expect(spec1.toString(), contains('IncludeSpec(posts'));

      final spec2 = IncludeSpec(
        'posts',
        where: EqualsCondition('status', 'published'),
        limit: 10,
      );
      final str2 = spec2.toString();
      expect(str2, contains('posts'));
      expect(str2, contains('where'));
      expect(str2, contains('limit: 10'));
    });

    // Test 8: IncludeSpec with complex where conditions
    test('Test 8: IncludeSpec with complex AND/OR where conditions', () {
      final condition1 = EqualsCondition('status', 'published');
      final condition2 = GreaterThanCondition('views', 100);
      final combined = condition1 & condition2;

      final spec = IncludeSpec(
        'posts',
        where: combined,
        limit: 5,
        orderBy: 'views',
        descending: true,
      );

      // Verify complex where condition is stored
      expect(spec.relationName, equals('posts'));
      expect(spec.where, isNotNull);
      expect(spec.where, isA<AndCondition>());
      expect(spec.limit, equals(5));
      expect(spec.orderBy, equals('views'));
      expect(spec.descending, equals(true));
    });
  });
}
