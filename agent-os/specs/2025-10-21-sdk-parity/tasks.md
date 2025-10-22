# Task Breakdown: SurrealDB Dart SDK Parity

## Overview

Total Task Groups: 8
Total Tasks: ~50 subtasks organized across 8 phases
Estimated Effort: 35-50 days (7-10 weeks)
Assigned Implementers: api-engineer, database-engineer, testing-engineer

**Goal:** Achieve 100% Rust:Dart SDK parity (from 32% to 100%) by implementing 15 remaining methods, 7 type definitions, 5 new exception types, and advanced features (live queries, transactions).

## Task List

### Phase 1: Foundation & Type System

#### Task Group 1.1: Core Type Definitions
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 3-5 days

- [ ] 1.1.0 Complete core type definitions
  - [ ] 1.1.1 Write 2-8 focused tests for type conversions
    - RecordId parsing and serialization (e.g., "person:alice")
    - Datetime conversion to/from Dart DateTime
    - Duration parsing (e.g., "2h30m")
    - PatchOp JSON serialization
    - Test ONLY critical conversion paths
  - [ ] 1.1.2 Implement RecordId class
    - Properties: `table` (String), `id` (dynamic - String or number)
    - Constructor: `RecordId(String table, dynamic id)`
    - Factory: `RecordId.parse(String recordId)` for "table:id" parsing
    - Methods: `toString()`, `toJson()`, `fromJson()`
    - Validation: Ensure table and id are valid SurrealDB identifiers
    - Reference existing patterns in lib/src/
  - [ ] 1.1.3 Implement Datetime class
    - Wraps SurrealDB datetime with conversion to/from Dart DateTime
    - Constructor: `Datetime(DateTime dateTime)`, `Datetime.parse(String iso8601)`
    - Methods: `toDateTime()`, `toIso8601String()`, `toJson()`, `fromJson()`
    - Serialization: ISO 8601 format for FFI transport
  - [ ] 1.1.4 Implement Duration class
    - Wraps SurrealDB duration with conversion to/from Dart Duration
    - Constructor: `SurrealDuration(Duration duration)`, `SurrealDuration.parse(String str)`
    - Methods: `toDuration()`, `toString()`, `toJson()`, `fromJson()`
    - String parsing supports SurrealDB syntax: "2h30m", "5d", "1w3d"
    - Note: Name it `SurrealDuration` to avoid conflict with Dart's Duration
  - [ ] 1.1.5 Implement PatchOp class
    - Static factories: `PatchOp.add(String path, dynamic value)`, `PatchOp.change(String path, dynamic value)`, `PatchOp.remove(String path)`, `PatchOp.replace(String path, dynamic value)`
    - Properties: `operation` (enum: add/change/remove/replace), `path`, `value`
    - Methods: `toJson()` serializes to JSON Patch format (RFC 6902)
    - Used with upsert().patch([PatchOp.add(...)])
  - [ ] 1.1.6 Ensure type definition tests pass
    - Run ONLY the 2-8 tests written in 1.1.1
    - Verify all conversions work correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1.1 pass
- RecordId parses "table:id" format correctly
- Datetime converts to/from Dart DateTime
- Duration parses SurrealDB duration strings
- PatchOp serializes to JSON Patch format

#### Task Group 1.2: Authentication Types & Exceptions
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 2-3 days

