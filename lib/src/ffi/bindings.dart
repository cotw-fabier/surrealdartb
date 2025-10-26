/// Low-level FFI bindings to the Rust SurrealDB library.
///
/// This library provides direct access to the native functions exported
/// by the Rust FFI layer. These functions should not be called directly
/// by application code - instead, use the high-level Database API.
///
/// All functions in this library use direct FFI calls for asynchronous
/// operations to ensure non-blocking behavior.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'native_types.dart';

/// The native library instance.
///
/// This DynamicLibrary provides access to all native functions exported
/// by the Rust FFI layer. It is initialized once and reused for all
/// FFI function lookups.
///
/// The library is loaded differently based on platform:
/// - Process-embedded library (recommended)
/// - Platform-specific dynamic library loading
late final DynamicLibrary _nativeLib = _loadNativeLibrary();

/// Loads the native library for the current platform.
///
/// This function attempts to load the native library using the most
/// appropriate method for each platform. It first tries to load via
/// DynamicLibrary.process() which works when the library is embedded
/// in the process. If that fails, it falls back to platform-specific
/// loading methods.
///
/// Returns: DynamicLibrary instance for accessing native functions
/// Throws: Error if library cannot be loaded
DynamicLibrary _loadNativeLibrary() {
  try {
    // Try loading from process first (works with native assets)
    return DynamicLibrary.process();
  } catch (_) {
    // Fall back to platform-specific loading
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libsurrealdartb_bindings.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.executable();
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('surrealdartb_bindings.dll');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libsurrealdartb_bindings.so');
    } else {
      throw UnsupportedError(
        'Platform ${Platform.operatingSystem} is not supported',
      );
    }
  }
}

//
// Logging Operations
//

/// Initializes the Rust logger for FFI debugging.
///
/// This function initializes env_logger to enable logging from Rust code.
/// Call this once at the start of your application before making any other
/// FFI calls to enable Rust-level logging output.
///
/// Logging can be controlled via the RUST_LOG environment variable:
/// - RUST_LOG=error - Only errors
/// - RUST_LOG=warn  - Warnings and errors
/// - RUST_LOG=info  - Info, warnings, and errors (recommended for debugging)
/// - RUST_LOG=debug - Debug plus above (includes detailed response data)
/// - RUST_LOG=trace - All logs including trace level
///
/// This function is idempotent and safe to call multiple times. Only the
/// first call will initialize the logger.
@Native<NativeInitLogger>(symbol: 'init_logger', assetId: 'package:surrealdartb/surrealdartb_bindings')
external void initLogger();

//
// Database Lifecycle Operations
//

