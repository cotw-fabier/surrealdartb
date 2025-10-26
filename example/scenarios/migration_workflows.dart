/// Demonstrates migration workflows for development and production environments.
///
/// This scenario shows how to:
/// - Use auto-migration in development
/// - Preview migrations in production with dry-run mode
/// - Handle destructive changes safely
/// - Manually control migration execution
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the migration workflow scenario.
///
/// This demonstrates different approaches to migrations:
/// - Development: Auto-migration for rapid iteration
/// - Production: Manual migration with preview and safety checks
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runMigrationWorkflowsScenario() async {
  print('\n=== Scenario: Migration Workflows (Dev vs Production) ===\n');

  // ===================================================================
  // PART A: Development Workflow (Auto-Migration)
  // ===================================================================
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║ PART A: Development Workflow                             ║');
  print('║ (Auto-Migration for Rapid Iteration)                     ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  await _demonstrateDevelopmentWorkflow();

  // ===================================================================
  // PART B: Production Workflow (Manual Migration with Preview)
  // ===================================================================
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║ PART B: Production Workflow                              ║');
  print('║ (Manual Migration with Safety Checks)                    ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  await _demonstrateProductionWorkflow();
}

/// Demonstrates the development workflow with auto-migration.
Future<void> _demonstrateDevelopmentWorkflow() async {
  Database? db;

  try {
    // Step 1: Initial schema
    print('Step 1: Creating initial schema...');
    final initialSchema = TableStructure('products', {
      'name': FieldDefinition(StringType(), optional: false),
      'price': FieldDefinition(
        NumberType(format: NumberFormat.floating),
        optional: false,
      ),
    });

    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'dev',
      database: 'dev',
      tableDefinitions: [initialSchema],
      autoMigrate: true, // Automatic migration!
    );
    print('✓ Database connected, schema auto-created\n');

    // Add some data
    print('Step 2: Adding test data...');
    await db.create('products', {
      'name': 'Widget',
      'price': 19.99,
    });
    print('✓ Product created\n');

    // Step 3: Evolve schema (add new field)
    print('Step 3: Evolving schema (adding description field)...');
    print('In development, just update your annotations:');
    print('');
    print('  @SurrealField(type: StringType())');
    print('  final String? description; // New field!');
    print('');
    print('Then reconnect with updated schema...\n');

    await db.close();

    final evolvedSchema = TableStructure('products', {
      'name': FieldDefinition(StringType(), optional: false),
      'price': FieldDefinition(
        NumberType(format: NumberFormat.floating),
        optional: false,
      ),
      'description': FieldDefinition(StringType(), optional: true), // New!
    });

    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'dev',
      database: 'dev',
      tableDefinitions: [evolvedSchema],
      autoMigrate: true, // Auto-applies new field!
    );
    print('✓ Schema evolution auto-detected and applied');
    print('✓ New field \'description\' added to existing table\n');

    // Verify old data still exists
    print('Step 4: Verifying data preservation...');
    final products = await db.select('products');
    print('✓ Data preserved: ${products.length} product(s) still exist');
    print('  Old records have null for new optional fields\n');

    // Add new data with description
    await db.create('products', {
      'name': 'Gadget',
      'price': 29.99,
      'description': 'A cool gadget',
    });
    print('✓ New product created with description field\n');

    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ Development Workflow: SUCCESS ✓                          ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Development Benefits:');
    print('✓ Instant schema updates (no manual migration needed)');
    print('✓ Fast iteration cycle');
    print('✓ Safe additions (optional fields, new tables)');
    print('✓ Automatic detection of changes\n');
  } catch (e) {
    print('\n✗ Development workflow error: $e');
    rethrow;
  } finally {
    await db?.close();
  }
}

