# Specification: SurrealDB Dart SDK Parity

## Goal

Achieve complete 1:1 Rust:Dart SDK parity for surrealdartb by implementing all remaining SurrealDB SDK methods, types, and features for embedded mode (memory and RocksDB storage). This brings the SDK from 32% feature complete to 100%, enabling comprehensive database operations including CRUD extensions, authentication, live queries, transactions, parameter management, and data import/export.

## User Stories

- As a developer using surrealdartb, I want to insert records with both content and relation patterns so that I can create standard records and graph relationships efficiently
- As a developer, I want to upsert records with content, merge, and patch operations so that I can handle create-or-update scenarios with different merge strategies
- As a developer, I want to authenticate users and manage sessions so that I can implement secure access control in my applications
- As a developer, I want to subscribe to live queries with Dart Streams so that I can build reactive applications that respond to database changes in real-time
- As a developer, I want to execute transactions with automatic commit/rollback so that I can ensure data consistency for multi-step operations
- As a developer, I want to set and manage query parameters so that I can write reusable parameterized queries
- As a developer, I want to execute custom SurrealQL functions so that I can leverage server-side logic and built-in utilities
- As a developer, I want to export and import database data so that I can backup, restore, and migrate databases
- As a developer, I want type-safe Dart representations of SurrealDB types (RecordId, Datetime, Duration, etc.) so that I can work with SurrealDB data idiomatically in Dart

## Core Requirements

### Functional Requirements

**Priority 1 - CRUD Operations Completion:**
- Insert records using builder pattern: `db.insert('table').content(data)` and `db.insert('relation').relation(data)`
- Upsert records with three variants: content (replace all), merge (update fields), patch (JSON patch operations)
- Get specific record by ID with type-safe deserialization
- All operations return appropriate typed results

**Priority 2 - Authentication:**
- Authenticate with existing JWT token
- Sign in with credentials (root, namespace, database, scope levels)
- Sign up new users with scope credentials
- Invalidate current session
- Typed credential classes for type safety (RootCredentials, NamespaceCredentials, DatabaseCredentials, ScopeCredentials)
- JWT token wrapper with access methods

**Priority 3 - Data Methods:**
- Export database to file path (basic functionality, no advanced configuration)
- Import database from file path (basic functionality, no advanced configuration)
- File-based operations suitable for embedded mode

**Priority 4 - Parameter Methods:**
- Set query parameter for connection: `db.set(key, value)`
- Unset query parameter: `db.unset(key)`
- Parameters persist per connection and work in queries with `$param_name` syntax

**Priority 5 - Function Execution:**
- Execute SurrealQL functions: `db.run(function, [args])`
- Support both built-in functions (e.g., "rand::float") and user-defined functions
- Generic return type handling for various function results
- Get database version: `db.version()`

**Priority 6 - Advanced Features:**
- Live queries returning Dart Stream: `await db.select('table').live()` returns `Stream<Notification<T>>`
- Notification class with queryId, action (Create/Update/Delete), and data
- Stream cancellation automatically cleans up live query subscriptions
- Transaction support with callback pattern: `await db.transaction((txn) => { ... })`
- Automatic BEGIN/COMMIT with automatic ROLLBACK on exception
- Transaction-scoped database instance passed to callback

### Non-Functional Requirements

**Performance:**
- Live query FFI callbacks must have minimal overhead
- Transaction operations should perform at near-native speed
- Stream subscription and cancellation must be efficient
- No memory leaks from long-lived subscriptions or transaction state

**Type Safety:**
- All SurrealDB types have Dart equivalents with proper serialization
- Builder patterns maintain type safety across method chains
- Generic types properly constrain to valid SurrealDB types
- Credential classes use compile-time type checking

**Error Handling:**
- Expand exception hierarchy with 6 new exception types
- Preserve native error context in all exceptions
- Clear error messages for authentication failures
- Proper error handling in FFI callbacks (never throw into native code)
- Transaction failures trigger automatic rollback with clear exception

**Memory Safety:**
- All native resources cleaned up via try/finally
- NativeFinalizer used for long-lived resources
- Stream cancellation releases native subscriptions
- Transaction cleanup even on exception paths

**Compatibility:**
- Embedded mode only (memory and RocksDB)
- Authentication may have limitations in embedded mode (document clearly)
- Remote-only features explicitly excluded and documented
- Clear migration guide for users who later need remote functionality

## Visual Design

Not applicable - This is an SDK/API specification without UI components.

