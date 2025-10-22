# SurrealDartB Example Application

An interactive CLI demonstration of the SurrealDartB library, showcasing core features through hands-on scenarios.

## Overview

This example application provides a menu-driven interface to explore SurrealDB's capabilities via the Dart FFI bindings. Each scenario demonstrates different aspects of the library, from basic connectivity to advanced CRUD operations and storage backend comparisons.

## Running the Example

From the project root directory, run:

```bash
dart run example/cli_example.dart
```

You'll see an interactive menu:

```
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        SurrealDB Dart FFI Bindings - CLI Example          ║
║                                                            ║
║  This interactive example demonstrates core features of   ║
║  the SurrealDB Dart library through various scenarios.    ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

┌────────────────────────────────────────────────────────────┐
│ Available Scenarios:                                       │
├────────────────────────────────────────────────────────────┤
│ 1. Connect and Verify Connectivity                        │
│ 2. CRUD Operations Demonstration                          │
│ 3. Storage Backend Comparison                             │
│ 4. Exit                                                    │
└────────────────────────────────────────────────────────────┘
```

## Available Scenarios

### Scenario 1: Connect and Verify Connectivity

**File**: `scenarios/connect_verify.dart`

**What it demonstrates:**
- Connecting to an in-memory database
- Setting namespace and database context
- Executing INFO queries to verify connection
- Basic database information retrieval

**What you'll learn:**
- How to establish a database connection
- The importance of namespace and database selection
- How to execute raw SurrealQL queries
- Resource cleanup patterns (`try`/`finally`)

**Example output:**
```
Connecting to in-memory database...
✓ Connected successfully!

Setting namespace and database context...
✓ Context set to: namespace='test', database='test'

Verifying database connectivity...
✓ Database is accessible and responding!

Database information:
  Namespace: test
  Database: test
  Version: <SurrealDB version>

✓ Connection verified successfully!
```

### Scenario 2: CRUD Operations Demonstration

**File**: `scenarios/crud_operations.dart`

**What it demonstrates:**
- Creating records with structured data
- Querying records with SELECT statements
- Updating existing records
- Deleting records
- Proper error handling
- Field value access and type handling

**What you'll learn:**
- Complete CRUD lifecycle
- Working with Dart Map structures for records
- Accessing field values from query results
- ID generation and record references
- Exception handling patterns

**Example output:**
```
Creating a new person record...
✓ Created person: John Doe
  ID: person:abc123
  Age: 30
  Email: john.doe@example.com

Querying all person records...
✓ Found 1 record(s)
  - John Doe (Age: 30)

Updating person record...
✓ Updated person age from 30 to 31

Deleting person record...
✓ Successfully deleted person:abc123

Verification: Querying again...
✓ Database is now empty (0 records)
```

### Scenario 3: Storage Backend Comparison

**File**: `scenarios/storage_comparison.dart`

