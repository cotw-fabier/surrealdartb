/// High-level database API for SurrealDB.
///
/// This library provides the main Database class which offers a clean,
/// Future-based API for interacting with SurrealDB through FFI.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'exceptions.dart';
import 'ffi/bindings.dart';
import 'ffi/native_types.dart';
import 'response.dart';
import 'storage_backend.dart';

/// High-level asynchronous database client for SurrealDB.
///
/// This class provides a Future-based API for all database operations,
/// wrapping direct FFI calls in Future constructors to maintain async behavior
/// while avoiding the complexity and bugs of isolate-based communication.
///
/// All database operations are executed directly through FFI, which is safe
/// because the Rust layer uses runtime.block_on() to handle async operations.
///
/// Example usage:
/// ```dart
/// // Connect to an in-memory database
/// final db = await Database.connect(
///   backend: StorageBackend.memory,
///   namespace: 'test',
///   database: 'test',
/// );
///
/// try {
///   // Create a record
///   final person = await db.create('person', {
///     'name': 'John Doe',
///     'age': 30,
///   });
///
///   // Query records
///   final response = await db.query('SELECT * FROM person');
///   final results = response.getResults();
///
///   for (final record in results) {
///     print(record['name']);
///   }
/// } finally {
///   // Always close the database when done
///   await db.close();
/// }
/// ```
class Database {
  /// Creates a Database instance with a native database handle.
  ///
  /// This constructor is private. Use [Database.connect] to create
  /// a database instance.
  Database._(this._handle);

  /// The native database handle.
  Pointer<NativeDatabase> _handle;

  /// Whether the database connection has been closed.
  bool _closed = false;

  /// Connects to a SurrealDB database.
  ///
  /// This factory method creates a new database instance and establishes
  /// a connection to the specified backend. All operations are performed
  /// asynchronously through direct FFI calls wrapped in Futures.
  ///
  /// Parameters:
  /// - [backend] - The storage backend to use (memory or rocksdb)
  /// - [path] - File path for rocksdb backend (required for rocksdb, ignored for memory)
  /// - [namespace] - Optional namespace to use after connection
  /// - [database] - Optional database to use after connection
  ///
  /// Returns a connected Database instance.
  ///
  /// Throws:
  /// - [ArgumentError] if path is null for rocksdb backend
  /// - [ConnectionException] if connection fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// // In-memory database
  /// final memDb = await Database.connect(
  ///   backend: StorageBackend.memory,
  ///   namespace: 'test',
  ///   database: 'test',
  /// );
  ///
  /// // Persistent database
  /// final fileDb = await Database.connect(
  ///   backend: StorageBackend.rocksdb,
  ///   path: '/data/mydb',
  ///   namespace: 'prod',
  ///   database: 'main',
  /// );
  /// ```
  static Future<Database> connect({
    required StorageBackend backend,
    String? path,
    String? namespace,
    String? database,
  }) async {
    // Validate parameters
    if (backend.requiresPath && (path == null || path.isEmpty)) {
      throw ArgumentError.value(
        path,
        'path',
        'Path is required for ${backend.displayName} backend',
      );
    }

    return Future(() {
      // Create endpoint string
      final endpoint = backend.toEndpoint(path);
      final endpointPtr = endpoint.toNativeUtf8();

      try {
        // Create database instance
        final handle = dbNew(endpointPtr);
        if (handle == nullptr) {
          final error = _getLastErrorString();
          throw ConnectionException(error ?? 'Failed to create database instance');
        }

        // Connect to database
        final connectResult = dbConnect(handle);
        if (connectResult != 0) {
          final error = _getLastErrorString();
          dbClose(handle);
          throw ConnectionException(error ?? 'Failed to connect to database');
        }

        // Set namespace if provided
        if (namespace != null) {
          final nsPtr = namespace.toNativeUtf8();
          try {
            final nsResult = dbUseNs(handle, nsPtr);
            if (nsResult != 0) {
              final error = _getLastErrorString();
              dbClose(handle);
              throw DatabaseException(error ?? 'Failed to set namespace');
            }
          } finally {
            malloc.free(nsPtr);
          }
        }

        // Set database if provided
        if (database != null) {
          final dbPtr = database.toNativeUtf8();
          try {
            final dbResult = dbUseDb(handle, dbPtr);
            if (dbResult != 0) {
              final error = _getLastErrorString();
              dbClose(handle);
              throw DatabaseException(error ?? 'Failed to set database');
            }
          } finally {
            malloc.free(dbPtr);
          }
        }

        // Create and return database instance
        final db = Database._(handle);
        return db;
      } finally {
        malloc.free(endpointPtr);
      }
    });
  }

