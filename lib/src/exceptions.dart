/// Exception types for SurrealDB database operations.
///
/// This library defines a hierarchy of exceptions that can be thrown
/// during database operations, providing clear error context and
/// allowing for specific error handling.
library;

/// Base exception class for all database-related errors.
///
/// This exception is thrown when a database operation fails. It includes
/// the error message, optional error code from the native layer, and
/// optional native stack trace information.
///
/// Specific error types extend this class to provide more context about
/// the type of failure that occurred.
class DatabaseException implements Exception {
  /// Creates a database exception with the given message.
  ///
  /// [message] - Human-readable description of the error
  /// [errorCode] - Optional native error code (negative values indicate errors)
  /// [nativeStackTrace] - Optional stack trace from native code
  DatabaseException(
    this.message, {
    this.errorCode,
    this.nativeStackTrace,
  });

  /// Human-readable error message describing what went wrong.
  final String message;

  /// Error code from the native layer, if available.
  ///
  /// Convention:
  /// - 0: Success (should not have exception)
  /// - Negative values: Various error conditions
  final int? errorCode;

  /// Stack trace from native code, if available.
  ///
  /// This may be populated by the Rust FFI layer to provide
  /// additional debugging context about where the error originated.
  final String? nativeStackTrace;

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a database connection operation fails.
///
/// This includes failures to:
/// - Create a new database instance
/// - Connect to an existing database
/// - Initialize storage backend
/// - Establish communication with the database
///
/// Example:
/// ```dart
/// try {
///   final db = await Database.connect(
///     backend: StorageBackend.rocksdb,
///     path: '/invalid/path',
///   );
/// } catch (e) {
///   if (e is ConnectionException) {
///     print('Failed to connect: ${e.message}');
///   }
/// }
/// ```
class ConnectionException extends DatabaseException {
  /// Creates a connection exception.
  ConnectionException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ConnectionException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a query execution fails.
///
/// This includes failures during:
/// - SurrealQL query parsing
/// - Query execution
/// - Result retrieval
/// - Invalid query syntax
/// - Runtime query errors
///
/// Example:
/// ```dart
/// try {
///   final result = await db.query('INVALID SYNTAX');
/// } catch (e) {
///   if (e is QueryException) {
///     print('Query failed: ${e.message}');
///   }
/// }
/// ```
class QueryException extends DatabaseException {
  /// Creates a query exception.
  QueryException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('QueryException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when an authentication operation fails.
///
/// This includes failures during:
/// - User signin with credentials
/// - User signup with scope credentials
/// - JWT token authentication
/// - Session invalidation
/// - Permission checks
/// - Authorization validation
///
/// Example:
/// ```dart
/// try {
///   final jwt = await db.signin(credentials);
/// } catch (e) {
///   if (e is AuthenticationException) {
///     print('Authentication failed: ${e.message}');
///   }
/// }
/// ```
class AuthenticationException extends DatabaseException {
  /// Creates an authentication exception.
  AuthenticationException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AuthenticationException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a transaction operation fails.
///
/// This includes failures during:
/// - Transaction begin
/// - Transaction commit
/// - Transaction rollback
/// - Transaction-scoped operations
///
/// Example:
/// ```dart
/// try {
///   await db.transaction((txn) async {
///     // Transaction operations...
///   });
/// } catch (e) {
///   if (e is TransactionException) {
///     print('Transaction failed: ${e.message}');
///   }
/// }
/// ```
class TransactionException extends DatabaseException {
  /// Creates a transaction exception.
  TransactionException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('TransactionException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a live query subscription fails.
///
/// This includes failures during:
/// - Live query subscription creation
/// - Live query notification processing
/// - Live query cancellation
/// - Stream creation or management
///
/// Example:
/// ```dart
/// try {
///   final stream = await db.select('person').live();
/// } catch (e) {
///   if (e is LiveQueryException) {
///     print('Live query failed: ${e.message}');
///   }
/// }
/// ```
class LiveQueryException extends DatabaseException {
  /// Creates a live query exception.
  LiveQueryException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('LiveQueryException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a parameter operation fails.
///
/// This includes failures during:
/// - Setting query parameters
/// - Unsetting query parameters
/// - Parameter validation
/// - Parameter serialization
///
/// Example:
/// ```dart
/// try {
///   await db.set('param_name', value);
/// } catch (e) {
///   if (e is ParameterException) {
///     print('Parameter operation failed: ${e.message}');
///   }
/// }
/// ```
class ParameterException extends DatabaseException {
  /// Creates a parameter exception.
  ParameterException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ParameterException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a database export operation fails.
///
/// This includes failures during:
/// - File creation or writing
/// - Data serialization
/// - Export operation execution
/// - Permission errors
///
/// Example:
/// ```dart
/// try {
///   await db.export('/path/to/backup.surql');
/// } catch (e) {
///   if (e is ExportException) {
///     print('Export failed: ${e.message}');
///   }
/// }
/// ```
class ExportException extends DatabaseException {
  /// Creates an export exception.
  ExportException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ExportException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a database import operation fails.
///
/// This includes failures during:
/// - File reading or parsing
/// - Data deserialization
/// - Import operation execution
/// - Permission errors
///
/// Example:
/// ```dart
/// try {
///   await db.import('/path/to/backup.surql');
/// } catch (e) {
///   if (e is ImportException) {
///     print('Import failed: ${e.message}');
///   }
/// }
/// ```
class ImportException extends DatabaseException {
  /// Creates an import exception.
  ImportException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ImportException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when data validation fails.
///
/// This exception is thrown by Dart-side validation when data doesn't
/// conform to a defined TableStructure schema. It provides field-level
/// error details to help developers fix validation issues.
///
/// This is distinct from [DatabaseException] which represents errors
/// from the SurrealDB database layer.
///
/// Example:
/// ```dart
/// try {
///   schema.validate({'title': 'Test'}); // missing required 'content' field
/// } catch (e) {
///   if (e is ValidationException) {
///     print('Validation failed on field: ${e.fieldName}');
///     print('Constraint: ${e.constraint}');
///   }
/// }
/// ```
class ValidationException extends DatabaseException {
  /// Creates a validation exception.
  ///
  /// [message] - Human-readable description of the validation failure
  /// [fieldName] - Optional name of the field that failed validation
  /// [constraint] - Optional description of the constraint that was violated
  ValidationException(
    super.message, {
    this.fieldName,
    this.constraint,
  });

  /// The name of the field that failed validation, if applicable.
  ///
  /// This helps developers identify exactly which field in their data
  /// caused the validation to fail.
  final String? fieldName;

  /// Description of the constraint that was violated, if applicable.
  ///
  /// Examples: 'required', 'dimension_mismatch', 'not_normalized', 'type_mismatch'
  final String? constraint;

  @override
  String toString() {
    final buffer = StringBuffer('ValidationException: $message');
    if (fieldName != null) {
      buffer.write(' (field: $fieldName)');
    }
    if (constraint != null) {
      buffer.write(' [constraint: $constraint]');
    }
    return buffer.toString();
  }
}

/// Exception thrown when schema introspection fails.
///
/// This exception is thrown when the system fails to query or parse
/// database schema information using INFO FOR DB or INFO FOR TABLE queries.
/// It provides clear diagnostic information about what went wrong during
/// schema discovery.
///
/// This is used by the migration detection system when introspecting
/// the current database schema to compare with code-defined schemas.
///
/// Example:
/// ```dart
/// try {
///   final snapshot = await DatabaseSchema.introspect(db);
/// } catch (e) {
///   if (e is SchemaIntrospectionException) {
///     print('Failed to introspect schema: ${e.message}');
///   }
/// }
/// ```
class SchemaIntrospectionException extends DatabaseException {
  /// Creates a schema introspection exception.
  ///
  /// [message] - Human-readable description of the introspection failure
  /// [errorCode] - Optional error code from the native layer
  /// [nativeStackTrace] - Optional stack trace from native code
  SchemaIntrospectionException(
    super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('SchemaIntrospectionException: $message');
    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }
    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a schema migration operation fails.
///
/// This exception is thrown when the migration system encounters errors
/// during schema migration execution, including:
/// - Destructive schema changes without explicit permission
/// - Migration execution failures
/// - DDL generation errors
/// - Transaction failures during migration
///
/// This exception includes a migration report with detailed information
/// about the attempted changes and a flag indicating if destructive
/// changes were involved.
///
/// Example:
/// ```dart
/// try {
///   await engine.executeMigration(db, tables);
/// } catch (e) {
///   if (e is MigrationException) {
///     print('Migration failed: ${e.message}');
///     if (e.isDestructive) {
///       print('Destructive changes detected:');
///       if (e.report != null) {
///         for (final table in e.report!.tablesRemoved) {
///           print('  - Table "$table" will be removed');
///         }
///       }
///     }
///   }
/// }
/// ```
class MigrationException extends DatabaseException {
  /// Creates a migration exception.
  ///
  /// [message] - Human-readable description of the migration failure
  /// [report] - Optional migration report with detailed change information
  /// [isDestructive] - Whether the migration involves destructive changes
  /// [errorCode] - Optional error code from the native layer
  /// [nativeStackTrace] - Optional stack trace from native code
  MigrationException(
    super.message, {
    this.report,
    this.isDestructive = false,
    super.errorCode,
    super.nativeStackTrace,
  });

  /// The migration report with detailed change information, if available.
  ///
  /// This provides information about tables, fields, and indexes that
  /// would be added, removed, or modified during the migration.
  final MigrationReport? report;

  /// Whether the migration involves destructive changes.
  ///
  /// Destructive changes include:
  /// - Removing tables
  /// - Removing fields
  /// - Changing field types
  /// - Making optional fields required
  final bool isDestructive;

  @override
  String toString() {
    // If the message already contains detailed information (from analyzer),
    // just return it with the exception prefix
    if (message.contains('DESTRUCTIVE CHANGES:')) {
      return 'MigrationException:\n$message';
    }

    final buffer = StringBuffer('MigrationException: $message');

    if (isDestructive) {
      buffer.write(' [DESTRUCTIVE]');
    }

    if (errorCode != null) {
      buffer.write(' (error code: $errorCode)');
    }

    if (report != null && isDestructive) {
      buffer.write('\n\nDestructive changes detected:');

      if (report!.tablesRemoved.isNotEmpty) {
        buffer.write('\n  Tables to be removed:');
        for (final table in report!.tablesRemoved) {
          buffer.write('\n    - $table');
        }
      }

      if (report!.fieldsRemoved.isNotEmpty) {
        buffer.write('\n  Fields to be removed:');
        for (final entry in report!.fieldsRemoved.entries) {
          for (final field in entry.value) {
            buffer.write('\n    - ${entry.key}.$field');
          }
        }
      }

      buffer.write('\n\nTo apply these changes:');
      buffer.write('\n  1. Set allowDestructiveMigrations: true');
      buffer.write('\n  2. OR fix schema to match database');
      buffer.write('\n  3. OR manually migrate data before applying changes');
    }

    if (nativeStackTrace != null) {
      buffer.write('\nNative stack trace:\n$nativeStackTrace');
    }

    return buffer.toString();
  }
}

/// Migration report class (forward reference for MigrationException).
///
/// This is a placeholder to avoid circular dependencies.
/// The actual implementation is in migration_engine.dart.
abstract class MigrationReport {
  /// List of tables that were removed.
  List<String> get tablesRemoved;

  /// Map of table names to lists of fields removed.
  Map<String, List<String>> get fieldsRemoved;

  /// Whether the migration involves destructive changes.
  bool get hasDestructiveChanges;
}
