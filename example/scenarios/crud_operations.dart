/// Demonstrates complete CRUD (Create, Read, Update, Delete) operations.
///
/// This scenario shows how to:
/// - Connect to an in-memory database
/// - Create a new record
/// - Query records
/// - Update an existing record
/// - Delete a record
/// - Handle errors gracefully
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the CRUD operations scenario.
///
/// This scenario demonstrates a complete lifecycle of data operations:
/// creating, reading, updating, and deleting records. It uses an in-memory
/// database for fast execution and clear demonstration of each operation.
///
/// All operations include detailed console output showing the data at
/// each step of the process.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runCrudScenario() async {
  print('\n=== Scenario 2: CRUD Operations ===\n');

  Database? db;

  try {
    // Step 1: Connect to database
    print('Step 1: Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected successfully\n');

    // Step 2: Create a new person record
    print('Step 2: Creating a new person record...');
    final person = await db.create('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });
    print('✓ Record created:');
    print('  ID: ${person['id']}');
    print('  Name: ${person['name']}');
    print('  Age: ${person['age']}');
    print('  Email: ${person['email']}');
    print('  City: ${person['city']}\n');

    // Extract the record ID for later operations
    final recordId = person['id'] as String;

    // Step 3: Query all person records
    print('Step 3: Querying all person records...');
    final persons = await db.select('person');
    print('✓ Found ${persons.length} record(s)');
    for (final p in persons) {
      print('  - ${p['name']} (${p['age']} years old)');
    }
    print('');

    // Step 4: Update the record
    print('Step 4: Updating person record...');
    final updated = await db.update(recordId, {
      'age': 31,
      'email': 'john.updated@example.com',
      'city': 'Los Angeles',
    });
    print('✓ Record updated:');
    print('  ID: ${updated['id']}');
    print('  Name: ${updated['name']}');
    print('  Age: ${updated['age']} (was 30)');
    print('  Email: ${updated['email']} (was john.doe@example.com)');
    print('  City: ${updated['city']} (was San Francisco)\n');

    // Step 5: Verify the update with a query
    print('Step 5: Verifying update with query...');
    final response = await db.query('SELECT * FROM person WHERE age > 30');
    final results = response.getResults();
    print('✓ Query result for age > 30:');
    if (results.isEmpty) {
      print('  No records found');
    } else {
      for (final r in results) {
        print('  - ${r['name']}: ${r['age']} years old');
      }
    }
    print('');

    // Step 6: Delete the record
    print('Step 6: Deleting person record...');
    await db.delete(recordId);
    print('✓ Record deleted: $recordId\n');

    // Step 7: Verify deletion
    print('Step 7: Verifying deletion...');
    final remaining = await db.select('person');
    print('✓ Remaining records: ${remaining.length}');
    if (remaining.isEmpty) {
      print('  All records have been deleted\n');
    }

    // Success summary
    print('=== CRUD Operations: SUCCESS ===');
    print('All operations completed successfully!');
    print('  ✓ Create');
    print('  ✓ Read (Select)');
    print('  ✓ Update');
    print('  ✓ Delete\n');
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
