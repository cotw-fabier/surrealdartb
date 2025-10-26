# SurrealDartB - Dart FFI Bindings for Embedded SurrealDB

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](CHANGELOG.md)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

A powerful Dart package providing native FFI bindings to embed [SurrealDB](https://surrealdb.com) directly in your Dart and Flutter applications. Run a full-featured database on-device with support for vector indexing, graph queries, and advanced SurrealQL features.

## Features

- **Embedded Database** - Run SurrealDB locally without external dependencies
- **Vector Indexing** - Built-in support for AI/ML workflows with vector storage and similarity search
- **Multiple Storage Backends** - In-memory for testing, RocksDB for persistence
- **Full SurrealQL Support** - Execute complex queries, transactions, and graph operations
- **Type-Safe FFI** - Safe Rust-to-Dart bridge with automatic memory management
- **Async/Await API** - Non-blocking operations via direct FFI calls
- **Production Ready** - Comprehensive safety audits, zero memory leaks, panic-safe FFI boundary
- **Authentication** - Signin, signup, and session management for embedded mode
- **Parameter Management** - Reusable parameterized queries
- **Function Execution** - Built-in and user-defined SurrealQL functions

## Why SurrealDB?

While Dart has excellent local database options (Hive, SQLite, Mimir), few offer advanced features like vector indexing for AI-powered applications. SurrealDB bridges this gap by providing:

- **Vector Search** - Store and query high-dimensional embeddings for semantic search, recommendations, and similarity matching
- **Graph Capabilities** - Model complex relationships with graph traversal and queries
- **Flexible Schema** - Schema-less or schema-full, your choice
- **Rich Query Language** - SurrealQL combines the best of SQL and NoSQL
- **On-Device AI** - Perfect for offline-first ML workloads

**This package is ideal for:**
- Applications requiring vector search or embeddings storage
- Offline-first apps with complex data relationships
- Projects needing both SQL-like queries and NoSQL flexibility
- On-device AI/ML workloads

**For simpler use cases**, consider [Hive](https://pub.dev/packages/hive_ce), [SQLite](https://pub.dev/packages/sqlite3), or [Mimir](https://pub.dev/packages/mimir).

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^1.1.0
  ffi: ^2.1.0

dev_dependencies:
  hooks: ^0.20.4
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: 34fc6155224d844f70b3fc631fb0b0049c4d51c6
      path: native_toolchain_rs
```

### Requirements

- **Dart SDK**: 3.0.0 or higher
- **Rust Toolchain**: Required for building native assets (automatically managed by `native_toolchain_rs`)
- **Supported Platforms**: macOS, iOS, Android, Windows, Linux

### Native Asset Setup

This package uses Dart's native assets feature to automatically compile the Rust library. No manual build steps required! Just run:

```bash
dart pub get
```

The build hook will automatically:
1. Compile the Rust library
2. Link it as a native asset
3. Make it available to your Dart code

## Quick Start

### Basic Usage

```dart
import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  // Connect to an in-memory database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a record
    final person = await db.create('person', {
      'name': 'Alice Smith',
      'age': 30,
      'email': 'alice@example.com',
    });
    print('Created: ${person['name']}');

    // Query records
    final response = await db.query('SELECT * FROM person');
    final results = response.getResults();

    for (final record in results) {
      print('Found: ${record['name']}, Age: ${record['age']}');
    }

    // Update a record
    await db.update('person:${person['id']}', {
      'age': 31,
    });

    // Delete a record
    await db.delete('person:${person['id']}');
  } finally {
    // Always close the database when done
    await db.close();
  }
}
```

### Persistent Storage

```dart
import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  // Use RocksDB for persistent storage
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: '/path/to/database',
    namespace: 'production',
    database: 'main',
  );

  try {
    // Your data persists across app restarts!
    final data = await db.select('users');
    print('Found ${data.length} users');
  } finally {
    await db.close();
  }
}
```

## Storage Backends

### In-Memory (`StorageBackend.memory`)

- **Use Case**: Testing, temporary data, caching
- **Persistence**: None - all data lost on close
- **Performance**: Fastest option
- **Setup**: No path required

```dart
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);
```

### RocksDB (`StorageBackend.rocksdb`)

- **Use Case**: Production apps, persistent storage
- **Persistence**: Data survives app restarts
- **Performance**: Optimized for disk storage
- **Setup**: Requires file path

```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/myapp/database',
  namespace: 'prod',
  database: 'main',
);
```

## CRUD Operations

### Create Records

```dart
// Create a single record with auto-generated ID
final person = await db.create('person', {
  'name': 'Alice',
  'age': 25,
  'email': 'alice@example.com',
});
print('Created: ${person['id']}');
```

### Get Specific Record

Retrieve a single record by its identifier. Returns `null` if the record doesn't exist.

```dart
// Get a record by ID
final person = await db.get<Map<String, dynamic>>('person:alice');
if (person != null) {
  print('Found: ${person['name']}');
} else {
  print('Person not found');
}
```

### Select Records

```dart
// Select all records from a table
final persons = await db.select('person');
for (final person in persons) {
  print('${person['name']}: ${person['age']}');
}
```

### Update Records

```dart
// Update an existing record
final updated = await db.update('person:alice', {
  'age': 26,
  'email': 'alice.new@example.com',
});
print('Updated: ${updated['name']}');
```

### Delete Records

```dart
// Delete a record
await db.delete('person:alice');
print('Deleted person:alice');
```

## Advanced CRUD Operations

### Insert Operations

Insert provides more control over record creation compared to create. Note: Insert operations are implemented but currently under testing. Use `create()` for standard record creation.

**Standard Content Insert:**
```dart
// Insert a record (currently under testing)
// Functionality being validated - use create() for production use
```

**Relation Insert for Graph Edges:**
```dart
// Insert a relation/edge (currently under testing)
// Functionality being validated - use raw queries for graph operations
```

### Upsert Operations

Upsert operations (create if not exists, update if exists) are implemented but currently under testing. For production use, combine `get()` and `create()` or `update()` operations.

**Content Upsert (Replace All):**
```dart
// Upsert with full content replacement (currently under testing)
// Functionality being validated
```

**Merge Upsert (Update Fields):**
```dart
// Upsert with field merging (currently under testing)
// Functionality being validated
```

**Patch Upsert (JSON Patch Operations):**
```dart
// Upsert with JSON patch operations (currently under testing)
// Functionality being validated
```

## Authentication Methods

SurrealDB supports multiple authentication levels. In embedded mode, authentication has some limitations compared to remote server mode.

### Embedded Mode Authentication Limitations

- Authentication may have reduced functionality in embedded mode
- Scope-based access control may not fully apply
- Token refresh is not supported
- User creation via signup may be limited

### Sign In with Credentials

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Root-level authentication
final rootJwt = await db.signin(RootCredentials('root', 'rootpass'));

// Database-level authentication
final dbJwt = await db.signin(DatabaseCredentials(
  'user',
  'password',
  'myNamespace',
  'myDatabase',
));

// Scope-based authentication
final scopeJwt = await db.signin(ScopeCredentials(
  'myNamespace',
  'myDatabase',
  'user_scope',
  {'email': 'user@example.com', 'password': 'pass123'},
));

print('Authenticated successfully');
```