- [ ] 1.2.0 Complete authentication types and exception hierarchy
  - [ ] 1.2.1 Write 2-8 focused tests for authentication types
    - Credential class JSON serialization
    - JWT token wrapping
    - Exception construction and message formatting
    - Test ONLY critical type behaviors
  - [ ] 1.2.2 Implement Jwt wrapper class
    - Properties: `_token` (private String)
    - Constructor: `Jwt(String token)`, `Jwt.fromJson(Map<String, dynamic>)`
    - Methods: `asInsecureToken()` returns String, `toJson()`
    - Serializable for FFI transport
  - [ ] 1.2.3 Implement Credentials base class and hierarchy
    - Base: `abstract class Credentials` with `toJson()` method
    - `RootCredentials(String username, String password)`
    - `NamespaceCredentials(String username, String password, String namespace)`
    - `DatabaseCredentials(String username, String password, String namespace, String database)`
    - `ScopeCredentials(String namespace, String database, String scope, Map<String, dynamic> params)`
    - `RecordCredentials(String namespace, String database, String access, Map<String, dynamic> params)`
    - All extend base and serialize to appropriate JSON
  - [ ] 1.2.4 Implement Notification class for live queries
    - Generic class: `Notification<T>`
    - Properties: `queryId` (String), `action` (NotificationAction enum), `data` (T)
    - Enum: `enum NotificationAction { create, update, delete }`
    - Constructor: `Notification(String queryId, NotificationAction action, T data)`
    - Factory: `Notification.fromJson(Map<String, dynamic> json, T Function(dynamic) deserializer)`
  - [ ] 1.2.5 Add new exception types
    - `TransactionException extends DatabaseException` - Transaction failures
    - `LiveQueryException extends DatabaseException` - Live query subscription failures
    - `ParameterException extends DatabaseException` - Parameter set/unset failures
    - `ExportException extends DatabaseException` - Export operation failures
    - `ImportException extends DatabaseException` - Import operation failures
    - Follow existing exception pattern with message, errorCode, nativeStackTrace
  - [ ] 1.2.6 Ensure authentication type tests pass
    - Run ONLY the 2-8 tests written in 1.2.1
    - Verify credential serialization works
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.2.1 pass
- All credential types serialize to correct JSON
- JWT wrapper exposes token via asInsecureToken()
- All 5 new exception types are defined
- Notification class supports generic type parameter

---

### Phase 2: CRUD Operations Completion (Priority 1)

#### Task Group 2.1: Insert Operations with Builder Pattern
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.1 (RecordId type)
**Estimated Effort:** 4-5 days

- [ ] 2.1.0 Complete insert operations
  - [ ] 2.1.1 Write 2-8 focused tests for insert operations
    - Test insert().content() for standard records
    - Test insert().relation() for graph relationships
    - Test basic error cases (invalid table, null data)
    - Skip exhaustive validation tests
  - [ ] 2.1.2 Decide builder pattern vs method variants
    - Attempt builder pattern: `db.insert('table').content(data)`
    - If FFI state management too complex, use fallback: `db.insertContent('table', data)`
    - Document decision in code comments
    - Evaluate feasibility based on existing FFI patterns in lib/src/database.dart
  - [ ] 2.1.3 Implement Rust FFI function for insert
    - Add `db_insert` function in Rust native layer
    - Support both content and relation variants
    - Return JSON response
    - Follow panic safety pattern with catch_unwind
    - Use CString for string parameters
  - [ ] 2.1.4 Implement Dart insert wrapper
    - If builder pattern: Create `InsertBuilder` class with FFI handle
    - If method variants: Add `insertContent()` and `insertRelation()` methods
    - Wrap FFI call in Future(() {...})
    - JSON encode/decode for data transport
    - Try/finally for memory cleanup
    - Process response using `_processResponse()` pattern
  - [ ] 2.1.5 Handle insert edge cases
    - Null data validation
    - Empty table name validation
    - RecordId serialization in relations (in/out fields)
    - Error message extraction from native layer
  - [ ] 2.1.6 Ensure insert tests pass
    - Run ONLY the 2-8 tests written in 2.1.1
    - Verify both content and relation patterns work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1.1 pass
- Insert content pattern works for standard records
- Insert relation pattern works for graph edges
- FFI memory management is safe (try/finally)
- Proper exceptions thrown on errors

#### Task Group 2.2: Upsert Operations with Multiple Variants
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.1 (PatchOp type), Task Group 2.1
**Estimated Effort:** 4-5 days

