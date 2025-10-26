/// Tests for destructive operation protection and migration safety features.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Migration Safety Tests', () {
    late Database db;
    late MigrationEngine engine;

    setUp(() async {
      // Create in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
      engine = MigrationEngine();
    });

    tearDown(() async {
      await db.close();
    });

    test('safe mode blocks destructive table removal', () async {
      // Create initial table with data
      final originalTable = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
      });

      await engine.executeMigration(db, [originalTable]);

      // Insert some test data
      await db.query(
        "CREATE products SET name = 'Test Product', price = 19.99",
      );

      // Try to remove table (destructive)
      try {
        await engine.executeMigration(
          db,
          [], // Empty list = remove all tables
          allowDestructiveMigrations: false,
        );
        fail('Should throw MigrationException for destructive change');
      } on MigrationException catch (e) {
        expect(e.isDestructive, isTrue);
        expect(e.message, contains('Destructive schema changes detected'));
        expect(e.message, contains('allowDestructiveMigrations=false'));

        // Verify report contains destructive changes
        expect(e.report, isNotNull);
        expect(e.report!.tablesRemoved, contains('products'));

        // Verify error message provides resolution options (case-insensitive)
        final errorMsg = e.toString().toLowerCase();
        expect(errorMsg, contains('allowdestructivemigrations: true'));
        expect(errorMsg, contains('fix'));
        expect(errorMsg, contains('schema'));
        expect(errorMsg, contains('manually migrate data'));
      }
    });

    test('safe mode blocks destructive field removal', () async {
      // Create table with multiple fields
      final initialTable = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      await engine.executeMigration(db, [initialTable]);

      // Remove a field (destructive)
      final modifiedTable = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType()),
        // age field removed
      });

      try {
        await engine.executeMigration(
          db,
          [modifiedTable],
          allowDestructiveMigrations: false,
        );
        fail('Should throw MigrationException for field removal');
      } on MigrationException catch (e) {
        expect(e.isDestructive, isTrue);
        expect(e.report!.fieldsRemoved['users'], contains('age'));

        // Verify error message lists specific field removal
        expect(e.toString(), contains('users.age'));
      }
    });

    test('safe mode blocks destructive type changes', () async {
      // Create table with string field
      final initialTable = TableStructure('products', {
        'price': FieldDefinition(StringType()), // String price
      });

      await engine.executeMigration(db, [initialTable]);

      // Change type to number (destructive)
      final modifiedTable = TableStructure('products', {
        'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
      });

      try {
        await engine.executeMigration(
          db,
          [modifiedTable],
          allowDestructiveMigrations: false,
        );
        fail('Should throw MigrationException for type change');
      } on MigrationException catch (e) {
        expect(e.isDestructive, isTrue);

        // Type change should be detected as field modification
        final report = e.report!;
        expect(report.hasDestructiveChanges, isTrue);
      }
    });

    test('allow mode permits all destructive changes', () async {
      // Create initial schema
      final initialTable = TableStructure('orders', {
        'product_id': FieldDefinition(StringType()),
        'quantity': FieldDefinition(NumberType(format: NumberFormat.integer)),
        'status': FieldDefinition(StringType()),
      });

      await engine.executeMigration(db, [initialTable]);

      // Make multiple destructive changes
      final modifiedTable = TableStructure('orders', {
        'product_id': FieldDefinition(StringType()),
        // quantity removed (destructive)
        // status removed (destructive)
        'total_price':
            FieldDefinition(NumberType(format: NumberFormat.floating)),
      });

      // Should succeed with flag enabled
      final report = await engine.executeMigration(
        db,
        [modifiedTable],
        allowDestructiveMigrations: true,
      );

      expect(report.success, isTrue);
      expect(report.hasDestructiveChanges, isTrue);
      expect(report.fieldsRemoved['orders'], containsAll(['quantity', 'status']));
    });

    test('error message includes all destructive operations', () async {
      // Create multiple tables
      final table1 = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType()),
      });

      final table2 = TableStructure('posts', {
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'author_id': FieldDefinition(StringType()),
      });

      await engine.executeMigration(db, [table1, table2]);

      // Make destructive changes to both tables
      final modifiedTable1 = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        // email removed
      });

      final modifiedTable2 = TableStructure('posts', {
        'title': FieldDefinition(StringType()),
        // content and author_id removed
      });

      try {
        await engine.executeMigration(
          db,
          [modifiedTable1, modifiedTable2],
          allowDestructiveMigrations: false,
        );
        fail('Should throw MigrationException');
      } on MigrationException catch (e) {
        final errorMsg = e.toString();

        // Should list all removed fields
        expect(errorMsg, contains('users.email'));
        expect(errorMsg, contains('posts.content'));
        expect(errorMsg, contains('posts.author_id'));
      }
    });

    test('mixed safe and destructive changes handled correctly', () async {
      // Create initial table
      final initialTable = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
      });

      await engine.executeMigration(db, [initialTable]);

      // Add safe change (new field) AND destructive change (remove field)
      final modifiedTable = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'description': FieldDefinition(StringType()), // New field (safe)
        // price removed (destructive)
      });

      try {
        await engine.executeMigration(
          db,
          [modifiedTable],
          allowDestructiveMigrations: false,
        );
        fail('Should throw MigrationException for destructive part');
      } on MigrationException catch (e) {
        expect(e.isDestructive, isTrue);

        // Report should show both safe and destructive changes
        final report = e.report!;
        expect(report.fieldsRemoved['products'], contains('price'));
      }
    });

    test('safe changes do not trigger destructive protection', () async {
      // Create initial table
      final initialTable = TableStructure('articles', {
        'title': FieldDefinition(StringType()),
      });

      await engine.executeMigration(db, [initialTable]);

      // Make only safe changes
      final safeTable = TableStructure('articles', {
        'title': FieldDefinition(StringType()),
        'summary': FieldDefinition(StringType()), // New field (safe)
        'tags': FieldDefinition(ArrayType(StringType())), // New field (safe)
      });

      // Should succeed without destructive flag
      final report = await engine.executeMigration(
        db,
        [safeTable],
        allowDestructiveMigrations: false,
      );

      expect(report.success, isTrue);
      expect(report.hasDestructiveChanges, isFalse);
    });
  });
}
