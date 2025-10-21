# Task Breakdown: Initial FFI Bindings Setup

## Overview
Total Task Groups: 7
This implementation establishes the foundational Rust-to-Dart FFI infrastructure for SurrealDB integration using native_toolchain_rs, featuring a three-layer architecture with background isolate for async operations.

**Key Technical Components:**
- Rust FFI layer (C-compatible functions, opaque handles, memory management)
- Dart FFI bindings (low-level FFI declarations, isolate worker, message protocol)
- High-level Dart API (async wrappers, Future-based API)
- CLI example app (demonstrates connectivity, CRUD, storage backends)

**Architecture:**
- Background isolate for all database operations (thread safety)
- All operations async mirroring SurrealDB Rust SDK
- NativeFinalizer for automatic memory cleanup
- Error propagation through isolate boundaries
- Minimal SurrealDB features (kv-mem and kv-rocksdb only)

## Task List

### Build System and Project Setup

#### Task Group 1: Build Infrastructure and Dependencies
**Assigned implementer:** database-engineer
**Dependencies:** None

- [x] 1.0 Set up build infrastructure
  - [x] 1.1 Research and identify stable native_toolchain_rs commit hash
    - Visit GitHub repository: https://github.com/GregoryConrad/native_toolchain_rs
    - Identify recent stable commit (no older than 3 months)
    - Document commit hash for use in pubspec.yaml
  - [x] 1.2 Update pubspec.yaml with required dependencies
    - Add `ffi: ^2.1.0` to dependencies
    - Add `native_toolchain_rs` as git dependency with pinned commit
    - Ensure Dart SDK constraint is `>=3.0.0 <4.0.0`
    - Reference: agent-os/standards/global/tech-stack.md
  - [x] 1.3 Create rust-toolchain.toml with version pinning
    - Pin Rust toolchain to exact version 1.90.0
    - Include all platform targets: aarch64-apple-darwin, x86_64-apple-darwin, aarch64-apple-ios, aarch64-linux-android, armv7-linux-androideabi, x86_64-pc-windows-msvc, x86_64-unknown-linux-gnu, aarch64-unknown-linux-gnu
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 1.4 Create Cargo.toml with SurrealDB dependencies
    - Set library crate-type to ["staticlib", "cdylib"]
    - Add surrealdb dependency with minimal features: `{ version = "2.0", default-features = false, features = ["kv-mem", "kv-rocksdb"] }`
    - Add tokio dependency: `{ version = "1", features = ["rt-multi-thread"] }`
    - Configure release profile: opt-level = "z", lto = true, codegen-units = 1, strip = true
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 1.5 Create hook/build.dart for automatic Rust compilation
    - Import package:hooks/hooks.dart and package:native_toolchain_rs
    - Implement main function using RustBuilder
    - Set assetName to 'package:surrealdartb/surrealdartb_bindings'
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 1.6 Verify build system works
    - Run `dart pub get` to trigger build hook
    - Verify Rust code compiles successfully
    - Confirm native library is generated in expected location
    - Test on macOS (primary platform)

**Acceptance Criteria:**
- pubspec.yaml configured with all required dependencies and pinned versions
- rust-toolchain.toml pins Rust to 1.90.0 with all platform targets
- Cargo.toml configured with minimal SurrealDB features (kv-mem, kv-rocksdb only)
- Build hook successfully compiles Rust code during dart pub get
- Native library accessible via asset name 'package:surrealdartb/surrealdartb_bindings'
- Build process completes without errors on macOS

### Rust FFI Layer

#### Task Group 2: Core Rust FFI Implementation
**Assigned implementer:** database-engineer
**Dependencies:** Task Group 1