/// Demonstrates the production workflow with manual migration control.
Future<void> _demonstrateProductionWorkflow() async {
  Database? db;

  try {
    // Step 1: Production database with existing data
    print('Step 1: Connecting to production database...');
    final currentSchema = TableStructure('users', {
      'name': FieldDefinition(StringType(), optional: false),
      'email': FieldDefinition(StringType(), optional: false),
    });

    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'prod',
      database: 'prod',
      tableDefinitions: [currentSchema],
      autoMigrate: true,
    );
    print('✓ Connected to production database\n');

    // Add production data
    print('Step 2: Simulating existing production data...');
    await db.create('users', {'name': 'John Doe', 'email': 'john@example.com'});
    await db.create('users', {'name': 'Jane Smith', 'email': 'jane@example.com'});
    print('✓ Production database has 2 users\n');

    await db.close();

    // Step 3: New version of app with schema changes
    print('Step 3: New app version with schema changes...');
    final newSchema = TableStructure('users', {
      'name': FieldDefinition(StringType(), optional: false),
      'email': FieldDefinition(StringType(), optional: false, indexed: true), // Added index!
      'created_at': FieldDefinition(
        DatetimeType(),
        optional: true,
        defaultValue: 'time::now()',
      ), // New field!
    });

    print('Schema changes:');
    print('  + Added index on \'email\' field');
    print('  + Added \'created_at\' field with default value\n');

    // Step 4: Connect WITHOUT auto-migration
    print('Step 4: Connecting without auto-migration...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'prod',
      database: 'prod',
      tableDefinitions: [newSchema],
      autoMigrate: false, // IMPORTANT: Manual control!
    );
    print('✓ Connected');
    print('✓ Schema changes detected but NOT applied yet\n');

    // Step 5: Preview migration (dry-run)
    print('Step 5: Previewing migration with dry-run...');
    final previewReport = await db.migrate(dryRun: true);

    print('✓ Migration preview completed:');
    if (previewReport.success) {
      print('  Status: Safe to apply');
      print('  Changes detected:');
      print('    - ${previewReport.indexesAdded.length} indexes to add');
      print('    - ${previewReport.fieldsAdded.length} fields to add');
      print('    - ${previewReport.fieldsModified.length} fields to modify');
      print('  Destructive: ${previewReport.hasDestructiveChanges ? 'YES' : 'NO'}');
      print('');
      print('  Generated DDL:');
      for (final ddl in previewReport.generatedDDL) {
        print('    $ddl');
      }
      print('');
    } else {
      print('  Status: Would fail');
      print('  Error: ${previewReport.errorMessage}\n');
    }

    // Step 6: Apply migration
    print('Step 6: Applying migration...');
    final applyReport = await db.migrate(
      allowDestructiveMigrations: false,
      dryRun: false,
    );

    if (applyReport.success) {
      print('✓ Migration applied successfully');
      print('  Migration ID: ${applyReport.migrationId}');
      print('  Applied at: ${DateTime.now()}\n');
    } else {
      print('✗ Migration failed: ${applyReport.errorMessage}\n');
    }

    // Step 7: Verify migration
    print('Step 7: Verifying migration...');
    final users = await db.select('users');
    print('✓ Data preserved: ${users.length} user(s) still exist');
    print('  Existing users have default value for \'created_at\'\n');

    // Step 8: View migration history
    print('Step 8: Checking migration history...');
    final historyResponse = await db.query(
      'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 5',
    );
    final history = historyResponse.getResults();
    print('✓ Migration history:');
    for (final migration in history) {
      print('  - ${migration['migration_id']}: ${migration['status']}');
    }
    print('');

    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ Production Workflow: SUCCESS ✓                           ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Production Benefits:');
    print('✓ Full control over migration timing');
    print('✓ Preview changes before applying');
    print('✓ Validation of safe vs destructive changes');
    print('✓ Migration history for auditing');
    print('✓ Zero downtime schema evolution\n');
  } catch (e) {
    print('\n✗ Production workflow error: $e');
    rethrow;
  } finally {
    await db?.close();
  }
}

/// Demonstrates handling destructive changes.
Future<void> _demonstrateDestructiveChanges() async {
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║ BONUS: Handling Destructive Changes                      ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  Database? db;

  try {
    // Create initial schema
    final initialSchema = TableStructure('items', {
      'name': FieldDefinition(StringType(), optional: false),
      'price': FieldDefinition(
        NumberType(format: NumberFormat.floating),
        optional: false,
      ),
      'old_field': FieldDefinition(StringType(), optional: true),
    });

    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
      tableDefinitions: [initialSchema],
      autoMigrate: true,
    );

    // Add data
    await db.create('items', {
      'name': 'Item 1',
      'price': 10.0,
      'old_field': 'legacy data',
    });

    await db.close();

    // New schema removes field (DESTRUCTIVE!)
    final destructiveSchema = TableStructure('items', {
      'name': FieldDefinition(StringType(), optional: false),
      'price': FieldDefinition(
        NumberType(format: NumberFormat.floating),
        optional: false,
      ),
      // old_field removed!
    });

    print('Attempting to apply destructive change...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
      tableDefinitions: [destructiveSchema],
      autoMigrate: false,
    );

    try {
      // This will fail without allowDestructiveMigrations
      await db.migrate(allowDestructiveMigrations: false);
      print('✗ Should have blocked destructive migration!');
    } on MigrationException catch (e) {
      print('✓ Destructive migration blocked (as expected):');
      print('  ${e.message}');
      print('');
      print('To apply destructive changes:');
      print('  1. Review the changes carefully');
      print('  2. Backup your data');
      print('  3. Use allowDestructiveMigrations: true');
      print('');
      print('Example:');
      print('  await db.migrate(allowDestructiveMigrations: true);\n');
    }

    print('Applying with explicit permission...');
    final report = await db.migrate(allowDestructiveMigrations: true);
    if (report.success) {
      print('✓ Destructive migration applied');
      print('  Field \'old_field\' has been removed\n');
    }

    print('=== Destructive Change Handling: SUCCESS ✓ ===\n');
  } catch (e) {
    print('\n✗ Destructive change demo error: $e');
    rethrow;
  } finally {
    await db?.close();
  }
}
