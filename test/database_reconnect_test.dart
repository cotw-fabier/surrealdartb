/// Tests for database reconnection behavior.
///
/// This test suite verifies that opening an existing database at a path
/// works correctly without throwing "database already exists" errors.
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Database Reconnection', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('surrealdb_reconnect_test_');
      dbPath = '${tempDir.path}/testdb';
    });

    tearDown(() async {
      // Wait for any lingering locks to release
      await Future.delayed(const Duration(milliseconds: 500));
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    });

    test('opens existing database without error', () async {
      // Create initial database and add data
      var db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      await db.createQL('test_table', {'name': 'Test Record', 'value': 42});
      await db.close();

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 600));

      // Reconnect to the same path - should NOT throw "database already exists"
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Verify data persisted
        final results = await db.selectQL('test_table');
        expect(results, hasLength(1));
        expect(results.first['name'], equals('Test Record'));
        expect(results.first['value'], equals(42));
      } finally {
        await db.close();
      }
    });

    test('handles multiple open-close cycles gracefully', () async {
      // Perform multiple open-close cycles on the same path
      for (var i = 0; i < 3; i++) {
        final db = await Database.connect(
          backend: StorageBackend.rocksdb,
          path: dbPath,
          namespace: 'test',
          database: 'test',
        );

        await db.createQL('iteration', {'count': i, 'timestamp': DateTime.now().toIso8601String()});
        await db.close();

        // Wait for locks to release
        await Future.delayed(const Duration(milliseconds: 600));
      }

      // Final verification - open one more time and check all data
      final db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      try {
        final results = await db.selectQL('iteration');
        expect(results, hasLength(3));
      } finally {
        await db.close();
      }
    });

    test('data persists across reconnections', () async {
      // Create database and add initial records
      var db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      await db.createQL('users', {'name': 'Alice', 'age': 30});
      await db.createQL('users', {'name': 'Bob', 'age': 25});
      await db.close();

      await Future.delayed(const Duration(milliseconds: 600));

      // Reconnect and add more data
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      await db.createQL('users', {'name': 'Charlie', 'age': 35});
      await db.close();

      await Future.delayed(const Duration(milliseconds: 600));

      // Final reconnect and verify all data
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      try {
        final users = await db.selectQL('users');
        expect(users, hasLength(3));

        final names = users.map((u) => u['name']).toSet();
        expect(names, containsAll(['Alice', 'Bob', 'Charlie']));
      } finally {
        await db.close();
      }
    });

    test('hot restart simulation - new connection without closing old one succeeds', () async {
      // This test simulates what happens during Flutter Hot Restart:
      // 1. A database connection is created
      // 2. The Dart isolate restarts (without explicit close)
      // 3. A new connection is attempted to the same path
      //
      // The connection registry should automatically close the old connection
      // before creating the new one, preventing lock errors.

      // First connection - DO NOT CLOSE to simulate hot restart
      final db1 = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      // Add some data through first connection
      await db1.createQL('hot_restart_test', {'created_by': 'db1', 'value': 1});

      // Simulate hot restart: create new connection WITHOUT closing first one
      // This should NOT throw "lock held by current process" error
      final db2 = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );

      try {
        // New connection should work - add data
        await db2.createQL('hot_restart_test', {'created_by': 'db2', 'value': 2});

        // Verify we can query data (original data from db1 should still exist)
        final results = await db2.selectQL('hot_restart_test');
        expect(results, hasLength(2));
      } finally {
        await db2.close();
      }

      // Note: db1's handle is now invalid (was closed by registry)
      // We don't call db1.close() because it would try to use an invalid handle
    });

    test('different namespaces on same path work independently', () async {
      // Create database with namespace A
      var db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'namespace_a',
        database: 'db_a',
      );

      await db.createQL('records', {'source': 'A'});
      await db.close();

      await Future.delayed(const Duration(milliseconds: 600));

      // Reconnect with namespace B
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'namespace_b',
        database: 'db_b',
      );

      await db.createQL('records', {'source': 'B'});

      // Verify only B's data is visible
      final resultsB = await db.selectQL('records');
      expect(resultsB, hasLength(1));
      expect(resultsB.first['source'], equals('B'));

      await db.close();

      await Future.delayed(const Duration(milliseconds: 600));

      // Reconnect with namespace A and verify A's data is still there
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'namespace_a',
        database: 'db_a',
      );

      try {
        final resultsA = await db.selectQL('records');
        expect(resultsA, hasLength(1));
        expect(resultsA.first['source'], equals('A'));
      } finally {
        await db.close();
      }
    });
  });
}