- [x] 2.0 Implement Rust FFI layer
  - [x] 2.1 Write 2-8 focused tests for Rust FFI core functionality
    - Limit to 2-8 highly focused tests maximum
    - Test database creation with mem:// endpoint
    - Test error code return pattern
    - Test string allocation/deallocation
    - Skip exhaustive coverage of all functions
    - Use `#[cfg(test)]` module in rust/src/lib.rs
  - [x] 2.2 Create rust/src/lib.rs with FFI entry points
    - Define opaque types for Database and Response
    - Implement #[no_mangle] extern "C" functions
    - Wrap all entry points with std::panic::catch_unwind for panic safety
    - Document thread safety requirements
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 2.3 Create rust/src/error.rs for error handling
    - Implement thread-local error state storage using thread_local!
    - Create function to store error message: `set_last_error(msg: &str)`
    - Create FFI function to retrieve error: `get_last_error() -> *mut c_char`
    - Create FFI function to free error string: `free_error_string(ptr: *mut c_char)`
    - All errors return as integer codes (0 = success, negative = error)
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 2.4 Create rust/src/runtime.rs for Tokio async runtime
    - Implement lazy_static or once_cell for global Tokio runtime
    - Create get_runtime() function returning reference to Runtime
    - Configure multi-threaded runtime with rt-multi-thread feature
    - Document runtime lifecycle and shutdown strategy
    - Reference: agent-os/standards/backend/async-patterns.md
  - [x] 2.5 Create rust/src/database.rs for database lifecycle
    - Implement `db_new(endpoint: *const c_char) -> *mut Database`
    - Implement `db_connect(handle: *mut Database) -> i32` (uses runtime.block_on)
    - Implement `db_use_ns(handle: *mut Database, ns: *const c_char) -> i32`
    - Implement `db_use_db(handle: *mut Database, db: *const c_char) -> i32`
    - Implement `db_close(handle: *mut Database)` destructor
    - Use CStr::from_ptr for string parameters, validate non-null
    - Use Box::into_raw for owned Database handles
    - All async operations use get_runtime().block_on()
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 2.6 Create rust/src/query.rs for query execution
    - Implement `db_query(handle: *mut Database, sql: *const c_char) -> *mut Response`
    - Implement `response_get_results(handle: *mut Response) -> *mut c_char` (returns JSON)
    - Implement `response_has_errors(handle: *mut Response) -> i32`
    - Implement `response_free(handle: *mut Response)` destructor
    - Use serde_json to serialize query results to JSON string
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 2.7 Implement basic CRUD FFI functions
    - Implement `db_select(handle: *mut Database, table: *const c_char) -> *mut Response`
    - Implement `db_create(handle: *mut Database, table: *const c_char, data: *const c_char) -> *mut Response`
    - Implement `db_update(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut Response`
    - Implement `db_delete(handle: *mut Database, resource: *const c_char) -> *mut Response`
    - All operations async using runtime.block_on()
    - Parse data parameter as JSON using serde_json
    - Reference: /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust
  - [x] 2.8 Ensure Rust FFI layer tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify panic safety wrappers work correctly
    - Verify error codes propagate correctly
    - Do NOT run comprehensive test suite at this stage
    - Run with: `cargo test` in rust/ directory

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- All FFI functions use #[no_mangle] and extern "C"
- All entry points wrapped with catch_unwind for panic safety
- Error handling uses thread-local storage with get_last_error()
- Database lifecycle functions work (new, connect, use_ns, use_db, close)
- Query execution returns opaque Response handles
- All async operations use Tokio runtime with block_on()
- CRUD operations implemented and working
- Null pointer checks on all Rust entry points
- Memory management follows Box::into_raw/Box::from_raw pattern

### Dart FFI Bindings Layer

#### Task Group 3: Low-Level Dart FFI Bindings
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 2

