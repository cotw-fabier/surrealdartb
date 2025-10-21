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
/// Thread safety: Must only be accessed from the isolate that created it
final class NativeDatabase extends Opaque {}

/// Opaque handle to a native query response.
///
/// This handle represents the result of a query execution. It contains
/// the query results and any errors that occurred during execution.
/// The underlying memory is managed by Rust and must be freed using
/// the appropriate destructor function.
///
/// Lifetime: Created by query functions, destroyed by response_free()
/// Thread safety: Must only be accessed from the isolate that created it
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