  /// Sets the active namespace for subsequent operations.
  ///
  /// All database operations will be executed within this namespace
  /// until changed by another call to this method.
  ///
  /// Parameters:
  /// - [namespace] - The namespace name to use
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [DatabaseException] if operation fails
  ///
  /// Example:
  /// ```dart
  /// await db.useNamespace('production');
  /// ```
  Future<void> useNamespace(String namespace) async {
    _ensureNotClosed();

    return Future(() {
      final nsPtr = namespace.toNativeUtf8();
      try {
        final result = dbUseNs(_handle, nsPtr);
        if (result != 0) {
          final error = _getLastErrorString();
          throw DatabaseException(error ?? 'Failed to set namespace');
        }
      } finally {
        malloc.free(nsPtr);
      }
    });
  }

  /// Sets the active database for subsequent operations.
  ///
  /// All database operations will be executed within this database
  /// until changed by another call to this method.
  ///
  /// Parameters:
  /// - [database] - The database name to use
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [DatabaseException] if operation fails
  ///
  /// Example:
  /// ```dart
  /// await db.useDatabase('main');
  /// ```
  Future<void> useDatabase(String database) async {
    _ensureNotClosed();

    return Future(() {
      final dbPtr = database.toNativeUtf8();
      try {
        final result = dbUseDb(_handle, dbPtr);
        if (result != 0) {
          final error = _getLastErrorString();
          throw DatabaseException(error ?? 'Failed to set database');
        }
      } finally {
        malloc.free(dbPtr);
      }
    });
  }

  /// Executes a SurrealQL query.
  ///
  /// This method executes the provided SQL query and returns a Response
  /// containing the results. The query can contain multiple statements
  /// separated by semicolons.
  ///
  /// Parameters:
  /// - [sql] - The SurrealQL query to execute
  /// - [bindings] - Optional parameter bindings (reserved for future use)
  ///
  /// Returns a Response containing the query results.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if query execution fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final response = await db.query('''
  ///   SELECT * FROM person WHERE age > 18
  /// ''');
  ///
  /// for (final person in response.getResults()) {
  ///   print('${person['name']}: ${person['age']}');
  /// }
  /// ```
  Future<Response> query(String sql, [Map<String, dynamic>? bindings]) async {
    _ensureNotClosed();

    return Future(() {
      final sqlPtr = sql.toNativeUtf8();
      try {
        final responsePtr = dbQuery(_handle, sqlPtr);
        return _processQueryResponse(responsePtr);
      } finally {
        malloc.free(sqlPtr);
      }
    });
  }

  /// Selects all records from a table.
  ///
  /// This is a convenience method that queries all records from the
  /// specified table and returns them as a list.
  ///
  /// Parameters:
  /// - [table] - The table name to select from
  ///
  /// Returns a list of records, where each record is a Map<String, dynamic>.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if select operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final persons = await db.select('person');
  /// for (final person in persons) {
  ///   print(person['name']);
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> select(String table) async {
    _ensureNotClosed();

    return Future(() {
      final tablePtr = table.toNativeUtf8();
      try {
        final responsePtr = dbSelect(_handle, tablePtr);
        final data = _processResponse(responsePtr);

        // SELECT returns a nested array structure like CREATE/UPDATE
        // The response structure is: [[{record1}, {record2}, ...]]
        // We need to unwrap the outer array
        if (data is List && data.isNotEmpty) {
          final firstElement = data.first;
          if (firstElement is List) {
            // Unwrap the nested array
            return firstElement.cast<Map<String, dynamic>>();
          }
          // If not nested, cast directly
          return data.cast<Map<String, dynamic>>();
        }

        return [];
      } finally {
        malloc.free(tablePtr);
      }
    });
  }

