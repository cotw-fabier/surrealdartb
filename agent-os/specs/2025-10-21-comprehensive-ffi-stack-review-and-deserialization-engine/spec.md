# Specification: Comprehensive FFI Stack Review & Deserialization Engine

## Goal

Fix critical deserialization bug causing all field values to appear as null by replacing incorrect serde serialization with SurrealDB's Display trait, then perform comprehensive audit of the entire FFI stack to ensure 100% functionality of core CRUD operations across both storage backends.

## User Stories

- As a developer, I want SurrealDB query results to return clean JSON data so that I can access field values correctly in my Dart application
- As a developer, I want all CRUD operations to work reliably so that I can build applications with confidence
- As a developer, I want errors to propagate clearly from Rust to Dart so that I can debug issues effectively
- As a developer, I want both in-memory and RocksDB storage backends to work correctly so that I can choose the appropriate persistence strategy
- As a developer, I want the FFI stack to be memory-safe and leak-free so that my application remains stable during extended operation

## Core Requirements

### Functional Requirements

**Deserialization Fix:**
- Replace `serde_json::to_string(value)` with `value.to_string()` at line 22 in `rust/src/query.rs`
- Remove the entire custom recursive unwrapper (`unwrap_value()`, `unwrap_number()`, `unwrap_thing()`, `unwrap_array()`, `unwrap_object()` functions, lines 42-164)
- Display trait automatically unwraps all SurrealDB type wrappers (Strand, Number, Thing, Object, Array, etc.)
- All field values must appear with correct data (no nulls from type wrapper interference)
- Handle nested structures correctly (objects within arrays, arrays within objects)
- Preserve semantic types (Thing IDs as "table:id" strings, Decimals as strings for precision)

