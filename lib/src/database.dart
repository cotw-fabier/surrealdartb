/// High-level database API for SurrealDB.
///
/// This library provides the main Database class which offers a clean,
/// Future-based API for interacting with SurrealDB through FFI.
///
/// ## Dual Validation Strategy
///
/// This SDK implements a dual validation strategy for data integrity:
///
/// **Dart-Side Validation (Optional)**:
/// When a [TableStructure] schema is provided to CRUD operations ([createQL],
/// [updateQL]), the data is validated in Dart before being sent to SurrealDB.
/// This provides:
/// - Immediate feedback on validation errors
/// - Field-level error details via [ValidationException]
/// - Type safety and dimension checks for vector fields
/// - No database round-trip for invalid data
///
/// **SurrealDB Fallback Validation**:
/// When no [TableStructure] is provided, data passes directly to SurrealDB,
/// which performs its own validation based on any `DEFINE TABLE` schemas.
/// SurrealDB errors are returned as [DatabaseException].
///
/// ### Choosing a Validation Strategy
///
/// **Use Dart-side validation when**:
/// - You want immediate, detailed validation feedback
/// - You're working with vector embeddings and need dimension checks
/// - You want to catch errors before FFI boundary crossing
/// - You have complex nested schemas to validate
///
/// **Skip Dart-side validation when**:
/// - You're doing simple inserts with no complex validation
/// - You want maximum performance (skip validation overhead)
/// - SurrealDB schema validation is sufficient for your use case
///
/// ### Example: Dart-Side Validation
///
/// ```dart
/// // Define schema with vector field
/// final schema = TableStructure('documents', {
///   'title': FieldDefinition(StringType()),
///   'embedding': FieldDefinition(
///     VectorType.f32(1536, normalized: true),
///   ),
/// });
///
/// // Create vector embedding
/// final embedding = VectorValue.fromList(List.filled(1536, 0.1));
///
/// try {
///   // Validate before insert
///   final doc = await db.createQL(
///     'documents',
///     {
///       'title': 'AI Document',
///       'embedding': embedding.toJson(),
///     },
///     schema: schema, // Dart-side validation enabled
///   );
/// } catch (e) {
///   if (e is ValidationException) {
///     print('Validation failed on field: ${e.fieldName}');
///     print('Constraint violated: ${e.constraint}');
///   }
/// }
/// ```
///
/// ### Example: SurrealDB Fallback Validation
///
/// ```dart
/// // No schema provided - data passes directly to SurrealDB
/// try {
///   final doc = await db.createQL('documents', {
///     'title': 'Simple Document',
///     'content': 'Content here',
///   });
///   // SurrealDB validates based on its own schema (if defined)
/// } catch (e) {
///   if (e is DatabaseException) {
///     print('SurrealDB error: ${e.message}');
///   }
/// }
/// ```
///
/// ## Vector Data Storage
///
/// Vectors can be stored and retrieved seamlessly using existing CRUD operations.
/// No new FFI functions are required - vectors are serialized to JSON for transport.
///
/// ### Storing Vectors
///
/// ```dart
/// // Create vector embedding
/// final embedding = VectorValue.fromList([0.1, 0.2, 0.3, 0.4]);
///
/// // Store via createQL()
/// final record = await db.createQL('embeddings', {
///   'text': 'Hello world',
///   'vector': embedding.toJson(), // Serializes to JSON List
/// });
/// ```
///
/// ### Retrieving Vectors
///
/// ```dart
/// // Get record with vector
/// final record = await db.get<Map<String, dynamic>>('embeddings:abc');
///
/// // Convert JSON back to VectorValue
/// final vector = VectorValue.fromJson(record!['vector']);
///
/// // Use vector operations
/// print('Dimensions: ${vector.dimensions}');
/// print('Magnitude: ${vector.magnitude()}');
/// ```
///
/// ### Batch Operations with Vectors
///
/// ```dart
/// // Create multiple vectors
/// final vectors = [
///   VectorValue.fromList([1.0, 0.0, 0.0]),
///   VectorValue.fromList([0.0, 1.0, 0.0]),
///   VectorValue.fromList([0.0, 0.0, 1.0]),
/// ];
///
/// // Batch insert via queryQL()
/// await db.set('vec1', vectors[0].toJson());
/// await db.set('vec2', vectors[1].toJson());
/// await db.set('vec3', vectors[2].toJson());
///
/// await db.queryQL('''
///   INSERT INTO embeddings [
///     { name: "x", vec: $vec1 },
///     { name: "y", vec: $vec2 },
///     { name: "z", vec: $vec3 }
///   ]
/// ''');
/// ```
///
/// ### Updating Vectors
///
/// ```dart
/// // Update existing vector
/// final newEmbedding = VectorValue.fromList([0.5, 0.6, 0.7, 0.8]);
///
/// await db.updateQL('embeddings:abc', {
///   'vector': newEmbedding.toJson(),
///   'updated_at': DateTime.now().toIso8601String(),
/// });
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'exceptions.dart';
import 'ffi/bindings.dart';
import 'ffi/native_types.dart';
import 'response.dart';
import 'schema/table_structure.dart';
import 'storage_backend.dart';
import 'types/credentials.dart';
import 'types/jwt.dart';
import 'schema/migration_engine.dart';
import 'orm/where_condition.dart';
import 'orm/include_spec.dart';
import 'types/vector_value.dart';
import 'vector/distance_metric.dart';
import 'vector/similarity_result.dart';
import 'vector/index_type.dart';
import 'vector/index_definition.dart';

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
///   // Create a record using QL method (map-based)
///   final person = await db.createQL('person', {
///     'name': 'John Doe',
///     'age': 30,
///   });
///
///   // Query records
///   final response = await db.queryQL('SELECT * FROM person');
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
  Database._(this._handle, this._tableDefinitions);

  /// The native database handle.
  Pointer<NativeDatabase> _handle;

  /// Whether the database connection has been closed.
  bool _closed = false;

  /// Table definitions for schema migration.
  final List<TableStructure>? _tableDefinitions;

  /// Counter for generating unique parameter names.
  int _paramCounter = 0;

  /// Generates a unique parameter name for query binding.
  ///
  /// This method creates unique parameter names for use in WhereCondition
  /// classes to prevent parameter name collisions.
  ///
  /// Returns a unique parameter name in the format "param_N" where N is
  /// an incrementing counter.
  String generateParamName() {
    return 'param_${_paramCounter++}';
  }

  /// Connects to a SurrealDB database with optional auto-migration support.
  ///
  /// This factory method creates a new database instance and establishes
  /// a connection to the specified backend. All operations are performed
  /// asynchronously through direct FFI calls wrapped in Futures.
  ///
  /// ## Migration Support
  ///
  /// This method supports automatic schema migration when table definitions
  /// are provided. Migrations can be applied automatically on connection or
  /// deferred for manual control.
  ///
  /// Parameters:
  /// - [backend] - The storage backend to use (memory or rocksdb)
  /// - [path] - File path for rocksdb backend (required for rocksdb, ignored for memory)
  /// - [namespace] - Optional namespace to use after connection
  /// - [database] - Optional database to use after connection
  /// - [tableDefinitions] - Optional list of table schemas for migration
  /// - [autoMigrate] - Whether to automatically apply migrations on connect (default: true)
  /// - [allowDestructiveMigrations] - Whether to allow destructive schema changes (default: false)
  /// - [dryRun] - Whether to preview migrations without applying (default: false)
  ///
  /// Returns a connected Database instance.
  ///
  /// Throws:
  /// - [ArgumentError] if path is null for rocksdb backend
  /// - [ConnectionException] if connection fails
  /// - [MigrationException] if migration fails (when autoMigrate=true)
  /// - [DatabaseException] for other errors
  ///
  /// Example without migrations:
  /// ```dart
  /// // Simple connection without migrations
  /// final db = await Database.connect(
  ///   backend: StorageBackend.memory,
  ///   namespace: 'test',
  ///   database: 'test',
  /// );
  /// ```
  ///
  /// Example with auto-migration:
  /// ```dart
  /// // Define table schemas
  /// final tables = [
  ///   TableStructure('users', {
  ///     'name': FieldDefinition(StringType()),
  ///     'email': FieldDefinition(StringType(), indexed: true),
  ///   }),
  /// ];
  ///
  /// // Connect with auto-migration
  /// final db = await Database.connect(
  ///   backend: StorageBackend.memory,
  ///   namespace: 'test',
  ///   database: 'test',
  ///   tableDefinitions: tables,
  ///   autoMigrate: true,
  /// );
  /// // Tables are automatically created/updated
  /// ```
  ///
  /// Example with manual migration:
  /// ```dart
  /// // Connect without auto-migration
  /// final db = await Database.connect(
  ///   backend: StorageBackend.rocksdb,
  ///   path: '/data/mydb',
  ///   namespace: 'prod',
  ///   database: 'main',
  ///   tableDefinitions: tables,
  ///   autoMigrate: false, // Don't migrate on connect
  /// );
  ///
  /// // Preview migration
  /// final preview = await db.migrate(dryRun: true);
  /// print('Would apply: ${preview.tablesAdded}');
  ///
  /// // Apply migration manually
  /// await db.migrate();
  /// ```
  static Future<Database> connect({
    required StorageBackend backend,
    String? path,
    String? namespace,
    String? database,
    List<TableStructure>? tableDefinitions,
    bool autoMigrate = true,
    bool allowDestructiveMigrations = false,
    bool dryRun = false,
  }) async {
    // Validate parameters
    if (backend.requiresPath && (path == null || path.isEmpty)) {
      throw ArgumentError.value(
        path,
        'path',
        'Path is required for ${backend.displayName} backend',
      );
    }

    return Future(() async {
      // Create endpoint string
      final endpoint = backend.toEndpoint(path);
      final endpointPtr = endpoint.toNativeUtf8();

      try {
        // Create database instance
        final handle = dbNew(endpointPtr);
        if (handle == nullptr) {
          final error = _getLastErrorString();
          throw ConnectionException(
              error ?? 'Failed to create database instance');
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

        // Create database instance
        final db = Database._(handle, tableDefinitions);

        // Auto-migrate if requested and table definitions provided
        if (autoMigrate && tableDefinitions != null && tableDefinitions.isNotEmpty) {
          try {
            final engine = MigrationEngine();
            await engine.executeMigration(
              db,
              tableDefinitions,
              allowDestructiveMigrations: allowDestructiveMigrations,
              dryRun: dryRun,
            );
          } catch (e) {
            // Close database on migration failure
            await db.close();
            rethrow;
          }
        }

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

  /// Executes a SurrealQL query (QL-suffix version for backward compatibility).
  ///
  /// This method executes the provided SQL query and returns a Response
  /// containing the results. The query can contain multiple statements
  /// separated by semicolons.
  ///
  /// **Note**: This is the renamed version of the original `query()` method.
  /// The QL suffix indicates this method uses raw SurrealQL with Map-based
  /// parameters. In the future, a new type-safe `query()` method will be
  /// introduced for the ORM layer.
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
  /// final response = await db.queryQL('''
  ///   SELECT * FROM person WHERE age > 18
  /// ''');
  ///
  /// for (final person in response.getResults()) {
  ///   print('${person['name']}: ${person['age']}');
  /// }
  /// ```
  Future<Response> queryQL(String sql, [Map<String, dynamic>? bindings]) async {
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

  /// Selects all records from a table (QL-suffix version for backward compatibility).
  ///
  /// This is a convenience method that queries all records from the
  /// specified table and returns them as a list.
  ///
  /// **Note**: This is the renamed version of the original `select()` method.
  /// The QL suffix indicates this method uses raw SurrealQL with Map-based
  /// results. In the future, a new type-safe `select()` method will be
  /// introduced for the ORM layer.
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
  /// final persons = await db.selectQL('person');
  /// for (final person in persons) {
  ///   print(person['name']);
  /// }
  /// ```
  Future<List<Map<String, dynamic>>> selectQL(String table) async {
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

  /// Creates a new record in a table with optional schema validation (QL-suffix version).
  ///
  /// This method creates a new record with the specified data in the
  /// given table. SurrealDB will automatically generate an ID if not
  /// provided in the data.
  ///
  /// **Note**: This is the renamed version of the original `create()` method.
  /// The QL suffix indicates this method uses Map-based data. In the future,
  /// a new type-safe `create()` method will be introduced for the ORM layer
  /// that accepts Dart objects instead of Maps.
  ///
  /// **Dual Validation Strategy**:
  ///
  /// If [schema] is provided, the data is validated in Dart before
  /// being sent to SurrealDB. This provides immediate feedback and
  /// detailed error information via [ValidationException].
  ///
  /// If [schema] is null, data passes directly to SurrealDB, which
  /// performs its own validation based on any defined table schemas.
  ///
  /// Parameters:
  /// - [table] - The table name to create the record in
  /// - [data] - The record data as key-value pairs
  /// - [schema] - Optional TableStructure for Dart-side validation
  ///
  /// Returns the created record including any auto-generated fields.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ValidationException] if schema validation fails (when schema provided)
  /// - [QueryException] if create operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example with Dart-side validation:
  /// ```dart
  /// // Define schema
  /// final schema = TableStructure('person', {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  /// });
  ///
  /// // Create with validation
  /// final person = await db.createQL(
  ///   'person',
  ///   {
  ///     'name': 'Alice',
  ///     'age': 25,
  ///     'email': 'alice@example.com',
  ///   },
  ///   schema: schema, // Validates before insert
  /// );
  ///
  /// print('Created person with ID: ${person['id']}');
  /// ```
  ///
  /// Example with vector field:
  /// ```dart
  /// final embedding = VectorValue.fromList(List.filled(384, 0.1));
  ///
  /// final doc = await db.createQL('documents', {
  ///   'title': 'AI Document',
  ///   'embedding': embedding.toJson(),
  /// });
  /// ```
  Future<Map<String, dynamic>> createQL(
    String table,
    Map<String, dynamic> data, {
    TableStructure? schema,
  }) async {
    _ensureNotClosed();

    // Dart-side validation if schema provided
    // For CREATE operations, we require all fields (partial: false)
    if (schema != null) {
      schema.validate(data, partial: false);
    }

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
            throw QueryException(
                'Create operation returned empty result array');
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

  /// Updates an existing record with optional schema validation (QL-suffix version).
  ///
  /// This method updates the record identified by [resource] with the
  /// provided data. The resource should be in the format "table:id".
  ///
  /// **Note**: This is the renamed version of the original `update()` method.
  /// The QL suffix indicates this method uses Map-based data. In the future,
  /// a new type-safe `update()` method will be introduced for the ORM layer
  /// that accepts Dart objects instead of Maps.
  ///
  /// **Dual Validation Strategy**:
  ///
  /// If [schema] is provided, the data is validated in Dart before
  /// being sent to SurrealDB. This provides immediate feedback and
  /// detailed error information via [ValidationException].
  ///
  /// If [schema] is null, data passes directly to SurrealDB, which
  /// performs its own validation based on any defined table schemas.
  ///
  /// Parameters:
  /// - [resource] - The record identifier (e.g., "person:john")
  /// - [data] - The update data as key-value pairs
  /// - [schema] - Optional TableStructure for Dart-side validation
  ///
  /// Returns the updated record.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ValidationException] if schema validation fails (when schema provided)
  /// - [QueryException] if update operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example with validation:
  /// ```dart
  /// final schema = TableStructure('person', {
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  ///   'email': FieldDefinition(StringType(), optional: true),
  /// });
  ///
  /// final updated = await db.updateQL(
  ///   'person:john',
  ///   {
  ///     'age': 31,
  ///     'email': 'john.new@example.com',
  ///   },
  ///   schema: schema,
  /// );
  ///
  /// print('Updated: ${updated['name']}');
  /// ```
  ///
  /// Example updating vector:
  /// ```dart
  /// final newEmbedding = VectorValue.fromList([0.5, 0.6, 0.7]);
  ///
  /// await db.updateQL('embeddings:abc', {
  ///   'vector': newEmbedding.toJson(),
  /// });
  /// ```
  Future<Map<String, dynamic>> updateQL(
    String resource,
    Map<String, dynamic> data, {
    TableStructure? schema,
  }) async {
    _ensureNotClosed();

    // Dart-side validation if schema provided
    // For UPDATE operations, we use partial validation (default)
    // This allows updating only specific fields without requiring all fields
    if (schema != null) {
      schema.validate(data);
    }

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
            throw QueryException(
                'Update operation returned empty result array');
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

  /// Deletes a record (QL-suffix version for backward compatibility).
  ///
  /// This method deletes the record identified by [resource].
  /// The resource should be in the format "table:id".
  ///
  /// **Note**: This is the renamed version of the original `delete()` method.
  /// The QL suffix indicates this method uses raw record identifiers. In the
  /// future, a new type-safe `delete()` method will be introduced for the
  /// ORM layer that accepts Dart objects.
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
  /// await db.deleteQL('person:john');
  /// print('Deleted person:john');
  /// ```
  Future<void> deleteQL(String resource) async {
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

  /// Gets a specific record by resource identifier.
  ///
  /// This method retrieves a single record identified by [resource].
  /// The resource should be in the format "table:id".
  ///
  /// Unlike other operations, this method returns null if the record
  /// does not exist, rather than throwing an exception.
  ///
  /// Parameters:
  /// - [resource] - The record identifier (e.g., "person:alice")
  ///
  /// Returns the record if it exists, null otherwise.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [DatabaseException] if resource parameter is invalid
  /// - [QueryException] if get operation fails
  ///
  /// Example:
  /// ```dart
  /// final person = await db.get<Map<String, dynamic>>('person:alice');
  /// if (person != null) {
  ///   print('Found: ${person['name']}');
  /// } else {
  ///   print('Person not found');
  /// }
  /// ```
  ///
  /// Example retrieving vector:
  /// ```dart
  /// final record = await db.get<Map<String, dynamic>>('embeddings:abc');
  /// if (record != null) {
  ///   final vector = VectorValue.fromJson(record['embedding']);
  ///   print('Vector dimensions: ${vector.dimensions}');
  /// }
  /// ```
  Future<T?> get<T>(String resource) async {
    _ensureNotClosed();

    return Future(() {
      final resourcePtr = resource.toNativeUtf8();
      try {
        final responsePtr = dbGet(_handle, resourcePtr);
        final data = _processResponse(responsePtr);

        // GET returns a nested array structure similar to SELECT
        // The response structure is: [[{record}]] or [[]] if not found
        // We need to unwrap and handle the null case
        if (data is List && data.isNotEmpty) {
          final firstElement = data.first;
          if (firstElement is List) {
            final recordList = firstElement as List;
            if (recordList.isEmpty) {
              // Record not found
              return null;
            }
            // Return first record as type T
            return recordList.first as T?;
          }
          // If not nested, return directly
          return firstElement as T?;
        }

        // Empty response means record not found
        return null;
      } finally {
        malloc.free(resourcePtr);
      }
    });
  }

  /// Signs in with credentials and returns a JWT token.
  ///
  /// This method authenticates a user with the provided credentials and
  /// returns a JWT token that can be used for subsequent authenticated
  /// operations.
  ///
  /// Parameters:
  /// - [credentials] - The credentials to authenticate with
  ///
  /// Returns a JWT token on successful authentication.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [AuthenticationException] if authentication fails
  /// - [DatabaseException] for other errors
  ///
  /// Embedded Mode Limitations:
  /// - Authentication may have reduced functionality in embedded mode
  /// - Scope-based access control may not fully apply
  /// - Token refresh is not supported
  ///
  /// Example:
  /// ```dart
  /// final jwt = await db.signin(RootCredentials('root', 'rootpass'));
  /// print('Authenticated with token');
  /// ```
  Future<Jwt> signin(Credentials credentials) async {
    _ensureNotClosed();

    return Future(() {
      final credentialsJson = jsonEncode(credentials.toJson());
      final credentialsPtr = credentialsJson.toNativeUtf8();

      try {
        final tokenPtr = dbSignin(_handle, credentialsPtr);
        if (tokenPtr == nullptr) {
          final error = _getLastErrorString();
          throw AuthenticationException(error ?? 'Signin failed');
        }

        try {
          final tokenJsonStr = tokenPtr.toDartString();
          final tokenJson = jsonDecode(tokenJsonStr);
          return Jwt.fromJson(tokenJson);
        } finally {
          freeString(tokenPtr);
        }
      } finally {
        malloc.free(credentialsPtr);
      }
    });
  }

  /// Signs up a new user with scope credentials and returns a JWT token.
  ///
  /// This method creates a new user account within a scope and returns
  /// a JWT token for the newly created user.
  ///
  /// Parameters:
  /// - [credentials] - The scope or record credentials for signup
  ///
  /// Returns a JWT token for the newly created user.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [AuthenticationException] if signup fails
  /// - [ArgumentError] if credentials are not scope or record credentials
  /// - [DatabaseException] for other errors
  ///
  /// Embedded Mode Limitations:
  /// - Signup functionality may be limited in embedded mode
  /// - User creation and scope-based authentication may not work as expected
  ///
  /// Example:
  /// ```dart
  /// final jwt = await db.signup(ScopeCredentials(
  ///   'myNamespace',
  ///   'myDatabase',
  ///   'user_scope',
  ///   {'email': 'user@example.com', 'password': 'pass123'},
  /// ));
  /// print('User created and authenticated');
  /// ```
  Future<Jwt> signup(Credentials credentials) async {
    _ensureNotClosed();

    // Validate that credentials are scope or record credentials
    if (credentials is! ScopeCredentials && credentials is! RecordCredentials) {
      throw ArgumentError(
        'Signup only accepts ScopeCredentials or RecordCredentials',
      );
    }

    return Future(() {
      final credentialsJson = jsonEncode(credentials.toJson());
      final credentialsPtr = credentialsJson.toNativeUtf8();

      try {
        final tokenPtr = dbSignup(_handle, credentialsPtr);
        if (tokenPtr == nullptr) {
          final error = _getLastErrorString();
          throw AuthenticationException(error ?? 'Signup failed');
        }

        try {
          final tokenJsonStr = tokenPtr.toDartString();
          final tokenJson = jsonDecode(tokenJsonStr);
          return Jwt.fromJson(tokenJson);
        } finally {
          freeString(tokenPtr);
        }
      } finally {
        malloc.free(credentialsPtr);
      }
    });
  }

  /// Authenticates with an existing JWT token.
  ///
  /// This method authenticates the current session using a previously
  /// obtained JWT token. This is useful for resuming sessions or
  /// authenticating with tokens obtained from signin or signup.
  ///
  /// Parameters:
  /// - [token] - The JWT token to authenticate with
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [AuthenticationException] if authentication fails
  /// - [DatabaseException] for other errors
  ///
  /// Embedded Mode Limitations:
  /// - Token-based authentication may have limited functionality
  /// - Token validation may not work as expected
  ///
  /// Example:
  /// ```dart
  /// final jwt = await db.signin(credentials);
  /// // ... later or in another session ...
  /// await db.authenticate(jwt);
  /// print('Session authenticated');
  /// ```
  Future<void> authenticate(Jwt token) async {
    _ensureNotClosed();

    return Future(() {
      final tokenStr = token.asInsecureToken();
      final tokenPtr = tokenStr.toNativeUtf8();

      try {
        final result = dbAuthenticate(_handle, tokenPtr);
        if (result != 0) {
          final error = _getLastErrorString();
          throw AuthenticationException(error ?? 'Authentication failed');
        }
      } finally {
        malloc.free(tokenPtr);
      }
    });
  }

  /// Invalidates the current authentication session.
  ///
  /// This method clears the current authentication state, effectively
  /// logging out the current user. After calling this method, authenticated
  /// operations will fail until a new signin or authenticate is performed.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [AuthenticationException] if invalidation fails
  /// - [DatabaseException] for other errors
  ///
  /// Embedded Mode Limitations:
  /// - Session invalidation may have limited effect in embedded mode
  /// - Authentication state is managed differently than in remote server mode
  ///
  /// Example:
  /// ```dart
  /// await db.invalidate();
  /// print('Session invalidated');
  /// ```
  Future<void> invalidate() async {
    _ensureNotClosed();

    return Future(() {
      final result = dbInvalidate(_handle);
      if (result != 0) {
        final error = _getLastErrorString();
        throw AuthenticationException(error ?? 'Invalidate failed');
      }
    });
  }

  /// Refreshes the current authentication token.
  ///
  /// This method uses a valid JWT token to obtain a new access token.
  /// The current token must still be valid (not expired) for refresh to succeed.
  ///
  /// **New in SurrealDB 3.0**: This method uses the refresh token support
  /// added in SurrealDB 3.0.0-beta.
  ///
  /// Parameters:
  /// - [currentToken] - The current JWT token to refresh
  ///
  /// Returns a new JWT token with updated access and optional refresh tokens.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [AuthenticationException] if token refresh fails
  /// - [DatabaseException] for other errors
  ///
  /// Embedded Mode Limitations:
  /// - Token refresh may have limited functionality in embedded mode
  /// - Authentication is typically bypassed in embedded mode
  ///
  /// Example:
  /// ```dart
  /// // Get initial token via signin
  /// final jwt = await db.signin(credentials);
  ///
  /// // Later, refresh the token before it expires
  /// try {
  ///   final newJwt = await db.refreshToken(jwt);
  ///   print('Token refreshed successfully');
  /// } catch (e) {
  ///   print('Token refresh failed: $e');
  ///   // Re-authenticate if refresh fails
  ///   final newJwt = await db.signin(credentials);
  /// }
  /// ```
  Future<Jwt> refreshToken(Jwt currentToken) async {
    _ensureNotClosed();

    return Future(() {
      final tokenStr = currentToken.asInsecureToken();
      final tokenPtr = tokenStr.toNativeUtf8();

      try {
        final resultPtr = dbRefreshToken(_handle, tokenPtr);
        if (resultPtr == nullptr) {
          final error = _getLastErrorString();
          throw AuthenticationException(error ?? 'Token refresh failed');
        }

        try {
          final tokenJsonStr = resultPtr.toDartString();
          final tokenJson = jsonDecode(tokenJsonStr);
          return Jwt.fromJson(tokenJson);
        } finally {
          freeString(resultPtr);
        }
      } finally {
        malloc.free(tokenPtr);
      }
    });
  }

  /// Sets a query parameter that can be used in subsequent queries.
  ///
  /// Parameters are stored per connection and can be referenced in queries
  /// using the syntax $paramName. This is useful for creating reusable
  /// parameterized queries and avoiding SQL injection.
  ///
  /// Parameters:
  /// - [name] - The parameter name (without the $ prefix)
  /// - [value] - The parameter value (can be any JSON-serializable type)
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ParameterException] if parameter operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// await db.set('user_id', 'person:alice');
  /// await db.set('min_age', 18);
  ///
  /// // Use parameters in queries
  /// final response = await db.queryQL(
  ///   'SELECT * FROM person WHERE id = $user_id AND age >= $min_age'
  /// );
  /// ```
  Future<void> set(String name, dynamic value) async {
    _ensureNotClosed();

    return Future(() {
      final namePtr = name.toNativeUtf8();
      final valueJson = jsonEncode(value);
      final valuePtr = valueJson.toNativeUtf8();

      try {
        final result = dbSet(_handle, namePtr, valuePtr);
        if (result != 0) {
          final error = _getLastErrorString();
          throw ParameterException(error ?? 'Failed to set parameter');
        }
      } finally {
        malloc.free(namePtr);
        malloc.free(valuePtr);
      }
    });
  }

  /// Removes a query parameter from the connection.
  ///
  /// If the parameter doesn't exist, this method completes successfully
  /// without error.
  ///
  /// Parameters:
  /// - [name] - The parameter name to remove (without the $ prefix)
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ParameterException] if parameter operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// await db.set('temp_value', 42);
  /// // ... use the parameter ...
  /// await db.unset('temp_value');
  /// ```
  Future<void> unset(String name) async {
    _ensureNotClosed();

    return Future(() {
      final namePtr = name.toNativeUtf8();

      try {
        final result = dbUnset(_handle, namePtr);
        if (result != 0) {
          final error = _getLastErrorString();
          throw ParameterException(error ?? 'Failed to unset parameter');
        }
      } finally {
        malloc.free(namePtr);
      }
    });
  }

  /// Executes a SurrealQL function and returns the result.
  ///
  /// This method can execute both built-in SurrealQL functions (like
  /// rand::float, time::now, etc.) and user-defined functions. The result
  /// type is determined by the generic type parameter T.
  ///
  /// Parameters:
  /// - [function] - The function name (e.g., "rand::float", "fn::my_function")
  /// - [args] - Optional list of arguments to pass to the function
  ///
  /// Returns the function result, deserialized to type T.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [QueryException] if function execution fails
  /// - [DatabaseException] for other errors
  ///
  /// Examples:
  /// ```dart
  /// // Execute built-in function with no arguments
  /// final randomValue = await db.run<double>('rand::float');
  ///
  /// // Execute function with arguments
  /// final upperCase = await db.run<String>('string::uppercase', ['hello']);
  ///
  /// // Execute user-defined function
  /// final result = await db.run<Map<String, dynamic>>(
  ///   'fn::calculate_tax',
  ///   [100.0, 0.08],
  /// );
  /// ```
  Future<T> run<T>(String function, [List<dynamic>? args]) async {
    _ensureNotClosed();

    return Future(() {
      final functionPtr = function.toNativeUtf8();
      final argsJson = args != null && args.isNotEmpty ? jsonEncode(args) : '';
      final argsPtr = argsJson.toNativeUtf8();

      try {
        final responsePtr = dbRun(_handle, functionPtr, argsPtr);
        final data = _processResponse(responsePtr);

        // Function results are wrapped in an array structure
        // Similar to query results: [[result]]
        if (data is List && data.isNotEmpty) {
          final firstElement = data.first;
          if (firstElement is List && firstElement.isNotEmpty) {
            return firstElement.first as T;
          }
          return firstElement as T;
        }

        throw QueryException('Function returned no results');
      } finally {
        malloc.free(functionPtr);
        malloc.free(argsPtr);
      }
    });
  }

  /// Gets the database version string.
  ///
  /// Returns a version string like "1.5.0" representing the SurrealDB
  /// server/engine version.
  ///
  /// Returns the database version string.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [DatabaseException] if version query fails
  ///
  /// Example:
  /// ```dart
  /// final version = await db.version();
  /// print('SurrealDB version: $version');
  /// ```
  Future<String> version() async {
    _ensureNotClosed();

    return Future(() {
      final versionPtr = dbVersion(_handle);
      if (versionPtr == nullptr) {
        final error = _getLastErrorString();
        throw DatabaseException(error ?? 'Failed to get version');
      }

      try {
        return versionPtr.toDartString();
      } finally {
        freeString(versionPtr);
      }
    });
  }


  /// Type-safe query builder for ORM operations (direct parameter API).
  ///
  /// This method provides a direct parameter API for building type-safe queries.
  /// It accepts all query parameters as named arguments and executes the query
  /// immediately, returning results as a list of Maps.
  ///
  /// **Note**: This is a placeholder implementation for Task Group 16.
  /// Full type-safe query building with code generation will be implemented
  /// in later task groups (6-15). For now, this method provides the API
  /// interface and basic query execution.
  ///
  /// Parameters:
  /// - [table] - The table name to query from (required)
  /// - [where] - Optional where clause using WhereCondition
  /// - [include] - Optional list of relationships to include
  /// - [orderBy] - Optional field name to sort by
  /// - [ascending] - Sort direction (default: true)
  /// - [limit] - Optional maximum number of records
  /// - [offset] - Optional number of records to skip
  ///
  /// Returns a Future<List<Map<String, dynamic>>> with query results.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if table name is empty
  /// - [OrmQueryException] if query building fails
  /// - [QueryException] if query execution fails
  ///
  /// Example:
  /// ```dart
  /// // Simple query
  /// final users = await db.query(
  ///   table: 'users',
  ///   limit: 10,
  /// );
  ///
  /// // Query with where clause
  /// final activeUsers = await db.query(
  ///   table: 'users',
  ///   where: EqualsCondition('status', 'active'),
  ///   orderBy: 'name',
  /// );
  ///
  /// // Query with complex where and includes
  /// final usersWithPosts = await db.query(
  ///   table: 'users',
  ///   where: EqualsCondition('age', 25) & GreaterThanCondition('posts_count', 0),
  ///   include: [
  ///     IncludeSpec('posts', limit: 5),
  ///   ],
  ///   limit: 10,
  /// );
  /// ```
  Future<List<Map<String, dynamic>>> query({
    required String table,
    WhereCondition? where,
    List<IncludeSpec>? include,
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }

    return Future(() {
      // Build the SurrealQL query
      final queryBuffer = StringBuffer('SELECT * FROM $table');

      // Add WHERE clause if provided
      if (where != null) {
        final whereClause = where.toSurrealQL(this);
        queryBuffer.write(' WHERE $whereClause');
      }

      // Add ORDER BY clause if provided
      if (orderBy != null && orderBy.isNotEmpty) {
        queryBuffer.write(' ORDER BY $orderBy ${ascending ? 'ASC' : 'DESC'}');
      }

      // Add LIMIT clause if provided
      if (limit != null && limit > 0) {
        queryBuffer.write(' LIMIT $limit');
      }

      // Add OFFSET (START in SurrealQL) if provided
      if (offset != null && offset > 0) {
        queryBuffer.write(' START $offset');
      }

      // TODO: Add include/FETCH support in future task groups
      // For now, includes are ignored with a note
      if (include != null && include.isNotEmpty) {
        // Placeholder: In full implementation, this will add FETCH clauses
        // for each IncludeSpec with proper filtering, limiting, and sorting
      }

      final sqlQuery = queryBuffer.toString();

      // Execute the query using existing queryQL infrastructure
      final sqlPtr = sqlQuery.toNativeUtf8();
      try {
        final responsePtr = dbQuery(_handle, sqlPtr);
        final data = _processResponse(responsePtr);

        // Process results similar to selectQL
        if (data is List && data.isNotEmpty) {
          final firstElement = data.first;
          if (firstElement is List) {
            return firstElement.cast<Map<String, dynamic>>();
          }
          return data.cast<Map<String, dynamic>>();
        }

        return <Map<String, dynamic>>[];
      } finally {
        malloc.free(sqlPtr);
      }
    });
  }
  /// Creates a new record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [createQL] by accepting
  /// a Dart object instead of a Map. The object is automatically serialized
  /// using its generated `toSurrealMap()` method, validated against its schema,
  /// and the result is deserialized back into the same type.
  ///
  /// The table name is automatically extracted from the object's `@SurrealTable`
  /// annotation via the generated `tableName` getter.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to create in the database
  ///
  /// Returns the created object with any auto-generated fields populated.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [OrmValidationException] if validation fails
  /// - [QueryException] if create operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// @SurrealTable('users')
  /// class User {
  ///   @SurrealField(type: StringType())
  ///   final String? id;
  ///
  ///   @SurrealField(type: StringType())
  ///   final String name;
  ///
  ///   User({this.id, required this.name});
  /// }
  ///
  /// final user = User(name: 'Alice');
  /// final created = await db.create(user);
  /// print('Created user: ${created.id}');
  /// ```
  Future<T> create<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Extract TableStructure from generated static getter
      final tableStructure = extension.tableStructure as TableStructure;

      // Validate object before sending
      try {
        tableStructure.validate(extension.toSurrealMap());
      } on ValidationException catch (e) {
        throw OrmValidationException(
          'Validation failed for ${T.toString()}',
          field: e.fieldName,
          constraint: e.constraint,
          cause: e,
        );
      }

      // Serialize object to map
      final Map<String, dynamic> data = extension.toSurrealMap();

      // Call existing createQL method
      final result = await createQL(tableName, data);

      // Deserialize result back to typed object
      return extension.fromSurrealMap(result) as T;
    });
  }

  /// Updates an existing record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [updateQL] by accepting
  /// a Dart object instead of a Map. The object's ID is automatically extracted
  /// using the generated `recordId` getter, the object is serialized and validated,
  /// and the result is deserialized back into the same type.
  ///
  /// The table name is automatically extracted from the object's `@SurrealTable`
  /// annotation via the generated `tableName` getter.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to update in the database
  ///
  /// Returns the updated object.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if object ID is null or empty
  /// - [OrmValidationException] if validation fails
  /// - [QueryException] if update operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final user = await db.get<User>('users:alice');
  /// final updated = User(id: user.id, name: 'Alice Updated');
  /// final result = await db.update(updated);
  /// print('Updated user: ${result.name}');
  /// ```
  Future<T> update<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract ID from object using generated recordId getter
      final id = extension.recordId;
      if (id == null || (id is String && id.isEmpty)) {
        throw ArgumentError.value(
          id,
          'object.recordId',
          'Object ID cannot be null or empty for update operation',
        );
      }

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Extract TableStructure from generated static getter
      final tableStructure = extension.tableStructure as TableStructure;

      // Validate object before sending
      try {
        tableStructure.validate(extension.toSurrealMap());
      } on ValidationException catch (e) {
        throw OrmValidationException(
          'Validation failed for ${T.toString()}',
          field: e.fieldName,
          constraint: e.constraint,
          cause: e,
        );
      }

      // Serialize object to map
      final Map<String, dynamic> data = extension.toSurrealMap();

      // Build resource identifier (table:id)
      final resource = '$tableName:$id';

      // Call existing updateQL method
      final result = await updateQL(resource, data);

      // Deserialize result back to typed object
      return extension.fromSurrealMap(result) as T;
    });
  }

  /// Deletes a record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [deleteQL] by accepting
  /// a Dart object instead of a resource string. The object's ID and table name
  /// are automatically extracted from the object using generated methods.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to delete from the database
  ///
  /// Returns a Future that completes when the delete operation succeeds.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if object ID is null or empty
  /// - [QueryException] if delete operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final user = await db.get<User>('users:alice');
  /// await db.delete(user);
  /// print('Deleted user: ${user.id}');
  /// ```
  Future<void> delete<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract ID from object using generated recordId getter
      final id = extension.recordId;
      if (id == null || (id is String && id.isEmpty)) {
        throw ArgumentError.value(
          id,
          'object.recordId',
          'Object ID cannot be null or empty for delete operation',
        );
      }

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Build resource identifier (table:id)
      final resource = '$tableName:$id';

      // Call existing deleteQL method
      await deleteQL(resource);
    });
  }



  /// Executes a transaction with automatic commit/rollback.
  ///
  /// This method provides transactional semantics by wrapping the callback
  /// execution in a BEGIN TRANSACTION...COMMIT TRANSACTION block. If the
  /// callback throws an exception, the transaction is automatically rolled back.
  ///
  /// All database operations performed within the callback function operate
  /// within the transaction scope using the same database handle.
  ///
  /// Parameters:
  /// - [callback] - Async function that performs database operations
  ///
  /// Returns the value returned by the callback function.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [TransactionException] if begin, commit, or rollback fails
  /// - Any exception thrown by the callback (after rollback)
  ///
  /// Example:
  /// ```dart
  /// final result = await db.transaction((txn) async {
  ///   // Create account
  ///   final account = await txn.createQL("account", {"balance": 100});
  ///   // Create related transaction record
  ///   await txn.createQL("transaction", {
  ///     "account_id": account["id"],
  ///     "amount": 100,
  ///     "type": "deposit"
  ///   });
  ///   return account;
  /// });
  /// // If any operation fails, both creates are rolled back
  /// print("Account created: ${result["id"]}");
  /// ```
  Future<T> transaction<T>(Future<T> Function(Database txn) callback) async {
    _ensureNotClosed();

    return Future(() async {
      // BEGIN TRANSACTION
      final beginResult = dbBegin(_handle);
      if (beginResult != 0) {
        final error = _getLastErrorString();
        throw TransactionException(error ?? "Failed to begin transaction");
      }

      try {
        // Execute callback with this database instance
        // The callback uses the same handle which is now in transaction mode
        final result = await callback(this);

        // COMMIT TRANSACTION
        final commitResult = dbCommit(_handle);
        if (commitResult != 0) {
          final error = _getLastErrorString();
          throw TransactionException(error ?? "Failed to commit transaction");
        }

        return result;
      } catch (e) {
        // ROLLBACK TRANSACTION on any exception
        try {
          final rollbackResult = dbRollback(_handle);
          if (rollbackResult != 0) {
            final error = _getLastErrorString();
            // Log rollback failure but rethrow original exception
            print("Warning: Rollback failed: $error");
          }
        } catch (_) {
          // Ignore rollback errors and rethrow original exception
        }
        rethrow;
      }
    });
  }

  /// Executes a manual schema migration.
  ///
  /// This method manually triggers a migration using the table definitions
  /// provided during connection. It allows control over when migrations
  /// are applied, as opposed to automatic migration on connect.
  ///
  /// ## Parameters
  ///
  /// [dryRun] - Whether to preview changes without applying (default: false)
  /// [allowDestructiveMigrations] - Whether to allow destructive changes (default: false)
  ///
  /// Returns a [MigrationReportImpl] with details of the migration.
  ///
  /// Throws [StateError] if no table definitions were provided during connection.
  /// Throws [MigrationException] if migration fails or destructive changes are blocked.
  ///
  /// ## Example: Preview Migration
  ///
  /// ```dart
  /// final preview = await db.migrate(dryRun: true);
  /// print('Would add tables: ${preview.tablesAdded}');
  /// print('Would add fields: ${preview.fieldsAdded}');
  /// print('Generated DDL: ${preview.generatedDDL}');
  /// ```
  ///
  /// ## Example: Apply Migration
  ///
  /// ```dart
  /// try {
  ///   final report = await db.migrate();
  ///   print('Migration succeeded');
  ///   print('Tables added: ${report.tablesAdded}');
  /// } catch (e) {
  ///   if (e is MigrationException && e.isDestructive) {
  ///     print('Destructive changes detected');
  ///     print('Enable allowDestructiveMigrations to proceed');
  ///   }
  /// }
  /// ```
  ///
  /// ## Example: Allow Destructive Changes
  ///
  /// ```dart
  /// final report = await db.migrate(
  ///   allowDestructiveMigrations: true,
  /// );
  /// print('Migration completed with destructive changes');
  /// print('Fields removed: ${report.fieldsRemoved}');
  /// ```
  Future<MigrationReportImpl> migrate({
    bool dryRun = false,
    bool allowDestructiveMigrations = false,
  }) async {
    _ensureNotClosed();

    if (_tableDefinitions == null || _tableDefinitions!.isEmpty) {
      throw StateError(
        'Cannot migrate: No table definitions provided during Database.connect(). '
        'To use migrations, provide tableDefinitions parameter when connecting.',
      );
    }

    final engine = MigrationEngine();
    return await engine.executeMigration(
      this,
      _tableDefinitions!,
      allowDestructiveMigrations: allowDestructiveMigrations,
      dryRun: dryRun,
    );
  }

  /// Rolls back to the previous migration.
  ///
  /// This method retrieves the last two successful migrations from the migration
  /// history, calculates the difference between the current schema and the
  /// previous snapshot, generates reverse DDL, and executes the rollback within
  /// a transaction.
  ///
  /// ## When to Use
  ///
  /// Use this method when you need to revert schema changes after a migration:
  /// - A migration caused unexpected issues in production
  /// - You need to temporarily revert to debug a problem
  /// - A destructive migration needs to be undone
  ///
  /// ## Requirements
  ///
  /// - At least 2 successful migrations must exist in history
  /// - The rollback may require `allowDestructiveMigrations: true` if it involves data loss
  ///
  /// ## Transaction Safety
  ///
  /// The rollback executes within a transaction. If any DDL statement fails,
  /// the entire rollback is automatically reverted, leaving the schema unchanged.
  ///
  /// [allowDestructiveMigrations] - Whether to allow destructive changes during rollback (default: false)
  /// [dryRun] - Whether to preview rollback without applying (default: false)
  ///
  /// Returns a [MigrationReportImpl] with details of the rollback operation.
  ///
  /// Throws [MigrationException] if:
  /// - Fewer than 2 successful migrations exist
  /// - Rollback would be destructive and allowDestructiveMigrations is false
  /// - Rollback execution fails
  ///
  /// Example:
  /// ```dart
  /// // Preview rollback
  /// final preview = await db.rollbackMigration(dryRun: true);
  /// print('Rollback would: ${preview.summary}');
  ///
  /// // Execute rollback
  /// final result = await db.rollbackMigration(
  ///   allowDestructiveMigrations: true,
  /// );
  ///
  /// if (result.success) {
  ///   print('Rolled back successfully');
  ///   print('Removed ${result.fieldsRemoved} fields');
  /// }
  /// ```
  Future<MigrationReportImpl> rollbackMigration({
    bool allowDestructiveMigrations = false,
    bool dryRun = false,
  }) async {
    _ensureNotClosed();

    final engine = MigrationEngine();
    return await engine.rollbackMigration(
      this,
      allowDestructiveMigrations: allowDestructiveMigrations,
      dryRun: dryRun,
    );
  }


  // ============================================================================
  // Vector Similarity Search Methods (Task Group 3)
  // ============================================================================

  /// Performs vector similarity search on a vector field.
  ///
  /// This method searches for similar vectors in a table using the specified
  /// distance metric and returns results ordered by similarity (distance).
  ///
  /// ## CRITICAL: Vector Storage Requirements
  ///
  /// **SCHEMAFULL tables MUST define vector fields as `array<float>` or `array<number>`!**
  ///
  /// Using just `array` will cause vectors to be stored as empty arrays.
  ///
  /// ✅ Correct:
  /// ```
  /// DEFINE TABLE docs SCHEMAFULL;
  /// DEFINE FIELD embedding ON docs TYPE array<float>;
  /// ```
  ///
  /// ❌ Incorrect (vectors will be empty):
  /// ```
  /// DEFINE TABLE docs SCHEMAFULL;
  /// DEFINE FIELD embedding ON docs TYPE array;
  /// ```
  ///
  /// For schemaless tables, vectors are stored correctly without type specification.
  ///
  /// ## Distance Metrics
  ///
  /// - **Euclidean**: Straight-line distance (L2 norm) - best for general-purpose
  /// - **Cosine**: Angle-based similarity - best for text embeddings
  /// - **Manhattan**: Taxicab distance (L1 norm) - best for high-dimensional spaces
  /// - **Minkowski**: Generalized distance - best for specialized applications
  ///
  /// ## Query Generation
  ///
  /// Generates SurrealQL:
  /// ```
  /// SELECT *, vector::similarity::metric(field, $queryVector) AS distance
  /// FROM table
  /// WHERE [conditions]
  /// ORDER BY distance [ASC|DESC]
  /// LIMIT n
  /// ```
  ///
  /// Parameters:
  /// - [table] - The table name to search
  /// - [field] - The vector field name to search on
  /// - [queryVector] - The query vector to compare against
  /// - [metric] - The distance metric to use
  /// - [limit] - Maximum number of results (default: 10)
  /// - [where] - Optional WHERE conditions for filtering
  /// - [orderBy] - Optional field to order by (after distance)
  /// - [ascending] - Sort direction for orderBy (default: true)
  ///
  /// Returns a list of SimilarityResult objects ordered by distance.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if table or field name is empty
  /// - [QueryException] if search operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// // Basic similarity search
  /// final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
  /// final results = await db.searchSimilar(
  ///   table: 'documents',
  ///   field: 'embedding',
  ///   queryVector: queryVector,
  ///   metric: DistanceMetric.euclidean,
  ///   limit: 10,
  /// );
  ///
  /// for (final result in results) {
  ///   print('${result.record['title']}: distance = ${result.distance}');
  /// }
  ///
  /// // Search with filtering
  /// final filtered = await db.searchSimilar(
  ///   table: 'documents',
  ///   field: 'embedding',
  ///   queryVector: queryVector,
  ///   metric: DistanceMetric.cosine,
  ///   limit: 5,
  ///   where: EqualsCondition('status', 'active'),
  /// );
  /// ```
  Future<List<SimilarityResult<Map<String, dynamic>>>> searchSimilar({
    required String table,
    required String field,
    required VectorValue queryVector,
    required DistanceMetric metric,
    int limit = 10,
    WhereCondition? where,
    String? orderBy,
    bool ascending = true,
  }) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'field', 'Field name cannot be empty');
    }

    return Future(() async {
      // Generate unique parameter name for query vector
      final vectorParamName = 'queryVector_${_paramCounter++}';

      // Bind query vector as parameter
      await set(vectorParamName, queryVector.toJson());

      try {
        // Build SurrealQL query using direct distance function
        // Note: KNN operator syntax is the modern approach but may not be supported
        // in all embedded SurrealDB versions yet. Using direct function calls ensures
        // compatibility while providing the same functionality.
        final queryBuffer = StringBuffer();

        // Build distance function call
        // Minkowski requires a third parameter (p value), default to 3
        final distanceFunction = metric == DistanceMetric.minkowski
            ? '${metric.toFullSurrealQLFunction()}($field, \$$vectorParamName, 3)'
            : '${metric.toFullSurrealQLFunction()}($field, \$$vectorParamName)';

        queryBuffer.write(
          'SELECT *, $distanceFunction AS distance FROM $table',
        );

        // Add WHERE clause if provided
        if (where != null) {
          final whereClause = where.toSurrealQL(this);
          queryBuffer.write(' WHERE $whereClause');
        }

        // Primary ordering is always by distance
        queryBuffer.write(' ORDER BY distance ${ascending ? 'ASC' : 'DESC'}');

        // Add secondary orderBy if provided
        if (orderBy != null && orderBy.isNotEmpty) {
          queryBuffer.write(', $orderBy ${ascending ? 'ASC' : 'DESC'}');
        }

        // Add LIMIT clause
        if (limit > 0) {
          queryBuffer.write(' LIMIT $limit');
        }

        final sqlQuery = queryBuffer.toString();

        // Execute query
        final sqlPtr = sqlQuery.toNativeUtf8();
        try {
          final responsePtr = dbQuery(_handle, sqlPtr);
          final data = _processResponse(responsePtr);

          // Process results into SimilarityResult objects
          if (data is List && data.isNotEmpty) {
            final firstElement = data.first;
            final List<dynamic> records;

            if (firstElement is List) {
              records = firstElement;
            } else {
              records = data;
            }

            // Parse each record into SimilarityResult
            final results = <SimilarityResult<Map<String, dynamic>>>[];
            for (final record in records) {
              if (record is Map<String, dynamic>) {
                try {
                  final result = SimilarityResult<Map<String, dynamic>>.fromJson(record);
                  results.add(result);
                } catch (e) {
                  throw QueryException(
                    'Failed to parse similarity result: $e. '
                    'Ensure query includes distance field.',
                  );
                }
              }
            }

            return results;
          }

          return <SimilarityResult<Map<String, dynamic>>>[];
        } finally {
          malloc.free(sqlPtr);
        }
      } finally {
        // Clean up parameter
        await unset(vectorParamName);
      }
    });
  }

  /// Performs batch similarity search on multiple query vectors.
  ///
  /// This method executes multiple similarity searches in sequence and returns
  /// results mapped by the input vector index. Each query vector gets its own
  /// result set.
  ///
  /// ## Use Cases
  ///
  /// - Compare multiple query vectors against the same dataset
  /// - Find similar documents for multiple embeddings in one call
  /// - Batch process search queries for efficiency
  ///
  /// ## Performance
  ///
  /// Queries are executed sequentially. For very large batch sizes, consider
  /// splitting into smaller batches.
  ///
  /// Parameters:
  /// - [table] - The table name to search
  /// - [field] - The vector field name to search on
  /// - [queryVectors] - List of query vectors to search with
  /// - [metric] - The distance metric to use
  /// - [limit] - Maximum number of results per query (default: 10)
  ///
  /// Returns a map of input index to result list. Each entry contains the
  /// similarity results for the corresponding query vector.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if table or field name is empty
  /// - [QueryException] if any search operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// // Batch search with multiple vectors
  /// final queryVectors = [
  ///   VectorValue.f32([1.0, 0.0, 0.0]),
  ///   VectorValue.f32([0.0, 1.0, 0.0]),
  ///   VectorValue.f32([0.0, 0.0, 1.0]),
  /// ];
  ///
  /// final results = await db.batchSearchSimilar(
  ///   table: 'embeddings',
  ///   field: 'vector',
  ///   queryVectors: queryVectors,
  ///   metric: DistanceMetric.cosine,
  ///   limit: 5,
  /// );
  ///
  /// // Access results by input index
  /// for (var i = 0; i < queryVectors.length; i++) {
  ///   print('Results for query vector $i:');
  ///   for (final result in results[i]!) {
  ///     print('  - ${result.record['id']}: ${result.distance}');
  ///   }
  /// }
  /// ```
  Future<Map<int, List<SimilarityResult<Map<String, dynamic>>>>> batchSearchSimilar({
    required String table,
    required String field,
    required List<VectorValue> queryVectors,
    required DistanceMetric metric,
    int limit = 10,
  }) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'field', 'Field name cannot be empty');
    }

    // Handle empty query list
    if (queryVectors.isEmpty) {
      return {};
    }

    return Future(() async {
      final results = <int, List<SimilarityResult<Map<String, dynamic>>>>{};

      // Execute searches sequentially
      for (var i = 0; i < queryVectors.length; i++) {
        final queryResults = await searchSimilar(
          table: table,
          field: field,
          queryVector: queryVectors[i],
          metric: metric,
          limit: limit,
        );

        results[i] = queryResults;
      }

      return results;
    });
  }

  // ============================================================================
  // Vector Index Management
  // ============================================================================

  /// Creates a vector index for efficient similarity search.
  ///
  /// Vector indexes enable fast nearest neighbor searches on high-dimensional
  /// vector embeddings. Without an index, searches perform brute-force comparison
  /// against all records, which is slow for large datasets.
  ///
  /// ## IMPORTANT: Vector Field Type Requirement
  ///
  /// Before creating an index, ensure your vector field is defined as `array<float>`
  /// or `array<number>` in SCHEMAFULL tables. Using just `array` will cause vectors
  /// to be stored as empty arrays and indexing will fail.
  ///
  /// ## Index Types
  ///
  /// - **HNSW**: Best for large datasets (>100,000 vectors). Fast approximate search.
  /// - **M-Tree**: Best for medium datasets (1,000-100,000 vectors). Balanced performance.
  /// - **FLAT**: Best for small datasets (<1,000 vectors). Exact search, no index overhead.
  /// - **AUTO**: Automatically selects index type based on dataset size.
  ///
  /// ## Parameters
  ///
  /// - [table] - Name of the table containing the vector field
  /// - [field] - Name of the vector field to index
  /// - [dimensions] - Number of dimensions in the vectors
  /// - [indexType] - Type of index structure (defaults to AUTO)
  /// - [metric] - Distance metric for similarity calculations (defaults to EUCLIDEAN)
  /// - [indexName] - Optional custom index name (auto-generated if not provided)
  /// - [hnswM] - HNSW parameter: connections per node (optional, HNSW only)
  /// - [hnswEfc] - HNSW parameter: construction candidate list size (optional, HNSW only)
  /// - [mtreeCapacity] - M-Tree parameter: node capacity (optional, M-Tree only)
  ///
  /// ## Returns
  ///
  /// The name of the created index.
  ///
  /// ## Throws
  ///
  /// - [StateError] if database is closed
  /// - [ArgumentError] if parameters are invalid
  /// - [QueryException] if index creation fails
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Create HNSW index for OpenAI ada-002 embeddings
  /// await db.createVectorIndex(
  ///   table: 'documents',
  ///   field: 'embedding',
  ///   dimensions: 1536,
  ///   indexType: IndexType.hnsw,
  ///   metric: DistanceMetric.cosine,
  ///   hnswM: 16,
  ///   hnswEfc: 200,
  /// );
  ///
  /// // Auto-select index type based on dataset size
  /// await db.createVectorIndex(
  ///   table: 'products',
  ///   field: 'image_vector',
  ///   dimensions: 512,
  ///   indexType: IndexType.auto,
  ///   metric: DistanceMetric.euclidean,
  /// );
  /// ```
  Future<String> createVectorIndex({
    required String table,
    required String field,
    required int dimensions,
    IndexType indexType = IndexType.auto,
    DistanceMetric metric = DistanceMetric.euclidean,
    String? indexName,
    int? hnswM,
    int? hnswEfc,
    int? mtreeCapacity,
  }) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'field', 'Field name cannot be empty');
    }

    return Future(() async {
      // Generate index name if not provided
      final effectiveIndexName = indexName ?? 'idx_${table}_${field}_vector';

      // Create index definition
      final indexDef = IndexDefinition(
        indexName: effectiveIndexName,
        tableName: table,
        fieldName: field,
        distanceMetric: metric,
        indexType: indexType,
        dimensions: dimensions,
        m: hnswM,
        efc: hnswEfc,
        capacity: mtreeCapacity,
      );

      // Generate and execute DEFINE INDEX statement
      final ddl = indexDef.toSurrealQL();
      await queryQL(ddl);

      return effectiveIndexName;
    });
  }

  /// Checks if a vector index exists on a specific field.
  ///
  /// Queries the database information schema to determine if a vector index
  /// exists for the specified table and field.
  ///
  /// ## Parameters
  ///
  /// - [table] - Name of the table to check
  /// - [field] - Name of the field to check for an index
  ///
  /// ## Returns
  ///
  /// `true` if a vector index exists on the field, `false` otherwise.
  ///
  /// ## Throws
  ///
  /// - [StateError] if database is closed
  /// - [ArgumentError] if table or field name is empty
  /// - [QueryException] if the query fails
  ///
  /// ## Example
  ///
  /// ```dart
  /// if (!await db.hasVectorIndex('documents', 'embedding')) {
  ///   await db.createVectorIndex(
  ///     table: 'documents',
  ///     field: 'embedding',
  ///     dimensions: 384,
  ///   );
  /// }
  /// ```
  Future<bool> hasVectorIndex(String table, String field) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'field', 'Field name cannot be empty');
    }

    return Future(() async {
      // Query information schema for indexes on this field
      final response = await queryQL('''
        SELECT * FROM information_schema.indexes
        WHERE table = '$table' AND fields CONTAINS '$field'
      ''');

      final results = response.getResults();
      return results.isNotEmpty;
    });
  }

  /// Drops a vector index from a table field.
  ///
  /// Removes the specified index from the database. This does not affect
  /// the underlying data, only the index structure used for optimization.
  ///
  /// ## Parameters
  ///
  /// - [table] - Name of the table containing the index
  /// - [field] - Name of the field with the index
  /// - [indexName] - Optional specific index name to drop. If not provided,
  ///   uses the auto-generated name pattern 'idx_{table}_{field}_vector'
  ///
  /// ## Throws
  ///
  /// - [StateError] if database is closed
  /// - [ArgumentError] if table or field name is empty
  /// - [QueryException] if the drop operation fails
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Drop auto-generated index
  /// await db.dropVectorIndex('documents', 'embedding');
  ///
  /// // Drop custom-named index
  /// await db.dropVectorIndex(
  ///   'documents',
  ///   'embedding',
  ///   indexName: 'my_custom_index',
  /// );
  /// ```
  Future<void> dropVectorIndex(
    String table,
    String field, {
    String? indexName,
  }) async {
    _ensureNotClosed();

    if (table.isEmpty) {
      throw ArgumentError.value(table, 'table', 'Table name cannot be empty');
    }
    if (field.isEmpty) {
      throw ArgumentError.value(field, 'field', 'Field name cannot be empty');
    }

    return Future(() async {
      // Use provided index name or generate default
      final effectiveIndexName = indexName ?? 'idx_${table}_${field}_vector';

      // Execute REMOVE INDEX statement
      await queryQL('REMOVE INDEX $effectiveIndexName ON $table');
    });
  }

  // ============================================================================
  // Type-Safe Query Builder Factory (Task Group 7)
  // ============================================================================
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

    // Capture handle before zeroing to prevent use-after-free
    // Any subsequent operations will see nullptr and fail safely
    final handleToClose = _handle;
    _handle = nullptr.cast<NativeDatabase>();

    return Future(() async {
      try {
        // Close the native database handle
        if (handleToClose != nullptr) {
          dbClose(handleToClose);
        }

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
  /// This is specifically for the queryQL() method which returns a Response
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

  // ============================================================================
  // Database Recovery Methods
  // ============================================================================

  /// Verifies the integrity of a RocksDB database without connecting.
  ///
  /// This static method checks the health of a RocksDB database by examining
  /// its critical files (MANIFEST, CURRENT) and attempting a read-only open.
  /// It works directly on file system paths, without establishing a database
  /// connection.
  ///
  /// This is useful for:
  /// - Detecting database corruption before connection attempts
  /// - Implementing recovery flows in your application
  /// - Health monitoring and diagnostics
  ///
  /// ## Health States
  ///
  /// - [DatabaseHealth.healthy]: Database is intact and can be opened
  /// - [DatabaseHealth.corrupted]: Database is corrupted but may be repairable via [repairRocksDB]
  /// - [DatabaseHealth.severelyCorrupted]: Database has severe corruption (missing CURRENT/MANIFEST)
  /// - [DatabaseHealth.error]: Verification failed due to an error
  ///
  /// Parameters:
  /// - [path] - The file system path to the RocksDB database directory
  ///   (NOT the rocksdb:// URL, just the path)
  ///
  /// Returns the health status of the database.
  ///
  /// Example:
  /// ```dart
  /// final dbPath = '/path/to/my/database';
  /// final health = await Database.verifyRocksDB(dbPath);
  ///
  /// switch (health) {
  ///   case DatabaseHealth.healthy:
  ///     print('Database is healthy, safe to connect');
  ///     break;
  ///   case DatabaseHealth.corrupted:
  ///     print('Database is corrupted, attempting repair...');
  ///     await Database.repairRocksDB(dbPath);
  ///     break;
  ///   case DatabaseHealth.severelyCorrupted:
  ///     print('Database is severely corrupted, consider restore or fresh start');
  ///     break;
  ///   case DatabaseHealth.error:
  ///     print('Verification error occurred');
  ///     break;
  /// }
  /// ```
  static Future<DatabaseHealth> verifyRocksDB(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path cannot be empty');
    }

    return Future(() {
      final pathPtr = path.toNativeUtf8();
      try {
        final result = dbVerifyRocksDB(pathPtr);
        return switch (result) {
          0 => DatabaseHealth.healthy,
          1 => DatabaseHealth.corrupted,
          2 => DatabaseHealth.severelyCorrupted,
          _ => DatabaseHealth.error,
        };
      } finally {
        malloc.free(pathPtr);
      }
    });
  }

  /// Attempts to repair a corrupted RocksDB database.
  ///
  /// This static method uses RocksDB's built-in repair functionality to attempt
  /// recovery of a corrupted database. It works directly on file system paths
  /// without establishing a database connection.
  ///
  /// ## When to Use
  ///
  /// Call this method when [verifyRocksDB] returns [DatabaseHealth.corrupted].
  /// For [DatabaseHealth.severelyCorrupted], repair may not succeed and you may
  /// need to restore from backup or start fresh.
  ///
  /// ## Important Notes
  ///
  /// - **Backup first**: Always backup your database directory before repair
  /// - **Closes existing connections**: This function will close any existing
  ///   connections to the database before attempting repair
  /// - **Data loss possible**: While repair tries to preserve data, some data
  ///   may be lost during the repair process
  /// - **Blocking operation**: Repair may take a long time for large databases
  ///
  /// Parameters:
  /// - [path] - The file system path to the RocksDB database directory
  ///   (NOT the rocksdb:// URL, just the path)
  ///
  /// Returns `true` if repair succeeded, `false` if repair failed.
  ///
  /// Example:
  /// ```dart
  /// final dbPath = '/path/to/my/database';
  ///
  /// // Always backup first
  /// await backupDatabase(dbPath);
  ///
  /// // Verify database health
  /// final health = await Database.verifyRocksDB(dbPath);
  /// if (health == DatabaseHealth.corrupted) {
  ///   print('Attempting repair...');
  ///   final success = await Database.repairRocksDB(dbPath);
  ///   if (success) {
  ///     print('Repair successful');
  ///     // Re-verify after repair
  ///     final newHealth = await Database.verifyRocksDB(dbPath);
  ///     if (newHealth == DatabaseHealth.healthy) {
  ///       // Safe to connect
  ///       final db = await Database.connect(
  ///         backend: StorageBackend.rocksdb,
  ///         path: dbPath,
  ///       );
  ///     }
  ///   } else {
  ///     print('Repair failed, restore from backup');
  ///   }
  /// }
  /// ```
  static Future<bool> repairRocksDB(String path) async {
    if (path.isEmpty) {
      throw ArgumentError.value(path, 'path', 'Path cannot be empty');
    }

    return Future(() {
      final pathPtr = path.toNativeUtf8();
      try {
        final result = dbRepairRocksDB(pathPtr);
        return result == 0;
      } finally {
        malloc.free(pathPtr);
      }
    });
  }
}

/// Health status of a RocksDB database.
///
/// Used by [Database.verifyRocksDB] to report database integrity status.
enum DatabaseHealth {
  /// Database is healthy and can be opened normally.
  healthy,

  /// Database is corrupted but may be repairable.
  ///
  /// This typically indicates missing SST files, corrupted MANIFEST,
  /// or other recoverable corruption. Use [Database.repairRocksDB] to
  /// attempt recovery.
  corrupted,

  /// Database has severe corruption that may not be repairable.
  ///
  /// This typically indicates missing CURRENT file, no MANIFEST files,
  /// or fundamental structure issues. Consider restoring from backup
  /// or starting fresh.
  severelyCorrupted,

  /// An error occurred during verification.
  ///
  /// This may indicate lock issues, permission problems, or other
  /// system-level errors. Check error logs for details.
  error,
}
