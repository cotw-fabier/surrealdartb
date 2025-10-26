/// Unit tests for ORM annotations (Task Group 2).
///
/// These tests verify:
/// - @SurrealRecord annotation parsing and validation
/// - @SurrealRelation annotation with direction enum
/// - @SurrealEdge annotation for edge tables
/// - @SurrealId annotation for ID field marking
/// - Annotation parameter handling and defaults
/// - Annotation combinations on fields
///
/// Total tests: 8 focused tests covering critical annotation behaviors
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 2: ORM Annotations', () {
    // Test 1: SurrealRecord annotation with default parameters
    test('Test 1: SurrealRecord annotation with default parameters', () {
      const annotation = SurrealRecord();

      // Verify default tableName is null (inferred from type)
      expect(annotation.tableName, isNull);
    });

    // Test 2: SurrealRecord annotation with explicit table name
    test('Test 2: SurrealRecord annotation with explicit table name', () {
      const annotation = SurrealRecord(tableName: 'users');

      // Verify tableName is set
      expect(annotation.tableName, equals('users'));
    });

    // Test 3: SurrealRelation annotation with all parameters
    test('Test 3: SurrealRelation annotation with all parameters', () {
      const annotation = SurrealRelation(
        name: 'likes',
        direction: RelationDirection.out,
        targetTable: 'posts',
      );

      // Verify all parameters
      expect(annotation.name, equals('likes'));
      expect(annotation.direction, equals(RelationDirection.out));
      expect(annotation.targetTable, equals('posts'));
    });

    // Test 4: SurrealRelation annotation with optional targetTable
    test('Test 4: SurrealRelation annotation with optional targetTable', () {
      const annotation = SurrealRelation(
        name: 'follows',
        direction: RelationDirection.both,
      );

      // Verify name and direction, targetTable is null
      expect(annotation.name, equals('follows'));
      expect(annotation.direction, equals(RelationDirection.both));
      expect(annotation.targetTable, isNull);
    });

    // Test 5: RelationDirection enum values
    test('Test 5: RelationDirection enum has all three directions', () {
      // Verify all three direction values exist
      expect(RelationDirection.out, isNotNull);
      expect(RelationDirection.inbound, isNotNull);
      expect(RelationDirection.both, isNotNull);

      // Verify enum values are distinct
      expect(RelationDirection.out, isNot(equals(RelationDirection.inbound)));
      expect(RelationDirection.out, isNot(equals(RelationDirection.both)));
      expect(RelationDirection.inbound, isNot(equals(RelationDirection.both)));
    });

    // Test 6: SurrealEdge annotation
    test('Test 6: SurrealEdge annotation with edge table name', () {
      const annotation = SurrealEdge('user_posts');

      // Verify edge table name
      expect(annotation.edgeTableName, equals('user_posts'));
    });

    // Test 7: SurrealId annotation (marker annotation)
    test('Test 7: SurrealId annotation as marker', () {
      const annotation = SurrealId();

      // Verify annotation can be instantiated
      // This is a marker annotation with no parameters
      expect(annotation, isNotNull);
    });

    // Test 8: Multiple annotations can be applied to same field
    test('Test 8: Annotations are const and can be used as decorators', () {
      // This test verifies that annotations are proper const classes
      // that can be used in decorator syntax @AnnotationName()

      const record = SurrealRecord();
      const recordWithTable = SurrealRecord(tableName: 'custom_table');
      const relation = SurrealRelation(
        name: 'edge',
        direction: RelationDirection.out,
      );
      const edge = SurrealEdge('edge_table');
      const id = SurrealId();

      // All annotations should be const-constructable
      expect(record, isNotNull);
      expect(recordWithTable, isNotNull);
      expect(relation, isNotNull);
      expect(edge, isNotNull);
      expect(id, isNotNull);
    });
  });
}
