/// Tests for schema diff calculation (Task Group 3.2).
///
/// This test file covers schema diff calculation between current database
/// schema and desired TableStructure definitions, change detection,
/// classification of safe vs destructive changes, and migration hash generation.
library;

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Task Group 3.2: Schema Diff Calculation Tests', () {
    test('3.2.1.1 - Detect new tables', () {
      // Arrange: Current schema has no tables
      final currentSchema = DatabaseSchema({});

      // Desired schema has a new table
      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: New table should be detected
      expect(diff.tablesAdded, contains('users'));
      expect(diff.tablesRemoved, isEmpty);
      expect(diff.hasDestructiveChanges, isFalse);
    });

    test('3.2.1.2 - Detect removed tables', () {
      // Arrange: Current schema has a table
      final currentSchema = DatabaseSchema({
        'old_table': TableSchema(
          name: 'old_table',
          fields: {
            'id': FieldSchema(name: 'id', type: 'string'),
          },
          indexes: {},
        ),
      });

      // Desired schema is empty (table removed)
      final desiredTables = <TableStructure>[];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Removed table should be detected as destructive
      expect(diff.tablesRemoved, contains('old_table'));
      expect(diff.tablesAdded, isEmpty);
      expect(diff.hasDestructiveChanges, isTrue);
    });

    test('3.2.1.3 - Detect new fields', () {
      // Arrange: Current schema has table with one field
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'name': FieldSchema(name: 'name', type: 'string'),
          },
          indexes: {},
        ),
      });

      // Desired schema adds a new field
      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'email': FieldDefinition(StringType()),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: New field should be detected
      expect(diff.fieldsAdded['users'], contains('email'));
      expect(diff.fieldsAdded['users'], hasLength(1));
      expect(diff.hasDestructiveChanges, isFalse);
    });

    test('3.2.1.4 - Detect removed fields', () {
      // Arrange: Current schema has two fields
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'name': FieldSchema(name: 'name', type: 'string'),
            'age': FieldSchema(name: 'age', type: 'int'),
          },
          indexes: {},
        ),
      });

      // Desired schema removes 'age' field
      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Removed field should be detected as destructive
      expect(diff.fieldsRemoved['users'], contains('age'));
      expect(diff.hasDestructiveChanges, isTrue);
    });

    test('3.2.1.5 - Detect modified field types', () {
      // Arrange: Current schema has string field
      final currentSchema = DatabaseSchema({
        'products': TableSchema(
          name: 'products',
          fields: {
            'price': FieldSchema(name: 'price', type: 'string'),
          },
          indexes: {},
        ),
      });

      // Desired schema changes field type to float
      final desiredTables = [
        TableStructure('products', {
          'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Type change should be detected as destructive
      expect(diff.fieldsModified['products'], isNotNull);
      expect(diff.fieldsModified['products'], isNotEmpty);
      final modification = diff.fieldsModified['products']!.first;
      expect(modification.fieldName, equals('price'));
      expect(modification.oldType, equals('string'));
      expect(modification.newType, equals('float'));
      expect(diff.hasDestructiveChanges, isTrue);
    });

    test('3.2.1.6 - Detect constraint changes', () {
      // Arrange: Current schema has field without assertion
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'age': FieldSchema(name: 'age', type: 'int'),
          },
          indexes: {},
        ),
      });

      // Desired schema adds ASSERT clause
      final desiredTables = [
        TableStructure('users', {
          'age': FieldDefinition(
            NumberType(format: NumberFormat.integer),
            assertClause: r'$value >= 0',
          ),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Constraint addition is safe (non-destructive)
      expect(diff.fieldsModified['users'], isNotNull);
      final modification = diff.fieldsModified['users']!.first;
      expect(modification.fieldName, equals('age'));
      expect(modification.assertClauseChanged, isTrue);
      expect(diff.hasDestructiveChanges, isFalse);
    });

    test('3.2.1.7 - Detect identical schema (no changes)', () {
      // Arrange: Current and desired schemas are identical
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'name': FieldSchema(name: 'name', type: 'string'),
            'age': FieldSchema(name: 'age', type: 'int'),
          },
          indexes: {},
        ),
      });

      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: No changes should be detected
      expect(diff.tablesAdded, isEmpty);
      expect(diff.tablesRemoved, isEmpty);
      expect(diff.fieldsAdded, isEmpty);
      expect(diff.fieldsRemoved, isEmpty);
      expect(diff.fieldsModified, isEmpty);
      expect(diff.hasDestructiveChanges, isFalse);
      expect(diff.hasChanges, isFalse);
    });

    test('3.2.1.8 - Detect index changes', () {
      // Arrange: Current schema has no indexes
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'email': FieldSchema(name: 'email', type: 'string'),
          },
          indexes: {},
        ),
      });

      // Desired schema adds index
      final desiredTables = [
        TableStructure('users', {
          'email': FieldDefinition(StringType(), indexed: true),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Index addition is safe
      expect(diff.indexesAdded['users'], isNotEmpty);
      expect(diff.hasDestructiveChanges, isFalse);
    });

    test('3.2.2 - Generate deterministic migration hash', () {
      // Arrange: Same schema changes
      final currentSchema = DatabaseSchema({});
      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      // Act: Calculate diff multiple times
      final diff1 = SchemaDiff.calculate(currentSchema, desiredTables);
      final diff2 = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Same changes produce same hash
      expect(diff1.migrationHash, isNotEmpty);
      expect(diff1.migrationHash, equals(diff2.migrationHash));
    });

    test('3.2.3 - Different changes produce different hashes', () {
      // Arrange: Different schema changes
      final currentSchema = DatabaseSchema({});

      final desiredTables1 = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      final desiredTables2 = [
        TableStructure('products', {
          'title': FieldDefinition(StringType()),
        }),
      ];

      // Act: Calculate diffs
      final diff1 = SchemaDiff.calculate(currentSchema, desiredTables1);
      final diff2 = SchemaDiff.calculate(currentSchema, desiredTables2);

      // Assert: Different changes produce different hashes
      expect(diff1.migrationHash, isNot(equals(diff2.migrationHash)));
    });

    test('3.2.4 - Classify optional field addition as safe', () {
      // Arrange: Add optional field
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'name': FieldSchema(name: 'name', type: 'string'),
          },
          indexes: {},
        ),
      });

      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'bio': FieldDefinition(StringType(), optional: true),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Optional field addition is safe
      expect(diff.fieldsAdded['users'], contains('bio'));
      expect(diff.hasDestructiveChanges, isFalse);
    });

    test('3.2.5 - Classify field optionality change', () {
      // Arrange: Field becomes required (was optional)
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'email': FieldSchema(
                name: 'email', type: 'option<string>', optional: true),
          },
          indexes: {},
        ),
      });

      final desiredTables = [
        TableStructure('users', {
          'email': FieldDefinition(StringType(), optional: false),
        }),
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: Making field required is destructive
      expect(diff.fieldsModified['users'], isNotNull);
      final modification = diff.fieldsModified['users']!.first;
      expect(modification.fieldName, equals('email'));
      expect(modification.optionalityChanged, isTrue);
      expect(diff.hasDestructiveChanges, isTrue);
    });

    test('3.2.6 - Handle complex nested changes', () {
      // Arrange: Multiple changes across tables
      final currentSchema = DatabaseSchema({
        'users': TableSchema(
          name: 'users',
          fields: {
            'name': FieldSchema(name: 'name', type: 'string'),
          },
          indexes: {},
        ),
        'old_posts': TableSchema(
          name: 'old_posts',
          fields: {
            'title': FieldSchema(name: 'title', type: 'string'),
          },
          indexes: {},
        ),
      });

      final desiredTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'email': FieldDefinition(StringType()), // Added field
        }),
        TableStructure('products', {
          'title': FieldDefinition(StringType()), // New table
        }),
        // old_posts removed
      ];

      // Act: Calculate diff
      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Assert: All changes detected correctly
      expect(diff.tablesAdded, contains('products'));
      expect(diff.tablesRemoved, contains('old_posts'));
      expect(diff.fieldsAdded['users'], contains('email'));
      expect(diff.hasDestructiveChanges, isTrue); // Due to table removal
    });
  });
}
