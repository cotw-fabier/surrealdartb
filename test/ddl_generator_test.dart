/// Tests for DDL generation from schema diffs (Task Group 4.1).
///
/// This test file covers DDL generation for DEFINE TABLE, DEFINE FIELD,
/// DEFINE INDEX, REMOVE TABLE, REMOVE FIELD, and REMOVE INDEX statements.
/// Tests ensure generated SurrealQL is syntactically correct and handles
/// all schema elements including vectors, ASSERT clauses, and DEFAULT values.
library;

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Task Group 4.1: DDL Generator Tests', () {
    test('4.1.1.1 - Generate DEFINE TABLE statement', () {
      // Arrange: Create a simple table structure
      final table = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      // Act: Generate DDL for new table
      final generator = DdlGenerator();
      final ddl = generator.generateDefineTable(table);

      // Assert: Should generate DEFINE TABLE with SCHEMAFULL
      expect(ddl, contains('DEFINE TABLE users SCHEMAFULL'));
    });

    test('4.1.1.2 - Generate DEFINE FIELD statements', () {
      // Arrange: Create a table with various field types
      final table = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),
        'active': FieldDefinition(BoolType()),
        'created': FieldDefinition(DatetimeType()),
      });

      // Act: Generate DDL for fields
      final generator = DdlGenerator();
      final ddl = generator.generateDefineFields(table.tableName, table.fields);

      // Assert: Should generate DEFINE FIELD statements for each field
      expect(ddl.join('\n'), contains('DEFINE FIELD name ON products TYPE string'));
      expect(ddl.join('\n'), contains('DEFINE FIELD price ON products TYPE decimal'));
      expect(ddl.join('\n'), contains('DEFINE FIELD active ON products TYPE bool'));
      expect(ddl.join('\n'), contains('DEFINE FIELD created ON products TYPE datetime'));
    });

    test('4.1.1.3 - Generate DEFINE INDEX statements', () {
      // Arrange: Create a table with indexed fields
      final table = TableStructure('users', {
        'email': FieldDefinition(StringType(), indexed: true),
        'username': FieldDefinition(StringType(), indexed: true),
        'bio': FieldDefinition(StringType(), optional: true),
      });

      // Act: Generate DDL for indexes
      final generator = DdlGenerator();
      final ddl = generator.generateDefineIndexes(table.tableName, table.fields);

      // Assert: Should generate DEFINE INDEX statements for indexed fields
      expect(ddl.join('\n'), contains('DEFINE INDEX idx_users_email ON users FIELDS email'));
      expect(ddl.join('\n'), contains('DEFINE INDEX idx_users_username ON users FIELDS username'));
      expect(ddl.join('\n'), isNot(contains('bio'))); // Non-indexed field should not have index
    });

    test('4.1.1.4 - Generate REMOVE TABLE statement', () {
      // Arrange: Table name to remove
      const tableName = 'old_users';

      // Act: Generate DDL to remove table
      final generator = DdlGenerator();
      final ddl = generator.generateRemoveTable(tableName);

      // Assert: Should generate REMOVE TABLE statement
      expect(ddl, equals('REMOVE TABLE old_users'));
    });

    test('4.1.1.5 - Generate REMOVE FIELD statement', () {
      // Arrange: Table and field names
      const tableName = 'users';
      const fieldName = 'deprecated_field';

      // Act: Generate DDL to remove field
      final generator = DdlGenerator();
      final ddl = generator.generateRemoveField(tableName, fieldName);

      // Assert: Should generate REMOVE FIELD statement
      expect(ddl, equals('REMOVE FIELD deprecated_field ON users'));
    });

    test('4.1.1.6 - Generate DDL for complex schema with all elements', () {
      // Arrange: Create diff with multiple change types
      final currentSchema = DatabaseSchema({});

      final desiredTables = [
        TableStructure('products', {
          'name': FieldDefinition(StringType()),
          'description': FieldDefinition(StringType(), optional: true),
          'price': FieldDefinition(
            NumberType(format: NumberFormat.decimal),
            assertClause: r'$value > 0',
          ),
          'stock': FieldDefinition(
            NumberType(format: NumberFormat.integer),
            defaultValue: 0,
          ),
          'sku': FieldDefinition(StringType(), indexed: true),
        }),
      ];

      final diff = SchemaDiff.calculate(currentSchema, desiredTables);

      // Act: Generate complete DDL from diff
      final generator = DdlGenerator();
      final statements = generator.generateFromDiff(diff, desiredTables);
      final ddl = statements.join('\n');

      // Assert: Should generate all DDL elements
      expect(ddl, contains('DEFINE TABLE products SCHEMAFULL'));
      expect(ddl, contains('DEFINE FIELD name ON products TYPE string'));
      expect(ddl, contains('DEFINE FIELD price ON products TYPE decimal ASSERT \$value > 0'));
      expect(ddl, contains('DEFINE FIELD stock ON products TYPE int DEFAULT 0'));
      expect(ddl, contains('DEFINE INDEX idx_products_sku ON products FIELDS sku'));
    });

    test('4.1.4.1 - Generate DDL for vector field', () {
      // Arrange: Create table with vector field
      final table = TableStructure('documents', {
        'title': FieldDefinition(StringType()),
        'embedding': FieldDefinition(
          VectorType.f32(1536, normalized: true),
        ),
      });

      // Act: Generate DDL for vector field
      final generator = DdlGenerator();
      final ddl = generator.generateDefineFields(table.tableName, table.fields);

      // Assert: Should generate vector type with dimensions
      expect(ddl.join('\n'), contains('DEFINE FIELD embedding ON documents TYPE vector<F32, 1536>'));
    });

    test('4.1.5.1 - Generate DDL with ASSERT clause', () {
      // Arrange: Create field with ASSERT clause
      final table = TableStructure('users', {
        'age': FieldDefinition(
          NumberType(format: NumberFormat.integer),
          assertClause: r'$value >= 0 AND $value <= 150',
        ),
        'email': FieldDefinition(
          StringType(),
          assertClause: r'string::is::email($value)',
        ),
      });

      // Act: Generate DDL
      final generator = DdlGenerator();
      final ddl = generator.generateDefineFields(table.tableName, table.fields);

      // Assert: Should include ASSERT clauses
      final combined = ddl.join('\n');
      expect(combined, contains(r'ASSERT $value >= 0 AND $value <= 150'));
      expect(combined, contains(r'ASSERT string::is::email($value)'));
    });

    test('4.1.5.2 - Generate DDL with DEFAULT values', () {
      // Arrange: Create fields with various default values
      final table = TableStructure('settings', {
        'notifications_enabled': FieldDefinition(
          BoolType(),
          defaultValue: true,
        ),
        'max_retries': FieldDefinition(
          NumberType(format: NumberFormat.integer),
          defaultValue: 3,
        ),
        'theme': FieldDefinition(
          StringType(),
          defaultValue: 'light',
        ),
      });

      // Act: Generate DDL
      final generator = DdlGenerator();
      final ddl = generator.generateDefineFields(table.tableName, table.fields);

      // Assert: Should include DEFAULT clauses with proper formatting
      final combined = ddl.join('\n');
      expect(combined, contains('DEFAULT true'));
      expect(combined, contains('DEFAULT 3'));
      expect(combined, contains("DEFAULT 'light'"));
    });
  });
}
