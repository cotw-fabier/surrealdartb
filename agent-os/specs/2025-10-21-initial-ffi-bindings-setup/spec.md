# Specification: Initial FFI Bindings Setup

## Goal

Set up foundational Rust-to-Dart FFI infrastructure using native_toolchain_rs to bootstrap SurrealDB database operations with minimal feature set (kv-mem and kv-rocksdb), enabling async database operations through a background isolate architecture with automatic memory management.

## User Stories

- As a Dart developer, I want to initialize and connect to a SurrealDB database instance so that I can persist and query data locally
- As a developer, I want all database operations to be async so that my application remains responsive during database operations
- As a developer, I want automatic memory cleanup so that I don't have to manually manage native resources
- As a developer, I want clear error messages from native operations so that I can debug issues effectively
- As a CLI user, I want example scenarios demonstrating both in-memory and persistent storage so that I can understand how to use the library

## Core Requirements

### Functional Requirements

**FFI Infrastructure:**
- Build hook using native_toolchain_rs for automatic Rust compilation during Dart build
- Rust toolchain pinned to exact version 1.90.0
- Multi-platform target configuration (macOS, iOS, Android, Windows, Linux) with macOS as primary development platform
- Native asset name: `package:surrealdartb/surrealdartb_bindings`
- Opaque handle pattern for SurrealDB database and response objects
- NativeFinalizer for automatic resource cleanup tied to Dart GC lifecycle

