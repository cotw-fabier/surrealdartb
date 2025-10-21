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
    final record = await db.create('product', {
      'name': 'Laptop',
      'price': 999.99,
      'stock': 42,
    });
    print('✓ Created: ${record['name']} - \$${record['price']}');
    print('  Record ID: ${record['id']}\n');

    // Verify data exists
    print('Querying records...');
    final products = await db.select('product');
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
    final productsAfter = await db.select('product');
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

  // Create a temporary directory for RocksDB
  final tempDir = Directory.systemTemp.createTempSync('surrealdartb_test_');
  final dbPath = '${tempDir.path}/testdb';

  print('Using temporary database path: $dbPath\n');

  Database? db;

  try {
    // Connect and create data
    print('Connecting to RocksDB database...');
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected\n');

    print('Creating test record...');
    final record = await db.create('product', {
      'name': 'Desktop',
      'price': 1499.99,
      'stock': 15,
    });
    print('✓ Created: ${record['name']} - \$${record['price']}');
    print('  Record ID: ${record['id']}\n');

    final recordId = record['id'] as String;

    // Verify data exists
    print('Querying records...');
    final products = await db.select('product');
    print('✓ Found ${products.length} product(s) in database\n');

    // Close the database
    print('Closing database...');
    await db.close();
    db = null;
    print('✓ Database closed\n');

    // Reconnect to the same path - data should persist
    print('Reconnecting to the same database path...');
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Reconnected\n');

    print('Querying records after reconnection...');
    final productsAfter = await db.select('product');
    print('✓ Found ${productsAfter.length} product(s) in database');

    if (productsAfter.isNotEmpty) {
      print('  ✓ Data persisted successfully!');
      for (final p in productsAfter) {
        print('    - ${p['name']}: \$${p['price']} (${p['stock']} in stock)');
      }
      print('');

      // Verify we can still operate on persisted data
      print('Updating persisted record...');
      final updated = await db.update(recordId, {'stock': 20});
      print('✓ Updated stock from ${record['stock']} to ${updated['stock']}\n');
    } else {
      print('  ⚠ Warning: Data was not persisted (unexpected for RocksDB)\n');
    }

    print('RocksDB Backend Summary:');
    print('  • Data persists to disk');
    print('  • Survives database close and application restart');
    print('  • Stored in RocksDB files at specified path');
    print('  • Ideal for production and long-term storage\n');
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