- [ ] 2.2.0 Complete upsert operations
  - [ ] 2.2.1 Write 2-8 focused tests for upsert operations
    - Test upsert().content() for full replacement
    - Test upsert().merge() for field merging
    - Test upsert().patch() with PatchOp operations
    - Test critical error case
    - Skip exhaustive edge case testing
  - [ ] 2.2.2 Implement Rust FFI functions for upsert variants
    - Add `db_upsert_content`, `db_upsert_merge`, `db_upsert_patch` in Rust
    - Or single `db_upsert` with mode parameter if simpler
    - Support PatchOp JSON patch format for patch variant
    - Return JSON response
    - Follow existing FFI safety patterns
  - [ ] 2.2.3 Implement Dart upsert wrapper
    - If builder pattern: Create `UpsertBuilder` class
    - If method variants: Add `upsertContent()`, `upsertMerge()`, `upsertPatch()` methods
    - Serialize PatchOp list to JSON for patch variant
    - Wrap FFI calls in Future(() {...})
    - Try/finally for memory cleanup
  - [ ] 2.2.4 Handle upsert edge cases
    - Validate resource parameter (must be specific record, not table)
    - Validate PatchOp array for patch variant
    - Null/empty data validation
    - Error handling for invalid patch operations
  - [ ] 2.2.5 Ensure upsert tests pass
    - Run ONLY the 2-8 tests written in 2.2.1
    - Verify all three variants work correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.2.1 pass
- Upsert content replaces entire record
- Upsert merge updates only specified fields
- Upsert patch applies JSON patch operations
- PatchOp serialization works correctly

#### Task Group 2.3: Get Operation
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.1 (RecordId type)
**Estimated Effort:** 2-3 days

- [ ] 2.3.0 Complete get operation
  - [ ] 2.3.1 Write 2-8 focused tests for get operation
    - Test get() for existing record
    - Test get() for non-existent record (returns null)
    - Test generic type deserialization
    - Skip exhaustive type testing
  - [ ] 2.3.2 Implement Rust FFI function for get
    - Add `db_get` function in Rust native layer
    - Accept resource parameter (table:id)
    - Return JSON response (null if not found)
    - Follow existing FFI patterns
  - [ ] 2.3.3 Implement Dart get wrapper
    - Method signature: `Future<T?> get<T>(String resource)`
    - Wrap FFI call in Future(() {...})
    - Deserialize JSON response to generic type T
    - Return null if record not found
    - Try/finally for memory cleanup
  - [ ] 2.3.4 Handle get edge cases
    - Null resource validation
    - Invalid resource format handling
    - Type deserialization errors
    - Non-existent record returns null, not exception
  - [ ] 2.3.5 Ensure get tests pass
    - Run ONLY the 2-8 tests written in 2.3.1
    - Verify type-safe deserialization
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.3.1 pass
- Get returns typed result for existing record
- Get returns null for non-existent record
- Generic type deserialization works
- No exceptions thrown for missing records

---

### Phase 3: Authentication Methods (Priority 2)

#### Task Group 3.1: Authentication Operations
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.2 (Jwt and Credentials types)
**Estimated Effort:** 4-6 days