### Sign Up New Users

```dart
// Signup creates a new user within a scope
final jwt = await db.signup(ScopeCredentials(
  'myNamespace',
  'myDatabase',
  'user_scope',
  {
    'email': 'newuser@example.com',
    'password': 'password123',
    'name': 'New User',
  },
));
print('User created and authenticated');
```

### Authenticate with Existing Token

```dart
// Get token from signin or signup
final jwt = await db.signin(credentials);

// Later, authenticate with the saved token
await db.authenticate(jwt);
print('Session authenticated');

// Access token string if needed (e.g., for storage)
final tokenString = jwt.asInsecureToken();
```

### Invalidate Session

```dart
// Clear current authentication session
await db.invalidate();
print('Session cleared');
```

## Parameter Management

Parameters allow you to create reusable, parameterized queries and avoid SQL injection.

### Set Parameters

```dart
// Set query parameters
await db.set('user_id', 'person:alice');
await db.set('min_age', 18);
await db.set('status', 'active');

// Use parameters in queries with $ syntax
final response = await db.query('''
  SELECT * FROM person
  WHERE id = $user_id
  AND age >= $min_age
  AND status = $status
''');

final results = response.getResults();
print('Found ${results.length} matching records');
```

### Unset Parameters

```dart
// Remove a parameter
await db.unset('temp_value');

// Safe to unset non-existent parameters
await db.unset('does_not_exist'); // No error
```