**Database Lifecycle Operations:**
- Create new SurrealDB instance with endpoint specification (mem://, file path)
- Connect to database asynchronously
- Set namespace and database context (use_ns, use_db) asynchronously
- Close database and release all resources
- Support kv-mem (in-memory) and kv-rocksdb (persistent) storage backends only

**Query Execution:**
- Execute SurrealQL queries asynchronously
- Return opaque response handles for query results
- Parse and expose query results to Dart side
- Basic parameterized query support via bind operations

**CRUD Operations:**
- Select records from table (async)
- Create new records (async)
- Update existing records (async)
- Delete records (async)
- Mirror SurrealDB Rust SDK async patterns

**Error Handling:**
- Integer error code return pattern for FFI functions
- Separate function to retrieve error message strings
- Thread-local error state storage in Rust
- Propagate errors from background isolate to main thread via try/catch
- Convert error codes to meaningful Dart exceptions

**Async Architecture:**
- Dedicated background isolate for all database operations
- All database calls funneled through isolate for thread safety
- Future-based Dart API wrapping async FFI calls
- SendPort/ReceivePort communication between main thread and isolate
- Proper isolate cleanup on database close

**CLI Example Application:**
- Three choosable demonstration scenarios:
  1. Connect to database and verify connectivity
  2. Connect, create namespace/database, insert record, query back
  3. Demonstrate both mem:// and RocksDB storage backends
- Clear console output showing each operation step
- Error handling demonstration

### Non-Functional Requirements

**Performance:**
- Non-blocking async operations preventing UI thread jank
- Optimized Rust release builds with size optimization (opt-level = "z", LTO enabled)
- Minimal overhead for isolate communication

**Memory Safety:**
- Zero memory leaks in normal operation
- Proper cleanup via NativeFinalizer even on abnormal termination
- Safe string conversion between Dart and C boundaries
- Null pointer validation before all native dereferencing

**Thread Safety:**
- All database operations serialized through single background isolate
- No data races between Dart and Rust code
- Safe error propagation across isolate boundaries

**Code Quality:**
- Follow all agent-os standards for Dart and Rust integration
- Comprehensive inline documentation for FFI boundary contracts
- Clear documentation of memory ownership and lifetime expectations
- Document threading model and safety guarantees

## Visual Design

Not applicable - this is a foundational infrastructure feature without UI components.

## Reusable Components

### Existing Code to Leverage

No existing similar features identified. This is the foundational FFI layer that all future SurrealDB integration will build upon.

### New Components Required

**Core FFI Infrastructure:**
- `hook/build.dart` - Build hook with RustBuilder configuration for native asset compilation
- `rust-toolchain.toml` - Rust version pinning and multi-platform target configuration
- `Cargo.toml` - Rust library configuration with minimal SurrealDB features
- `lib/src/ffi/bindings.dart` - Low-level FFI function bindings and opaque types
- `lib/src/ffi/native_types.dart` - Opaque handle types for native objects
- `lib/src/ffi/ffi_utils.dart` - String conversion and memory management utilities

**Rust FFI Layer:**
- `rust/src/lib.rs` - Main Rust FFI entry point with panic safety wrappers
- `rust/src/database.rs` - Database lifecycle operations (new, connect, close)
- `rust/src/query.rs` - Query execution and response handling
- `rust/src/error.rs` - Error state management and message retrieval
- `rust/src/runtime.rs` - Tokio async runtime setup for SurrealDB operations

**Background Isolate Architecture:**
- `lib/src/isolate/database_isolate.dart` - Background isolate spawn and management
- `lib/src/isolate/isolate_messages.dart` - Message types for isolate communication
- `lib/src/isolate/isolate_commands.dart` - Command serialization for database operations

**High-Level Dart API:**
- `lib/src/database.dart` - Public Database class with async methods
- `lib/src/response.dart` - Response wrapper for query results
- `lib/src/exceptions.dart` - Custom exception types for database errors
- `lib/src/storage_backend.dart` - Storage backend enum (Mem, RocksDB)

**Example Application:**
- `example/cli_example.dart` - CLI app with interactive scenario selection
- `example/scenarios/connect_verify.dart` - Basic connectivity test
- `example/scenarios/crud_operations.dart` - Full CRUD demonstration
- `example/scenarios/storage_comparison.dart` - Mem vs RocksDB comparison

**Why new code is needed:** This is the initial FFI setup with no prior Rust-Dart integration in the codebase. All components are necessary to establish the foundational FFI bridge between Dart and SurrealDB's Rust implementation.

## Technical Approach

### Database Architecture

**Three-Layer Design:**

1. **Rust FFI Layer** - C-compatible functions wrapping SurrealDB Rust SDK
   - Panic safety via `std::panic::catch_unwind`
   - CString/CStr for string boundary crossing
   - Box::into_raw() for owned data passed to Dart
   - Thread-local error state for error propagation
   - Tokio runtime for async SurrealDB operations

2. **Dart FFI Bindings Layer** - Low-level FFI function declarations
   - Opaque types extending Opaque for native handles
   - `@Native` annotations for symbol resolution
   - Raw pointer management with NativeFinalizer attachment
   - String conversion utilities (Dart String ↔ Pointer<Utf8>)

3. **High-Level Dart API Layer** - Future-based async API
   - Background isolate wrapping all native calls
   - Public Database class with clean async methods
   - Automatic error conversion to exceptions
   - Resource lifecycle tied to Dart object lifetime

### API Design

**Core Database API:**
```dart
class Database {
  // Factory constructor with storage backend
  static Future<Database> connect({
    required StorageBackend backend,
    String? path, // Required for RocksDB, ignored for Mem
    String? namespace,
    String? database,
  });

  // Namespace and database selection
  Future<void> useNamespace(String namespace);
  Future<void> useDatabase(String database);

  // Query execution
  Future<Response> query(String sql, [Map<String, dynamic>? bindings]);

  // CRUD operations
  Future<List<Map<String, dynamic>>> select(String table);
  Future<Map<String, dynamic>> create(String table, Map<String, dynamic> data);
  Future<Map<String, dynamic>> update(String resource, Map<String, dynamic> data);
  Future<void> delete(String resource);

  // Resource cleanup
  Future<void> close();
}

enum StorageBackend {
  memory,  // mem://
  rocksdb, // file-based persistent storage
}
```

**Error Handling:**
```dart
class DatabaseException implements Exception {
  final String message;
  final int? errorCode;
  final String? nativeStackTrace;

  DatabaseException(this.message, {this.errorCode, this.nativeStackTrace});
}

// Specific error types
class ConnectionException extends DatabaseException { }
class QueryException extends DatabaseException { }
class AuthenticationException extends DatabaseException { }
```

**Response Handling:**
```dart
class Response {
  // Access query results
  List<Map<String, dynamic>> getResults();

  // Check for errors in specific statement
  bool hasErrors();
  List<String> getErrors();

  // Extract specific result by index
  dynamic takeResult(int index);
}
```

### Isolate Communication Pattern

**Message Flow:**
```
Main Thread                Background Isolate
    |                             |
    |--[Command + ResponsePort]-->|
    |                             |
    |                      [Execute FFI call]
    |                             |
    |<-----[Result/Error]---------|
    |                             |
```

**Command Types:**
- InitializeCommand - Set up native library and runtime
- ConnectCommand - Create and connect database instance
- QueryCommand - Execute SurrealQL query
- CrudCommand - Perform CRUD operation
- CloseCommand - Clean up and shutdown isolate

**Error Propagation:**
- Native errors captured as error codes
- Error messages retrieved via separate FFI function
- Wrapped in DatabaseException and sent through ReceivePort
- Propagated as Future.error to caller

### Memory Management Strategy

**Opaque Handle Pattern:**
- Dart wrapper classes hold `Pointer<NativeDatabase>`
- NativeFinalizer attached to wrapper object
- Finalizer calls Rust destructor function on GC
- Explicit `close()` methods for critical resources

**String Lifecycle:**
- Dart → Native: toNativeUtf8() allocates with malloc
- Native → Dart: toDartString() copies, then free original
- All allocations paired with free in try/finally blocks

**Response Lifecycle:**
- Query responses returned as opaque handles
- Consumed once by converting to Dart types
- Automatically freed after conversion via finalizer
- No manual memory management exposed to API users

### FFI Boundary Contracts

**Rust Side Guarantees:**
- Never panic across FFI boundary (use catch_unwind)
- Return error codes, never Result types
- Null pointer checks before all dereferencing
- Thread-safe or explicitly single-threaded (documented)
- Store error messages in thread-local storage

**Dart Side Guarantees:**
- Validate non-null before passing pointers to native
- Free all allocated strings in finally blocks
- Attach finalizers to all native resource wrappers
- Never expose raw Pointer types in public API
- Catch all exceptions in isolate message handlers

### Build System Integration

**Hook Implementation:**
```dart
// hook/build.dart
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'package:surrealdartb/surrealdartb_bindings',
    ).run(input: input, output: output);
  });
}
```

**Rust Configuration:**
```toml
# rust-toolchain.toml
[toolchain]
channel = "1.90.0"
targets = [
  "aarch64-apple-darwin",
  "x86_64-apple-darwin",
  "aarch64-apple-ios",
  "aarch64-linux-android",
  "armv7-linux-androideabi",
  "x86_64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
  "aarch64-unknown-linux-gnu"
]

# Cargo.toml
[lib]
crate-type = ["staticlib", "cdylib"]

[dependencies]
surrealdb = { version = "2.0", default-features = false, features = ["kv-mem", "kv-rocksdb"] }
tokio = { version = "1", features = ["rt-multi-thread"] }

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
strip = true
```

**Dependencies:**
```yaml
# pubspec.yaml additions
dependencies:
  ffi: ^2.1.0

dev_dependencies:
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: <commit-hash-to-be-determined>
```

### Async Runtime Architecture

**Tokio Integration:**
- Single-threaded or multi-threaded Tokio runtime
- Initialized once in background isolate
- All SurrealDB operations run on Tokio runtime
- Runtime shutdown on isolate cleanup

**Rust Async → Dart Future:**
```rust
// Rust side - block on async in FFI function
#[no_mangle]
pub extern "C" fn db_connect(handle: *mut Database, endpoint: *const c_char) -> i32 {
    // Panic safety wrapper
    std::panic::catch_unwind(|| {
        // Get or create Tokio runtime
        let runtime = get_runtime();

        // Block on async operation
        runtime.block_on(async {
            // SurrealDB async operation
            handle.connect(endpoint).await
        })
    }).unwrap_or(-1)
}
```

```dart
// Dart side - wrap in Future via isolate
Future<void> connect(String endpoint) async {
  final command = ConnectCommand(endpoint);
  _sendPort.send((command, responsePort.sendPort));

  final result = await responsePort.first;
  if (result is DatabaseException) {
    throw result;
  }
}
```

### Testing Strategy

**Rust Unit Tests:**
- Test database creation with various endpoints
- Test error handling and error message retrieval
- Test memory safety (no leaks, proper cleanup)
- Mock SurrealDB for isolated testing

**Dart Integration Tests:**
- Test FFI boundary crossing (strings, errors)
- Test isolate communication reliability
- Test finalizer cleanup (create many objects, force GC)
- Test both storage backends (mem, rocksdb)

**Example App as Manual Test:**
- Serves as integration test suite
- Demonstrates all major operations
- Validates error handling paths
- Confirms cross-platform compatibility (when tested)

### Platform Considerations

**Primary Platform:** macOS (Apple Silicon and Intel)
- Full development and testing
- Used for initial validation

**Configured Platforms:** iOS, Android, Windows, Linux
- Rust targets configured in toolchain
- Native asset compilation configured
- Testing deferred to future phases

**Platform-Specific Notes:**
- RocksDB path handling differs per platform
- File permissions vary per platform
- Document platform-specific limitations in README

## Out of Scope

**Advanced SurrealDB Features:**
- Vector indexing and similarity search
- Live queries and real-time subscriptions
- Graph traversal and complex queries
- Transactions with ACID guarantees
- Multi-statement transactions
- Subqueries and advanced SurrealQL
- Authentication and permissions
- User management and access control

**Remote Connectivity:**
- WebSocket connections to remote SurrealDB instances
- HTTP connections to SurrealDB server
- TLS/SSL configuration
- Connection pooling
- Reconnection logic

**Additional Storage Backends:**
- kv-tikv (TiKV backend)
- kv-indxdb (IndexedDB for web)
- kv-fdb (FoundationDB)
- Any other storage engines beyond mem and rocksdb

**Advanced Features:**
- Data synchronization between instances
- Replication and clustering
- Backup and restore functionality
- Import/export utilities
- Schema migrations
- Performance benchmarking suite

**Developer Experience:**
- Code generation with ffigen
- Automated API documentation generation
- Comprehensive multi-platform CI/CD
- Flutter plugin variant with UI
- Web platform support (WASM)

**Polish and Optimization:**
- Performance profiling and optimization
- Advanced error recovery strategies
- Detailed logging and debugging tools
- Custom query builder API
- ORM-like abstractions

## Success Criteria

**Functional Success:**
- CLI example app runs successfully on macOS without crashes
- Can create in-memory database and execute basic queries
- Can create RocksDB database, persist data, close, reopen, and query persisted data
- All three example scenarios complete successfully
- Namespace and database selection works correctly

**Performance Success:**
- No UI blocking or jank during database operations
- Database operations complete within reasonable timeframes
- Memory usage remains stable during extended operation
- Isolate communication overhead is negligible

**Quality Success:**
- Zero memory leaks detected via Dart DevTools or Instruments
- Errors properly propagated with clear messages
- All FFI calls complete asynchronously via isolate
- Clean shutdown releases all resources
- NativeFinalizer triggers cleanup when objects are GC'd

**Documentation Success:**
- README contains clear setup and usage instructions
- Example app includes inline comments explaining each operation
- FFI boundary contracts documented with safety comments
- Threading model clearly documented
- Limitations and future enhancements documented

**Standards Compliance:**
- Code follows all agent-os standards for Dart and Rust
- Null safety throughout Dart code
- Proper error handling (no silent failures)
- Semantic versioning followed
- CHANGELOG.md updated with all changes (required at end of implementation)