/// Creates a new database instance with the specified endpoint.
///
/// This function allocates a new SurrealDB instance and returns an opaque
/// handle. The handle must be freed using [dbClose] when no longer needed.
///
/// Parameters:
/// - [endpoint] - Database endpoint string (e.g., "mem://", "file://path")
///
/// Returns: Opaque pointer to the database instance
///
/// Note: This function does not establish a connection. Call [dbConnect]
/// to actually connect to the database.
@Native<NativeDbNew>(symbol: 'db_new', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeDatabase> dbNew(Pointer<Utf8> endpoint);

/// Connects to the database.
///
/// This function establishes a connection to the database instance
/// created by [dbNew]. It is an async operation that blocks the calling
/// thread until the connection is established.
///
/// Parameters:
/// - [handle] - Database handle from [dbNew]
///
/// Returns: 0 on success, negative error code on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbConnect>(symbol: 'db_connect', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbConnect(Pointer<NativeDatabase> handle);

/// Sets the active namespace for the database.
///
/// All subsequent operations will be performed within this namespace
/// until changed by another call to this function.
///
/// Parameters:
/// - [handle] - Database handle
/// - [namespace] - Namespace name as UTF-8 string
///
/// Returns: 0 on success, negative error code on failure
@Native<NativeDbUseNs>(symbol: 'db_use_ns', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbUseNs(Pointer<NativeDatabase> handle, Pointer<Utf8> namespace);

/// Sets the active database for the database instance.
///
/// All subsequent operations will be performed within this database
/// until changed by another call to this function.
///
/// Parameters:
/// - [handle] - Database handle
/// - [database] - Database name as UTF-8 string
///
/// Returns: 0 on success, negative error code on failure
@Native<NativeDbUseDb>(symbol: 'db_use_db', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbUseDb(Pointer<NativeDatabase> handle, Pointer<Utf8> database);

/// Closes the database connection and frees resources.
///
/// This function should be called when the database is no longer needed.
/// After calling this function, the handle is invalid and must not be used.
///
/// Parameters:
/// - [handle] - Database handle to close
///
/// Note: This function is also registered as a NativeFinalizer callback
/// for automatic cleanup when the Dart object is garbage collected.
@Native<NativeDbClose>(symbol: 'db_close', assetId: 'package:surrealdartb/surrealdartb_bindings')
external void dbClose(Pointer<NativeDatabase> handle);

//
// Transaction Operations
//

/// Begins a transaction.
///
/// This function starts a new transaction. All subsequent operations
/// on this handle will be part of the transaction until [dbCommit] or
/// [dbRollback] is called.
///
/// Parameters:
/// - [handle] - Database handle
///
/// Returns: 0 on success, -1 on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbTransaction>(symbol: 'db_begin', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbBegin(Pointer<NativeDatabase> handle);

/// Commits a transaction.
///
/// This function commits the current transaction, making all changes
/// permanent. If the commit fails, the transaction remains active and
/// should be rolled back.
///
/// Parameters:
/// - [handle] - Database handle
///
/// Returns: 0 on success, -1 on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbTransaction>(symbol: 'db_commit', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbCommit(Pointer<NativeDatabase> handle);

/// Rolls back a transaction.
///
/// This function rolls back the current transaction, discarding all
/// changes made within the transaction.
///
/// Parameters:
/// - [handle] - Database handle
///
/// Returns: 0 on success, -1 on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbTransaction>(symbol: 'db_rollback', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbRollback(Pointer<NativeDatabase> handle);

//
// Query Execution
//

/// Executes a SurrealQL query.
///
/// This function executes the provided SQL query and returns an opaque
/// response handle. The response must be freed using [responseFree]
/// after extracting the results.
///
/// Parameters:
/// - [handle] - Database handle
/// - [sql] - SurrealQL query as UTF-8 string
///
/// Returns: Opaque pointer to query response, or nullptr on error
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbQuery>(symbol: 'db_query', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbQuery(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> sql,
);

/// Retrieves results from a query response.
///
/// This function extracts the results from a response handle and returns
/// them as a JSON string. The returned string must be freed using
/// [freeString] after use.
///
/// Parameters:
/// - [handle] - Response handle from query operation
///
/// Returns: JSON string containing query results
@Native<NativeResponseGetResults>(symbol: 'response_get_results', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<Utf8> responseGetResults(Pointer<NativeResponse> handle);

/// Checks if a response contains errors.
///
/// Parameters:
/// - [handle] - Response handle
///
/// Returns: 1 if response has errors, 0 otherwise
@Native<NativeResponseHasErrors>(symbol: 'response_has_errors', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int responseHasErrors(Pointer<NativeResponse> handle);

/// Frees a response handle.
///
/// This function must be called for every response handle returned by
/// query operations to avoid memory leaks.
///
/// Parameters:
/// - [handle] - Response handle to free
@Native<NativeResponseFree>(symbol: 'response_free', assetId: 'package:surrealdartb/surrealdartb_bindings')
external void responseFree(Pointer<NativeResponse> handle);

//
// CRUD Operations
//

/// Selects all records from a table.
///
/// Parameters:
/// - [handle] - Database handle
/// - [table] - Table name as UTF-8 string
///
/// Returns: Response handle with query results
@Native<NativeDbSelect>(symbol: 'db_select', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbSelect(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> table,
);

/// Gets a specific record by resource identifier.
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id")
///
/// Returns: Response handle with the record (or null if not found)
@Native<NativeDbGet>(symbol: 'db_get', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbGet(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
);

/// Creates a new record in a table.
///
/// Parameters:
/// - [handle] - Database handle
/// - [table] - Table name as UTF-8 string
/// - [data] - Record data as JSON string
///
/// Returns: Response handle with created record
@Native<NativeDbCreate>(symbol: 'db_create', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbCreate(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> table,
  Pointer<Utf8> data,
);

/// Updates an existing record.
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id")
/// - [data] - Update data as JSON string
///
/// Returns: Response handle with updated record
@Native<NativeDbUpdate>(symbol: 'db_update', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbUpdate(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

/// Deletes a record.
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id")
///
/// Returns: Response handle (empty on success)
@Native<NativeDbDelete>(symbol: 'db_delete', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbDelete(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
);

/// Upserts a record with CONTENT (full replacement).
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id", must be specific record)
/// - [data] - Record data as JSON string
///
/// Returns: Response handle with upserted record
@Native<NativeDbUpdate>(symbol: 'db_upsert_content', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbUpsertContent(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

/// Upserts a record with MERGE (field merging).
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id", must be specific record)
/// - [data] - Fields to merge as JSON string
///
/// Returns: Response handle with upserted record
@Native<NativeDbUpdate>(symbol: 'db_upsert_merge', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbUpsertMerge(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

/// Upserts a record with PATCH (JSON patch operations).
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Record identifier (e.g., "table:id", must be specific record)
/// - [patches] - JSON array of patch operations (RFC 6902 format)
///
/// Returns: Response handle with upserted record
@Native<NativeDbUpdate>(symbol: 'db_upsert_patch', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbUpsertPatch(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> patches,
);

/// Inserts a record with content.
///
/// Parameters:
/// - [handle] - Database handle
/// - [resource] - Resource identifier (table or table:id)
/// - [data] - Record data as JSON string
///
/// Returns: Response handle with inserted record
@Native<NativeDbInsert>(symbol: 'db_insert', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbInsert(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> resource,
  Pointer<Utf8> data,
);

//
// Authentication Operations
//

/// Signs in with credentials and returns a JWT token.
///
/// Parameters:
/// - [handle] - Database handle
/// - [credentialsJson] - JSON-serialized credentials
///
/// Returns: Pointer to C string containing JWT token JSON, or nullptr on error
///
/// Embedded mode limitations:
/// - Authentication may have reduced functionality
/// - Scope-based access control may not fully apply
/// - Token refresh not supported
@Native<NativeDbSignin>(symbol: 'db_signin', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<Utf8> dbSignin(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> credentialsJson,
);

/// Signs up a new user with scope credentials and returns a JWT token.
///
/// Parameters:
/// - [handle] - Database handle
/// - [credentialsJson] - JSON-serialized scope or record credentials
///
/// Returns: Pointer to C string containing JWT token JSON, or nullptr on error
///
/// Embedded mode limitations:
/// - Signup functionality may be limited
/// - User creation may not work as expected
@Native<NativeDbSignup>(symbol: 'db_signup', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<Utf8> dbSignup(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> credentialsJson,
);

/// Authenticates with an existing JWT token.
///
/// Parameters:
/// - [handle] - Database handle
/// - [token] - JWT token string
///
/// Returns: 0 on success, negative error code on failure
///
/// Embedded mode limitations:
/// - Token-based authentication may have limited functionality
/// - Token validation may not work as expected
@Native<NativeDbAuthenticate>(symbol: 'db_authenticate', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbAuthenticate(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> token,
);

/// Invalidates the current authentication session.
///
/// Parameters:
/// - [handle] - Database handle
///
/// Returns: 0 on success, negative error code on failure
///
/// Embedded mode limitations:
/// - Session invalidation may have limited effect
@Native<NativeDbInvalidate>(symbol: 'db_invalidate', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbInvalidate(Pointer<NativeDatabase> handle);

//
// Error Handling
//

/// Retrieves the last error message from thread-local storage.
///
/// This function should be called after any FFI function returns an
/// error code to get a human-readable error message.
///
/// Returns: UTF-8 string containing error message, must be freed with [freeString]
@Native<NativeGetLastError>(symbol: 'get_last_error', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<Utf8> getLastError();

/// Frees a string allocated by the native library.
///
/// This function must be called for every string returned by native
/// functions (error messages, query results, etc.) to avoid memory leaks.
///
/// Parameters:
/// - [ptr] - Pointer to UTF-8 string to free
@Native<NativeFreeString>(symbol: 'free_string', assetId: 'package:surrealdartb/surrealdartb_bindings')
external void freeString(Pointer<Utf8> ptr);

/// Sets a query parameter for the connection.
///
/// Parameters persist per connection and can be used in queries with $name syntax.
///
/// Parameters:
/// - [handle] - Database handle
/// - [name] - Parameter name as UTF-8 string
/// - [value] - Parameter value as JSON string
///
/// Returns: 0 on success, -1 on failure
@Native<NativeDbSet>(symbol: 'db_set', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbSet(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> name,
  Pointer<Utf8> value,
);

/// Unsets a query parameter from the connection.
///
/// Parameters:
/// - [handle] - Database handle
/// - [name] - Parameter name as UTF-8 string
///
/// Returns: 0 on success, -1 on failure
@Native<NativeDbUnset>(symbol: 'db_unset', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbUnset(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> name,
);

/// Executes a SurrealQL function.
///
/// Parameters:
/// - [handle] - Database handle
/// - [function] - Function name as UTF-8 string (e.g., "rand::float")
/// - [args] - JSON array of arguments as UTF-8 string (null for no arguments)
///
/// Returns: Response handle with function result
@Native<NativeDbRun>(symbol: 'db_run', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<NativeResponse> dbRun(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> function,
  Pointer<Utf8> args,
);

/// Gets the database version.
///
/// Parameters:
/// - [handle] - Database handle
///
/// Returns: UTF-8 string containing version (must be freed with freeString)
@Native<NativeDbVersion>(symbol: 'db_version', assetId: 'package:surrealdartb/surrealdartb_bindings')
external Pointer<Utf8> dbVersion(Pointer<NativeDatabase> handle);
