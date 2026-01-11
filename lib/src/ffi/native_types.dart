/// Opaque types for native FFI bindings.
///
/// These types represent native handles that are managed by the Rust FFI layer.
/// They cannot be instantiated directly from Dart and are only created by
/// native functions.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Opaque handle to a native SurrealDB database instance.
///
/// This handle is created by the Rust FFI layer and represents a connection
/// to a SurrealDB database. The underlying memory is managed by Rust and
/// must be freed using the appropriate destructor function.
///
/// Lifetime: Created by db_new(), destroyed by db_close()
/// Thread safety: Must be accessed from a single thread or properly synchronized
final class NativeDatabase extends Opaque {}

/// Opaque handle to a native query response.
///
/// This handle represents the result of a query execution. It contains
/// the query results and any errors that occurred during execution.
/// The underlying memory is managed by Rust and must be freed using
/// the appropriate destructor function.
///
/// Lifetime: Created by query functions, destroyed by response_free()
/// Thread safety: Must be accessed from a single thread or properly synchronized
final class NativeResponse extends Opaque {}

/// Type definition for native database destructor function.
///
/// This function pointer type matches the signature of the Rust function
/// that destroys a database handle and frees its memory.
typedef NativeDbDestructor = Void Function(Pointer<NativeDatabase>);

/// Type definition for native response destructor function.
///
/// This function pointer type matches the signature of the Rust function
/// that destroys a response handle and frees its memory.
typedef NativeResponseDestructor = Void Function(Pointer<NativeResponse>);

/// Type definition for database creation function.
///
/// Creates a new database instance with the specified endpoint.
/// Returns null on failure.
typedef NativeDbNew = Pointer<NativeDatabase> Function(Pointer<Utf8> endpoint);

/// Type definition for database connection function.
///
/// Connects to the database asynchronously.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbConnect = Int32 Function(Pointer<NativeDatabase> handle);

/// Type definition for namespace selection function.
///
/// Sets the active namespace for subsequent operations.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbUseNs = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> namespace,
);

/// Type definition for database selection function.
///
/// Sets the active database for subsequent operations.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbUseDb = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> database,
);

/// Type definition for database close function.
///
/// Closes the database connection and frees resources.
typedef NativeDbClose = Void Function(Pointer<NativeDatabase> handle);

/// Type definition for transaction operation function.
///
/// Begins, commits, or rolls back a transaction.
/// Returns 0 on success, -1 on failure.
typedef NativeDbTransaction = Int32 Function(Pointer<NativeDatabase> handle);

/// Type definition for query execution function.
///
/// Executes a SurrealQL query and returns a response handle.
/// Returns null on failure.
typedef NativeDbQuery = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> sql,
);

/// Type definition for select operation.
///
/// Selects all records from a table.
/// Returns null on failure.
typedef NativeDbSelect = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> table,
);

/// Type definition for get operation.
///
/// Gets a specific record by resource identifier.
/// Returns null on failure.
typedef NativeDbGet = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
);

/// Type definition for create operation.
///
/// Creates a new record in a table.
/// Returns null on failure.
typedef NativeDbCreate = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> table,
  Pointer<Utf8> data,
);

/// Type definition for update operation.
///
/// Updates an existing record.
/// Returns null on failure.
typedef NativeDbUpdate = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

/// Type definition for delete operation.
///
/// Deletes a record.
/// Returns null on failure.
typedef NativeDbDelete = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
);

/// Type definition for insert operation.
///
/// Inserts a record with content.
/// Returns null on failure.
typedef NativeDbInsert = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

/// Type definition for signin operation.
///
/// Signs in with credentials and returns a JWT token.
/// Returns null on failure.
typedef NativeDbSignin = Pointer<Utf8> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> credentialsJson,
);

/// Type definition for signup operation.
///
/// Signs up a new user and returns a JWT token.
/// Returns null on failure.
typedef NativeDbSignup = Pointer<Utf8> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> credentialsJson,
);

/// Type definition for authenticate operation.
///
/// Authenticates with an existing JWT token.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbAuthenticate = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> token,
);

/// Type definition for invalidate operation.
///
/// Invalidates the current authentication session.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbInvalidate = Int32 Function(Pointer<NativeDatabase> handle);

/// Type definition for getting query results.
///
/// Returns a JSON string containing query results.
/// Caller must free the returned string.
typedef NativeResponseGetResults = Pointer<Utf8> Function(
  Pointer<NativeResponse> handle,
);

/// Type definition for checking if response has errors.
///
/// Returns 1 if errors exist, 0 otherwise.
typedef NativeResponseHasErrors = Int32 Function(
  Pointer<NativeResponse> handle,
);

/// Type definition for freeing a response handle.
///
/// Frees memory associated with a response handle.
typedef NativeResponseFree = Void Function(Pointer<NativeResponse> handle);

/// Type definition for getting last error message.
///
/// Returns error message string from thread-local storage.
/// Caller must free the returned string.
typedef NativeGetLastError = Pointer<Utf8> Function();

/// Type definition for freeing error string.
///
/// Frees a string allocated by the native layer.
typedef NativeFreeString = Void Function(Pointer<Utf8> ptr);

/// Type definition for set parameter operation.
///
/// Sets a query parameter for the connection.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbSet = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> name,
  Pointer<Utf8> value,
);

/// Type definition for unset parameter operation.
///
/// Removes a query parameter from the connection.
/// Returns 0 on success, negative error code on failure.
typedef NativeDbUnset = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> name,
);

/// Type definition for function execution operation.
///
/// Executes a SurrealQL function with optional arguments.
/// Returns null on failure.
typedef NativeDbRun = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> function,
  Pointer<Utf8> args,
);

/// Type definition for version query operation.
///
/// Returns the database version string.
/// Caller must free the returned string.
typedef NativeDbVersion = Pointer<Utf8> Function(Pointer<NativeDatabase> handle);

/// Type definition for logger initialization function.
///
/// Initializes the Rust env_logger for debugging FFI operations.
/// This function is idempotent and safe to call multiple times.
/// Should be called before any other FFI operations to enable Rust logging.
typedef NativeInitLogger = Void Function();

/// Type definition for RocksDB repair function.
///
/// Attempts to repair a corrupted RocksDB database at the specified path.
/// This function works directly on the file system, not through SurrealDB.
///
/// Returns:
/// - 0 on successful repair
/// - -1 on failure (call getLastError for details)
typedef NativeDbRepairRocksDB = Int32 Function(Pointer<Utf8> path);

/// Type definition for RocksDB verification function.
///
/// Checks the integrity of a RocksDB database at the specified path.
/// This function works directly on the file system, not through SurrealDB.
///
/// Returns:
/// - 0 if database is healthy (or path doesn't exist)
/// - 1 if database is corrupted but likely repairable
/// - 2 if database has severe corruption
/// - -1 on error (call getLastError for details)
typedef NativeDbVerifyRocksDB = Int32 Function(Pointer<Utf8> path);
