# Database Connection & CRUD Operations

**File:** `lib/src/database.dart`

## Database Connection

### Database.connect()
Connect to embedded SurrealDB instance.

```dart
Future<Database> Database.connect({
  required StorageBackend backend,
  String? path,                    // Required for rocksdb
  required String namespace,
  required String database,
  List<TableStructure>? tableDefinitions,
  bool autoMigrate = false,
  bool allowDestructiveMigrations = false,
})
```

**Example:**
```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/db',
  namespace: 'prod',
  database: 'main',
  tableDefinitions: [UserTableDef()],
  autoMigrate: true,
);
```

### Storage Backends
**File:** `lib/src/storage_backend.dart`

```dart
StorageBackend.memory      // In-memory (testing, no persistence)
StorageBackend.rocksdb     // RocksDB (production, persistent)
```

### Lifecycle Management

```dart
await db.close()                          // Close connection, cleanup resources
await db.useNamespace(String namespace)   // Switch namespace
await db.useDatabase(String database)     // Switch database
```

**Pattern:**
```dart
final db = await Database.connect(/*...*/);
try {
  // operations
} finally {
  await db.close();
}
```

## CRUD Operations

### Create

```dart
Future<T?> createQL<T>(
  String table,
  Map<String, dynamic> data,
  {TableStructure? schema}
)
```

**Example:**
```dart
final user = await db.createQL('users', {
  'name': 'Alice',
  'age': 30,
});
```

With validation:
```dart
final user = await db.createQL('users', data, schema: UserTableDef());
```

### Read

```dart
// Get by ID (returns null if not found)
Future<T?> get<T>(String resource)

// Select all from table
Future<List<T>> selectQL<T>(String table)
```

**Example:**
```dart
final user = await db.get<Map>('users:alice');
final users = await db.selectQL<Map>('users');
```

### Update

```dart
Future<T?> updateQL<T>(
  String resource,
  Map<String, dynamic> data,
  {TableStructure? schema}
)
```

**Example:**
```dart
await db.updateQL('users:alice', {'age': 31});
```

### Delete

```dart
Future<T?> deleteQL<T>(String resource)
```

**Example:**
```dart
await db.deleteQL('users:alice');
```

## Raw Query Execution

### queryQL()
Execute raw SurrealQL with optional parameter bindings.

```dart
Future<Response> queryQL(String sql, [Map<String, dynamic>? bindings])
```

**Example:**
```dart
final result = await db.queryQL('''
  SELECT * FROM users WHERE age > \$minAge
''', {'minAge': 18});

final users = result.getResults<Map>();
```

**Multi-statement:**
```dart
await db.queryQL('''
  CREATE users:alice SET name = "Alice";
  CREATE users:bob SET name = "Bob";
''');
```

## Response Handling

**File:** `lib/src/response.dart`

```dart
class Response {
  List<T> getResults<T>()           // Extract typed results
  bool hasErrors()                   // Check for errors
  List<String> getErrors()          // Get error messages
}
```

**Pattern:**
```dart
final response = await db.queryQL('SELECT * FROM users');
if (response.hasErrors()) {
  print('Errors: ${response.getErrors()}');
} else {
  final users = response.getResults<Map>();
}
```

## Advanced Operations

### Insert (Under Testing)

```dart
Future<T?> insertQL<T>(String table, Map<String, dynamic> data)
```

### Upsert (Under Testing)

```dart
Future<T?> upsertQL<T>(String resource, Map<String, dynamic> data)
```

## Common Patterns

### Basic CRUD Flow
```dart
// Connect
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);

// Create
await db.createQL('products', {'name': 'Widget', 'price': 9.99});

// Read
final products = await db.selectQL<Map>('products');
final widget = await db.get<Map>('products:⟨${products[0]['id']}⟩');

// Update
await db.updateQL('products:${widget!['id']}', {'price': 12.99});

// Delete
await db.deleteQL('products:${widget['id']}');

// Cleanup
await db.close();
```

### With Auto-Migration
```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: './db',
  namespace: 'app',
  database: 'main',
  tableDefinitions: [UserTableDef(), PostTableDef()],
  autoMigrate: true,               // Auto-apply migrations
  allowDestructiveMigrations: false, // Require confirmation for destructive
);
```

## Gotchas

1. **Null Returns:** `get()`, `createQL()`, `updateQL()`, `deleteQL()` return `null` if operation fails or resource not found
2. **Resource Format:** Use `table:id` format (e.g., `'users:alice'` or `'users:123'`)
3. **Memory Backend:** No persistence - data lost on close
4. **Close Required:** Always call `db.close()` to prevent resource leaks
5. **Schema Validation:** Optional but recommended via `schema` parameter
