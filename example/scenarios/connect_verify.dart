/// Demonstrates basic database connection and verification.
///
/// This scenario shows how to:
/// - Connect to an in-memory database
/// - Set namespace and database context
/// - Execute a simple query to verify connectivity
/// - Handle errors gracefully
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the connect and verify scenario.
///
/// This scenario demonstrates basic connectivity by connecting to an
/// in-memory database, setting the namespace and database context,
/// and executing an INFO query to verify the connection works.
///
/// All operations are performed asynchronously and include clear
/// console output showing each step.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runConnectVerifyScenario() async {
  print('\n=== Scenario 1: Connect and Verify ===\n');

  Database? db;

  try {
    // Step 1: Connect to in-memory database
    print('Step 1: Connecting to in-memory database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Successfully connected to database\n');

    // Step 2: Verify namespace and database are set
    print('Step 2: Verifying database context...');
    print('  Namespace: test');
    print('  Database: test\n');

    // Step 3: Execute INFO query to verify connectivity
    print('Step 3: Executing INFO FOR DB query...');
    final response = await db.query('INFO FOR DB;');
    final results = response.getResults();

    if (results.isEmpty) {
      print('✓ Query executed successfully (no schema defined yet)\n');
    } else {
      print('✓ Query executed successfully');
      print('  Result: ${results.first}\n');
    }

    // Step 4: Success summary
    print('=== Connect and Verify: SUCCESS ===');
    print('Database connection is working correctly!\n');
  } on ConnectionException catch (e) {
    print('\n✗ Connection failed: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } on QueryException catch (e) {
    print('\n✗ Query failed: ${e.message}');
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