- [x] 3.0 Implement Dart FFI bindings layer
  - [x] 3.1 Write 2-8 focused tests for FFI bindings
    - Limit to 2-8 highly focused tests maximum
    - Test string conversion utilities (Dart ↔ C)
    - Test opaque handle creation and destruction
    - Test error code to exception mapping
    - Skip exhaustive testing of all FFI functions
    - Create test file: test/unit/ffi_bindings_test.dart
  - [x] 3.2 Create lib/src/ffi/native_types.dart for opaque types
    - Define class NativeDatabase extends Opaque
    - Define class NativeResponse extends Opaque
    - Add type definitions for native function signatures
    - Reference: agent-os/standards/backend/ffi-types.md
  - [x] 3.3 Create lib/src/ffi/ffi_utils.dart for utilities
    - Implement stringToCString(String str) -> Pointer<Utf8>
    - Implement cStringToDartString(Pointer<Utf8> ptr) -> String
    - Implement freeCString(Pointer<Utf8> ptr)
    - Implement error code to exception conversion
    - Use malloc.allocate for string allocation
    - Use malloc.free for cleanup
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 3.4 Create lib/src/ffi/bindings.dart with FFI function declarations
    - Load native library using DynamicLibrary.process() or .open()
    - Declare all Rust FFI functions with @Native annotations
    - Database lifecycle: dbNew, dbConnect, dbUseNs, dbUseDb, dbClose
    - Query functions: dbQuery, responseGetResults, responseHasErrors, responseFree
    - CRUD functions: dbSelect, dbCreate, dbUpdate, dbDelete
    - Error functions: getLastError, freeErrorString
    - Use NativeDatabase and NativeResponse opaque types
    - Reference: agent-os/standards/backend/rust-integration.md
  - [x] 3.5 Create lib/src/ffi/finalizers.dart for memory management
    - Create NativeFinalizer for NativeDatabase with dbClose callback
    - Create NativeFinalizer for NativeResponse with responseFree callback
    - Document finalizer attachment pattern
    - Reference: agent-os/standards/global/tech-stack.md
  - [x] 3.6 Ensure FFI bindings layer tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify string conversion works correctly
    - Verify opaque handles can be created
    - Do NOT run the entire test suite at this stage
    - Run with: `dart test test/unit/ffi_bindings_test.dart`

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Opaque types defined for NativeDatabase and NativeResponse
- All FFI functions declared with @Native annotations
- String conversion utilities handle Dart ↔ C correctly
- NativeFinalizer configured for automatic cleanup
- Error code conversion to exceptions implemented
- Memory allocation/deallocation paired correctly
- No raw Pointer types exposed in public API

### Background Isolate Architecture

#### Task Group 4: Async Isolate Communication Layer
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 3

- [x] 4.0 Implement background isolate architecture
  - [x] 4.1 Write 2-8 focused tests for isolate communication
    - Limit to 2-8 highly focused tests maximum
    - Test isolate spawning and initialization
    - Test command sending and response receiving
    - Test error propagation through isolate
    - Skip exhaustive testing of all message types
    - Create test file: test/unit/isolate_communication_test.dart
  - [x] 4.2 Create lib/src/isolate/isolate_messages.dart for message types
    - Define sealed class IsolateCommand with subclasses:
      - InitializeCommand (no parameters)
      - ConnectCommand(String endpoint, String? namespace, String? database)
      - QueryCommand(String sql, Map<String, dynamic>? bindings)
      - SelectCommand(String table)
      - CreateCommand(String table, Map<String, dynamic> data)
      - UpdateCommand(String resource, Map<String, dynamic> data)
      - DeleteCommand(String resource)
      - CloseCommand (no parameters)
    - Define sealed class IsolateResponse with subclasses:
      - SuccessResponse(dynamic data)
      - ErrorResponse(String message, int? errorCode)
    - All types must be Sendable across isolates (primitives only)
    - Reference: agent-os/standards/backend/async-patterns.md
  - [x] 4.3 Create lib/src/isolate/database_isolate.dart for isolate management
    - Implement class DatabaseIsolate with start() method
    - Spawn isolate using Isolate.spawn() with entry point
    - Set up two-way communication: SendPort and ReceivePort
    - Implement sendCommand(IsolateCommand cmd) -> Future<IsolateResponse>
    - Create ReceivePort for responses, use Completer for async handling
    - Implement dispose() method to kill isolate and close ports
    - Reference: agent-os/standards/backend/async-patterns.md
  - [x] 4.4 Implement isolate entry point function
    - Create static void _isolateEntry(SendPort mainSendPort)
    - Initialize FFI bindings inside isolate (load native library)
    - Listen on ReceivePort for incoming commands
    - Call appropriate FFI functions based on command type
    - Catch all exceptions and convert to ErrorResponse
    - Send responses back through mainSendPort
    - Store native handle in isolate-local variable
    - Reference: agent-os/standards/backend/async-patterns.md
  - [x] 4.5 Implement error propagation through isolate
    - Catch FFI errors (negative return codes)
    - Call getLastError() FFI function to retrieve error message
    - Convert to ErrorResponse with code and message
    - Send ErrorResponse through ReceivePort
    - Throw DatabaseException on main thread when ErrorResponse received
    - Reference: agent-os/standards/global/error-handling.md
  - [x] 4.6 Ensure isolate communication tests pass
    - Run ONLY the 2-8 tests written in 4.1
    - Verify commands send and responses return correctly
    - Verify errors propagate from isolate to main thread
    - Do NOT run the entire test suite at this stage
    - Run with: `dart test test/unit/isolate_communication_test.dart`

