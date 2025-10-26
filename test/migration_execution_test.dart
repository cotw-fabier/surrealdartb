/// Tests for migration execution engine with transaction support.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Migration Execution Tests', () {
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

    test('successful migration with transaction commit', () async {
      // Define initial table structure
      final userTable = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      // Create migration engine
      final engine = MigrationEngine();

      // Execute migration
      final report = await engine.executeMigration(
        db,
        [userTable],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Verify migration succeeded
      expect(report.success, isTrue);
      expect(report.tablesAdded, contains('users'));
      expect(report.fieldsAdded['users'], containsAll(['name', 'age']));

      // Verify table was actually created
      final response = await db.queryQL('INFO FOR TABLE users');
      final results = response.getResults();
      expect(results, isNotEmpty);

      final tableInfo = results.first as Map<String, dynamic>;
      expect(tableInfo['fields'], isNotNull);
      expect(tableInfo['fields'], contains('name'));
      expect(tableInfo['fields'], contains('age'));
    });

    test('failed migration with automatic rollback', () async {
      // Define table with invalid syntax in ASSERT (to force failure)
      final invalidTable = TableStructure('products', {
        'name': FieldDefinition(StringType()),
      });

      final engine = MigrationEngine();

      // Manually inject a bad DDL statement to force failure
      // We'll do this by creating a table, then trying to create it again
      await db.queryQL('DEFINE TABLE products SCHEMAFULL');

      // Now try to migrate with the same table (will fail on duplicate)
      try {
        await engine.executeMigration(
          db,
          [invalidTable],
          allowDestructiveMigrations: false,
          dryRun: false,
        );
        fail('Expected MigrationException to be thrown');
      } catch (e) {
        expect(e, isA<MigrationException>());
        final migEx = e as MigrationException;
        expect(migEx.message, contains('migration'));
      }

      // Verify rollback - check migration history
      final historyResponse = await db.queryQL(
        'SELECT * FROM _migrations WHERE status = "failed"',
      );
      final historyResults = historyResponse.getResults();

      // Should have a failed migration recorded
      expect(historyResults, isNotEmpty);
    });

    test('dry run mode executes migration in transaction then cancels',
        () async {
      final testTable = TableStructure('test_table', {
        'field1': FieldDefinition(StringType()),
        'field2': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final engine = MigrationEngine();

      // Execute in dry run mode
      final report = await engine.executeMigration(
        db,
        [testTable],
        allowDestructiveMigrations: false,
        dryRun: true,
      );

      // Verify report shows what would happen
      expect(report.dryRun, isTrue);
      expect(report.tablesAdded, contains('test_table'));
      expect(report.generatedDDL, isNotEmpty);

      // Verify table was NOT actually created (transaction was cancelled)
      try {
        await db.queryQL('INFO FOR TABLE test_table');
        fail('Table should not exist after dry run');
      } catch (e) {
        // Expected - table should not exist
        expect(e, isA<QueryException>());
      }
    });

    test('migration history recording for successful migration', () async {
      final historyTable = TableStructure('history_test', {
        'data': FieldDefinition(StringType()),
      });

      final engine = MigrationEngine();

      // Execute migration
      final report = await engine.executeMigration(
        db,
        [historyTable],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Verify migration history was recorded
      await db.set('id', report.migrationId);

      final historyResponse = await db.queryQL(
        'SELECT * FROM _migrations WHERE migration_id = \$id',
      );

      final historyResults = historyResponse.getResults();
      expect(historyResults, isNotEmpty);

      // getResults() already unwraps nested structures
      final historyRecord = historyResults.first as Map<String, dynamic>;
      expect(historyRecord['status'], equals('success'));
      expect(historyRecord['migration_id'], equals(report.migrationId));
      expect(historyRecord['schema_snapshot'], isNotNull);
      expect(historyRecord['changes_applied'], isNotNull);
    });

    test('destructive operation blocking', () async {
      // First, create a table
      final originalTable = TableStructure('block_test', {
        'field1': FieldDefinition(StringType()),
        'field2': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final engine = MigrationEngine();

      await engine.executeMigration(
        db,
        [originalTable],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Now try to remove a field (destructive operation)
      final modifiedTable = TableStructure('block_test', {
        'field1': FieldDefinition(StringType()),
        // field2 removed - this is destructive
      });

      // Should throw exception when destructive changes detected
      expect(
        () => engine.executeMigration(
          db,
          [modifiedTable],
          allowDestructiveMigrations: false,
          dryRun: false,
        ),
        throwsA(isA<MigrationException>().having(
          (e) => e.isDestructive,
          'isDestructive',
          isTrue,
        )),
      );
    });

    test('destructive operation allowed with flag', () async {
      // Create initial table
      final initialTable = TableStructure('allow_test', {
        'field1': FieldDefinition(StringType()),
        'field2': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final engine = MigrationEngine();

      await engine.executeMigration(
        db,
        [initialTable],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Remove a field with flag enabled
      final modifiedTable = TableStructure('allow_test', {
        'field1': FieldDefinition(StringType()),
        // field2 removed
      });

      // Should succeed when flag is set
      final report = await engine.executeMigration(
        db,
        [modifiedTable],
        allowDestructiveMigrations: true,
        dryRun: false,
      );

      expect(report.success, isTrue);
      expect(report.hasDestructiveChanges, isTrue);
      expect(report.fieldsRemoved['allow_test'], contains('field2'));
    });

    test('migration with indexes', () async {
      final indexedTable = TableStructure('indexed_table', {
        'email': FieldDefinition(StringType(), indexed: true),
        'name': FieldDefinition(StringType()),
      });

      final engine = MigrationEngine();

      final report = await engine.executeMigration(
        db,
        [indexedTable],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      expect(report.success, isTrue);
      expect(report.indexesAdded['indexed_table'], contains('email'));

      // Verify index was created
      final response = await db.queryQL('INFO FOR TABLE indexed_table');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;

      expect(tableInfo['indexes'], isNotNull);
      expect(tableInfo['indexes'], isNotEmpty);
    });

    test('no-op migration when schemas match', () async {
      final table1 = TableStructure('noop_table', {
        'field1': FieldDefinition(StringType()),
      });

      final engine = MigrationEngine();

      // First migration
      await engine.executeMigration(
        db,
        [table1],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Second migration with same schema
      final report = await engine.executeMigration(
        db,
        [table1],
        allowDestructiveMigrations: false,
        dryRun: false,
      );

      // Should report no changes
      expect(report.hasChanges, isFalse);
      expect(report.generatedDDL, isEmpty);
    });
  });
}