  /// Creates a new record in a table.
  ///
  /// This method creates a new record with the specified data in the
  /// given table. SurrealDB will automatically generate an ID if not
  /// provided in the data.
  ///
  /// Parameters:
  /// - [table] - The table name to create the record in
  /// - [data] - The record data as key-value pairs
  ///
  /// Returns the created record including any auto-generated fields.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if create operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final person = await db.create('person', {
  ///   'name': 'Alice',
  ///   'age': 25,
  ///   'email': 'alice@example.com',
  /// });
  ///
  /// print('Created person with ID: ${person['id']}');
  /// ```
  Future<Map<String, dynamic>> create(
    String table,
    Map<String, dynamic> data,
  ) async {
    _ensureNotClosed();

    return Future(() {
      final tablePtr = table.toNativeUtf8();
      final dataJson = jsonEncode(data);
      final dataPtr = dataJson.toNativeUtf8();

      try {
        final responsePtr = dbCreate(_handle, tablePtr, dataPtr);
        final results = _processResponse(responsePtr);

        // CREATE returns a list with one element - extract it
        if (results is! List || results.isEmpty) {
          throw QueryException('Create operation returned no results');
        }

        // SurrealDB CREATE returns an array containing the created record(s)
        // The response structure is: results = [[{record}]]
        // We need to unwrap one level: results.first = [{record}]
        final firstResult = results.first;
        if (firstResult is List) {
          final recordList = firstResult as List;
          if (recordList.isEmpty) {
            throw QueryException('Create operation returned empty result array');
          }
          return recordList.first as Map<String, dynamic>;
        }

        // Fallback: if it's already a Map, return it directly
        return firstResult as Map<String, dynamic>;
      } finally {
        malloc.free(tablePtr);
        malloc.free(dataPtr);
      }
    });
  }

  /// Updates an existing record.
  ///
  /// This method updates the record identified by [resource] with the
  /// provided data. The resource should be in the format "table:id".
  ///
  /// Parameters:
  /// - [resource] - The record identifier (e.g., "person:john")
  /// - [data] - The update data as key-value pairs
  ///
  /// Returns the updated record.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if update operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final updated = await db.update('person:john', {
  ///   'age': 31,
  ///   'email': 'john.new@example.com',
  /// });
  ///
  /// print('Updated: ${updated['name']}');
  /// ```
  Future<Map<String, dynamic>> update(
    String resource,
    Map<String, dynamic> data,
  ) async {
    _ensureNotClosed();

    return Future(() {
      final resourcePtr = resource.toNativeUtf8();
      final dataJson = jsonEncode(data);
      final dataPtr = dataJson.toNativeUtf8();

      try {
        final responsePtr = dbUpdate(_handle, resourcePtr, dataPtr);
        final results = _processResponse(responsePtr);

        // UPDATE returns a list - extract first element
        if (results is! List || results.isEmpty) {
          throw QueryException('Update operation returned no results');
        }

        // SurrealDB UPDATE returns an array containing the updated record(s)
        // The response structure is: results = [[{record}]]
        // We need to unwrap one level: results.first = [{record}]
        final firstResult = results.first;
        if (firstResult is List) {
          final recordList = firstResult as List;
          if (recordList.isEmpty) {
            throw QueryException('Update operation returned empty result array');
          }
          return recordList.first as Map<String, dynamic>;
        }

        // Fallback: if it's already a Map, return it directly
        return firstResult as Map<String, dynamic>;
      } finally {
        malloc.free(resourcePtr);
        malloc.free(dataPtr);
      }
    });
  }

  /// Deletes a record.
  ///
  /// This method deletes the record identified by [resource].
  /// The resource should be in the format "table:id".
  ///
  /// Parameters:
  /// - [resource] - The record identifier (e.g., "person:john")
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if delete operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// await db.delete('person:john');
  /// print('Deleted person:john');
  /// ```
  Future<void> delete(String resource) async {
    _ensureNotClosed();

    return Future(() {
      final resourcePtr = resource.toNativeUtf8();
      try {
        final responsePtr = dbDelete(_handle, resourcePtr);
        // Process response to check for errors, but don't return data
        _processResponse(responsePtr);
      } finally {
        malloc.free(resourcePtr);
      }
    });
  }