### Parameter Use Cases

Parameters are useful for:
- **Reusable queries**: Define once, use with different values
- **Security**: Prevent SQL injection
- **Complex operations**: Store intermediate results
- **Dynamic queries**: Build queries programmatically

```dart
// Example: Reusable search function
Future<List<Map<String, dynamic>>> searchPersons(
  Database db,
  String name,
  int minAge,
) async {
  await db.set('search_name', name);
  await db.set('search_min_age', minAge);

  final response = await db.query('''
    SELECT * FROM person
    WHERE name CONTAINS $search_name
    AND age >= $search_min_age
  ''');

  return response.getResults();
}
```

## Function Execution

Execute both built-in SurrealQL functions and user-defined functions.

### Built-in Functions

```dart
// Random number generation
final randomFloat = await db.run<double>('rand::float');
print('Random: $randomFloat');

// String manipulation
final upperCase = await db.run<String>('string::uppercase', ['hello']);
print('Uppercase: $upperCase'); // HELLO

// Time functions
final now = await db.run<String>('time::now');
print('Current time: $now');

// Math functions
final result = await db.run<double>('math::sqrt', [16.0]);
print('Square root of 16: $result'); // 4.0
```

### User-Defined Functions

```dart
// First, define a function via query
await db.query('''
  DEFINE FUNCTION fn::calculate_tax($amount: number, $rate: number) {
    RETURN $amount * $rate;
  };
''');

// Execute the custom function
final tax = await db.run<double>('fn::calculate_tax', [100.0, 0.08]);
print('Tax: \$${tax}'); // Tax: $8.0
```

### Database Version

```dart
// Get SurrealDB version
final version = await db.version();
print('SurrealDB version: $version');
```

## Type Definitions

SurrealDartB provides Dart representations of SurrealDB types for type-safe operations.

### RecordId

Represents a SurrealDB record identifier in "table:id" format.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create from table and id
final personId = RecordId('person', 'alice');
print(personId); // person:alice

// Parse from string
final parsed = RecordId.parse('person:bob');
print(parsed.table); // person
print(parsed.id); // bob

// Numeric IDs
final userId = RecordId('user', 123);
print(userId); // user:123

// Use in record creation
final record = await db.create('follows', {
  'in': RecordId('person', 'alice').toJson(),
  'out': RecordId('person', 'bob').toJson(),
  'since': '2024-01-01',
});
```

### Datetime

Wraps SurrealDB datetime with conversion to/from Dart DateTime.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create from Dart DateTime
final now = Datetime(DateTime.now());
print(now.toIso8601String());

// Parse from ISO 8601 string
final parsed = Datetime.parse('2024-01-15T10:30:00Z');
print(parsed.toDateTime()); // Dart DateTime object

// Use in records
final event = await db.create('event', {
  'name': 'Conference',
  'start_time': Datetime(DateTime(2024, 6, 15, 9, 0)).toJson(),
  'end_time': Datetime(DateTime(2024, 6, 15, 17, 0)).toJson(),
});
```

### SurrealDuration

Represents SurrealDB duration with string parsing.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create from Dart Duration
final duration = SurrealDuration(Duration(hours: 2, minutes: 30));
print(duration.toString()); // 2h30m

// Parse from SurrealDB duration string
final parsed = SurrealDuration.parse('1w3d12h'); // 1 week, 3 days, 12 hours
print(parsed.toDuration()); // Dart Duration object

// Supported units: ns, us, ms, s, m, h, d, w, y
final timeout = SurrealDuration.parse('30s');
final deadline = SurrealDuration.parse('2h');
```

### PatchOp

JSON Patch operations for upsert patch operations (currently under testing).

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create patch operations
final patches = [
  PatchOp.replace('/age', 31),
  PatchOp.add('/email', 'newemail@example.com'),
  PatchOp.remove('/temporary_field'),
];

// Note: Upsert patch functionality is under testing
// For production use, use update() method
```

### Credentials

Type-safe credential classes for authentication.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Root credentials
final root = RootCredentials('root', 'rootpass');

// Namespace credentials
final ns = NamespaceCredentials('user', 'pass', 'myNamespace');