**CRUD Operations:**
- SELECT returns clean JSON arrays of records
- CREATE returns newly created record with auto-generated ID
- UPDATE returns updated record with all fields
- DELETE completes without errors
- Raw query() method handles all SurrealQL statements correctly
- All operations work across both storage backends (mem:// and RocksDB)

**FFI Stack Verification:**
- Rust FFI boundary safety (null pointer checks, panic handling)
- Dart isolate communication reliability (command/response flow)
- Memory management correctness (no leaks, proper cleanup)
- Error propagation across all three layers (Rust -> Dart FFI -> High-level API)
- Thread safety of background isolate architecture
- Tokio async runtime behavior with SurrealDB operations

**Error Handling:**
- Errors bubble up from Rust to Dart with clear messages
- Database errors appear as DatabaseException or subclasses
- Query errors appear as QueryException
- Connection errors appear as ConnectionException
- Stack traces preserved when available

### Non-Functional Requirements

**Performance:**
- Deserialization must not regress performance
- All operations complete within reasonable timeframes
- Background isolate prevents UI thread blocking
- Memory usage remains stable during extended operation

**Code Quality:**
- Remove all temporary diagnostic logging (eprintln! statements)
- Clean, maintainable code without unnecessary complexity
- Follow agent-os coding standards for Rust and Dart
- Comprehensive inline documentation maintained

**Reliability:**
- Zero memory leaks detected
- No panics across FFI boundary
- Proper resource cleanup via NativeFinalizer
- Graceful error handling without silent failures

**Maintainability:**
- Simplified codebase (removing custom unwrapper reduces complexity)
- Future-proof to handle new SurrealDB types automatically via Display trait
- Clear separation of concerns across three layers

## Visual Design

Not applicable - this is a backend infrastructure fix.

## Reusable Components

### Existing Code to Leverage

**Core FFI Infrastructure (already implemented):**
- `/Users/fabier/Documents/code/surrealdartb/rust/src/database.rs` - Database lifecycle operations
- `/Users/fabier/Documents/code/surrealdartb/rust/src/error.rs` - Error state management
- `/Users/fabier/Documents/code/surrealdartb/rust/src/runtime.rs` - Tokio runtime setup
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart` - FFI function declarations
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/ffi_utils.dart` - String conversion utilities
- `/Users/fabier/Documents/code/surrealdartb/lib/src/isolate/database_isolate.dart` - Background isolate management
- `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart` - High-level Database API

**Existing Error Handling Patterns:**
- Thread-local error storage in Rust (error.rs)
- ErrorResponse/SuccessResponse message types (isolate_messages.dart)
- Exception hierarchy (exceptions.dart)
- Panic safety via catch_unwind wrapper

**Existing Memory Management:**
- Opaque handle pattern (NativeDatabase, Response types)
- NativeFinalizer attachment for automatic cleanup
- Box::into_raw() and Box::from_raw() for ownership transfer
- CString/CStr for string boundary crossing

**Testing Infrastructure:**
- Example CLI app for manual validation
- Existing test scenarios in example app

### New Components Required

**None** - This is purely a fix to existing code:
- Modify `rust/src/query.rs` deserialization logic (one-line fix + removal of unwrapper)
- Remove diagnostic logging throughout codebase
- Update any documentation affected by the simplification

### Why This Approach Works

**The Research Discovery:**
From `docs/doc-sdk-rust/concepts/flexible-typing.mdx`, SurrealDB's `Value` type implements the `Display` trait which automatically produces clean JSON output:

```rust
// Current (WRONG):
let json_str = serde_json::to_string(value)  // Produces: {"Strand": "John"}

// Correct (using Display trait):
let json_str = value.to_string()  // Produces: "John"
```

The Display implementation handles all type unwrapping automatically:
- Strand -> plain string
- Number variants (Int, Float, Decimal) -> appropriate JSON numbers/strings
- Thing -> "table:id" format string
- Object -> clean JSON object
- Array -> clean JSON array
- Nested structures unwrapped recursively

This eliminates the need for a custom unwrapper entirely.

## Technical Approach

### The One-Line Fix

**Current code (line 22 in rust/src/query.rs):**
```rust
let json_str = serde_json::to_string(value)
    .map_err(|e| format!("Serialization error: {}", e))?;
```

**Fixed code:**
```rust
let json_str = value.to_string();
```

**Removal:**
Delete lines 23-164 (all diagnostic logging and the entire custom unwrapper implementation):
- Remove `eprintln!` diagnostic statements
- Remove `unwrap_value()` function
- Remove `unwrap_number()` function
- Remove `unwrap_thing()` function
- Remove `unwrap_array()` function
- Remove `unwrap_object()` function

### FFI Stack Audit Checklist

**Layer 1: Rust FFI (rust/src/*.rs)**
- Verify all FFI functions use `panic::catch_unwind`
- Check null pointer validation before dereferencing
- Confirm error messages stored in thread-local storage
- Validate CString/CStr conversions handle UTF-8 errors
- Ensure Box::into_raw/from_raw pairs are balanced
- Check Tokio runtime initialized correctly
- Verify async operations block correctly on runtime

**Layer 2: Dart FFI Bindings (lib/src/ffi/*.dart)**
- Verify opaque types extend Opaque correctly
- Check @Native annotations reference correct symbols
- Validate NativeFinalizer attached to all resource wrappers
- Ensure string conversions free allocations in finally blocks
- Check nullptr constants used for null checks
- Verify all FFI calls protected by try/catch

**Layer 3: High-Level API (lib/src/database.dart, lib/src/isolate/*.dart)**
- Verify background isolate spawns and initializes correctly
- Check command/response flow handles all message types
- Validate error responses converted to appropriate exceptions
- Ensure database handle persists across commands in isolate
- Check close() properly shuts down isolate and frees resources
- Verify StateError thrown when using closed database

**Cross-Layer Verification:**
- Test error propagation from Rust through all layers to Dart
- Verify memory cleanup occurs on abnormal termination
- Check isolate communication doesn't deadlock
- Validate response JSON parsing handles all data types
- Test concurrent operation safety (background isolate serialization)

### Testing Strategy

**Phase 1: Fix Verification (Primary Focus)**
- Apply the one-line fix to `rust/src/query.rs`
- Remove all unwrapper code and diagnostic logging
- Compile Rust code to verify no compilation errors
- Run example CLI app with all three scenarios
- Verify field values appear correctly (not null)
- Check type wrappers eliminated from output
- Test nested structures (objects in arrays, etc.)
- Verify Thing IDs formatted as "table:id"

**Phase 2: CRUD Operations Testing**
- Test SELECT on empty table (returns [])
- Test CREATE with various data types (strings, numbers, booleans, objects, arrays)
- Test SELECT after CREATE (returns created records)
- Test UPDATE on existing record
- Test DELETE on record
- Test SELECT after DELETE (record gone)
- Test raw query() with multiple statements
- Test parameterized queries (if bindings implemented)

**Phase 3: Storage Backend Testing**
- Repeat all CRUD tests with mem:// backend
- Repeat all CRUD tests with RocksDB backend
- Test RocksDB persistence (create, close, reopen, verify data still there)
- Test switching between databases within same backend
- Test switching namespaces

**Phase 4: Error Handling Testing**
- Test invalid SQL syntax (verify QueryException)
- Test operations on non-existent table (verify clean error)
- Test operations on closed database (verify StateError)
- Test null/invalid parameters to FFI functions
- Test malformed JSON in create/update operations
- Verify error messages are clear and actionable

**Phase 5: Memory and Performance Testing**
- Run extended operations (create 1000 records)
- Verify memory usage remains stable
- Force garbage collection, verify finalizers trigger
- Check for memory leaks using DevTools
- Verify no performance regression vs. previous version
- Test isolate shutdown leaves no dangling resources

**Test Execution:**
Use the existing example CLI app (not building new test suite):
- `example/cli_example.dart` serves as integration test
- Enhance validation in example scenarios
- Add assertions to verify clean data output
- Manually inspect console output for correct formatting
- Run multiple times to check for stability

### Implementation Steps

**Step 1: Apply Deserialization Fix**
1. Open `rust/src/query.rs`
2. Replace line 22: `serde_json::to_string(value)` with `value.to_string()`
3. Delete lines 23-164 (diagnostic logging and unwrapper functions)
4. Run `cargo build` to verify compilation
5. Run `cargo test` to verify Rust unit tests pass

**Step 2: Remove Diagnostic Logging**
1. Search for all `eprintln!` statements in Rust code
2. Remove diagnostic logging from `query.rs`, `database.rs`, etc.
3. Search for all `print('[ISOLATE]` statements in Dart isolate code
4. Remove diagnostic logging from `database_isolate.dart`
5. Verify clean console output after removal

**Step 3: Test Fix**
1. Run example app scenario 1 (connect and verify)
2. Run example app scenario 2 (create and query)
3. Run example app scenario 3 (storage backends)
4. Verify all field values appear correctly
5. Verify no type wrappers in output
6. Check error messages still clear and helpful

**Step 4: FFI Stack Audit**
1. Review each Rust FFI function for safety
2. Review Dart FFI bindings for correctness
3. Review isolate communication for reliability
4. Test error propagation from each layer
5. Test memory cleanup paths
6. Document any issues found

**Step 5: Fix Any Issues**
1. Address any bugs discovered during audit
2. Fix any memory leaks identified
3. Improve error messages if needed
4. Update documentation as necessary

**Step 6: Final Verification**
1. Run all CRUD operations on both backends
2. Verify performance hasn't regressed
3. Check memory usage remains stable
4. Verify error handling works correctly
5. Run example app multiple times for stability
6. Update CHANGELOG.md with all changes

### API Changes

**No public API changes required.** The fix is internal to the Rust FFI layer.

**Internal changes:**
- `surreal_value_to_json()` function simplified to use Display trait
- Custom unwrapper functions removed
- Response JSON now clean without type wrappers

**Behavior changes (fixes):**
- Field values now appear correctly instead of null
- JSON output cleaner and more readable
- Matches SurrealDB CLI output format
- Automatically handles new SurrealDB types via Display trait

## Out of Scope

**Advanced SurrealDB Features:**
- Vector indexing and similarity search
- Live queries and real-time subscriptions
- Graph traversal and complex queries
- Multi-statement transactions with ACID guarantees
- Subqueries and advanced SurrealQL features
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
- Any storage engines beyond mem and rocksdb

**Advanced Features:**
- Data synchronization between instances
- Replication and clustering
- Backup and restore functionality
- Import/export utilities
- Schema migrations
- Performance benchmarking suite

**Developer Experience Enhancements:**
- Code generation with ffigen
- Automated API documentation generation
- Comprehensive multi-platform CI/CD (focus on macOS only)
- Flutter plugin variant with UI
- Web platform support (WASM)

**New Features:**
- Parameterized query bindings (deferred to future)
- Query builder API
- ORM-like abstractions
- Custom serialization strategies

## Success Criteria

### Functional Success

**Deserialization:**
- All CRUD operations return clean JSON (no type wrappers visible)
- All field values appear correctly (no nulls from wrapper interference)
- Nested structures deserialize properly
- Thing IDs formatted as "table:id" strings
- Number types unwrapped to simplest representation
- Decimal types preserved as strings for precision

**CRUD Operations:**
- SELECT returns array of records
- CREATE returns single created record with ID
- UPDATE returns updated record
- DELETE completes without error
- Raw query() handles multiple statements
- All operations work on mem:// backend
- All operations work on RocksDB backend

**Error Handling:**
- Errors bubble up to Dart with clear messages
- Exception types match error categories (QueryException, ConnectionException, etc.)
- Stack traces preserved when available
- No silent failures

### Technical Success

**Code Quality:**
- Deserialization uses SurrealDB's Display trait
- Custom unwrapper code removed (simplified codebase)
- All diagnostic logging removed
- No compilation warnings
- Rust tests pass
- Code follows agent-os standards

**FFI Stack:**
- All FFI functions have null pointer checks
- All FFI functions wrapped with panic::catch_unwind
- Errors propagate correctly across all layers
- Memory management leak-free (verified with DevTools)
- Isolate communication works reliably
- Background isolate prevents UI blocking

**Performance:**
- No performance regression vs. previous version
- Memory usage stable during extended operation
- Response times within acceptable limits
- No memory leaks detected

**Reliability:**
- Example app runs multiple times without issues
- Both storage backends work correctly
- Database handle persists across operations
- Close() properly cleans up resources
- No crashes or panics

### Quality Success

**Documentation:**
- Inline comments updated to reflect simplified approach
- CHANGELOG.md updated with all changes
- README reflects accurate behavior
- FFI contracts documented clearly

**Maintainability:**
- Codebase simpler (fewer lines of code)
- Future SurrealDB types handled automatically
- Clear separation of concerns maintained
- No technical debt introduced

**Testing:**
- Example app validates all scenarios
- Manual testing confirms correct behavior
- Edge cases handled properly
- Error conditions tested

## Timeline Estimate

Based on the simple one-line fix identified:

**Day 1:**
- Morning: Apply deserialization fix, remove unwrapper code (1-2 hours)
- Afternoon: Remove diagnostic logging, test fix with example app (2-3 hours)
- Evening: Begin FFI stack audit (2-3 hours)

**Day 2:**
- Morning: Complete FFI stack audit (2-3 hours)
- Afternoon: Test all CRUD operations on both backends (2-3 hours)
- Evening: Fix any issues found, update documentation (2-3 hours)

**Total: ~2 days of focused work**

Much faster than a custom solution would have been, thanks to finding the proper SDK method.

## Implementation Notes

**Why This Fix Works:**
The SurrealDB Rust SDK team already solved this problem by implementing the Display trait on `surrealdb::Value`. This trait produces output identical to the SurrealDB CLI - clean, human-readable JSON with all type tags unwrapped automatically.

**Key Insight:**
We were solving a problem that was already solved. The issue was using the wrong serialization method (serde vs Display). By switching to the SDK's intended method, we get correct behavior for free, including automatic support for future SurrealDB types.

**Simplification Benefit:**
Removing the custom unwrapper eliminates ~120 lines of complex recursive code, reducing maintenance burden and potential bugs. The Display trait implementation in SurrealDB is battle-tested and handles edge cases we might have missed.

**Future-Proofing:**
When SurrealDB adds new types in future versions, the Display trait will handle them automatically. Our custom unwrapper would have required updates for each new type.