- [ ] 3.1.0 Complete authentication operations
  - [ ] 3.1.1 Write 2-8 focused tests for authentication
    - Test signin() with different credential types
    - Test authenticate() with JWT
    - Test signup() with scope credentials
    - Test invalidate()
    - Focus on embedded mode behavior
    - Skip remote-only authentication features
  - [ ] 3.1.2 Implement Rust FFI functions for authentication
    - Add `db_signin`, `db_signup`, `db_authenticate`, `db_invalidate` in Rust
    - Accept credential JSON for signin/signup
    - Accept JWT token string for authenticate
    - Return JWT token JSON for signin/signup
    - Handle embedded mode limitations
  - [ ] 3.1.3 Implement signin() method
    - Method signature: `Future<Jwt> signin(Credentials credentials)`
    - Serialize credentials to JSON
    - Call native `db_signin`
    - Deserialize response to Jwt object
    - Throw AuthenticationException on failure
    - Try/finally for memory cleanup
  - [ ] 3.1.4 Implement signup() method
    - Method signature: `Future<Jwt> signup(ScopeCredentials credentials)`
    - Only accepts ScopeCredentials or RecordCredentials
    - Serialize credentials to JSON
    - Call native `db_signup`
    - Deserialize response to Jwt object
    - Throw AuthenticationException on failure
  - [ ] 3.1.5 Implement authenticate() method
    - Method signature: `Future<void> authenticate(Jwt token)`
    - Extract token string via `token.asInsecureToken()`
    - Call native `db_authenticate`
    - Throw AuthenticationException on failure
    - No return value (void)
  - [ ] 3.1.6 Implement invalidate() method
    - Method signature: `Future<void> invalidate()`
    - Call native `db_invalidate`
    - Clear current authentication session
    - No return value (void)
  - [ ] 3.1.7 Document embedded mode limitations
    - Authentication may have reduced functionality in embedded mode
    - Scope-based access control may not fully apply
    - Token refresh not supported
    - Add clear documentation in method comments
  - [ ] 3.1.8 Ensure authentication tests pass
    - Run ONLY the 2-8 tests written in 3.1.1
    - Verify authentication flows work in embedded mode
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1.1 pass
- Signin works with all credential types
- Signup creates new user with scope credentials
- Authenticate accepts JWT token
- Invalidate clears session
- Embedded mode limitations documented

---

### Phase 4: Parameter & Function Methods (Priority 4-5)

#### Task Group 4.1: Parameter Management
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 2-3 days

- [ ] 4.1.0 Complete parameter management
  - [ ] 4.1.1 Write 2-8 focused tests for parameter operations
    - Test set() stores parameter
    - Test unset() removes parameter
    - Test parameters work in queries ($param_name)
    - Test basic error cases
    - Skip exhaustive parameter type testing
  - [ ] 4.1.2 Implement Rust FFI functions for parameters
    - Add `db_set` and `db_unset` in Rust native layer
    - Accept parameter name and JSON value for set
    - Accept parameter name for unset
    - Parameters persist per connection
    - Return error code on failure
  - [ ] 4.1.3 Implement set() method
    - Method signature: `Future<void> set(String name, dynamic value)`
    - JSON encode value
    - Call native `db_set`
    - Throw ParameterException on failure
    - Try/finally for memory cleanup
  - [ ] 4.1.4 Implement unset() method
    - Method signature: `Future<void> unset(String name)`
    - Call native `db_unset`
    - Throw ParameterException on failure
    - No error if parameter doesn't exist
  - [ ] 4.1.5 Ensure parameter tests pass
    - Run ONLY the 2-8 tests written in 4.1.1
    - Verify parameters work in queries
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1.1 pass
- Set stores parameters per connection
- Unset removes parameters
- Parameters accessible in queries via $name
- Proper exceptions on errors

#### Task Group 4.2: Function Execution
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 2-3 days

- [ ] 4.2.0 Complete function execution
  - [ ] 4.2.1 Write 2-8 focused tests for function execution
    - Test run() with built-in function (e.g., rand::float)
    - Test run() with function arguments
    - Test version() returns version string
    - Skip user-defined function tests (rely on integration tests)
  - [ ] 4.2.2 Implement Rust FFI functions
    - Add `db_run` for function execution in Rust
    - Accept function name and JSON arguments array
    - Return JSON response with function result
    - Add `db_version` for version retrieval
  - [ ] 4.2.3 Implement run() method
    - Method signature: `Future<T> run<T>(String function, [List<dynamic>? args])`
    - Serialize args to JSON array
    - Call native `db_run`
    - Deserialize response to generic type T
    - Throw QueryException on execution failure
  - [ ] 4.2.4 Implement version() method
    - Method signature: `Future<String> version()`
    - Call native `db_version`
    - Return version string (e.g., "1.5.0")
    - Simple implementation, no complex logic
  - [ ] 4.2.5 Ensure function execution tests pass
    - Run ONLY the 2-8 tests written in 4.2.1
    - Verify built-in functions execute
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.2.1 pass
- Run executes built-in SurrealQL functions
- Run accepts optional arguments array
- Version returns database version string
- Generic type deserialization works