// Database credentials
final db = DatabaseCredentials('user', 'pass', 'myNamespace', 'myDatabase');

// Scope credentials
final scope = ScopeCredentials(
  'myNamespace',
  'myDatabase',
  'user_scope',
  {'email': 'user@example.com', 'password': 'pass'},
);

// Record credentials
final record = RecordCredentials(
  'myNamespace',
  'myDatabase',
  'user_access',
  {'id': 'user:alice', 'password': 'pass'},
);

// Use with authentication
final jwt = await database.signin(scope);
```

### Jwt

JWT token wrapper for authentication.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Get token from signin/signup
final jwt = await db.signin(credentials);

// Access token string (e.g., for storage)
final tokenString = jwt.asInsecureToken();

// Authenticate with stored token
final stored = Jwt(tokenString);
await db.authenticate(stored);
```

## Embedded vs Remote Mode

This library currently focuses on **embedded mode** - running SurrealDB directly within your application. This is different from connecting to a remote SurrealDB server.

### What Works in Embedded Mode

- All CRUD operations (create, select, update, delete, get)
- Raw SurrealQL queries
- Parameter management (set, unset)
- Function execution (built-in and user-defined)
- Both storage backends (memory and RocksDB)
- Authentication (with limitations - see below)
- Type-safe operations with RecordId, Datetime, SurrealDuration
- Graph relationships and queries
- Vector storage and operations

### Embedded Mode Limitations

**Authentication:**
- Authentication is available but may have reduced functionality
- Scope-based access control may not fully apply as in remote mode
- Token refresh is not supported
- Session management behaves differently than remote server mode

**Features Not Available in Embedded Mode:**
- WebSocket connections to remote servers
- HTTP connections to remote servers
- Remote server wait-for functionality
- Network-specific retry and timeout configuration
- Server-side live queries via WebSocket (embedded uses polling)

### Features Currently Under Development

The following features are implemented but currently undergoing testing and validation:
- Live queries with Dart Streams (embedded mode implementation)
- Transaction support with callback pattern
- Insert operations with builder pattern
- Upsert operations (content, merge, patch variants)
- Export and import operations

These features will be fully documented and supported in an upcoming release once testing is complete.

### Migration Guide: Embedded to Remote

If you start with embedded mode and later need remote functionality:

1. **Install remote-capable SDK**: Future versions will support remote connections
2. **Change connection endpoint**: Switch from `mem://` or `rocksdb://` to `ws://` or `http://`
3. **Update authentication**: Remote mode supports full authentication features
4. **Enable live queries**: WebSocket-based live queries for real-time updates
5. **Consider architecture**: Remote mode requires network access and server deployment

**Example future remote connection** (not yet implemented):
```dart
// Future remote mode (not yet available)
// final db = await Database.connect(
//   endpoint: 'ws://localhost:8000',
//   namespace: 'prod',
//   database: 'main',
// );
```

For now, embedded mode provides a powerful on-device database solution. Remote mode support is planned for future releases.

## API Reference

### Database Class

#### `Database.connect()`

Connects to a SurrealDB database instance.

```dart
static Future<Database> connect({
  required StorageBackend backend,
  String? path,
  String? namespace,
  String? database,
})
```

**Parameters:**
- `backend` - Storage backend (memory or rocksdb)
- `path` - File path for RocksDB (required for rocksdb, ignored for memory)
- `namespace` - Optional namespace to use after connection
- `database` - Optional database to use after connection

**Returns:** Connected `Database` instance

**Throws:**
- `ArgumentError` if path is null for rocksdb backend
- `ConnectionException` if connection fails
- `DatabaseException` for other errors

#### CRUD Operations

**Create a record:**
```dart
Future<Map<String, dynamic>> create(String table, Map<String, dynamic> data)
```

**Get a specific record:**
```dart
Future<T?> get<T>(String resource)
```
Returns null if record doesn't exist.

**Select records:**
```dart
Future<List<Map<String, dynamic>>> select(String table)
```

**Update a record:**
```dart
Future<Map<String, dynamic>> update(String resource, Map<String, dynamic> data)
```

**Delete a record:**
```dart
Future<void> delete(String resource)
```

**Execute raw query:**
```dart
Future<Response> query(String sql, [Map<String, dynamic>? bindings])
```

#### Authentication Operations

