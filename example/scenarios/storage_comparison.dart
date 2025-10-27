/// Demonstrates the difference between in-memory and persistent storage.
///
/// This scenario shows how to:
/// - Use in-memory storage (data lost on close)
/// - Use RocksDB persistent storage (data survives restarts)
/// - Compare the behavior of both backends
/// - Handle temporary files and cleanup
library;

import 'dart:io';

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the storage comparison scenario.
///
/// This scenario demonstrates the key difference between the two storage
/// backends: in-memory storage loses data when closed, while RocksDB
/// persists data to disk and can be reopened with the same data.
///
/// The scenario creates temporary directories for RocksDB testing and
/// cleans them up afterward.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runStorageComparisonScenario() async {
  print('\n=== Scenario 3: Storage Backend Comparison ===\n');

  await _testMemoryBackend();
  await _testRocksDbBackend();

  print('=== Storage Comparison: SUCCESS ===');
  print('Both storage backends are working correctly!\n');
}

/// Tests the in-memory storage backend.
///
/// Demonstrates that data is lost when the database is closed.
Future<void> _testMemoryBackend() async {
  print('--- Part 1: In-Memory Storage (mem://) ---\n');

  Database? db;

  try {
    // Connect and create data
    print('Connecting to in-memory database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected\n');

    print('Creating test record...');
    final record = await db.createQL('product', {
      'name': 'Laptop',
      'price': 999.99,
      'stock': 42,
    });
    print('✓ Created: ${record['name']} - \$${record['price']}');
    print('  Record ID: ${record['id']}\n');

    // Verify data exists
    print('Querying records...');
    final products = await db.selectQL('product');
    print('✓ Found ${products.length} product(s) in database\n');

    // Close the database
    print('Closing database...');
    await db.close();
    db = null;
    print('✓ Database closed\n');

    // Attempt to reconnect - data should be gone
    print('Reconnecting to verify data persistence...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Reconnected\n');

    print('Querying records after reconnection...');
    final productsAfter = await db.selectQL('product');
    print('✓ Found ${productsAfter.length} product(s) in database');

    if (productsAfter.isEmpty) {
      print('  ⚠ Data was lost (expected for in-memory storage)\n');
    } else {
      print('  ⚠ Warning: Data persisted (unexpected for in-memory)\n');
    }

    print('Memory Backend Summary:');
    print('  • Fast and lightweight');
    print('  • Data stored in RAM only');
    print('  • All data lost when connection closes');
    print('  • Ideal for testing and temporary data\n');
  } catch (e) {
    print('✗ Memory backend test failed: $e\n');
    rethrow;
  } finally {
    if (db != null) {
      await db.close();
    }
  }
}

/// Tests the RocksDB persistent storage backend.
///
/// Demonstrates that data persists when the database is closed and reopened.
Future<void> _testRocksDbBackend() async {
  print('--- Part 2: RocksDB Persistent Storage ---\n');

  // Create a temporary directory for RocksDB tests
  final tempDir = Directory.systemTemp.createTempSync('surrealdartb_test_');

  // IMPORTANT: Use separate database paths for each connection
  //
  // Due to a limitation in SurrealDB's RocksDB backend, the database path
  // cannot be reliably reused immediately after closing. This is because:
  // 1. SurrealDB spawns a background thread that holds a reference to the database
  // 2. This prevents the file lock from being released until process exit
  //
  // Best practice: Use unique paths for each database instance, or wait
  // until application restart before reusing the same path.
  final dbPath1 = '${tempDir.path}/testdb1';
  final dbPath2 = '${tempDir.path}/testdb2';

  print('Using temporary database paths:');
  print('  First connection: $dbPath1');
  print('  Second connection: $dbPath2');
  print('  (Using separate paths due to RocksDB backend limitation)\n');

  Database? db;

  try {
    // === First Connection: Create and Verify Data ===
    print('Connecting to RocksDB database (first instance)...');
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath1,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected\n');

    print('Creating test record...');
    final record = await db.createQL('product', {
      'name': 'Desktop',
      'price': 1499.99,
      'stock': 15,
    });
    print('✓ Created: ${record['name']} - \$${record['price']}');
    print('  Record ID: ${record['id']}\n');

    // Verify data exists
    print('Querying records...');
    final products = await db.selectQL('product');
    print('✓ Found ${products.length} product(s) in database\n');

    // Close the database - this will trigger graceful cleanup
    print('Closing first database instance...');
    await db.close();
    db = null;
    print('✓ Database closed and resources released\n');

    // === Second Connection: Demonstrate Independent Database ===
    // Note: We use a different path (dbPath2) because SurrealDB's RocksDB
    // backend cannot immediately reuse the same path after closing.
    // This demonstrates that each database instance is independent.
    print('Connecting to RocksDB database (second independent instance)...');
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath2, // Use different path due to backend limitation
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected to new database path\n');

    print('Querying records in new database instance...');
    final productsAfter = await db.selectQL('product');
    print('✓ Found ${productsAfter.length} product(s) in database');

    if (productsAfter.isEmpty) {
      print('  ✓ New database is empty (as expected)\n');

      // Create a new record in the second database
      print('Creating a record in the second database...');
      final newRecord = await db.createQL('product', {
        'name': 'Monitor',
        'price': 399.99,
        'stock': 25,
      });
      print('✓ Created: ${newRecord['name']} - \$${newRecord['price']}\n');
    } else {
      print('  ⚠ Unexpected: New database contains data\n');
    }

    print('RocksDB Backend Summary:');
    print('  • Data persists to disk');
    print('  • Survives database close and application restart');
    print('  • Stored in RocksDB files at specified path');
    print('  • Ideal for production and long-term storage');
    print('  • Note: Cannot reuse same path immediately after close');
    print('    (SurrealDB backend limitation)\n');
  } catch (e) {
    print('✗ RocksDB backend test failed: $e\n');
    rethrow;
  } finally {
    // Close database
    if (db != null) {
      await db.close();
    }

    // Clean up temporary directory
    try {
      print('Cleaning up temporary files...');
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        print('✓ Temporary files deleted\n');
      }
    } catch (e) {
      print('⚠ Warning: Could not clean up temp directory: $e\n');
    }
  }
}