**Acceptance Criteria:**
- The 2-8 tests written in 4.1 pass
- IsolateCommand and IsolateResponse message types defined
- DatabaseIsolate class spawns and manages background isolate
- Two-way communication works: commands sent, responses received
- Entry point function handles all command types
- Errors propagate correctly from Rust → isolate → main thread
- Isolate cleanup (kill, close ports) implemented
- All database operations serialized through single isolate

### High-Level Dart API

#### Task Group 5: Public Async API
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 4

- [x] 5.0 Implement high-level Dart API
  - [x] 5.1 Write 2-8 focused tests for public API
    - Limit to 2-8 highly focused tests maximum
    - Test Database.connect() with mem:// backend
    - Test query execution returns Response
    - Test error handling throws DatabaseException
    - Skip exhaustive testing of all methods
    - Create test file: test/unit/database_api_test.dart
  - [x] 5.2 Create lib/src/storage_backend.dart for backend enum
    - Define enum StorageBackend { memory, rocksdb }
    - Add helper methods: toEndpoint(String? path) -> String
    - memory returns "mem://", rocksdb returns path
    - Validate path is non-null for rocksdb backend
    - Reference: spec requirements
  - [x] 5.3 Create lib/src/exceptions.dart for exception types
    - Define class DatabaseException implements Exception
    - Add fields: String message, int? errorCode, String? nativeStackTrace
    - Define subclasses: ConnectionException, QueryException, AuthenticationException
    - Add toString() for clear error messages
    - Reference: agent-os/standards/global/error-handling.md
  - [x] 5.4 Create lib/src/response.dart for query response wrapper
    - Define class Response wrapping query results
    - Implement getResults() -> List<Map<String, dynamic>>
    - Implement hasErrors() -> bool
    - Implement getErrors() -> List<String>
    - Implement takeResult(int index) -> dynamic
    - Parse JSON from native response string
    - Reference: /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust
  - [x] 5.5 Create lib/src/database.dart with public API
    - Define class Database with private constructor
    - Implement static Future<Database> connect() factory method
    - Parameters: StorageBackend backend, String? path, String? namespace, String? database
    - Spawn DatabaseIsolate in connect() method
    - Implement Future<void> useNamespace(String namespace)
    - Implement Future<void> useDatabase(String database)
    - Implement Future<Response> query(String sql, [Map<String, dynamic>? bindings])
    - Implement Future<List<Map<String, dynamic>>> select(String table)
    - Implement Future<Map<String, dynamic>> create(String table, Map<String, dynamic> data)
    - Implement Future<Map<String, dynamic>> update(String resource, Map<String, dynamic> data)
    - Implement Future<void> delete(String resource)
    - Implement Future<void> close() for cleanup
    - All methods send commands to DatabaseIsolate and await responses
    - Convert ErrorResponse to DatabaseException and throw
    - Reference: agent-os/standards/backend/async-patterns.md
  - [x] 5.6 Create lib/surrealdartb.dart as main library export
    - Export Database class
    - Export StorageBackend enum
    - Export Response class
    - Export all exception types
    - Hide internal FFI and isolate implementation details
    - Reference: agent-os/standards/global/conventions.md
  - [x] 5.7 Ensure public API tests pass
    - Run ONLY the 2-8 tests written in 5.1
    - Verify Database.connect() works with memory backend
    - Verify basic query execution works
    - Do NOT run the entire test suite at this stage
    - Run with: `dart test test/unit/database_api_test.dart`

