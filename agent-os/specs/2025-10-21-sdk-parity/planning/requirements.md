# Spec Requirements: SDK Parity

## Initial Description
Implement complete 1:1 Rust:Dart SDK parity by wrapping all remaining Rust SDK features. Currently have a basic wrapper setup (visible in the example app), but need to implement all remaining methods and concepts from the Rust SDK to achieve full feature parity.

Context:
- Rust SDK documentation is located at: docs/doc-sdk-rust/
- Current implementation exists in: lib/src/ and example/
- The docs show extensive SDK methods (authenticate, connect, create, delete, export, get, import, insert, invalidate, query, run, select, select-live, set, signin, signup, unset, update, upsert, use, version, wait-for)
- Concepts include: authenticating users, concurrency, fetch, flexible typing, live queries, transactions, vector embeddings
- Current wrapper has basic functionality but needs all remaining features implemented

## Requirements Discussion

### First Round Questions

**Q1:** Priority order for implementation?
**Answer:** APPROVED - (1) CRUD operations, (2) authentication, (3) data methods, (4) parameter methods, (5) function execution, (6) advanced features

**Q2:** Live queries implementation approach?
**Answer:** Use Dart Streams (Stream<Notification>)

**Q3:** Error handling strategy?
**Answer:** EXPAND the exception hierarchy (add AuthenticationException, TransactionException, LiveQueryException, etc.)

**Q4:** Type mapping strategy?
**Answer:** Create Dart equivalents for Rust SDK types (RecordId, Datetime, Duration, etc.)

**Q5:** Transaction API pattern?
**Answer:** Use idiomatic Dart pattern: `await db.transaction((txn) => { ... })`

**Q6:** Insert builder API?
**Answer:** Use method chaining (insert().content(), insert().relation()) - BUT only if not too difficult technically

**Q7:** Authentication credentials pattern?
**Answer:** Create typed classes (RootCredentials, DatabaseCredentials, ScopeCredentials)

**Q8:** Export/import configuration support?
**Answer:** Defer configuration support to future iteration (basic export/import only)

**Q9:** Upsert patch variant?
**Answer:** Create a Dart PatchOp class with methods

**Q10:** Testing scope?
**Answer:** Focus ONLY on embedded mode (in-memory and rocksdb) - NO remote server tests

**Q11:** Special cases handling?
**Answer:** Use your best judgment

**Q12:** Limitations documentation?
**Answer:** Exclude remote-only features and FFI-incompatible features, document them clearly

### Existing Code to Reference

No similar existing features identified for reference. This is a greenfield implementation building on the basic FFI foundation already established.

### Follow-up Questions

No follow-up questions were needed.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
N/A - This is an SDK/API implementation spec, not a UI feature.

## Requirements Summary

### Current Implementation Status

**Already Implemented (Database class):**
- `connect()` - Factory method for connection with StorageBackend enum (memory, rocksdb)
- `query(String sql, [Map<String, dynamic>? bindings])` - Returns Response object
- `select(String table)` - Returns List<Map<String, dynamic>>
- `create(String table, Map<String, dynamic> data)` - Returns Map<String, dynamic>
- `update(String resource, Map<String, dynamic> data)` - Returns Map<String, dynamic>
- `delete(String resource)` - Returns void
- `useNamespace(String namespace)` - Returns void
- `useDatabase(String database)` - Returns void
- `close()` - Returns void with cleanup delay

**Current Exception Hierarchy:**
- DatabaseException (base)
- ConnectionException
- QueryException
- AuthenticationException (defined but not used yet)

**Current Architecture Patterns:**
- Direct FFI calls wrapped in Future(() {...})
- JSON serialization as FFI bridge
- Pointer-based native types (NativeDatabase, NativeResponse)
- Memory cleanup with try/finally blocks
- Response processing extracts and unwraps nested array structures