**What it demonstrates:**
- In-memory (mem://) storage behavior
- RocksDB persistent storage behavior
- Data persistence across database instances
- Temporary file cleanup
- Backend-specific characteristics

**What you'll learn:**
- When to use each storage backend
- How data persistence works with RocksDB
- File path requirements for persistent storage
- The difference between volatile and persistent data

**Example output:**
```
=== Part 1: In-Memory Storage (mem://) ===

Creating in-memory database...
✓ Connected to memory backend

Adding test data...
✓ Created 3 records in memory

Closing database...
✓ Database closed

Reopening same in-memory database...
✓ Reconnected to memory backend

Checking for previous data...
✗ Memory database is empty (expected behavior)
  └─ In-memory data is lost when database closes

=== Part 2: RocksDB Persistent Storage ===

Creating RocksDB database at: /tmp/surreal_example_db_123
✓ Connected to RocksDB backend

Adding test data...
✓ Created 3 records in RocksDB

Closing database...
✓ Database closed

Reopening RocksDB database...
✓ Reconnected to RocksDB backend

Checking for previous data...
✓ Found 3 records (data persisted!)
  └─ RocksDB data survives database restarts

Cleaning up...
✓ Removed temporary database files
```

## Project Structure

```
example/
├── cli_example.dart              # Main menu driver
├── surrealdartb_example.dart     # Alternative simple example
└── scenarios/
    ├── connect_verify.dart       # Scenario 1
    ├── crud_operations.dart      # Scenario 2
    └── storage_comparison.dart   # Scenario 3
```

### File Descriptions

**`cli_example.dart`**
- Interactive menu interface
- Scenario orchestration
- Error handling wrapper
- User input management

**`scenarios/connect_verify.dart`**
- Basic connection demonstration
- Database context setup
- INFO query examples

**`scenarios/crud_operations.dart`**
- Complete CRUD workflow
- Record creation and manipulation
- Query execution examples

**`scenarios/storage_comparison.dart`**
- Backend comparison
- Persistence demonstration
- Temporary file handling

## Understanding the Code

### Common Patterns

#### Database Connection
```dart
final db = await Database.connect(
  backend: StorageBackend.memory,  // or StorageBackend.rocksdb
  path: '/path/to/db',             // only for RocksDB
  namespace: 'test',
  database: 'test',
);
```

#### Resource Cleanup
All scenarios use `try`/`finally` to ensure database closure:

```dart
try {
  // Database operations...
} finally {
  await db.close();  // Always close!
}
```

#### Error Handling
Scenarios catch and display errors clearly:

```dart
try {
  await db.create('table', data);
} catch (e) {
  print('✗ Error: $e');
}
```

## Key Concepts Demonstrated

### 1. Connection Lifecycle
- Connect → Use → Close pattern
- Importance of proper cleanup
- Context (namespace/database) management

### 2. CRUD Operations
- Creating records with auto-generated IDs
- Querying with SurrealQL
- Updating specific fields
- Deleting by record ID

### 3. Storage Backends
- **Memory**: Fast, temporary, testing
- **RocksDB**: Persistent, production-ready

### 4. Async/Await
- All operations return Futures
- Use `await` for sequential operations
- Background isolate prevents blocking

### 5. Type Safety
- Records returned as `Map<String, dynamic>`
- Type casting when needed
- Null safety practices

## Extending the Examples

### Adding Your Own Scenario

1. **Create a new file** in `scenarios/`:
```dart
// scenarios/my_scenario.dart

import 'package:surrealdartb/surrealdartb.dart';

Future<void> runMyScenario() async {
  print('\n=== My Custom Scenario ===\n');

  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Your code here...
    print('✓ Custom scenario completed!');
  } finally {
    await db.close();
  }
}
```

2. **Add to the menu** in `cli_example.dart`:
```dart
import 'scenarios/my_scenario.dart';

// In the menu display:
print('│ 4. My Custom Scenario                                 │');

// In the switch statement:
case '4':
  await _runScenario('My Custom Scenario', runMyScenario);
```

### Example Ideas

- **Advanced Queries**: Multi-statement transactions
- **Graph Relationships**: CREATE RELATE queries
- **Vector Storage**: Store and retrieve embeddings
- **Batch Operations**: Create multiple records efficiently
- **Error Scenarios**: Test error handling paths
- **Performance Testing**: Stress test with many records

## Troubleshooting

### Issue: Menu doesn't appear

**Solution**: Ensure you're in the project root and run:
```bash
dart pub get
dart run example/cli_example.dart
```

### Issue: Compilation errors

**Solution**: Check that native assets built correctly:
```bash
# Clean and rebuild
rm -rf .dart_tool/
dart pub get
```

### Issue: RocksDB scenario fails

**Solution**: Ensure you have write permissions to `/tmp`:
```bash
# Check permissions
ls -la /tmp

# Or modify path in storage_comparison.dart
```

### Issue: Example hangs or freezes

**Solution**:
- Check terminal input is working
- Try pressing Enter to continue
- Restart the example app

## Learning Path

**Recommended order for beginners:**

1. **Start with Scenario 1** (Connect and Verify)
   - Understand connection basics
   - Learn about contexts

2. **Try Scenario 2** (CRUD Operations)
   - Master data manipulation
   - Practice with queries

3. **Explore Scenario 3** (Storage Comparison)
   - Understand persistence
   - Choose appropriate backend

4. **Read the code** in `scenarios/` folder
   - See real-world patterns
   - Understand error handling

5. **Experiment**: Modify scenarios
   - Change queries
   - Add new operations
   - Break things and learn!

## Additional Resources

- **Main README**: `../README.md` - Complete library documentation
- **API Reference**: Check inline docs in `lib/src/database.dart`
- **CHANGELOG**: `../CHANGELOG.md` - Recent updates and fixes
- **Tests**: `../test/` - More code examples

## Common Questions

**Q: Can I use this in Flutter apps?**
A: Yes! The library works in Flutter. Just import and use the same API.

**Q: Where should I store my database files?**
A: Use Flutter's `path_provider` package to get appropriate directories:
```dart
import 'package:path_provider/path_provider.dart';

final dir = await getApplicationDocumentsDirectory();
final dbPath = '${dir.path}/my_database';
```

**Q: How do I handle large datasets?**
A: Use queries with LIMIT and pagination:
```dart
final response = await db.query('SELECT * FROM users LIMIT 100 START 0');
```

**Q: Can I use multiple databases?**
A: Yes! Either use multiple connections or switch contexts:
```dart
await db.useDatabase('database1');
// work with database1...

await db.useDatabase('database2');
// work with database2...
```

## Platform Support

This example has been tested on:
- ✅ macOS (Apple Silicon and Intel)

Other platforms are configured but not yet tested:
- ⏳ iOS
- ⏳ Android
- ⏳ Windows
- ⏳ Linux

## Requirements

- **Dart SDK**: 3.0.0 or higher
- **Rust Toolchain**: Automatically managed by `native_toolchain_rs`
- **Supported Platforms**: macOS, iOS, Android, Windows, Linux

---

**Ready to explore?** Run the example and select a scenario!

```bash
dart run example/cli_example.dart
```
