/// Unit tests for public Database API.
///
/// These tests verify the high-level Database API works correctly with
/// the new direct FFI architecture (no isolates).
///
/// NOTE: The Database class now calls FFI functions directly instead of
/// using isolate message passing. This provides better performance and
/// simpler architecture while maintaining async behavior through Future wrappers.

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('StorageBackend', () {
    test('memory backend generates correct endpoint', () {
      final endpoint = StorageBackend.memory.toEndpoint();
      expect(endpoint, equals('mem://'));
    });

    test('rocksdb backend generates correct endpoint with path', () {
      final endpoint = StorageBackend.rocksdb.toEndpoint('/data/mydb');
      expect(endpoint, equals('file:///data/mydb'));
    });

    test('rocksdb backend normalizes path without leading slash', () {
      final endpoint = StorageBackend.rocksdb.toEndpoint('data/mydb');
      expect(endpoint, equals('file:///data/mydb'));
    });

    test('rocksdb backend throws without path', () {
      expect(
        () => StorageBackend.rocksdb.toEndpoint(),
        throwsArgumentError,
      );
    });

    test('memory backend has correct properties', () {
      expect(StorageBackend.memory.requiresPath, isFalse);
      expect(StorageBackend.memory.isPersistent, isFalse);
      expect(StorageBackend.memory.displayName, equals('In-Memory'));
    });

    test('rocksdb backend has correct properties', () {
      expect(StorageBackend.rocksdb.requiresPath, isTrue);
      expect(StorageBackend.rocksdb.isPersistent, isTrue);
      expect(StorageBackend.rocksdb.displayName, equals('RocksDB'));
    });
  });

  group('Response', () {
    test('empty response returns empty results', () {
      final response = Response(null);
      expect(response.getResults(), isEmpty);
      expect(response.isEmpty, isTrue);
      expect(response.isNotEmpty, isFalse);
      expect(response.resultCount, equals(0));
    });

    test('response with list data returns results', () {
      final data = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      final response = Response(data);

      expect(response.getResults(), equals(data));
      expect(response.resultCount, equals(2));
      expect(response.isEmpty, isFalse);
      expect(response.isNotEmpty, isTrue);
    });

    test('response with single map wraps in list', () {
      final data = {'id': 1, 'name': 'Alice'};
      final response = Response(data);

      final results = response.getResults();
      expect(results, hasLength(1));
      expect(results.first, equals(data));
    });

    test('firstOrNull returns first result', () {
      final data = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      final response = Response(data);

      expect(response.firstOrNull, equals(data.first));
    });

    test('firstOrNull returns null for empty response', () {
      final response = Response(null);
      expect(response.firstOrNull, isNull);
    });

    test('takeResult extracts result by index', () {
      final data = [
        {'id': 1, 'name': 'Alice'},
        {'id': 2, 'name': 'Bob'},
      ];
      final response = Response(data);

      expect(response.takeResult(0), equals(data[0]));
      expect(response.takeResult(1), equals(data[1]));
      expect(response.takeResult(2), isNull);
      expect(response.takeResult(-1), isNull);
    });

    test('hasErrors returns false when no errors', () {
      final response = Response([]);
      expect(response.hasErrors(), isFalse);
      expect(response.getErrors(), isEmpty);
    });
  });

  group('DatabaseException', () {
    test('exception contains message', () {
      final ex = DatabaseException('Test error');
      expect(ex.message, equals('Test error'));
      expect(ex.errorCode, isNull);
      expect(ex.nativeStackTrace, isNull);
    });

    test('exception contains error code', () {
      final ex = DatabaseException('Test error', errorCode: -1);
      expect(ex.message, equals('Test error'));
      expect(ex.errorCode, equals(-1));
    });

    test('exception toString includes details', () {
      final ex = DatabaseException('Test error', errorCode: -1);
      final str = ex.toString();
      expect(str, contains('Test error'));
      expect(str, contains('-1'));
    });

    test('ConnectionException is DatabaseException', () {
      final ex = ConnectionException('Connection failed');
      expect(ex, isA<DatabaseException>());
      expect(ex.toString(), contains('ConnectionException'));
    });

    test('QueryException is DatabaseException', () {
      final ex = QueryException('Query failed');
      expect(ex, isA<DatabaseException>());
      expect(ex.toString(), contains('QueryException'));
    });

    test('AuthenticationException is DatabaseException', () {
      final ex = AuthenticationException('Auth failed');
      expect(ex, isA<DatabaseException>());
      expect(ex.toString(), contains('AuthenticationException'));
    });
  });

  group('Database Connection (Direct FFI)', () {
    test('connect throws without path for rocksdb', () async {
      expect(
        () => Database.connect(backend: StorageBackend.rocksdb),
        throwsArgumentError,
      );
    });

    test('connect throws with empty path for rocksdb', () async {
      expect(
        () => Database.connect(
          backend: StorageBackend.rocksdb,
          path: '',
        ),
        throwsArgumentError,
      );
    });

    test('Database.connect validates parameters', () async {
      // These tests validate parameter checking before FFI calls.
      // With direct FFI architecture, validation happens immediately
      // rather than being deferred to isolate.

      expect(
        () => Database.connect(
          backend: StorageBackend.rocksdb,
          path: null,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Database Operations (Direct FFI)', () {
    // These tests will work once the direct FFI implementation is complete.
    // They verify that operations throw StateError when database is closed,
    // which should work regardless of isolate vs direct FFI architecture.

    test('operations throw StateError when closed', () async {
      // Create and immediately close a database
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
      await db.close();

      // All operations should throw StateError when database is closed
      expect(
        () => db.query('SELECT * FROM test'),
        throwsStateError,
      );

      expect(
        () => db.select('test'),
        throwsStateError,
      );

      expect(
        () => db.create('test', {'data': 'value'}),
        throwsStateError,
      );

      expect(
        () => db.update('test:id', {'data': 'value'}),
        throwsStateError,
      );

      expect(
        () => db.delete('test:id'),
        throwsStateError,
      );

      expect(
        () => db.useNamespace('new_ns'),
        throwsStateError,
      );

      expect(
        () => db.useDatabase('new_db'),
        throwsStateError,
      );
    });
  });
}