**Storage Backends:**
- StorageBackend.memory (mem://)
- StorageBackend.rocksdb (rocksdb://{path})

### Functional Requirements

Based on the Rust SDK documentation review, the following methods need to be implemented, organized by priority:

#### Priority 1: CRUD Operations (Partially Complete)

**Completed:**
- ✅ `db.select(table)` - Selects all records from table
- ✅ `db.create(table, data)` - Creates new record
- ✅ `db.update(resource, data)` - Updates existing record
- ✅ `db.delete(resource)` - Deletes record

**Missing CRUD Methods:**
- ❌ `db.insert(resource).content(data)` - Insert with builder pattern
- ❌ `db.insert(resource).relation(data)` - Insert relation with builder pattern
- ❌ `db.upsert(resource).content(data)` - Upsert with content replacement
- ❌ `db.upsert(resource).merge(data)` - Upsert with merge
- ❌ `db.upsert(resource).patch(PatchOp)` - Upsert with JSON patch operations

**Implementation Notes:**
- Insert/upsert require builder pattern (if technically feasible)
- Fallback: simple method variants if builder pattern too complex
- PatchOp class needs: `add()`, `change()`, `remove()`, `replace()` methods

#### Priority 2: Authentication Methods (All Missing)

**Missing Authentication Methods:**
- ❌ `db.authenticate(token)` - Authenticate with JWT token
- ❌ `db.signin(credentials)` - Sign in to authentication scope
- ❌ `db.signup(credentials)` - Sign up to authentication scope
- ❌ `db.invalidate()` - Invalidate current authentication

**Credential Classes Needed:**
- `RootCredentials` - Root user authentication
- `DatabaseCredentials` - Database-level authentication
- `ScopeCredentials` - Scope-based authentication with custom params
- `RecordCredentials` - Record-based authentication

**Implementation Notes:**
- All methods return Future<Jwt> (except invalidate which returns Future<void>)
- Jwt class should have `.asInsecureToken()` method for token access
- Authentication may have limited functionality in embedded mode

#### Priority 3: Data Methods (All Missing)

**Missing Data Methods:**
- ❌ `db.export(destination)` - Export database to file/stream
- ❌ `db.import(source)` - Import database from file/stream

**Implementation Notes:**
- Basic implementation only (no configuration support in initial iteration)
- Destination/source can be file path String
- Embedded mode compatibility required

#### Priority 4: Parameter Methods (All Missing)

**Missing Parameter Methods:**
- ❌ `db.set(name, value)` - Set parameter for connection
- ❌ `db.unset(name)` - Remove parameter for connection

**Implementation Notes:**
- Parameters stored per-connection for use in queries
- Used with parameterized queries like `$param_name`

#### Priority 5: Function Execution (All Missing)

**Missing Function Methods:**
- ❌ `db.run(function)` - Run SurrealQL function
- ❌ `db.version()` - Get database version

**Implementation Notes:**
- `run()` executes both built-in functions (e.g., "rand::float") and user-defined functions
- Return types should be generic/deserializable

#### Priority 6: Advanced Features (All Missing)

**Missing Advanced Methods:**
- ❌ `db.select(table).live()` - Live query returning Stream<Notification>
- ❌ Transaction support via `db.transaction((txn) => {...})`

**Implementation Notes:**
- Live queries return Dart Stream<Notification<T>>
- Notification class contains: queryId, action (Create/Update/Delete), data
- Transactions use callback pattern with automatic commit/rollback

### Type Definitions Needed

**Core Types to Implement:**

1. **RecordId**
   - Represents a table:id pair
   - Constructor: `RecordId.from((table, id))`
   - Serializable to/from JSON

2. **Datetime**
   - Wrapper for SurrealDB datetime
   - Convertible to/from Dart DateTime
   - ISO 8601 formatting

3. **Duration**
   - Wrapper for SurrealDB duration
   - Convertible to/from Dart Duration
   - String parsing support (e.g., "2h30m")

4. **PatchOp**
   - Methods: `PatchOp.add(path, value)`, `PatchOp.change(path, value)`, `PatchOp.remove(path)`, `PatchOp.replace(path, value)`
   - Serializable to JSON Patch format

5. **Jwt**
   - Wrapper for JWT token
   - Method: `asInsecureToken()` returns String
   - Serializable

6. **Notification<T>**
   - Generic notification for live queries
   - Properties: `queryId` (String), `action` (enum), `data` (T)
   - Action enum: Create, Update, Delete

7. **Credential Classes**
   - RootCredentials(username, password)
   - DatabaseCredentials(username, password, namespace, database)
   - ScopeCredentials(namespace, database, scope, params)
   - RecordCredentials(namespace, database, access, params)

### Exception Classes to Add

**New Exception Types:**
- `TransactionException` - Transaction-specific errors (commit/rollback failures)
- `LiveQueryException` - Live query errors (subscription failures)
- `ExportException` - Export operation failures
- `ImportException` - Import operation failures
- `ParameterException` - Parameter operation failures

**Keep Existing:**
- `DatabaseException` (base)
- `ConnectionException`
- `QueryException`
- `AuthenticationException`

### Stream/Async Patterns

**Live Queries:**
- Return type: `Future<Stream<Notification<T>>>`
- Pattern: `final stream = await db.select('table').live(); await for (final notification in stream) { ... }`
- Cancellation: Stream subscription cancellation should clean up live query

**Transactions:**
- Pattern: `await db.transaction((txn) => { /* operations */ })`
- Automatic BEGIN/COMMIT
- Automatic ROLLBACK on exception
- Return value: Future<T> where T is callback return type

### Technical Concerns & Implementation Notes

#### Method Chaining for Insert/Upsert

**User Preference:** Use method chaining if not too difficult technically

**Options:**
1. **Full Builder Pattern** (Preferred if feasible):
   ```dart
   final record = await db.insert('person').content(data);
   final relation = await db.insert('founded').relation(data);
   ```
   - Requires intermediate builder classes (InsertBuilder, UpsertBuilder)
   - More complex but matches Rust SDK API exactly

2. **Simple Method Variants** (Fallback):
   ```dart
   final record = await db.insertContent('person', data);
   final relation = await db.insertRelation('founded', data);
   ```
   - Simpler implementation
   - Slightly different API from Rust SDK

**Recommendation:** Attempt builder pattern; fallback to method variants if FFI complexity makes it impractical.

#### Transaction API Design

**User Preference:** Callback-based pattern

**Implementation:**
```dart
Future<T> transaction<T>(Future<T> Function(Database txn) callback) async {
  // Execute BEGIN
  // Create transaction-scoped database instance
  // Execute callback
  // COMMIT on success, ROLLBACK on exception
  // Return callback result
}
```

**Note:** Transactions in Rust SDK are manual (BEGIN...COMMIT), but Dart API should provide automatic wrapper for ergonomics.

#### Live Queries with Streams

**User Preference:** Use Dart Streams

**Implementation:**
- FFI layer needs callback mechanism for notifications
- Use StreamController to bridge FFI callbacks to Dart Stream
- Subscription management to track active live queries
- Cleanup on stream cancellation

**Challenges:**
- FFI callbacks across isolate boundary
- Memory management for long-lived subscriptions
- Thread safety

#### Embedded Mode Limitations

**User Requirement:** Exclude remote-only features, document clearly

**Remote-Only Features to Exclude:**
- WebSocket-specific connection options
- HTTP-specific connection options
- Remote server wait-for functionality (may not apply to embedded)

**Documentation Required:**
- Clear README section on "Embedded vs Remote Differences"
- API documentation noting which features work only in remote mode
- Migration guide for users who later need remote functionality

#### FFI Technical Challenges

**Identified Challenges:**
1. **Method Chaining:** Requires returning intermediate FFI handles
2. **Streams:** Requires FFI callback mechanism
3. **Generic Types:** Type safety across FFI boundary
4. **Builder Patterns:** Multiple FFI calls with state preservation

**Mitigation Strategies:**
- Start with simpler variants, iterate to complex patterns
- Use JSON serialization for complex data structures
- Comprehensive error handling at FFI boundary
- Memory safety with NativeFinalizer for all native handles

### Scope Boundaries

**In Scope:**
- All methods listed in Rust SDK documentation applicable to embedded mode
- Type-safe Dart wrappers for SurrealDB types
- Comprehensive exception hierarchy
- Stream-based live queries
- Callback-based transactions
- Builder patterns for insert/upsert (if feasible)
- Basic export/import functionality
- Parameter management (set/unset)
- Function execution
- Authentication methods (with embedded mode limitations)

**Out of Scope:**
- Remote-only connection methods (WebSocket, HTTP specific features)
- Export/import configuration (deferred to future iteration)
- Advanced sync/replication features
- SurrealDB embedded ML models
- wait-for functionality (may be remote-only)
- Complex Value.get() method (marked as v3.0.0-alpha.1+ in docs)

**Future Enhancements:**
- Full configuration support for export/import
- Advanced connection pooling
- Query builder helpers
- Migration tooling
- Performance profiling integration

### Testing Requirements

**User Requirement:** Focus ONLY on embedded mode (in-memory and rocksdb) - NO remote server tests

**Test Coverage Required:**
1. **Unit Tests:**
   - All public methods
   - Exception handling
   - Type conversions
   - Edge cases (null values, empty results, etc.)

2. **Integration Tests:**
   - CRUD operations
   - Authentication flows
   - Live queries with real data changes
   - Transaction commit/rollback scenarios
   - Export/import round-trip
   - Parameter usage in queries

3. **Storage Backend Tests:**
   - All tests run against BOTH memory and rocksdb backends
   - RocksDB file locking and cleanup
   - Concurrent access patterns

4. **Memory Tests:**
   - No memory leaks (NativeFinalizer working correctly)
   - Resource cleanup on connection close
   - Stream cancellation cleanup

5. **Error Path Tests:**
   - All exception types triggered
   - FFI error propagation
   - Graceful degradation

**Test Exclusions:**
- Remote server connection tests
- Network failure scenarios
- WebSocket/HTTP specific features

### Reusability Opportunities

**From Current Codebase:**
- FFI patterns established in current Database class
- Response processing and JSON deserialization patterns
- Error handling with _getLastErrorString()
- Memory management with malloc/free patterns
- StorageBackend enum pattern can be extended
- Response/NativeResponse types

**Patterns to Extract/Reuse:**
- FFI guard pattern for all native calls
- Response unwrapping logic (nested array handling)
- Try/finally blocks for memory cleanup
- Future(() { ... }) wrapping pattern

### API Design Principles

**Alignment with Product Standards:**
- All methods async (return Future<T>)
- Type-safe APIs (no dynamic where avoidable)
- Null safety throughout
- Idiomatic Dart naming (camelCase, not snake_case)
- Rich exception types (not error codes)
- Documentation with examples for every public method
- Stream-based APIs for reactive features

**FFI Standards Compliance:**
- NativeFinalizer for all resource cleanup
- No exposed pointers in public API
- JSON as FFI serialization bridge
- Panic handling in Rust layer
- Memory safety checks at boundaries

**Error Handling Standards:**
- Custom exception hierarchy
- Preserve native error context
- Try/finally for resource cleanup
- Never let exceptions propagate to native code from callbacks
- Log all native errors with context

## Complete Method Inventory

### Summary by Category

| Category | Methods | Status |
|----------|---------|--------|
| **Initialization** | 6 methods | 3/6 Complete (50%) |
| **Query** | 4 methods | 1/4 Complete (25%) |
| **Mutation** | 5 methods | 3/5 Complete (60%) |
| **Authentication** | 4 methods | 0/4 Complete (0%) |
| **Data** | 2 methods | 0/2 Complete (0%) |
| **Other** | 1 method | 0/1 Complete (0%) |
| **TOTAL** | **22 methods** | **7/22 Complete (32%)** |

### Detailed Method List

#### Initialization Methods (3/6 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.connect(endpoint)` | ✅ DONE | P0 | Factory method implemented |
| `db.useNamespace(ns)` | ✅ DONE | P0 | Implemented as `useNamespace()` |
| `db.useDatabase(db)` | ✅ DONE | P0 | Implemented as `useDatabase()` |
| `db.set(name, value)` | ❌ TODO | P1 | Parameter management |
| `db.unset(name)` | ❌ TODO | P1 | Parameter management |
| `Surreal::init()` | ⚠️ N/A | P3 | Non-connected instance (may not apply to FFI pattern) |
| `Surreal::new()` | ⚠️ N/A | P3 | Connected instance (covered by connect()) |

#### Query Methods (1/4 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.query(sql, bindings)` | ✅ DONE | P0 | Returns Response object |
| `db.select(table)` | ✅ DONE | P0 | Returns List<Map> |
| `db.select(table).live()` | ❌ TODO | P2 | Returns Stream<Notification> |
| `db.run(function)` | ❌ TODO | P1 | Execute SurrealQL function |

#### Mutation Methods (3/5 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.create(table, data)` | ✅ DONE | P0 | Returns Map |
| `db.update(resource, data)` | ✅ DONE | P0 | Returns Map |
| `db.delete(resource)` | ✅ DONE | P0 | Returns void |
| `db.insert(resource).content(data)` | ❌ TODO | P1 | Builder pattern |
| `db.insert(resource).relation(data)` | ❌ TODO | P1 | Builder pattern |
| `db.upsert(resource).content(data)` | ❌ TODO | P1 | Builder pattern |
| `db.upsert(resource).merge(data)` | ❌ TODO | P1 | Builder pattern |
| `db.upsert(resource).patch(ops)` | ❌ TODO | P1 | Requires PatchOp class |

#### Authentication Methods (0/4 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.authenticate(token)` | ❌ TODO | P1 | JWT authentication |
| `db.signin(credentials)` | ❌ TODO | P1 | Returns Jwt |
| `db.signup(credentials)` | ❌ TODO | P1 | Returns Jwt |
| `db.invalidate()` | ❌ TODO | P1 | Clear authentication |

#### Data Methods (0/2 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.export(destination)` | ❌ TODO | P2 | Basic only, no config |
| `db.import(source)` | ❌ TODO | P2 | Basic only, no config |

#### Other Methods (0/1 Complete)

| Method | Status | Priority | Notes |
|--------|--------|----------|-------|
| `db.version()` | ❌ TODO | P2 | Returns version string |

#### Advanced Features (0/1 Complete)

| Feature | Status | Priority | Notes |
|---------|--------|----------|-------|
| Transactions | ❌ TODO | P2 | Callback pattern: `db.transaction((txn) => {})` |

### Type Definitions Inventory (0/7 Complete)

| Type | Status | Priority | Purpose |
|------|--------|----------|---------|
| `RecordId` | ❌ TODO | P0 | Table:ID representation |
| `Datetime` | ❌ TODO | P1 | SurrealDB datetime type |
| `Duration` | ❌ TODO | P1 | SurrealDB duration type |
| `PatchOp` | ❌ TODO | P1 | JSON patch operations |
| `Jwt` | ❌ TODO | P1 | JWT token wrapper |
| `Notification<T>` | ❌ TODO | P2 | Live query notifications |
| `Credential` classes | ❌ TODO | P1 | Root, Database, Scope, Record credentials |

### Exception Types Inventory (1/5 Complete)

| Exception | Status | Priority | Purpose |
|-----------|--------|----------|---------|
| `DatabaseException` | ✅ DONE | P0 | Base exception |
| `ConnectionException` | ✅ DONE | P0 | Connection errors |
| `QueryException` | ✅ DONE | P0 | Query errors |
| `AuthenticationException` | ⚠️ PARTIAL | P1 | Defined but not used |
| `TransactionException` | ❌ TODO | P2 | Transaction errors |
| `LiveQueryException` | ❌ TODO | P2 | Live query errors |
| `ExportException` | ❌ TODO | P2 | Export errors |
| `ImportException` | ❌ TODO | P2 | Import errors |
| `ParameterException` | ❌ TODO | P2 | Parameter errors |

## Implementation Roadmap

### Phase 1: Type System Foundation (Estimated: 3-5 days)
- Implement RecordId class
- Implement Datetime class
- Implement Duration class
- Implement PatchOp class
- Implement Jwt class
- Implement Notification class
- Implement Credential classes (Root, Database, Scope, Record)
- Add corresponding exception types

### Phase 2: Complete CRUD Operations (Estimated: 5-7 days)
- Implement insert() with builder pattern (or method variants)
- Implement upsert() with content/merge/patch variants
- Add comprehensive tests for all CRUD operations
- Document usage patterns

### Phase 3: Authentication (Estimated: 4-6 days)
- Implement signin/signup/authenticate/invalidate
- Test authentication flows in embedded mode
- Document embedded mode limitations
- Handle authentication exceptions properly

### Phase 4: Parameter & Function Methods (Estimated: 3-4 days)
- Implement set/unset for parameters
- Implement run() for function execution
- Implement version() method
- Test parameterized queries

### Phase 5: Advanced Features (Estimated: 7-10 days)
- Implement live queries with Stream<Notification>
- Implement transaction callback pattern
- FFI callback mechanism for live queries
- Stream lifecycle management
- Transaction commit/rollback handling

### Phase 6: Data Import/Export (Estimated: 3-4 days)
- Implement basic export() method
- Implement basic import() method
- Test round-trip export/import
- Document limitations (no config support)

### Phase 7: Testing & Documentation (Estimated: 5-7 days)
- Comprehensive test suite for all methods
- Both storage backends (memory, rocksdb)
- Error path testing
- Memory leak testing
- API documentation completion
- Usage examples
- Migration guide

**Total Estimated Effort:** 30-43 days (6-9 weeks)

## Success Criteria

1. ✅ All 22 SDK methods implemented for embedded mode
2. ✅ All 7 type definitions completed
3. ✅ Complete exception hierarchy (9 exception types)
4. ✅ Live queries working with Dart Streams
5. ✅ Transactions working with callback pattern
6. ✅ Comprehensive test coverage (>80% line coverage)
7. ✅ All tests pass on both storage backends
8. ✅ Zero memory leaks detected
9. ✅ Complete API documentation with examples
10. ✅ Clear documentation of embedded vs remote differences
11. ✅ Example app demonstrating all major features

## Risk Assessment

### High Risk Areas
1. **Live Queries FFI Callbacks** - Complex to implement correctly across FFI boundary
2. **Method Chaining/Builder Pattern** - May be technically difficult with FFI
3. **Transaction State Management** - Ensuring proper isolation and cleanup
4. **Memory Management** - Long-lived subscriptions, stream cleanup

### Medium Risk Areas
1. **Authentication in Embedded Mode** - May have limitations compared to remote mode
2. **Type Conversions** - Dart <-> Rust type mapping complexity
3. **Stream Cancellation** - Ensuring proper cleanup of native resources

### Low Risk Areas
1. **Parameter Methods (set/unset)** - Straightforward implementation
2. **Function Execution** - Similar to existing query() pattern
3. **Export/Import** - Basic file operations

### Mitigation Strategies
- Start with simpler implementations, iterate to complex patterns
- Comprehensive testing at each phase
- Clear documentation of limitations
- Fallback approaches for complex patterns (e.g., builder pattern fallback)
