/// Demonstrates basic table definition generation using annotations.
///
/// This scenario shows how to:
/// - Define tables using @SurrealTable and @SurrealField annotations
/// - Generate TableDefinition classes with build_runner
/// - Use generated definitions with the database
/// - Apply schema changes automatically
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the basic table generation scenario.
///
/// This demonstrates the simplest workflow for using annotation-based
/// schema generation:
/// 1. Define your schema with annotations
/// 2. Run build_runner to generate code
/// 3. Use generated TableDefinition with Database
///
/// Note: This example uses pre-generated TableDefinition classes to demonstrate
/// the workflow. In real usage, you would use @SurrealTable annotations and
/// run `dart run build_runner build` to generate these classes.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runBasicTableGenerationScenario() async {
  print('\n=== Scenario: Basic Table Generation & Migration ===\n');

  Database? db;

  try {
    // ===================================================================
    // STEP 1: Define Schema with Annotations
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ STEP 1: Schema Definition                                ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('In your code, define a class with annotations:');
    print('');
    print('  @SurrealTable(\'users\')');
    print('  class User {');
    print('    @SurrealField(type: StringType())');
    print('    final String name;');
    print('');
    print('    @SurrealField(');
    print('      type: NumberType(format: NumberFormat.integer),');
    print('      assertClause: r\'\$value >= 18\',');
    print('    )');
    print('    final int age;');
    print('');
    print('    @SurrealField(');
    print('      type: StringType(),');
    print('      indexed: true,');
    print('    )');
    print('    final String email;');
    print('  }');
    print('');
    print('Then run: dart run build_runner build');
    print('This generates: user.surreal.dart with UserTableDef\n');

    // ===================================================================
    // STEP 2: Create Table Definition (Normally Auto-Generated)
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ STEP 2: Generated Table Definition                       ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // This demonstrates what the generated code looks like
    final userTable = TableStructure('users', {
      'name': FieldDefinition(
        StringType(),
        optional: false,
      ),
      'age': FieldDefinition(
        NumberType(format: NumberFormat.integer),
        optional: false,
        assertClause: r'$value >= 18',
      ),
      'email': FieldDefinition(
        StringType(),
        optional: false,
        indexed: true,
      ),
    });

    print('✓ Table definition created:');
    print('  Table: ${userTable.tableName}');
    print('  Fields: ${userTable.fields.length}');
    print('    - name (string, required)');
    print('    - age (int, required, ASSERT >= 18)');
    print('    - email (string, required, indexed)\n');

    // ===================================================================
    // STEP 3: Connect with Auto-Migration
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ STEP 3: Connect Database with Auto-Migration             ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'demo',
      database: 'demo',
      tableDefinitions: [userTable],
      autoMigrate: true,
    );
    print('✓ Connected successfully');
    print('✓ Schema automatically created in database\n');

    // ===================================================================
    // STEP 4: Use the Database
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ STEP 4: Use the Database                                 ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // Create a user
    print('Creating a user...');
    final user = await db.createQL('users', {
      'name': 'Alice Smith',
      'age': 25,
      'email': 'alice@example.com',
    });
    print('✓ User created:');
    print('  ID: ${user['id']}');
    print('  Name: ${user['name']}');
    print('  Age: ${user['age']}');
    print('  Email: ${user['email']}\n');

    // Query users
    print('Querying users...');
    final users = await db.selectQL('users');
    print('✓ Found ${users.length} user(s)');
    for (final u in users) {
      print('  - ${u['name']} (${u['age']}) - ${u['email']}');
    }
    print('');

    // Try to create a user with invalid age (should fail assertion)
    print('Testing validation (age < 18)...');
    try {
      await db.createQL('users', {
        'name': 'Young User',
        'age': 15, // Too young!
        'email': 'young@example.com',
      });
      print('✗ Should have failed validation!');
    } on QueryException catch (e) {
      print('✓ Caught validation error (as expected):');
      print('  ${e.message}');
      print('  The ASSERT clause blocked invalid data\n');
    }

    // ===================================================================
    // Success Summary
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ Basic Table Generation: SUCCESS ✓                        ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('=== Key Takeaways ===');
    print('1. Define your schema once using annotations');
    print('2. build_runner generates type-safe TableDefinition classes');
    print('3. Pass definitions to Database.connect()');
    print('4. Auto-migration creates/updates tables automatically');
    print('5. ASSERT clauses provide database-level validation');
    print('6. Indexes improve query performance\n');
  } on ConnectionException catch (e) {
    print('\n✗ Connection failed: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } on MigrationException catch (e) {
    print('\n✗ Migration failed: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } on DatabaseException catch (e) {
    print('\n✗ Database error: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } catch (e) {
    print('\n✗ Unexpected error: $e');
    rethrow;
  } finally {
    // Always close the database connection
    if (db != null) {
      print('Closing database connection...');
      await db.close();
      print('✓ Database closed\n');
    }
  }
}
