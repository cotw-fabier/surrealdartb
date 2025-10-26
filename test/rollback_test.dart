/// Tests for manual rollback support.
library;

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Manual Rollback Support', () {
    late Database db;

    setUp(() async {
      // Create in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test_rollback',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('rollback to previous schema snapshot', () async {
      // Initial schema with users table
      final initialTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'email': FieldDefinition(StringType(), indexed: true),
        }),
      ];

      // Apply initial migration
      final migrationEngine = MigrationEngine();
      final report1 = await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );
      expect(report1.success, true);

      // Modified schema - add age field
      final modifiedTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
          'email': FieldDefinition(StringType(), indexed: true),
          'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      // Apply second migration
      final report2 = await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );
      expect(report2.success, true);

      // Verify age field exists
      final schemaBeforeRollback = await DatabaseSchema.introspect(db);
      final usersTableBefore = schemaBeforeRollback.getTable('users');
      expect(usersTableBefore, isNotNull);
      expect(usersTableBefore!.hasField('age'), true);

      // Rollback to previous migration
      final rollbackReport = await db.rollbackMigration();
      expect(rollbackReport.success, true);

      // Verify age field is removed after rollback
      final schemaAfterRollback = await DatabaseSchema.introspect(db);
      final usersTableAfter = schemaAfterRollback.getTable('users');
      expect(usersTableAfter, isNotNull);
      expect(usersTableAfter!.hasField('age'), false);
      expect(usersTableAfter.hasField('name'), true);
      expect(usersTableAfter.hasField('email'), true);
    });

    test('rollback generates correct reverse DDL', () async {
      // Initial schema
      final initialTables = [
        TableStructure('products', {
          'name': FieldDefinition(StringType()),
          'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
        }),
      ];

      // Apply initial migration
      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Add description field
      final modifiedTables = [
        TableStructure('products', {
          'name': FieldDefinition(StringType()),
          'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
          'description': FieldDefinition(StringType(), optional: true),
        }),
      ];

      await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Rollback and check DDL
      final rollbackReport = await db.rollbackMigration();
      expect(rollbackReport.success, true);
      expect(rollbackReport.generatedDDL, isNotEmpty);

      // DDL should contain REMOVE FIELD for description
      final ddlContainsRemoveField = rollbackReport.generatedDDL
          .any((stmt) => stmt.contains('REMOVE FIELD description'));
      expect(ddlContainsRemoveField, true);
    });

    test('rollback records history entry', () async {
      // Create initial schema
      final initialTables = [
        TableStructure('items', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Modify schema
      final modifiedTables = [
        TableStructure('items', {
          'name': FieldDefinition(StringType()),
          'quantity': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Rollback
      await db.rollbackMigration();

      // Check that rollback is recorded in migration history
      final history = MigrationHistory();
      final migrations = await history.getAllMigrations(db, limit: 10);

      // Should have 3 entries: initial, modification, and rollback
      expect(migrations.length, greaterThanOrEqualTo(3));

      // Last migration should be the rollback
      final lastMigration = migrations.first;
      expect(lastMigration.status, 'success');

      // Rollback should be indicated in changes or migration_id
      final hasRollbackIndicator = lastMigration.migrationId.contains('rollback') ||
          lastMigration.changesApplied.any((change) => change.toLowerCase().contains('rollback'));
      expect(hasRollbackIndicator, true);
    });

    test('rollback when no previous snapshot exists throws error', () async {
      // Try to rollback without any migrations
      expect(
        () => db.rollbackMigration(),
        throwsA(isA<MigrationException>()),
      );
    });

    test('rollback with only one migration throws error', () async {
      // Apply single migration
      final tables = [
        TableStructure('test_table', {
          'field1': FieldDefinition(StringType()),
        }),
      ];

      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        tables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Try to rollback - should fail as there's no previous state
      expect(
        () => db.rollbackMigration(),
        throwsA(isA<MigrationException>()),
      );
    });

    test('rollback handles table removal correctly', () async {
      // Initial schema with two tables
      final initialTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
        }),
        TableStructure('posts', {
          'title': FieldDefinition(StringType()),
        }),
      ];

      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Remove posts table
      final modifiedTables = [
        TableStructure('users', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: true, // Required for destructive change
        dryRun: false,
      );

      // Verify posts table is gone
      final schemaBeforeRollback = await DatabaseSchema.introspect(db);
      expect(schemaBeforeRollback.hasTable('posts'), false);

      // Rollback - should recreate posts table
      final rollbackReport = await db.rollbackMigration(
        allowDestructiveMigrations: true,
      );
      expect(rollbackReport.success, true);

      // Verify posts table is back
      final schemaAfterRollback = await DatabaseSchema.introspect(db);
      expect(schemaAfterRollback.hasTable('posts'), true);
      final postsTable = schemaAfterRollback.getTable('posts');
      expect(postsTable!.hasField('title'), true);
    });

    test('rollback with type changes requires destructive flag', () async {
      // Initial schema
      final initialTables = [
        TableStructure('data', {
          'value': FieldDefinition(StringType()),
        }),
      ];

      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Change type (destructive)
      final modifiedTables = [
        TableStructure('data', {
          'value': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: true,
        dryRun: false,
      );

      // Rollback without flag should fail (changing back is also destructive)
      expect(
        () => db.rollbackMigration(allowDestructiveMigrations: false),
        throwsA(isA<MigrationException>()),
      );

      // Rollback with flag should succeed
      final rollbackReport = await db.rollbackMigration(
        allowDestructiveMigrations: true,
      );
      expect(rollbackReport.success, true);
    });

    test('dry run rollback previews changes without applying', () async {
      // Initial schema
      final initialTables = [
        TableStructure('orders', {
          'status': FieldDefinition(StringType()),
        }),
      ];

      final migrationEngine = MigrationEngine();
      await migrationEngine.executeMigration(
        db,
        initialTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Add field
      final modifiedTables = [
        TableStructure('orders', {
          'status': FieldDefinition(StringType()),
          'customer_id': FieldDefinition(StringType()),
        }),
      ];

      await migrationEngine.executeMigration(
        db,
        modifiedTables,
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Dry run rollback
      final dryRunReport = await db.rollbackMigration(dryRun: true);
      expect(dryRunReport.success, true);
      expect(dryRunReport.dryRun, true);

      // Verify customer_id still exists (rollback wasn't applied)
      final schemaAfterDryRun = await DatabaseSchema.introspect(db);
      final ordersTable = schemaAfterDryRun.getTable('orders');
      expect(ordersTable!.hasField('customer_id'), true);

      // Now do actual rollback
      await db.rollbackMigration(dryRun: false);

      // Verify customer_id is removed
      final schemaAfterRollback = await DatabaseSchema.introspect(db);
      final ordersTableAfter = schemaAfterRollback.getTable('orders');
      expect(ordersTableAfter!.hasField('customer_id'), false);
    });
  });
}
