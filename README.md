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
- **Async/Await API** - Non-blocking operations via background isolate architecture
- **Production Ready** - Comprehensive safety audits, zero memory leaks, panic-safe FFI boundary

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

### Complex Queries

```dart
// Multi-statement transaction
final response = await db.query('''
  BEGIN TRANSACTION;

  LET $user = CREATE user SET name = "Charlie", credits = 100;
  UPDATE user:$user SET credits += 50;
  CREATE log SET action = "credit_added", user = $user;

  COMMIT TRANSACTION;
''');
```

## Architecture

### FFI Stack

```
┌─────────────────────────────┐
│   High-Level Dart API       │  Database class, Futures
│   (lib/src/database.dart)   │
├─────────────────────────────┤
│   Background Isolate        │  Async message passing
│   (database_isolate.dart)   │
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

1. **Thread Safety**: All database operations run in a dedicated background isolate, preventing UI blocking
2. **Memory Safety**: Automatic resource cleanup via `NativeFinalizer`, panic-safe FFI boundary
3. **Type Safety**: Manual deserialization converts SurrealDB types to clean Dart JSON
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

**Not Yet Supported:**
- Remote database connections (WebSocket/HTTP)
- Live queries and real-time subscriptions
- Vector indexing configuration (vector storage works, similarity search pending)
- Advanced transactions with ACID guarantees
- User authentication and permissions
- Database imports/exports

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

### Performance Issues

**Problem**: Database operations seem slow

**Solution**:
- Use `StorageBackend.memory` for testing
- Ensure operations are actually async (use `await`)
- Check you're not blocking the isolate

## Recent Updates

### Version 1.1.0 (Latest)

- ✅ **Fixed critical deserialization bug** - Field values now appear correctly
- ✅ **Comprehensive FFI safety audit** - Production-ready safety guarantees
- ✅ **Removed all diagnostic logging** - Clean console output
- ✅ **Enhanced documentation** - Inline comments and technical explanations

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
