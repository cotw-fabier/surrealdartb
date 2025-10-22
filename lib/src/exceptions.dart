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