## Reusable Components

### Existing Code to Leverage

**FFI Patterns:**
- Direct FFI call wrapping in `Future(() {...})` from `database.dart`
- JSON serialization as FFI bridge pattern
- Pointer-based native types (NativeDatabase, NativeResponse)
- Memory cleanup with try/finally blocks established in all methods
- Response processing that extracts and unwraps nested array structures
- `_processResponse()` and `_processQueryResponse()` helper methods
- `_getLastErrorString()` error extraction pattern

**Exception Hierarchy:**
- Base `DatabaseException` class with errorCode and nativeStackTrace
- `ConnectionException` for connection failures
- `QueryException` for query failures
- `AuthenticationException` defined but not yet used (ready to implement)
- Exception constructor pattern with optional errorCode and nativeStackTrace

**Response Processing:**
- `Response` class with `getResults()`, `takeResult(index)`, `firstOrNull`, etc.
- Nested array unwrapping logic for SurrealDB response structures
- JSON deserialization patterns

**Storage and Connection:**
- `StorageBackend` enum with memory and rocksdb variants
- Endpoint generation: `backend.toEndpoint(path)`
- Connection lifecycle: connect, useNamespace, useDatabase, close
- Close delay pattern for async cleanup (especially for RocksDB)

**Type Patterns:**
- Clean Future-based async APIs
- Null safety throughout
- Map<String, dynamic> for record data
- JSON encoding/decoding at FFI boundary

### New Components Required

**Type Definitions (7 new types):**
- `RecordId` - Cannot reuse existing types; need SurrealDB-specific table:id representation with serialization
- `Datetime` - Cannot reuse Dart DateTime directly; need SurrealDB datetime with ISO 8601 formatting and conversion
- `Duration` - Cannot reuse Dart Duration; need SurrealDB duration with string parsing (e.g., "2h30m")
- `PatchOp` - New class for JSON patch operations (add, change, remove, replace methods)
- `Jwt` - New wrapper for JWT tokens with `asInsecureToken()` method
- `Notification<T>` - New generic class for live query notifications with queryId, action enum, and typed data
- `Credentials` - New hierarchy: RootCredentials, NamespaceCredentials, DatabaseCredentials, ScopeCredentials, RecordCredentials

**Builder Classes (if technically feasible):**
- `InsertBuilder` - For method chaining insert operations (insert().content(), insert().relation())
- `UpsertBuilder` - For method chaining upsert operations (upsert().content(), upsert().merge(), upsert().patch())
- Builders maintain FFI state and execute on final method call
- Fallback: Simple method variants if builder pattern too complex with FFI (e.g., `db.insertContent()`, `db.insertRelation()`)

**Exception Types (6 new):**
- `TransactionException` - Cannot reuse existing; specific to transaction commit/rollback failures
- `LiveQueryException` - Cannot reuse existing; specific to live query subscription failures
- `ParameterException` - Cannot reuse existing; specific to parameter set/unset failures
- `ExportException` - Cannot reuse existing; specific to export operation failures
- `ImportException` - Cannot reuse existing; specific to import operation failures
- Note: `AuthenticationException` already defined, needs implementation

**Stream Management:**
- StreamController bridge for FFI callbacks to Dart Streams
- Subscription tracking for cleanup
- Cancellation handlers for live queries

**Transaction Infrastructure:**
- Transaction-scoped database instance
- BEGIN/COMMIT/ROLLBACK logic
- Exception-based rollback trigger
- Callback result handling

## Technical Approach

### Database Schema and Types

**Core Type Implementations:**

1. **RecordId**
   - Properties: `table` (String), `id` (String or dynamic)
   - Constructor: `RecordId(String table, dynamic id)`, `RecordId.parse(String recordId)`
   - Methods: `toString()` returns "table:id", `toJson()`, `fromJson()`
   - Validation: Ensure table and id are valid SurrealDB identifiers

2. **Datetime**
   - Wraps SurrealDB datetime with conversion to/from Dart DateTime
   - Constructor: `Datetime(DateTime dateTime)`, `Datetime.parse(String iso8601)`
   - Methods: `toDateTime()`, `toIso8601String()`, `toJson()`, `fromJson()`
   - Serialization: ISO 8601 format for FFI transport

3. **Duration**
   - Wraps SurrealDB duration with conversion to/from Dart Duration
   - Constructor: `Duration(Duration duration)`, `Duration.parse(String str)` (e.g., "2h30m")
   - Methods: `toDuration()`, `toString()`, `toJson()`, `fromJson()`
   - String parsing supports SurrealDB duration syntax