  /// Closes the database connection and releases resources.
  ///
  /// After calling this method, the database instance cannot be used anymore.
  /// All subsequent operations will throw a [StateError].
  ///
  /// It is recommended to call this method in a finally block to ensure
  /// cleanup even if exceptions occur.
  ///
  /// This method is idempotent - calling it multiple times is safe.
  ///
  /// Implementation note: This method includes a small delay after closing
  /// to ensure the Rust runtime has time to complete async cleanup tasks
  /// and release resources (especially important for RocksDB file locks).
  ///
  /// Example:
  /// ```dart
  /// final db = await Database.connect(backend: StorageBackend.memory);
  /// try {
  ///   // Use database
  /// } finally {
  ///   await db.close();
  /// }
  /// ```
  Future<void> close() async {
    if (_closed) {
      return; // Already closed
    }

    _closed = true;

    return Future(() async {
      try {
        // Close the native database handle
        dbClose(_handle);

        // Add a delay to ensure async cleanup completes
        // This is especially important for RocksDB to release file locks
        // The Rust layer does internal cleanup, but this extra delay
        // provides a safety margin for the async runtime to finish
        // and for RocksDB to fully release file system resources
        //
        // This delay is on top of the 500ms delay in the Rust layer
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {
        // Ignore errors during cleanup
      }
    });
  }

  /// Whether the database connection has been closed.
  ///
  /// Once closed, the database instance cannot be used anymore.
  ///
  /// Example:
  /// ```dart
  /// if (db.isClosed) {
  ///   print('Database is closed');
  /// }
  /// ```
  bool get isClosed => _closed;

  /// Ensures the database is not closed.
  ///
  /// Throws [StateError] if the database has been closed.
  void _ensureNotClosed() {
    if (_closed) {
      throw StateError('Database connection has been closed');
    }
  }

  /// Processes a Response pointer from FFI and returns the data.
  ///
  /// This method extracts JSON data from the native response and frees
  /// the response pointer after processing.
  ///
  /// Throws [QueryException] if the response indicates an error.
  dynamic _processResponse(Pointer<NativeResponse> responsePtr) {
    if (responsePtr == nullptr) {
      final error = _getLastErrorString();
      throw QueryException(error ?? 'Operation failed');
    }

    try {
      // Check if response has errors
      final hasErrors = responseHasErrors(responsePtr);
      if (hasErrors != 0) {
        final error = _getLastErrorString();
        throw QueryException(error ?? 'Query execution failed');
      }

      // Extract JSON from response
      final jsonPtr = responseGetResults(responsePtr);
      if (jsonPtr == nullptr) {
        throw QueryException('Failed to get response results');
      }

      try {
        final jsonStr = jsonPtr.toDartString();
        return jsonDecode(jsonStr);
      } finally {
        freeString(jsonPtr);
      }
    } finally {
      responseFree(responsePtr);
    }
  }

  /// Processes a query Response pointer and returns a Response object.
  ///
  /// This is specifically for the query() method which returns a Response
  /// object rather than raw data.
  Response _processQueryResponse(Pointer<NativeResponse> responsePtr) {
    if (responsePtr == nullptr) {
      final error = _getLastErrorString();
      throw QueryException(error ?? 'Query failed');
    }

    try {
      // Check if response has errors
      final hasErrors = responseHasErrors(responsePtr);
      if (hasErrors != 0) {
        final error = _getLastErrorString();
        throw QueryException(error ?? 'Query execution failed');
      }

      // Extract JSON from response
      final jsonPtr = responseGetResults(responsePtr);
      if (jsonPtr == nullptr) {
        throw QueryException('Failed to get query results');
      }

      try {
        final jsonStr = jsonPtr.toDartString();
        final data = jsonDecode(jsonStr);
        return Response(data);
      } finally {
        freeString(jsonPtr);
      }
    } finally {
      responseFree(responsePtr);
    }
  }

  /// Gets the last error string from native code and frees it.
  ///
  /// Returns null if no error string is available.
  static String? _getLastErrorString() {
    final errorPtr = getLastError();
    if (errorPtr == nullptr) {
      return null;
    }

    try {
      return errorPtr.toDartString();
    } finally {
      freeString(errorPtr);
    }
  }
}
