# Export/Import Implementation Status

## Completed Work

### 5.1.1: Tests Written
- Created `/Users/fabier/Documents/code/surrealdartb/test/unit/export_import_test.dart` with 8 comprehensive tests covering:
  - Export creates file
  - Import loads from file
  - Round-trip export/import preserves data
  - Export/import with empty database
  - Export/import with multiple tables
  - Export error handling (invalid path)
  - Import error handling (non-existent file)
  - Import error handling (invalid file content)

### 5.1.2: Rust FFI Functions Implemented
- Added `db_export()` function in `/Users/fabier/Documents/code/surrealdartb/rust/src/query.rs` (lines 1563-1631)
- Added `db_import()` function in `/Users/fabier/Documents/code/surrealdartb/rust/src/query.rs` (lines 1633-1702)
- Both functions follow existing FFI patterns:
  - Wrapped with `panic::catch_unwind`
  - Null pointer validation
  - UTF-8 string validation
  - Error handling with `set_last_error()`
  - Return codes: 0 for success, -1 for failure
- Updated `/Users/fabier/Documents/code/surrealdartb/rust/src/lib.rs` to export new functions (line 49)

## Remaining Work

### 5.1.3 & 5.1.4: Dart FFI Bindings and Wrapper Methods

#### Step 1: Add FFI Type Definitions
Add to `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart`:

```dart
/// Function signature for db_export
typedef NativeDbExport = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> path,
);

/// Function signature for db_import
typedef NativeDbImport = Int32 Function(
  Pointer<NativeDatabase> handle,
  Pointer<Utf8> path,
);
```

#### Step 2: Add FFI Bindings
Add to `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart`:

```dart
//
// Data Export/Import Operations
//

/// Exports the database to a file.
///
/// This is a basic implementation that exports the entire database.
/// Advanced configuration options are deferred to a future iteration.
///
/// Parameters:
/// - [handle] - Database handle
/// - [path] - File path for export as UTF-8 string
///
/// Returns: 0 on success, -1 on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbExport>(symbol: 'db_export', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbExport(Pointer<NativeDatabase> handle, Pointer<Utf8> path);

/// Imports the database from a file.
///
/// This is a basic implementation that imports the entire file.
/// Advanced configuration options are deferred to a future iteration.
///
/// Parameters:
/// - [handle] - Database handle
/// - [path] - File path for import as UTF-8 string
///
/// Returns: 0 on success, -1 on failure
///
/// On error, call [getLastError] to retrieve the error message.
@Native<NativeDbImport>(symbol: 'db_import', assetId: 'package:surrealdartb/surrealdartb_bindings')
external int dbImport(Pointer<NativeDatabase> handle, Pointer<Utf8> path);
```

#### Step 3: Add Dart Wrapper Methods
Add to `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart` (after the existing methods):

```dart
/// Exports the database to a file.
///
/// This method exports the entire database content to the specified file path
/// in SurrealQL format. The exported file can later be imported using [import].
///
/// **Limitations:**
/// - This is a basic implementation with no advanced configuration options
/// - No table selection (exports entire database)
/// - No format options (always SurrealQL format)
/// - No ML model handling
/// - These features are deferred to a future iteration
///
/// Parameters:
/// - [path] - File system path where the export file will be created
///
/// Throws:
/// - [ExportException] if the export operation fails
/// - [StateError] if the database connection is closed
///
/// Example:
/// ```dart
/// await db.export('/path/to/backup.surql');
/// ```
Future<void> export(String path) async {
  _ensureNotClosed();

  return Future(() {
    final pathPtr = path.toNativeUtf8();
    try {
      final result = dbExport(_handle, pathPtr);
      if (result != 0) {
        final error = _getLastErrorString();
        throw ExportException(
          error ?? 'Failed to export database',
          errorCode: result,
        );
      }
    } finally {
      malloc.free(pathPtr);
    }
  });
}

/// Imports the database from a file.
///
/// This method imports database content from the specified file path.
/// The file must contain valid SurrealQL statements (typically created
/// by a previous call to [export]).
///
/// **Limitations:**
/// - This is a basic implementation with no advanced configuration options
/// - Imports the entire file contents
/// - No selective table import
/// - These features are deferred to a future iteration
///
/// Parameters:
/// - [path] - File system path to the import file
///
/// Throws:
/// - [ImportException] if the import operation fails
/// - [StateError] if the database connection is closed
///
/// Example:
/// ```dart
/// await db.import('/path/to/backup.surql');
/// ```
Future<void> import(String path) async {
  _ensureNotClosed();

  return Future(() {
    final pathPtr = path.toNativeUtf8();
    try {
      final result = dbImport(_handle, pathPtr);
      if (result != 0) {
        final error = _getLastErrorString();
        throw ImportException(
          error ?? 'Failed to import database',
          errorCode: result,
        );
      }
    } finally {
      malloc.free(pathPtr);
    }
  });
}
```

### 5.1.5: Documentation
The limitations are already documented in the dartdoc comments above. Key points:
- No advanced configuration support
- No table selection
- No format options
- No ML model handling
- Deferred to future iteration

### 5.1.6: Run Tests
After implementing the Dart bindings and methods:

```bash
cd /Users/fabier/Documents/code/surrealdartb
dart test test/unit/export_import_test.dart
```

Expected: All 8 tests should pass.

## Implementation Notes

### FFI Pattern Compliance
The implementation follows all existing patterns:
- **Error handling**: Uses `set_last_error()` in Rust, `_getLastErrorString()` in Dart
- **Memory management**: try/finally blocks for cleanup
- **Panic safety**: All Rust functions wrapped with `catch_unwind`
- **Null checking**: Validates all pointers before dereferencing
- **Return codes**: 0 for success, -1 for failure (consistent with other operations)

### Exception Types
Using `ExportException` and `ImportException` which were already defined in Task Group 1.2 (completed).

### SurrealDB API
The Rust implementation uses the native SurrealDB methods:
- `db.inner.export(path).await` - exports to file
- `db.inner.import(path).await` - imports from file

These are the standard SurrealDB embedded API methods that handle the file I/O and format automatically.