4. **PatchOp**
   - Static factory methods: `PatchOp.add(String path, dynamic value)`, `PatchOp.change(String path, dynamic value)`, `PatchOp.remove(String path)`, `PatchOp.replace(String path, dynamic value)`
   - Properties: `operation` (enum: add/change/remove/replace), `path` (String), `value` (dynamic)
   - Methods: `toJson()` serializes to JSON Patch format (RFC 6902)
   - Used with `upsert().patch([PatchOp.add(...), PatchOp.remove(...)])`

5. **Jwt**
   - Properties: `token` (private String)
   - Constructor: `Jwt(String token)`, `Jwt.fromJson(Map<String, dynamic>)`
   - Methods: `asInsecureToken()` returns String, `toJson()`
   - Serializable for FFI transport

6. **Notification<T>**
   - Properties: `queryId` (String), `action` (NotificationAction enum), `data` (T)
   - Enum: `NotificationAction { create, update, delete }`
   - Constructor: `Notification(String queryId, NotificationAction action, T data)`
   - Factory: `Notification.fromJson(Map<String, dynamic> json, T Function(dynamic) deserializer)`
   - Generic type allows type-safe live query results

7. **Credential Classes**
   - Base: `abstract class Credentials` with `toJson()` method
   - `RootCredentials(String username, String password)`
   - `NamespaceCredentials(String username, String password, String namespace)`
   - `DatabaseCredentials(String username, String password, String namespace, String database)`
   - `ScopeCredentials(String namespace, String database, String scope, Map<String, dynamic> params)`
   - `RecordCredentials(String namespace, String database, String access, Map<String, dynamic> params)`
   - All extend base Credentials and serialize to appropriate JSON for FFI

**Exception Hierarchy Expansion:**

```dart
// Existing (already implemented)
class DatabaseException implements Exception {...}
class ConnectionException extends DatabaseException {...}
class QueryException extends DatabaseException {...}
class AuthenticationException extends DatabaseException {...}

// New exception types to add
class TransactionException extends DatabaseException {...}
class LiveQueryException extends DatabaseException {...}
class ParameterException extends DatabaseException {...}
class ExportException extends DatabaseException {...}
class ImportException extends DatabaseException {...}
```

All exceptions follow existing pattern with message, errorCode, and nativeStackTrace.

### API Design

**CRUD Operations - Insert and Upsert:**

Preferred approach (if technically feasible with FFI):
```dart
// Insert with builder pattern
final person = await db.insert('person').content({
  'name': 'Alice',
  'age': 25,
});

final relation = await db.insert('founded').relation({
  'in': RecordId('person', 'alice'),
  'out': RecordId('company', 'acme'),
  'year': 1995,
});

// Upsert variants
final result1 = await db.upsert('person:alice').content({
  'name': 'Alice',
  'age': 26,
}); // Replace entire record

final result2 = await db.upsert('person:alice').merge({
  'age': 27,
}); // Merge fields

final result3 = await db.upsert('person:alice').patch([
  PatchOp.replace('/age', 28),
  PatchOp.add('/email', 'alice@example.com'),
]); // JSON patch operations

// Get specific record
final record = await db.get<Map<String, dynamic>>('person:alice');
```

Fallback approach (if builder pattern too complex):
```dart
// Simple method variants
final person = await db.insertContent('person', {'name': 'Alice'});
final relation = await db.insertRelation('founded', {...});
final result = await db.upsertContent('person:alice', {...});
```

**Authentication:**

```dart
// Sign in with different credential types
final jwt1 = await db.signin(RootCredentials('root', 'root'));
final jwt2 = await db.signin(DatabaseCredentials('user', 'pass', 'ns', 'db'));
final jwt3 = await db.signin(ScopeCredentials('ns', 'db', 'user_scope', {
  'email': 'user@example.com',
  'password': 'pass',
}));

// Authenticate with existing token
await db.authenticate(jwt1);

// Get token string if needed
final tokenStr = jwt1.asInsecureToken();

// Sign up new user
final newJwt = await db.signup(ScopeCredentials('ns', 'db', 'user_scope', {
  'email': 'new@example.com',
  'password': 'newpass',
}));

// Invalidate session
await db.invalidate();
```

**Parameters and Functions:**