---

### Phase 5: Data Import/Export (Priority 3)

#### Task Group 5.1: Export and Import Operations
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 3-4 days

- [ ] 5.1.0 Complete export and import operations
  - [ ] 5.1.1 Write 2-8 focused tests for export/import
    - Test export() creates file
    - Test import() loads from file
    - Test round-trip export/import
    - Test file I/O error handling
    - Skip configuration options (deferred)
  - [ ] 5.1.2 Implement Rust FFI functions for export/import
    - Add `db_export` and `db_import` in Rust native layer
    - Accept file path string
    - Basic implementation only - no advanced configuration
    - Handle file I/O errors properly
    - Return error code on failure
  - [ ] 5.1.3 Implement export() method
    - Method signature: `Future<void> export(String path)`
    - Call native `db_export` with file path
    - Throw ExportException on failure
    - Basic functionality only
    - Try/finally for memory cleanup
  - [ ] 5.1.4 Implement import() method
    - Method signature: `Future<void> import(String path)`
    - Call native `db_import` with file path
    - Throw ImportException on failure
    - Basic functionality only
  - [ ] 5.1.5 Document limitations
    - No configuration support in initial implementation
    - No table selection, format options, or ML model handling
    - Deferred to future iteration
    - Add documentation comments
  - [ ] 5.1.6 Ensure export/import tests pass
    - Run ONLY the 2-8 tests written in 5.1.1
    - Verify round-trip works
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 5.1.1 pass
- Export writes database to file
- Import loads database from file
- Round-trip preserves data
- File I/O errors throw proper exceptions
- Limitations clearly documented

---

### Phase 6: Advanced Features - Live Queries (Priority 6)

#### Task Group 6.1: Live Query Infrastructure
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.2 (Notification type)
**Estimated Effort:** 7-10 days (HIGH COMPLEXITY)

