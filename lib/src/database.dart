/// High-level database API for SurrealDB.
///
/// This library provides the main Database class which offers a clean,
/// Future-based API for interacting with SurrealDB through FFI.
library;

import 'dart:async';

import 'exceptions.dart';
import 'isolate/database_isolate.dart';
import 'isolate/isolate_messages.dart';
import 'response.dart';
import 'storage_backend.dart';

/// High-level asynchronous database client for SurrealDB.
///
/// This class provides a Future-based API for all database operations,
/// ensuring that all native calls are executed asynchronously in a
/// background isolate to prevent blocking the UI thread.
///
/// All database operations are serialized through a single background
/// isolate for thread safety.
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
  /// Creates a Database instance with a background isolate.
  ///
  /// This constructor is private. Use [Database.connect] to create
  /// a database instance.
  Database._(this._isolate);

  /// The background isolate managing database operations.
  final DatabaseIsolate _isolate;

  /// Whether the database connection has been closed.
  bool _closed = false;

  /// Connects to a SurrealDB database.
  ///
  /// This factory method creates a new database instance and establishes
  /// a connection to the specified backend. All operations are performed
  /// asynchronously through a background isolate.
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

    // Create and start isolate
    final isolate = DatabaseIsolate();
    await isolate.start();

    try {
      // Initialize the isolate
      final initResponse = await isolate.sendCommand(const InitializeCommand());
      if (initResponse is ErrorResponse) {
        throw DatabaseException(
          initResponse.message,
          errorCode: initResponse.errorCode,
          nativeStackTrace: initResponse.nativeStackTrace,
        );
      }

      // Connect to database
      final endpoint = backend.toEndpoint(path);
      final connectResponse = await isolate.sendCommand(
        ConnectCommand(
          endpoint: endpoint,
          namespace: namespace,
          database: database,
        ),
      );

      if (connectResponse is ErrorResponse) {
        throw ConnectionException(
          connectResponse.message,
          errorCode: connectResponse.errorCode,
          nativeStackTrace: connectResponse.nativeStackTrace,
        );
      }

      // Create and return database instance
      return Database._(isolate);
    } catch (e) {
      // Clean up isolate on error
      await isolate.dispose();
      rethrow;
    }
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

    final response = await _isolate.sendCommand(
      UseNamespaceCommand(namespace),
    );

    _throwIfError(response);
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

    final response = await _isolate.sendCommand(
      UseDatabaseCommand(database),
    );

    _throwIfError(response);
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

    final response = await _isolate.sendCommand(
      QueryCommand(sql: sql, bindings: bindings),
    );

    if (response is ErrorResponse) {
      throw QueryException(
        response.message,
        errorCode: response.errorCode,
        nativeStackTrace: response.nativeStackTrace,
      );
    }

    final successResponse = response as SuccessResponse;
    return Response(successResponse.data);
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

    final response = await _isolate.sendCommand(
      SelectCommand(table),
    );

    if (response is ErrorResponse) {
      throw QueryException(
        response.message,
        errorCode: response.errorCode,
        nativeStackTrace: response.nativeStackTrace,
      );
    }

    final successResponse = response as SuccessResponse;
    final data = successResponse.data;

    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    return [];
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

    final response = await _isolate.sendCommand(
      CreateCommand(table: table, data: data),
    );

    if (response is ErrorResponse) {
      throw QueryException(
        response.message,
        errorCode: response.errorCode,
        nativeStackTrace: response.nativeStackTrace,
      );
    }

    final successResponse = response as SuccessResponse;
    // CREATE returns a list with one element - extract it
    final results = successResponse.data as List<dynamic>;
    if (results.isEmpty) {
      throw QueryException('Create operation returned no results');
    }
    return results.first as Map<String, dynamic>;
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

    final response = await _isolate.sendCommand(
      UpdateCommand(resource: resource, data: data),
    );

    if (response is ErrorResponse) {
      throw QueryException(
        response.message,
        errorCode: response.errorCode,
        nativeStackTrace: response.nativeStackTrace,
      );
    }

    final successResponse = response as SuccessResponse;
    // UPDATE returns a list - extract first element
    final results = successResponse.data as List<dynamic>;
    if (results.isEmpty) {
      throw QueryException('Update operation returned no results');
    }
    return results.first as Map<String, dynamic>;
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

    final response = await _isolate.sendCommand(
      DeleteCommand(resource),
    );

    _throwIfError(response);
  }

  /// Closes the database connection and shuts down the background isolate.
  ///
  /// After calling this method, the database instance cannot be used anymore.
  /// All subsequent operations will throw a [StateError].
  ///
  /// It is recommended to call this method in a finally block to ensure
  /// cleanup even if exceptions occur.
  ///
  /// This method is idempotent - calling it multiple times is safe.
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

    try {
      await _isolate.dispose();
    } catch (_) {
      // Ignore errors during cleanup
    }
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

  /// Throws an exception if the response is an error.
  ///
  /// Converts ErrorResponse to DatabaseException and throws.
  void _throwIfError(IsolateResponse response) {
    if (response is ErrorResponse) {
      throw DatabaseException(
        response.message,
        errorCode: response.errorCode,
        nativeStackTrace: response.nativeStackTrace,
      );
    }
  }
}