```dart
// Set parameters
await db.set('user_id', 'person:alice');
await db.set('min_age', 18);

// Use in queries
final response = await db.query('SELECT * FROM person WHERE id = $user_id AND age >= $min_age');

// Unset parameters
await db.unset('user_id');

// Execute functions
final randomFloat = await db.run<double>('rand::float');
final customResult = await db.run<Map<String, dynamic>>('fn::my_function', [arg1, arg2]);

// Get version
final version = await db.version(); // Returns String like "1.5.0"
```

**Live Queries:**

```dart
// Subscribe to live query
final stream = await db.select('person').live<Map<String, dynamic>>();

// Listen to changes
final subscription = stream.listen((notification) {
  print('Query ID: ${notification.queryId}');
  print('Action: ${notification.action}'); // create, update, delete
  print('Data: ${notification.data}');

  switch (notification.action) {
    case NotificationAction.create:
      // Handle new record
      break;
    case NotificationAction.update:
      // Handle update
      break;
    case NotificationAction.delete:
      // Handle deletion
      break;
  }
});

// Cancel subscription (automatically cleans up native resources)
await subscription.cancel();
```

**Transactions:**

```dart
// Execute transaction with automatic commit/rollback
final result = await db.transaction((txn) async {
  // All operations within transaction
  final person = await txn.create('person', {'name': 'Bob'});
  await txn.create('account', {'owner': person['id'], 'balance': 100});

  // If exception thrown, automatic ROLLBACK
  // If successful, automatic COMMIT

  return person;
});
// result contains the returned value from callback
```

**Export and Import:**

```dart
// Export database to file
await db.export('/path/to/backup.surql');

// Import database from file
await db.import('/path/to/backup.surql');

// Note: Basic functionality only - advanced configuration deferred to future
```

### FFI Integration

**Existing FFI Patterns to Follow:**

1. **Direct FFI Calls Wrapped in Future:**
```dart
Future<void> useNamespace(String namespace) async {
  _ensureNotClosed();

  return Future(() {
    final nsPtr = namespace.toNativeUtf8();
    try {
      final result = dbUseNs(_handle, nsPtr);
      if (result != 0) {
        final error = _getLastErrorString();
        throw DatabaseException(error ?? 'Failed to set namespace');
      }
    } finally {
      malloc.free(nsPtr);
    }
  });
}
```

2. **JSON Serialization for Complex Data:**
```dart
final dataJson = jsonEncode(data);
final dataPtr = dataJson.toNativeUtf8();
try {
  final responsePtr = dbCreate(_handle, tablePtr, dataPtr);
  // Process response
} finally {
  malloc.free(dataPtr);
}
```

3. **Response Processing with Error Checking:**
```dart
dynamic _processResponse(Pointer<NativeResponse> responsePtr) {
  if (responsePtr == nullptr) {
    final error = _getLastErrorString();
    throw QueryException(error ?? 'Operation failed');
  }

  try {
    final hasErrors = responseHasErrors(responsePtr);
    if (hasErrors != 0) {
      final error = _getLastErrorString();
      throw QueryException(error ?? 'Query execution failed');
    }

    final jsonPtr = responseGetResults(responsePtr);
    if (jsonPtr == nullptr) {
      throw QueryException('Failed to get response results');
    }

    try {
      final jsonStr = jsonPtr.toDartString();
      return jsonDecode(jsonStr);
    } finally {
      freeString(jsonPtr);
    }
  } finally {
    responseFree(responsePtr);
  }
}
```

**New FFI Patterns Needed:**

1. **Builder Pattern State Management:**
   - Builder classes hold FFI handle references
   - Final method (e.g., `.content()`) executes FFI call
   - Alternative: Simple method variants if builder state management too complex

2. **Stream/Callback Bridge for Live Queries:**
   - FFI callback mechanism for notifications from Rust
   - StreamController to bridge callbacks to Dart Stream
   - Subscription ID tracking for cleanup
   - Proper memory management for long-lived callbacks

3. **Transaction Scoping:**
   - Clone or scope database handle for transaction
   - Execute BEGIN via FFI
   - Pass scoped instance to callback
   - COMMIT on success, ROLLBACK on exception
   - Ensure cleanup even on exception paths

### Implementation Phases

**Phase 1: Type System Foundation (3-5 days)**
- Implement RecordId, Datetime, Duration classes with full serialization
- Implement PatchOp class with all operations
- Implement Jwt wrapper class
- Implement Credentials hierarchy (Root, Namespace, Database, Scope, Record)
- Implement Notification class with generic type support
- Add new exception types: TransactionException, LiveQueryException, ParameterException, ExportException, ImportException
- Unit tests for all type conversions and serialization