**Sign in with credentials:**
```dart
Future<Jwt> signin(Credentials credentials)
```

**Sign up new user:**
```dart
Future<Jwt> signup(Credentials credentials)
```

**Authenticate with token:**
```dart
Future<void> authenticate(Jwt token)
```

**Invalidate session:**
```dart
Future<void> invalidate()
```

#### Parameter Management

**Set query parameter:**
```dart
Future<void> set(String name, dynamic value)
```

**Unset query parameter:**
```dart
Future<void> unset(String name)
```

#### Function Execution

**Execute SurrealQL function:**
```dart
Future<T> run<T>(String function, [List<dynamic>? args])
```

**Get database version:**
```dart
Future<String> version()
```

#### Context Management

**Set namespace:**
```dart
Future<void> useNamespace(String namespace)
```

**Set database:**
```dart
Future<void> useDatabase(String database)
```

#### Resource Management

**Close database:**
```dart
Future<void> close()
```

Always call `close()` when done to free resources. Use `try`/`finally` blocks to ensure cleanup.

### Response Class

Query results are returned as a `Response` object:

```dart
final response = await db.query('SELECT * FROM users');

// Get all results as List<Map<String, dynamic>>
final results = response.getResults();

// Check for errors
if (response.hasErrors()) {
  print('Errors: ${response.getErrors()}');
}
```

### Exception Handling

```dart
try {
  final data = await db.create('user', {'name': 'Bob'});
} on QueryException catch (e) {
  // Invalid query or syntax error
  print('Query error: ${e.message}');
} on ConnectionException catch (e) {
  // Connection failed
  print('Connection error: ${e.message}');
} on AuthenticationException catch (e) {
  // Authentication failed
  print('Auth error: ${e.message}');
} on ParameterException catch (e) {
  // Parameter operation failed
  print('Parameter error: ${e.message}');
} on DatabaseException catch (e) {
  // General database error
  print('Database error: ${e.message}');
} on StateError catch (e) {
  // Using closed database
  print('Database is closed!');
}
```

## Complete Examples

### Vector Storage for AI/ML

```dart
// Store embeddings for semantic search
await db.create('documents', {
  'title': 'Machine Learning Guide',
  'content': 'Introduction to ML concepts...',
  'embedding': [0.23, 0.45, 0.12, ...], // 384-dimensional vector
  'category': 'education',
});

// Query with vector similarity (future feature)
// final similar = await db.query('''
//   SELECT * FROM documents
//   WHERE vector::similarity(embedding, $target_vector) > 0.8
// ''', {'target_vector': myVector});
```

### Graph Relationships

```dart
// Create nodes and edges
await db.create('person', {
  'id': 'person:alice',
  'name': 'Alice',
});

await db.create('person', {
  'id': 'person:bob',
  'name': 'Bob',
});

await db.query('''
  RELATE person:alice->knows->person:bob
  SET since = "2024-01-01"
''');

// Query relationships
final response = await db.query('''
  SELECT ->knows->person.name AS friends FROM person:alice
''');
```

### Complex Queries with Parameters

```dart
// Set parameters for complex query
await db.set('min_age', 18);
await db.set('max_age', 65);
await db.set('status', 'active');

final response = await db.query('''
  SELECT * FROM person
  WHERE age >= $min_age
  AND age <= $max_age
  AND status = $status
  ORDER BY age DESC
  LIMIT 10
''');

final results = response.getResults();
```

### Authentication Flow

```dart
// Sign up a new user
final jwt = await db.signup(ScopeCredentials(
  'myNamespace',
  'myDatabase',
  'user_scope',
  {
    'email': 'user@example.com',
    'password': 'securepassword',
    'name': 'John Doe',
  },
));

// Store token for later use
final tokenString = jwt.asInsecureToken();
await storage.save('auth_token', tokenString);

// Later, authenticate with stored token
final storedToken = Jwt(await storage.read('auth_token'));
await db.authenticate(storedToken);

// Perform authenticated operations
final profile = await db.get<Map<String, dynamic>>('user:me');

// Sign out
await db.invalidate();
```

## Architecture

### FFI Stack

