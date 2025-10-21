# Spec Requirements: Initial FFI Bindings Setup

## Initial Description

**Feature: Initial FFI Bindings Setup with native_toolchain_rs**

Description:
- Set up initial FFI bindings using native_toolchain_rs
- Enable bootstrapping the SurrealDB database and getting it running on the Dart side
- Build an example app to demonstrate working with the FFI bindings
- Ensure experimental-assets are enabled in Dart so native_assets/hooks are functional (reference: https://dart.dev/tools/hooks)
- Use SurrealDB native Rust APIs as reference (available at: /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust)

## Requirements Discussion

### First Round Questions

**Q1: What should the bootstrap focus on for the initial setup?**
**Answer:** Focus on bootstrap with minimal SurrealDB feature set (kv-mem and kv-rocksdb storage backends only). Keep the initial implementation simple and focused on proving out the FFI integration rather than comprehensive SurrealDB features.

**Q2: What format should the example application take?**
**Answer:** CLI Dart application with basic examples. This will be simpler than a full Flutter app and allow focus on the FFI layer without UI concerns.

**Q3: What core SurrealDB operations should be exposed in this initial implementation?**
**Answer:** Core operations should include:
- Database initialization and lifecycle management (creating, opening, closing databases)
- Connection management (handling connection state)
- Basic query execution (running simple SurrealQL queries)

**Q4: What should the FFI interface look like?**
**Answer:** Use opaque handles for Surreal database instance and Response type. Specific FFI functions should include:
- `db_new()` - Create new database instance
- `db_connect()` - Connect to database
- `db_query()` - Execute queries
- `db_close()` - Close database connection
And similar functions following SurrealDB Rust SDK patterns.

**Q5: What platform targets should be included in the initial setup?**
**Answer:** Rust toolchain should be pinned to version 1.90.0 with all platform targets included (macOS, iOS, Android, Windows, Linux) in rust-toolchain.toml, but initial testing and focus should be on macOS since that's the primary development environment. Other platforms will be validated in later phases.

**Q6: How should the native asset be named?**
**Answer:** Use the asset name: `package:surrealdartb/surrealdartb_bindings`

**Q7: What storage backends should be supported?**
**Answer:** Support both Mem (in-memory) and RocksDB (persistent) storage backends through SurrealDB feature flags `kv-mem` and `kv-rocksdb`.

**Q8: How should errors be handled across the FFI boundary?**
**Answer:** Use error codes with separate function for retrieving error messages. This follows standard FFI patterns where functions return integer status codes, and a separate function can be called to get human-readable error details.

**Q9: Should async support be included in the initial implementation?**
**Answer:** Yes, async support should be included for time-intensive operations like DB connection setup, to avoid blocking the main thread.

### Follow-up Questions

**Follow-up 1: Should we use a single-threaded approach or set up a background thread/isolate for DB operations?**
**Answer:** Set up a background thread/isolate for working with the DB. This does add complexity but it also adds a layer of safety and will remove any jank from waiting for DB functions to process.

**Follow-up 2: For the async operations, should we make all operations async or just connection/initialization?**
**Answer:** Mirror what the Rust SDK for SurrealDB does. If the SDK is asynchronous then we should mirror that approach.

**Follow-up 3: How should errors be communicated from the background thread/isolate back to Dart?**
**Answer:** Use try/catch and communicate errors back to Dart. This follows standard Dart async patterns.

**Follow-up 4: What should the example app demonstrate?**
**Answer:** All three of these seem ideal for the initial example:
- Connect to database and verify it works
- Connect, create namespace/database, insert a record, query it back
- Include both mem:// and RocksDB examples
Maybe as choosable steps - allowing the user to select which example to run.

**Follow-up 5: Given the background isolate setup, should all DB calls be funneled through it for thread safety?**
**Answer:** Since we're already setting up a thread isolate, it probably makes sense to funnel all calls through it anyway. So let's do that here for thread safety consistency.

### Existing Code to Reference

**Similar Features Identified:**
No similar existing features identified for reference. This is the foundational FFI setup that will serve as the basis for all future SurrealDB integration work.

### Reference Materials Analysis

**native_toolchain_rs Integration Pattern:**

From the GitHub example at https://github.com/GregoryConrad/native_toolchain_rs/tree/main/examples/dart_only/rust, the key patterns are:

1. **File Structure:**
   - `hook/build.dart` - Build hook for compiling Rust code
   - `rust-toolchain.toml` - Pins Rust version and targets
   - `Cargo.toml` - Rust library configuration with `crate-type = ["staticlib", "cdylib"]`
   - `src/` - Rust FFI implementation
   - `lib/src/ffi/` - Dart FFI bindings

2. **Build Hook Implementation:**
   - Uses `RustBuilder` with asset naming
   - Automatically compiles Rust during Dart build process
   - Integrates with Dart's native assets system

3. **FFI Binding Pattern:**
   - C-compatible interface via `bindings.h` or similar
   - Opaque pointer types for object handles
   - Standard FFI conventions with `#[no_mangle]` and `extern "C"`

**SurrealDB Rust SDK API Patterns:**

From the local documentation at /Users/fabier/Documents/libraries/docs.surrealdb.com/src/content/doc-sdk-rust:

1. **Database Initialization (new):**
   ```rust
   Surreal::new::<T>(address)
   ```
   - Takes endpoint address (e.g., "mem://", "path/to/db")
   - Supports Config struct for advanced configuration
   - Returns async Result

2. **Connection (connect):**
   ```rust
   db.connect::<Ws>("127.0.0.1:8000").await?
   ```
   - Async operation
   - Type parameter specifies connection type
   - Can accept tuple with Config for fine-tuning

3. **Namespace/Database Selection (use_ns/use_db):**
   ```rust
   db.use_ns("ns").use_db("db").await?
   ```
   - Required before performing operations
   - Chainable method calls
   - Async operations

4. **Query Execution (query):**
   ```rust
   db.query(query_string).await?
   ```
   - Executes SurrealQL statements
   - Returns Response with multiple results
   - Supports `.bind()` for parameterized queries
   - Use `.take(index)` to extract specific results

5. **CRUD Operations:**
   - **Select:** `db.select("table").await?` or `db.select(("table", "id")).await?`
   - **Create:** `db.create("table").content(data).await?`
   - **Update:** Similar pattern with content or merge
   - **Delete:** `db.delete(resource).await?`

6. **Error Handling:**
   - All operations return `Result<T, Error>`
   - Query responses contain per-statement results
   - Response has `.check()` and `.take_errors()` helpers

7. **Async Architecture:**
   - ALL SurrealDB Rust SDK operations are async
   - Uses tokio runtime: `#[tokio::main]`
   - Returns Futures that must be awaited

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
Not applicable - this is a foundational infrastructure feature without UI components.

## Requirements Summary

### Functional Requirements

**Core FFI Infrastructure:**
- Set up Rust-to-Dart FFI bridge using native_toolchain_rs
- Configure build hooks for automatic Rust compilation during Dart build
- Pin Rust toolchain to version 1.90.0
- Support all platform targets (macOS, iOS, Android, Windows, Linux) with macOS as primary focus
- Create opaque handle types for SurrealDB objects (database instance, response)
- Implement memory management with NativeFinalizer for automatic cleanup
- Asset name: `package:surrealdartb/surrealdartb_bindings`

**Database Lifecycle Operations:**
- `db_new()` - Create new SurrealDB instance with endpoint
- `db_connect()` - Connect to database (async)
- `db_use_ns()` / `db_use_db()` - Set namespace and database (async)
- `db_close()` - Close database and clean up resources
- Support for both mem:// (in-memory) and RocksDB (file-based) backends

**Query Execution:**
- `db_query()` - Execute SurrealQL queries (async)
- Return response handles for query results
- Support for parameterized queries via bind operations
- Parse and expose query results to Dart

**CRUD Operations (Basic):**
- `db_select()` - Select records from table
- `db_create()` - Create new records
- `db_update()` - Update existing records
- `db_delete()` - Delete records
- All operations should be async following Rust SDK patterns

**Error Handling:**
- Error code return pattern for FFI functions
- Separate function to retrieve error messages
- Proper error propagation from Rust to Dart
- Try/catch error communication from isolate to main thread

**Async Architecture:**
- Background isolate for all database operations (thread safety)
- All DB calls funneled through dedicated isolate
- Future-based Dart API wrapping async FFI calls
- Mirror SurrealDB Rust SDK async patterns (everything async)

**Storage Backend Support:**
- Enable `kv-mem` feature flag for in-memory storage
- Enable `kv-rocksdb` feature flag for persistent storage
- Configure Cargo.toml with minimal feature set

**Example Application:**
- CLI Dart application (not Flutter)
- Choosable example steps:
  1. Connect to database and verify it works
  2. Connect, create namespace/database, insert record, query it back
  3. Demonstrate both mem:// and RocksDB examples
- Clear console output showing each operation

### Reusability Opportunities

No existing similar features identified. This is the foundational layer that future features will build upon.

However, the following patterns should be designed for reusability:
- Opaque handle pattern for wrapping native objects
- Async isolate communication pattern for native operations
- Error propagation pattern across FFI boundary
- Memory management with NativeFinalizer
- String conversion utilities (Dart ↔ C strings)

### Scope Boundaries

**In Scope:**
- FFI infrastructure setup with native_toolchain_rs
- Build hooks and native asset configuration
- Rust toolchain pinning and multi-platform target configuration
- Basic database lifecycle (new, connect, use_ns, use_db, close)
- Query execution with basic response handling
- Core CRUD operations (select, create, update, delete)
- Error code pattern with message retrieval
- Background isolate for thread safety
- Async support mirroring SurrealDB Rust SDK
- kv-mem and kv-rocksdb storage backends only
- CLI example app with multiple demonstration scenarios
- Memory management with NativeFinalizer
- macOS as primary development/testing platform

**Out of Scope:**
- Advanced SurrealDB features (vector indexing, live queries, transactions)
- Full SurrealQL language support (only basic queries)
- Authentication and permissions
- Real-time subscriptions
- Data synchronization
- Advanced query features (graph queries, subqueries, aggregations)
- Remote database connections (WebSocket, HTTP)
- Other storage backends beyond kv-mem and kv-rocksdb
- Flutter UI example (CLI only for initial implementation)
- Comprehensive cross-platform testing (macOS focus initially)
- Performance optimization and benchmarking
- Code generation with ffigen (manual bindings for now)
- API documentation generation (focus on working implementation)

**Future Enhancements (Documented for Later):**
- Full SurrealQL query support
- Vector indexing and similarity search
- Real-time live queries via Stream API
- Transaction support with ACID guarantees
- Advanced query features (graph traversal, subqueries)
- Data sync between local and remote instances
- Flutter plugin variant with UI examples
- Comprehensive multi-platform testing and CI/CD
- Performance benchmarking suite
- API documentation with dartdoc
- Code generation automation with ffigen

### Technical Considerations

**Build System:**
- Use `package:hooks` for build hook integration
- Use `native_toolchain_rs` (GitHub dependency, pinned to specific commit)
- Asset naming convention: descriptive path matching binding file
- Automatic compilation during `dart pub get`

**Rust Configuration:**
- `rust-toolchain.toml`: Pin to version 1.90.0 with all platform targets
- `Cargo.toml`:
  - `crate-type = ["staticlib", "cdylib"]` for multi-platform FFI
  - Minimal SurrealDB dependency: `surrealdb = { version = "latest", default-features = false, features = ["kv-mem", "kv-rocksdb"] }`
  - Release profile optimized for size: `opt-level = "z"`, `lto = true`, `strip = true`

**FFI Patterns:**
- All Rust functions: `#[no_mangle]` and `extern "C"`
- Panic safety: wrap entry points with `std::panic::catch_unwind`
- String handling: CString/CStr for FFI boundary
- Memory safety: Box::into_raw() for owned data, destructor functions for cleanup
- Null pointer checks on all Rust entry points
- Error codes: integer return values (0 = success, negative = error)

**Dart FFI Layer:**
- Low-level bindings in `lib/src/ffi/`
- Opaque types extending Opaque
- NativeFinalizer for automatic resource cleanup
- String conversion utilities (Dart ↔ C)
- Pointer management with proper allocation/deallocation

**Async Architecture Details:**
- Dedicated background isolate spawned at initialization
- All database operations sent to isolate via SendPort
- Results communicated back via ReceivePort
- Future-based wrapper API for async operations
- Error propagation through isolate boundaries
- Isolate cleanup on database close
- Thread-safe operation serialization

**Error Handling Strategy:**
- FFI functions return integer status codes
- Separate `get_last_error()` function returns error message string
- Rust side stores thread-local error state
- Dart wrapper converts codes to exceptions
- Async errors propagated through Future.error or Stream.addError

**Memory Management:**
- NativeFinalizer attached to Dart wrapper objects
- Finalizer calls Rust destructor functions
- Explicit close() methods for critical resources
- String memory freed after use
- Response handles freed after consumption

**Testing Strategy:**
- Rust unit tests for core database logic
- Dart integration tests for FFI boundary
- Example app serves as manual integration test
- Test both mem:// and RocksDB backends
- Test error conditions and error message retrieval
- Test isolate cleanup and resource management

**Standards Compliance:**

From agent-os/standards:

1. **Tech Stack (global/tech-stack.md):**
   - Dart 3.9.2+ with null safety
   - FFI via dart:ffi and package:ffi
   - native_toolchain_rs from GitHub with commit pinning
   - Rust with exact version pinning in rust-toolchain.toml
   - NativeFinalizer for memory management

2. **Rust Integration (backend/rust-integration.md):**
   - Pin native_toolchain_rs to specific GitHub commit
   - Create hook/build.dart with RustBuilder
   - Exact Rust version in rust-toolchain.toml (no "stable")
   - Multi-platform targets array in rust-toolchain.toml
   - crate-type = ["staticlib", "cdylib"] in Cargo.toml
   - #[no_mangle] and extern "C" for all FFI functions
   - std::panic::catch_unwind for panic safety
   - CString/CStr for string handling
   - Box::into_raw() for owned data, destructor functions provided
   - Error codes, never panic across FFI boundary
   - Null pointer checks before dereferencing
   - Document thread safety requirements

3. **Async Patterns (backend/async-patterns.md):**
   - Never block UI thread - use compute() or isolates
   - Future-based APIs for all async operations
   - SendPort/ReceivePort for isolate communication
   - Dedicated isolate for continuous background work
   - StreamController for native callbacks to streams
   - Cancellation mechanism for long operations
   - NativeFinalizer for cleanup even on cancel/fail
   - Document threading requirements clearly
   - Only send primitives/SendPort across isolates
   - Don't share Pointer<T> across isolates unless thread-safe

4. **Error Handling (global/error-handling.md):**
   - Errors propagate through Future.error or exceptions
   - Clear error messages from native code
   - No silent failures

5. **Code Style (global/coding-style.md, global/conventions.md):**
   - PascalCase for classes/enums
   - camelCase for variables/functions
   - snake_case for file names
   - Prefix FFI types with Native (e.g., NativeDatabase)
   - final by default for all variables
   - Explicit type annotations for public APIs
   - Null safety throughout

**SurrealDB Rust SDK Alignment:**

From reference documentation analysis:

1. **All operations are async** - must mirror this in Dart API
2. **Response type pattern** - queries return Response with multiple statement results
3. **Chainable methods** - use_ns().use_db() pattern should be supported
4. **Parameterized queries** - support .bind() pattern for SQL injection prevention
5. **Error handling** - Response.check() and .take_errors() patterns
6. **Resource types** - use tuples like ("table", "id") for record identifiers

**Platform Support:**
- Primary: macOS (development and testing)
- Configured: iOS, Android, Windows, Linux (via rust-toolchain.toml)
- Validation: Future phases will test all platforms

**Dependencies:**

Dart pubspec.yaml:
```yaml
dependencies:
  ffi: ^2.1.0

dev_dependencies:
  test: ^1.25.6
  lints: ^6.0.0
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: <commit-hash>  # Specific commit to be determined during implementation
```

Rust Cargo.toml:
```toml
[dependencies]
surrealdb = { version = "latest", default-features = false, features = ["kv-mem", "kv-rocksdb"] }

[lib]
crate-type = ["staticlib", "cdylib"]

[profile.release]
opt-level = "z"
lto = true
codegen-units = 1
strip = true
```

## Implementation Notes

**Critical Path Items:**
1. Set up hook/build.dart with RustBuilder
2. Configure rust-toolchain.toml with pinned version and targets
3. Implement Rust FFI layer with opaque handles
4. Create Dart FFI bindings with opaque types
5. Set up background isolate for database operations
6. Implement async wrapper API
7. Create CLI example app with choosable examples
8. Test both mem:// and RocksDB backends
9. Validate memory cleanup with NativeFinalizer

**Risk Mitigation:**
- Complexity of isolate setup: Start simple with single request/response pattern
- SurrealDB async runtime: Research if tokio runtime can run in background thread
- Memory leaks: Comprehensive testing of NativeFinalizer cleanup
- Error handling across isolate: Clear error type definitions and serialization
- Platform differences: Focus on macOS initially, document platform-specific issues

**Success Criteria:**
- CLI example app runs successfully on macOS
- Can create in-memory database and execute queries
- Can create RocksDB database, persist data, and query it back
- No memory leaks detected in normal usage
- Errors properly propagated from Rust through isolate to Dart
- All FFI calls are async and non-blocking
- Clean shutdown releases all resources

**Documentation Requirements:**
- README with setup instructions
- Example app with inline comments explaining each step
- Code comments on FFI boundary explaining safety contracts
- Document threading model and safety guarantees
- Note limitations and future enhancements