**Phase 2: CRUD Operations Completion (5-7 days)**
- Implement insert() - attempt builder pattern, fallback to method variants if needed
- Implement upsert() with content, merge, patch variants
- Implement get() method for specific record retrieval
- Add corresponding FFI bindings in Rust layer
- Integration tests for all CRUD variants
- Both storage backends (memory and RocksDB)

**Phase 3: Authentication (4-6 days)**
- Implement signin() with credential type handling
- Implement signup() with scope credentials
- Implement authenticate() with JWT
- Implement invalidate() for session clearing
- Add FFI bindings for authentication methods
- Test authentication flows in embedded mode
- Document embedded mode limitations clearly

**Phase 4: Parameter and Function Methods (3-4 days)**
- Implement set() and unset() for parameter management
- Implement run() for SurrealQL function execution
- Implement version() method
- Add FFI bindings for parameter and function methods
- Test parameterized queries with set parameters
- Test built-in and user-defined function execution

**Phase 5: Advanced Features - Live Queries (7-10 days)**
- Design and implement FFI callback mechanism
- Implement live() method returning Future<Stream<Notification>>
- Implement StreamController bridge for callbacks
- Implement subscription tracking and cleanup
- Add FFI bindings for live query subscription
- Test stream lifecycle (subscribe, receive notifications, cancel)
- Test memory cleanup on cancellation
- HIGH COMPLEXITY: FFI callbacks across isolate boundary, memory management

**Phase 6: Advanced Features - Transactions (5-7 days)**
- Implement transaction() method with callback pattern
- Implement BEGIN/COMMIT/ROLLBACK via FFI
- Implement transaction-scoped database instance
- Implement exception-based rollback trigger
- Add FFI bindings for transaction control
- Test commit scenarios
- Test rollback on exception
- Test nested transaction behavior (if supported)

**Phase 7: Data Import/Export (3-4 days)**
- Implement export() method for file export
- Implement import() method for file import
- Add FFI bindings for export/import
- Test round-trip export/import
- Test file I/O error handling
- Document basic-only functionality (no advanced config)

**Phase 8: Testing and Documentation (5-7 days)**
- Comprehensive unit tests for all new methods
- Integration tests covering all feature combinations
- Test both storage backends (memory and RocksDB)
- Error path testing for all exception types
- Memory leak testing with long-lived subscriptions
- Complete API documentation with examples
- Update README with all new features
- Create migration guide for embedded vs remote differences
- Update example app to demonstrate all major features

**Total Estimated Effort:** 35-50 days (7-10 weeks)

### Testing Strategy

**Unit Tests:**
- All type conversions (RecordId, Datetime, Duration parsing and serialization)
- PatchOp JSON serialization
- Credential class JSON serialization
- Exception hierarchy construction and message formatting
- Response unwrapping edge cases
- Null handling and validation

**Integration Tests - Embedded Mode Only:**
- Insert content and relation patterns
- Upsert content, merge, patch variants
- Get record by ID with type deserialization
- Authentication flows (signin, signup, authenticate, invalidate)
- Parameter set/unset and usage in queries
- Function execution (built-in and user-defined)
- Live query subscription, notification receipt, cancellation
- Transaction commit scenarios
- Transaction rollback on exception
- Export and import round-trip
- All tests run against BOTH memory and RocksDB backends

**Error Handling Tests:**
- All exception types triggered and caught
- FFI error propagation and message preservation
- Authentication failures with proper exceptions
- Transaction rollback triggers on various exception types
- Live query subscription failures
- Parameter operation failures
- Export/import file I/O errors

**Memory Safety Tests:**
- No memory leaks from live query subscriptions
- No memory leaks from transaction state
- NativeFinalizer cleanup verification
- Stream cancellation releases native resources
- Database close releases all resources
- RocksDB file lock release after close

**Excluded from Testing:**
- Remote server connections
- WebSocket/HTTP specific features
- Network failure scenarios
- Remote-only wait-for functionality

**Test Coverage Target:** >80% line coverage for all new code

## Out of Scope

**Remote-Only Features (Explicitly Excluded):**
- WebSocket-specific connection options
- HTTP-specific connection options
- Remote server wait-for functionality
- Network retry and timeout configuration specific to remote connections