```
┌─────────────────────────────┐
│   High-Level Dart API       │  Database class, Futures
│   (lib/src/database.dart)   │
├─────────────────────────────┤
│   Dart FFI Bindings         │  @Native annotations
│   (lib/src/ffi/)            │
├─────────────────────────────┤
│   Rust FFI Layer            │  Panic-safe C ABI
│   (rust/src/)               │
├─────────────────────────────┤
│   SurrealDB Rust SDK        │  Core database engine
└─────────────────────────────┘
```

### Key Design Principles

1. **Thread Safety**: All database operations use direct FFI calls wrapped in Futures for async behavior
2. **Memory Safety**: Automatic resource cleanup via `NativeFinalizer`, panic-safe FFI boundary
3. **Type Safety**: Type-safe Dart representations of SurrealDB types (RecordId, Datetime, etc.)
4. **Error Propagation**: Errors bubble up through all layers with clear exception types

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| macOS (Intel) | ✅ Supported | Primary development platform |
| macOS (Apple Silicon) | ✅ Supported | Native ARM64 support |
| iOS | ✅ Configured | Rust targets configured, testing needed |
| Android | ✅ Configured | Multiple architectures supported |
| Windows | ✅ Configured | x86_64 target |
| Linux | ✅ Configured | x86_64 and ARM64 targets |

## Known Limitations

Current version (1.1.0) focuses on core embedded database functionality:

**Implemented and Tested:**
- Complete CRUD operations (create, select, update, delete, get)
- Raw SurrealQL query execution
- Authentication methods (signin, signup, authenticate, invalidate)
- Parameter management (set, unset)
- Function execution (run, version)
- Type definitions (RecordId, Datetime, SurrealDuration, PatchOp, Jwt, Credentials)
- Both storage backends (memory and RocksDB)

**Under Testing (Available but not fully validated):**
- Insert operations with builder pattern
- Upsert operations (content, merge, patch)
- Live queries with Dart Streams
- Transactions with callback pattern
- Export and import operations

**Not Yet Supported:**
- Remote database connections (WebSocket/HTTP)
- Vector indexing configuration (vector storage works, similarity search pending)
- Advanced transaction isolation levels
- Server-side live query subscriptions

These features are on the roadmap for future releases.

## Troubleshooting

### Build Issues

**Problem**: Native assets fail to compile

**Solution**: Ensure Rust is installed:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Runtime Issues

**Problem**: `StateError` when using database

**Solution**: Ensure you've connected before using:
```dart
final db = await Database.connect(...);  // Must await!
```

**Problem**: Field values appear as null

**Solution**: This was fixed in v1.1.0. Update to the latest version.

**Problem**: Authentication errors in embedded mode

**Solution**: Authentication has limitations in embedded mode. Check the "Embedded Mode Limitations" section for details.

### Performance Issues

**Problem**: Database operations seem slow

**Solution**:
- Use `StorageBackend.memory` for testing
- Ensure operations are actually async (use `await`)
- Check query complexity and add appropriate indexes
- Use parameters for reusable queries

## Recent Updates

### Version 1.1.0 (Latest)

- ✅ **Fixed critical deserialization bug** - Field values now appear correctly
- ✅ **Comprehensive FFI safety audit** - Production-ready safety guarantees
- ✅ **Removed all diagnostic logging** - Clean console output
- ✅ **Enhanced documentation** - Inline comments and technical explanations
- ✅ **Added CRUD operations** - get() method for record retrieval
- ✅ **Authentication support** - signin, signup, authenticate, invalidate methods
- ✅ **Parameter management** - set() and unset() for parameterized queries
- ✅ **Function execution** - run() for SurrealQL functions, version() method
- ✅ **Type definitions** - RecordId, Datetime, SurrealDuration, PatchOp, Jwt, Credentials, Notification

See [CHANGELOG.md](CHANGELOG.md) for complete details.

## Contributing

Contributions are welcome! This project aims for 1:1 API parity with the SurrealDB Rust SDK.

**Areas for contribution:**
- Platform testing (iOS, Android, Windows, Linux)
- Additional storage backends
- Remote connection support
- Vector indexing features
- Live query implementation
- Documentation improvements

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- [SurrealDB](https://surrealdb.com) - The amazing multi-model database
- [native_toolchain_rs](https://github.com/GregoryConrad/native_toolchain_rs) - Seamless Rust-Dart integration
- Dart FFI team - Enabling native extensions

---

**Questions or Issues?** Open an issue on GitHub or check the [example app](example/) for working code samples.