- [ ] 6.1.0 Complete live query infrastructure
  - [ ] 6.1.1 Write 2-8 focused tests for live queries
    - Test live() returns Stream
    - Test notifications received on data changes
    - Test stream cancellation cleans up resources
    - Test notification action types (create/update/delete)
    - Focus on critical stream lifecycle
    - Skip performance and stress testing
  - [ ] 6.1.2 Design FFI callback mechanism
    - Research Dart FFI callback patterns
    - Design thread-safe callback bridge from Rust to Dart
    - Plan subscription ID tracking for cleanup
    - Consider isolate boundary challenges
    - Document design decisions
  - [ ] 6.1.3 Implement Rust FFI functions for live queries
    - Add `db_select_live` in Rust native layer
    - Implement callback mechanism for notifications
    - Use std::panic::catch_unwind in callback paths
    - Never panic into Dart code from callbacks
    - Return subscription ID for cleanup
    - Add `db_kill_live` for subscription cleanup
  - [ ] 6.1.4 Implement StreamController bridge
    - Create StreamController to bridge FFI callbacks to Dart Stream
    - Store active subscriptions in Map<String, StreamController>
    - Register FFI callback that adds events to StreamController
    - Handle callback errors gracefully (log, don't throw)
    - Ensure thread safety
  - [ ] 6.1.5 Implement live() method
    - Method signature: `Future<Stream<Notification<T>>> live<T>()`
    - Add to select() result or create selectLive() variant
    - Call native `db_select_live`
    - Create StreamController for notifications
    - Register callback for notifications
    - Return Stream from controller
    - Store subscription ID for cleanup
  - [ ] 6.1.6 Implement stream cancellation cleanup
    - Override Stream.listen() to track subscriptions
    - On subscription.cancel(), call native `db_kill_live`
    - Remove StreamController from tracking map
    - Close StreamController
    - Free native resources
    - Use NativeFinalizer if appropriate
  - [ ] 6.1.7 Handle live query edge cases
    - Callback error handling (never throw into native)
    - Multiple simultaneous live queries
    - Database close while live queries active
    - Memory cleanup on stream cancellation
    - Thread safety for callback invocations
  - [ ] 6.1.8 Ensure live query tests pass
    - Run ONLY the 2-8 tests written in 6.1.1
    - Verify notifications received
    - Verify cleanup works
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 6.1.1 pass
- Live queries return Stream<Notification<T>>
- Notifications received on database changes
- Stream cancellation cleans up native resources
- No memory leaks from long-lived subscriptions
- Thread-safe callback mechanism
- Proper error handling (no panics into Dart)

---

### Phase 7: Advanced Features - Transactions (Priority 6)

#### Task Group 7.1: Transaction Support
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 5-7 days

- [ ] 7.1.0 Complete transaction support
  - [ ] 7.1.1 Write 2-8 focused tests for transactions
    - Test transaction() commits on success
    - Test transaction() rolls back on exception
    - Test transaction-scoped database operations
    - Test callback return value propagation
    - Skip nested transaction testing (if not supported)
  - [ ] 7.1.2 Implement Rust FFI functions for transactions
    - Add `db_begin`, `db_commit`, `db_rollback` in Rust
    - Or unified `db_transaction` if simpler
    - Ensure transaction isolation
    - Handle errors properly
    - Return error codes for commit/rollback failures
  - [ ] 7.1.3 Design transaction-scoped database instance
    - Create transaction-scoped Database instance or wrapper
    - All operations within callback use transaction scope
    - Prevent operations outside transaction context
    - Share FFI handle or clone appropriately
  - [ ] 7.1.4 Implement transaction() method
    - Method signature: `Future<T> transaction<T>(Future<T> Function(Database txn) callback)`
    - Call native `db_begin`
    - Create transaction-scoped Database instance
    - Execute callback with scoped instance
    - On success: call native `db_commit`, return callback result
    - On exception: call native `db_rollback`, rethrow exception
    - Use try/catch/finally for cleanup
    - Throw TransactionException on commit/rollback failures
  - [ ] 7.1.5 Handle transaction edge cases
    - Ensure rollback happens on any exception
    - Cleanup even on commit/rollback failures
    - Prevent nested transactions (or document behavior)
    - Database close during transaction
    - Timeout handling if applicable
  - [ ] 7.1.6 Ensure transaction tests pass
    - Run ONLY the 2-8 tests written in 7.1.1
    - Verify commit and rollback behavior
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 7.1.1 pass
- Transaction commits on successful callback
- Transaction rolls back on exception
- Callback return value propagates correctly
- Transaction-scoped operations work
- Proper cleanup on all paths
- TransactionException thrown on failures

---

### Phase 8: Testing & Documentation

#### Task Group 8.1: Comprehensive Testing & Gap Analysis
**Assigned Implementer:** testing-engineer
**Dependencies:** Task Groups 1.1 - 7.1 (All implementation complete)
**Estimated Effort:** 5-7 days

- [ ] 8.1.0 Review existing tests and fill critical gaps only
  - [ ] 8.1.1 Review tests from all previous task groups
    - Review tests from Task Group 1.1 (type definitions - 2-8 tests)
    - Review tests from Task Group 1.2 (auth types - 2-8 tests)
    - Review tests from Task Group 2.1 (insert - 2-8 tests)
    - Review tests from Task Group 2.2 (upsert - 2-8 tests)
    - Review tests from Task Group 2.3 (get - 2-8 tests)
    - Review tests from Task Group 3.1 (authentication - 2-8 tests)
    - Review tests from Task Group 4.1 (parameters - 2-8 tests)
    - Review tests from Task Group 4.2 (functions - 2-8 tests)
    - Review tests from Task Group 5.1 (export/import - 2-8 tests)
    - Review tests from Task Group 6.1 (live queries - 2-8 tests)
    - Review tests from Task Group 7.1 (transactions - 2-8 tests)
    - Total existing tests: approximately 22-88 tests
  - [ ] 8.1.2 Analyze test coverage gaps for SDK parity feature only
    - Identify critical user workflows lacking test coverage
    - Focus ONLY on gaps related to SDK parity spec requirements
    - Do NOT assess entire application test coverage
    - Prioritize integration tests over unit test gaps
    - Key workflows: end-to-end CRUD, auth flow, live query lifecycle, transaction patterns
  - [ ] 8.1.3 Write up to 15 additional strategic tests maximum
    - Integration tests for feature combinations (e.g., auth + parameters in query)
    - End-to-end workflows (create → live query → update → notification)
    - Error path tests for all exception types
    - Memory safety tests (live query cleanup, transaction cleanup, finalizers)
    - Storage backend compatibility (memory vs RocksDB)
    - Do NOT write comprehensive coverage for all scenarios
    - Skip edge cases unless business-critical
    - Maximum 15 new tests to fill critical gaps
  - [ ] 8.1.4 Run SDK parity feature-specific tests only
    - Run ONLY tests related to SDK parity spec (tests from 8.1.1 + new tests from 8.1.3)
    - Expected total: approximately 37-103 tests maximum
    - Test on both memory and RocksDB storage backends
    - Do NOT run the entire application test suite
    - Verify critical workflows pass
    - Verify no memory leaks detected

**Acceptance Criteria:**
- All SDK parity feature-specific tests pass (approximately 37-103 tests total)
- Critical user workflows for SDK parity are covered
- No more than 15 additional tests added by testing-engineer
- Testing focused exclusively on SDK parity spec requirements
- Both storage backends (memory and RocksDB) tested
- No memory leaks detected

#### Task Group 8.2: Documentation & Examples
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 8.1
**Estimated Effort:** 3-4 days

- [ ] 8.2.0 Complete documentation and examples
  - [ ] 8.2.1 Document all new public APIs
    - Add dartdoc comments to all public methods
    - Include usage examples in method documentation
    - Document parameters, return types, exceptions
    - Follow existing documentation style in codebase
  - [ ] 8.2.2 Update README with new features
    - Add section on CRUD operations completion (insert, upsert, get)
    - Add section on authentication methods
    - Add section on live queries with Stream examples
    - Add section on transactions with callback pattern
    - Add section on parameter management
    - Add section on function execution
    - Add section on export/import
  - [ ] 8.2.3 Document embedded vs remote differences
    - Create clear section "Embedded vs Remote Mode"
    - Document authentication limitations in embedded mode
    - Document which features work only in remote mode
    - Provide migration guide for users who need remote functionality
    - List excluded features (WebSocket, HTTP-specific, wait-for)
  - [ ] 8.2.4 Update example app
    - Add examples for insert operations (content and relation)
    - Add examples for upsert variants (content, merge, patch)
    - Add examples for authentication flows
    - Add example for live query subscription
    - Add example for transaction usage
    - Add examples for parameter usage
    - Ensure example app runs successfully
  - [ ] 8.2.5 Create API reference documentation
    - Generate dartdoc HTML documentation
    - Verify all public APIs are documented
    - Review generated docs for clarity
  - [ ] 8.2.6 Document type definitions
    - RecordId usage and parsing
    - Datetime conversion patterns
    - Duration parsing syntax
    - PatchOp usage in upsert
    - Credentials hierarchy
    - Notification structure

**Acceptance Criteria:**
- All public APIs have dartdoc comments with examples
- README includes all new features
- Embedded vs remote differences clearly documented
- Example app demonstrates all major features
- Example app runs without errors
- Migration guide available for remote mode
- API reference documentation generated

---

## Execution Order

**Recommended implementation sequence:**

1. **Phase 1** (Task Groups 1.1 - 1.2): Foundation & Type System
   - Essential types needed by all subsequent phases
   - Can be implemented in parallel by api-engineer

2. **Phase 2** (Task Groups 2.1 - 2.3): CRUD Operations Completion
   - Builds on RecordId and PatchOp types
   - Sequential within phase (insert → upsert → get)

3. **Phase 3** (Task Group 3.1): Authentication Methods
   - Builds on Jwt and Credentials types
   - Independent of CRUD operations

4. **Phase 4** (Task Groups 4.1 - 4.2): Parameter & Function Methods
   - Independent features, can be parallelized
   - Lower complexity

5. **Phase 5** (Task Group 5.1): Data Import/Export
   - Independent feature
   - Lower complexity

6. **Phase 6** (Task Group 6.1): Advanced Features - Live Queries
   - HIGH COMPLEXITY - allocate extra time
   - Builds on Notification type
   - FFI callback mechanism is challenging

7. **Phase 7** (Task Group 7.1): Advanced Features - Transactions
   - MEDIUM COMPLEXITY
   - Independent of other features

8. **Phase 8** (Task Groups 8.1 - 8.2): Testing & Documentation
   - Final phase, requires all features complete
   - Testing and documentation can be partially parallelized

## Complexity Assessment

**High Complexity Tasks:**
- Task Group 6.1: Live Query Infrastructure (FFI callbacks, Stream bridge, memory management)
- Task Group 7.1: Transaction Support (scoping, automatic commit/rollback)

**Medium Complexity Tasks:**
- Task Group 2.1: Insert with Builder Pattern (FFI state management decision)
- Task Group 2.2: Upsert with Multiple Variants (three patterns to support)
- Task Group 3.1: Authentication Operations (embedded mode limitations)

**Low Complexity Tasks:**
- Task Group 1.1: Core Type Definitions (standard serialization)
- Task Group 1.2: Authentication Types & Exceptions (class definitions)
- Task Group 2.3: Get Operation (straightforward FFI call)
- Task Group 4.1: Parameter Management (simple key-value storage)
- Task Group 4.2: Function Execution (similar to query execution)
- Task Group 5.1: Export and Import Operations (basic file I/O)

## Risk Mitigation

**High Risk Areas:**
1. **Live Queries FFI Callbacks** - Complex FFI patterns, allocate extra time, research callback patterns early
2. **Builder Pattern Feasibility** - Have fallback approach ready (method variants), decide early in Phase 2
3. **Memory Management** - Use NativeFinalizer consistently, test cleanup thoroughly
4. **Authentication in Embedded Mode** - Document limitations clearly, test what works

**Mitigation Strategies:**
- Start with simpler implementations, iterate to complex patterns
- Comprehensive testing at each phase (2-8 focused tests per task group)
- Clear documentation of limitations and fallback approaches
- Follow existing FFI patterns in lib/src/database.dart strictly
- Use try/finally for all FFI cleanup

## Implementation Notes

**Builder Pattern Decision (Task Group 2.1):**
- Attempt builder pattern first: `db.insert('table').content(data)`
- If FFI state management too complex, use fallback: `db.insertContent('table', data)`
- Document decision in code comments
- Both approaches are acceptable per spec

**Authentication in Embedded Mode (Task Group 3.1):**
- Authentication features implemented but may have limited functionality
- Limitations must be clearly documented in API docs and README
- Testing should verify what works and document what doesn't

**Live Query Callbacks (Task Group 6.1):**
- Highest complexity component - allocate extra time
- Prioritize correctness and memory safety over performance
- Performance optimization can be addressed in future iterations
- Never throw exceptions into native code from callbacks

**Testing Focus:**
- All testing focuses exclusively on embedded mode (memory and RocksDB)
- No remote server tests in this iteration
- Each task group writes 2-8 focused tests for core functionality
- testing-engineer adds maximum 15 strategic tests for integration and gaps
- Total expected tests: approximately 37-103 tests for entire SDK parity feature

**FFI Standards Compliance:**
- Use NativeFinalizer for all resource cleanup
- Use panic::catch_unwind in all Rust FFI entry points
- Never return null pointers without checking in Dart
- Use CString/CStr for string passing
- JSON serialization as primary FFI data bridge
- Try/finally blocks for memory cleanup in Dart