**Deferred to Future Iterations:**
- Advanced export/import configuration options (ML models, specific table selection, format options)
- Export/import progress callbacks
- Advanced query builder helpers beyond basic operations
- Migration tooling and schema versioning
- Performance profiling and metrics integration
- Connection pooling (may not apply to embedded)
- Complex Value.get() method (marked as v3.0.0-alpha.1+ in Rust docs)

**FFI-Incompatible Features:**
- Features requiring bidirectional async communication without callback support
- Features requiring shared mutable state across isolates
- Advanced sync/replication features designed for remote servers

**Embedded Mode Limitations to Document:**
- Authentication may have reduced functionality compared to remote mode
- Live queries may have different performance characteristics than remote WebSocket subscriptions
- Some SurrealQL features may behave differently or be unavailable in embedded mode
- Clearly document which features work only in remote mode in README section "Embedded vs Remote Differences"

## Success Criteria

1. All 15 remaining SDK methods implemented and tested (total 22/22 = 100% coverage)
2. All 7 new type definitions completed with full serialization/deserialization
3. Complete exception hierarchy with all 9 exception types (4 existing + 5 new)
4. Live queries working with Dart Streams with proper notification handling
5. Transactions working with callback pattern and automatic commit/rollback
6. Insert and upsert builder patterns implemented (or documented fallback approach)
7. Authentication methods functional in embedded mode with limitations documented
8. Parameter management (set/unset) working with parameterized queries
9. Function execution working for built-in and user-defined functions
10. Export and import working for basic file operations
11. Comprehensive test coverage >80% for all new code
12. All tests pass on both storage backends (memory and RocksDB)
13. Zero memory leaks detected in long-running tests
14. Complete API documentation with examples for all public methods
15. Clear documentation of embedded vs remote differences
16. Updated example app demonstrating all major features
17. Migration guide for users who later need remote functionality

## Known Limitations and Future Work

**Current Implementation Limitations:**
- Authentication in embedded mode may not support all features available in remote mode (e.g., token refresh, scope-based access control may have reduced functionality)
- Live queries use polling or file watching in embedded mode rather than WebSocket push notifications
- Some advanced SurrealQL features may behave differently in embedded vs remote mode

**Technical Debt to Address in Future:**
- Builder pattern complexity may require fallback to simple method variants if FFI state management proves too difficult
- Live query FFI callback mechanism may need performance optimization for high-frequency updates
- Transaction isolation level configuration not exposed in initial implementation
- Export/import configuration options deferred to future iteration

**Future Enhancements:**
- Full configuration support for export/import (table selection, format options, ML model handling)
- Advanced connection pooling for embedded mode if beneficial
- Query builder helpers for complex query construction
- Schema migration tooling
- Performance profiling and metrics
- Support for additional storage backends beyond memory and RocksDB
- Remote mode support (WebSocket, HTTP) as separate feature set
- Bi-directional sync between embedded and remote instances

**Documentation Gaps to Fill:**
- Comprehensive embedded vs remote feature comparison table
- Performance benchmarks for embedded mode operations
- Best practices for live query subscription management
- Transaction isolation and concurrency guidelines
- Authentication setup guide for embedded mode
- Troubleshooting guide for common FFI-related issues

## Implementation Notes

**Builder Pattern Decision:**
The specification prefers builder patterns for insert/upsert operations to match the Rust SDK API exactly. However, if FFI state management for builders proves too complex during implementation, the approved fallback is to use simple method variants (e.g., `insertContent()`, `insertRelation()`, `upsertContent()`, `upsertMerge()`, `upsertPatch()`). The implementation phase should attempt builders first and fall back if needed, documenting the decision in code comments.

**Authentication in Embedded Mode:**
Authentication features will be implemented following the Rust SDK API, but may have limited functionality in embedded mode. All limitations must be clearly documented in API documentation and README. Testing should verify what works in embedded mode and document what doesn't.

**Live Query FFI Callbacks:**
This is identified as a high-risk, high-complexity component. The implementation should prioritize correctness and memory safety over performance initially. Performance optimization can be addressed in subsequent iterations once the core functionality is stable.

**Testing Focus:**
All testing must focus exclusively on embedded mode (memory and RocksDB storage backends). No remote server tests should be included in this iteration. This keeps the scope manageable and ensures thorough coverage of the embedded mode feature set.

**Reusable Code:**
The existing FFI patterns in `database.dart` should be strictly followed for consistency. The `_processResponse()` pattern, try/finally cleanup blocks, and Future wrapping should be replicated in all new methods. This ensures maintainability and reduces bugs from pattern inconsistency.