**Acceptance Criteria:**
- The 2-8 tests written in 5.1 pass
- StorageBackend enum supports memory and rocksdb
- DatabaseException hierarchy defined (base + subclasses)
- Response class parses and exposes query results
- Database class provides clean Future-based API
- All operations async (non-blocking)
- Errors converted from codes to exceptions
- No FFI details exposed in public API
- Library exports configured in surrealdartb.dart

### CLI Example Application

#### Task Group 6: Demonstration CLI App
**Assigned implementer:** ui-designer
**Dependencies:** Task Group 5

- [x] 6.0 Create CLI example application
  - [x] 6.1 Write 2-8 focused tests for CLI scenarios
    - Limit to 2-8 highly focused tests maximum
    - Test scenario execution functions return successfully
    - Test error handling in scenarios
    - Skip exhaustive testing of all user interactions
    - Create test file: test/example_scenarios_test.dart
  - [x] 6.2 Create example/scenarios/connect_verify.dart
    - Implement Future<void> runConnectVerifyScenario()
    - Connect to mem:// database
    - Print connection status to console
    - Set namespace and database (use "test", "test")
    - Execute simple query: "INFO FOR DB;"
    - Print query result
    - Close database connection
    - Handle and display any errors
    - Add clear console output showing each step
    - Reference: /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust
  - [x] 6.3 Create example/scenarios/crud_operations.dart
    - Implement Future<void> runCrudScenario()
    - Connect to mem:// database with namespace "test" and database "test"
    - Create a record: `db.create("person", {"name": "John", "age": 30})`
    - Query back all records: `db.select("person")`
    - Update the record
    - Delete the record
    - Print results at each step
    - Close database connection
    - Handle and display any errors
    - Add clear console output showing each operation result
    - Reference: /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust
  - [x] 6.4 Create example/scenarios/storage_comparison.dart
    - Implement Future<void> runStorageComparisonScenario()
    - Test mem:// backend:
      - Connect, create record, query, close
      - Verify record exists
    - Test RocksDB backend:
      - Connect with temp directory path
      - Create record, query, close
      - Reconnect to same path
      - Verify record persists after reconnection
    - Print comparison results showing mem:// vs persistent storage
    - Clean up RocksDB directory after test
    - Handle and display any errors
    - Reference: spec requirements
  - [x] 6.5 Create example/cli_example.dart main entry point
    - Implement main() function with interactive menu
    - Print welcome message and available scenarios:
      1. Connect and verify connectivity
      2. CRUD operations demonstration
      3. Storage backend comparison (mem:// vs RocksDB)
      4. Exit
    - Use dart:io stdin.readLineSync() for user input
    - Call appropriate scenario function based on selection
    - Loop until user selects exit
    - Handle invalid input gracefully
    - Add clear, user-friendly console output
    - Reference: spec requirements
  - [x] 6.6 Add example README with usage instructions
    - Create example/README.md
    - Document how to run the example: `dart run example/cli_example.dart`
    - Explain each scenario and what it demonstrates
    - Note platform requirements (tested on macOS)
    - Document expected output for each scenario
  - [x] 6.7 Ensure CLI example tests pass
    - Run ONLY the 2-8 tests written in 6.1
    - Verify scenario functions execute without crashing
    - Verify basic error handling works
    - Do NOT run comprehensive integration tests at this stage
    - Run with: `dart test test/example_scenarios_test.dart`

**Acceptance Criteria:**
- The 2-8 tests written in 6.1 pass
- Three scenarios implemented: connect_verify, crud_operations, storage_comparison
- cli_example.dart provides interactive menu for scenario selection
- Each scenario prints clear step-by-step output
- Error handling implemented and displays user-friendly messages
- Storage comparison demonstrates mem:// vs RocksDB persistence
- Example README documents usage and expectations
- Example runs successfully on macOS without crashes

### Testing and Verification

#### Task Group 7: Integration Testing and Gap Analysis
**Assigned implementer:** testing-engineer
**Dependencies:** Task Groups 1-6

- [ ] 7.0 Review existing tests and fill critical gaps only
  - [ ] 7.1 Review tests from previous task groups
    - Review 2-8 tests from Task 2.1 (Rust FFI core)
    - Review 2-8 tests from Task 3.1 (Dart FFI bindings)
    - Review 2-8 tests from Task 4.1 (Isolate communication)
    - Review 2-8 tests from Task 5.1 (Public API)
    - Review 2-8 tests from Task 6.1 (CLI scenarios)
    - Total existing tests: approximately 10-40 tests
  - [ ] 7.2 Analyze test coverage gaps for FFI bindings feature only
    - Identify critical workflows lacking test coverage
    - Focus ONLY on gaps related to FFI bindings specification
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end workflows: connect → query → close
    - Prioritize error paths: connection failures, query errors, memory cleanup
    - Identify gaps in memory management testing (finalizers, leaks)
    - Identify gaps in cross-boundary testing (Rust ↔ Dart ↔ isolate)
    - Document findings in test/analysis/coverage_gaps.md
  - [ ] 7.3 Write up to 10 additional strategic tests maximum
    - Add maximum of 10 new tests to fill identified critical gaps
    - Focus on integration points and end-to-end workflows
    - Do NOT write comprehensive coverage for all scenarios
    - Suggested test areas (if gaps identified):
      - End-to-end: connect → use_ns → use_db → query → close
      - Error path: invalid endpoint, connection timeout, query failure
      - Memory: NativeFinalizer triggers on GC (smoke test)
      - Isolate: multiple concurrent commands, isolate restart
      - Storage: RocksDB persistence across connections
      - Async: multiple simultaneous operations don't interfere
    - Skip edge cases, performance tests, and stress tests
    - Create integration test file: test/integration/ffi_integration_test.dart
    - Reference: agent-os/standards/testing/test-writing.md
  - [ ] 7.4 Run feature-specific tests only
    - Run ONLY tests related to FFI bindings feature
    - Expected total: approximately 20-50 tests maximum
    - Do NOT run entire application test suite (if other features exist)
    - Verify critical workflows pass:
      - Database connection and initialization
      - Query execution and result parsing
      - CRUD operations work correctly
      - Error propagation from Rust → Dart
      - Memory cleanup via finalizers
      - Both storage backends (mem:// and RocksDB)
    - Run with: `dart test`
    - Document any failures and fix before proceeding
  - [ ] 7.5 Manual testing of CLI example on macOS
    - Run example/cli_example.dart
    - Execute each scenario (1, 2, 3) and verify output
    - Verify no crashes or hangs
    - Verify error messages are clear
    - Verify RocksDB persistence works (scenario 3)
    - Document any issues found
    - Optional: Test on other platforms if available
  - [ ] 7.6 Memory leak verification (optional but recommended)
    - Run CLI example multiple times
    - Use Activity Monitor (macOS) or similar to check memory usage
    - Verify memory returns to baseline after close()
    - Force garbage collection in test: `await Future.delayed(Duration.zero);`
    - Note: NativeFinalizer timing is not guaranteed
    - Document findings in test/analysis/memory_verification.md

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 20-50 tests total)
- Critical user workflows for FFI bindings are covered
- No more than 10 additional tests added by testing-engineer
- Testing focused exclusively on FFI bindings specification
- End-to-end workflow tests pass (connect → query → close)
- Error propagation tests pass (Rust → isolate → Dart)
- Memory management smoke tests pass (finalizer triggers)
- Both storage backends tested (mem:// and RocksDB)
- CLI example runs successfully on macOS
- No memory leaks detected in normal operation

## Execution Order

Recommended implementation sequence:

1. **Task Group 1: Build Infrastructure** (database-engineer)
   - Sets up the entire build system, Rust toolchain, and dependencies
   - Prerequisite for all Rust and Dart development
   - Verifies native compilation works end-to-end

2. **Task Group 2: Rust FFI Layer** (database-engineer)
   - Implements core native functionality wrapping SurrealDB
   - Provides C-compatible functions for Dart to call
   - Must be complete before Dart can interact with native code

3. **Task Group 3: Dart FFI Bindings** (api-engineer)
   - Creates low-level Dart declarations for Rust functions
   - Handles string conversion and memory management
   - Bridges Rust layer to Dart application code

4. **Task Group 4: Isolate Architecture** (api-engineer)
   - Implements background isolate for async operations
   - Establishes message protocol for commands/responses
   - Ensures thread safety and non-blocking operations

5. **Task Group 5: Public API** (api-engineer)
   - Wraps isolate communication in clean Future-based API
   - Provides user-facing Database class and methods
   - Hides FFI complexity from library consumers

6. **Task Group 6: CLI Example** (ui-designer)
   - Demonstrates all major features working together
   - Serves as manual integration test
   - Validates both storage backends (mem:// and RocksDB)

7. **Task Group 7: Testing & Verification** (testing-engineer)
   - Reviews all prior tests (approximately 10-40 tests)
   - Adds up to 10 strategic integration tests for critical gaps
   - Verifies end-to-end functionality and memory management
   - Confirms success criteria met

## Critical Implementation Notes

**Memory Management:**
- All Rust functions return opaque pointers via Box::into_raw()
- Dart attaches NativeFinalizer to wrapper objects for automatic cleanup
- Explicit close() methods for critical resources (Database)
- String memory freed after use in try/finally blocks
- Response handles freed after parsing results

**Thread Safety:**
- All database operations serialized through single background isolate
- Native library called only from isolate thread (not main thread)
- No shared mutable state between isolates
- Rust side: operations execute on Tokio runtime (thread-safe)

**Error Handling:**
- Rust functions return integer error codes (0 = success, negative = error)
- Thread-local storage for error messages in Rust
- Separate getLastError() function retrieves error text
- Isolate catches errors and converts to ErrorResponse
- Main thread converts ErrorResponse to DatabaseException
- Never panic across FFI boundary (use catch_unwind)

**Async Architecture:**
- All SurrealDB operations are async in Rust SDK
- Rust side uses runtime.block_on() to wait for async operations
- Dart side wraps all calls in Future via isolate communication
- Result: non-blocking operations on Dart main thread
- All public API methods return Future<T>

**Build System:**
- hook/build.dart triggers Rust compilation during dart pub get
- Native library compiled for current platform automatically
- Asset name 'package:surrealdartb/surrealdartb_bindings' used for loading
- Rust toolchain pinned to exact version 1.90.0

**Testing Strategy:**
- Each implementer writes 2-8 focused tests (NOT comprehensive)
- Tests verify critical functionality only during development
- testing-engineer adds maximum 10 integration tests for gaps
- Total expected: 20-50 tests for entire feature
- Focus on critical paths, error handling, memory management

**Standards Compliance:**
- Follow agent-os/standards/backend/rust-integration.md for all Rust FFI code
- Follow agent-os/standards/backend/async-patterns.md for isolate architecture
- Follow agent-os/standards/global/tech-stack.md for dependencies
- Follow agent-os/standards/testing/test-writing.md for test structure
- Follow agent-os/standards/global/error-handling.md for error propagation

**Platform Support:**
- Primary development and testing: macOS (Apple Silicon and Intel)
- All platform targets configured in rust-toolchain.toml
- Cross-platform validation deferred to future phases
- Document platform-specific issues as discovered
