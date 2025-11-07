# SurrealDartBDocumentation

## Table of Contents
- [Section 1: Getting Started & Database Initialization](#section-1-getting-started--database-initialization)
  - [Installation](#installation)
  - [Database Initialization](#database-initialization)
  - [Storage Backends](#storage-backends)
  - [Flutter Integration](#flutter-integration)
  - [Error Handling](#error-handling)
  - [Database Lifecycle](#database-lifecycle)
- [Section 2: Basic QL Functions Usage](#section-2-basic-ql-functions-usage)
  - [Introduction to QL Methods](#introduction-to-ql-methods)
  - [CRUD Operations](#crud-operations)
  - [Raw Query Execution](#raw-query-execution)
  - [Parameter Management](#parameter-management)
  - [Batch Operations](#batch-operations)
  - [Info Queries](#info-queries)

---

## Section 1: Getting Started & Database Initialization

### Introduction

SurrealDartB is a high-performance Dart library that provides native FFI bindings to SurrealDB, an innovative multi-model database. This library enables you to leverage SurrealDB's powerful features directly in your Dart and Flutter applications with full type safety and async support.

**Key Features:**
- Async Operations - All database operations return Futures and execute asynchronously
- Memory Safety - Automatic memory management with no memory leaks
- Storage Backends - Support for in-memory (testing) and persistent (RocksDB) storage
- Type Safety - Full Dart null safety and strong typing
- Error Handling - Clear exception hierarchy for different error types
- Vector Operations - Built-in support for vector embeddings and similarity search

### Installation

Add SurrealDartBto your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^0.0.4
```

Then run:

```bash
dart pub get
# or for Flutter
flutter pub get
```

### Database Initialization

SurrealDartBsupports two storage backends: **in-memory** for testing and development, and **RocksDB** for production and persistent storage.

#### Basic Connection Example

Here's a complete example showing how to connect to a database:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Connect to an in-memory database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'my_namespace',
    database: 'my_database',
  );

  try {
    // Verify connection by executing an info query
    final response = await db.queryQL('INFO FOR DB;');
    print('Connected successfully!');

    // Use the database...
  } finally {
    // Always close the database connection
    await db.close();
  }
}
```

**Connection Parameters:**
- `backend` - Storage backend type (memory or rocksdb)
- `path` - File system path (required for rocksdb, not used for memory)
- `namespace` - Database namespace for organizing data
- `database` - Database name within the namespace

### Storage Backends

#### In-Memory Database

The in-memory backend stores all data in RAM, making it extremely fast but non-persistent. Data is lost when the connection closes.

**Use Cases:**
- Unit testing
- Integration testing
- Temporary data processing
- Prototyping and development

**Example:**

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> testWithMemoryDatabase() async {
  // Create in-memory database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('person', {
      'name': 'Alice',
      'age': 30,
    });

    // Query the data
    final persons = await db.selectQL('person');
    print('Found ${persons.length} person(s)');
  } finally {
    await db.close();
    // Data is lost after close
  }
}
```

#### RocksDB Persistent Database

The RocksDB backend persists data to disk, making it suitable for production use. Data survives application restarts.

**Use Cases:**
- Production applications
- Long-term data storage
- Applications requiring data persistence
- Server-side applications

**Example:**

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'dart:io';

Future<void> productionDatabase() async {
  // Define persistent storage path
  final dbPath = '/var/data/my_app/database';

  // Ensure directory exists
  final directory = Directory(dbPath).parent;
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // Connect to RocksDB database
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: dbPath,
    namespace: 'production',
    database: 'main',
  );

  try {
    // Create persistent data
    await db.createQL('user', {
      'email': 'user@example.com',
      'created_at': DateTime.now().toIso8601String(),
    });

    print('Data saved to disk at: $dbPath');
  } finally {
    await db.close();
    // Data persists on disk after close
  }
}
```

**Important Note:** Due to a limitation in SurrealDB's RocksDB backend, the database path cannot be immediately reused after closing. The database maintains a file lock until process termination. Best practice is to use unique paths for each database instance or wait until application restart before reusing the same path.

### Flutter Integration

When building Flutter applications, you need to determine the correct storage path for each platform. Flutter provides the `path_provider` package for this purpose.

#### Setting Up path_provider

Add `path_provider` to your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^0.0.4
  path_provider: ^2.1.0
```

#### Flutter Database Initialization

Here's a complete example showing how to initialize a database in a Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseService {
  Database? _database;

  /// Initialize the database with platform-appropriate storage path
  Future<Database> initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    // Get the application documents directory
    // This works on both iOS and Android
    final appDir = await getApplicationDocumentsDirectory();

    // Create a subdirectory for your database
    final dbDir = Directory('${appDir.path}/surreal_data');
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // Define database file path
    final dbPath = '${dbDir.path}/app_database';

    print('Initializing database at: $dbPath');

    // Connect to persistent database
    _database = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath,
      namespace: 'app',
      database: 'main',
    );

    return _database!;
  }

  /// Close the database connection
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Get the current database instance
  Database get database {
    if (_database == null) {
      throw StateError('Database not initialized. Call initDatabase() first.');
    }
    return _database!;
  }
}

// Example Flutter app using the database service
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final DatabaseService _dbService = DatabaseService();
  bool _isInitialized = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      await _dbService.initDatabase();
      setState(() {
        _isInitialized = true;
        _status = 'Database ready!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    _dbService.closeDatabase();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('SurrealDartBFlutter Example')),
        body: Center(
          child: _isInitialized
              ? Text(_status)
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
}
```

#### Platform-Specific Storage Paths

**iOS:**
- `getApplicationDocumentsDirectory()` returns the app's Documents directory
- Path: `/var/mobile/Containers/Data/Application/<UUID>/Documents/`
- This directory is backed up by iTunes and iCloud

**Android:**
- `getApplicationDocumentsDirectory()` returns the app's files directory
- Path: `/data/data/<package_name>/app_flutter/`
- This directory is private to the app and persists until app uninstall

#### Best Practices for Flutter Database File Naming

```dart
import 'package:path_provider/path_provider.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'dart:io';

Future<Database> createFlutterDatabase({
  required String namespace,
  required String database,
}) async {
  // Get platform-appropriate directory
  final appDir = await getApplicationDocumentsDirectory();

  // Create organized subdirectory structure
  final dbDir = Directory('${appDir.path}/databases/${namespace}');
  await dbDir.create(recursive: true);

  // Use descriptive database file naming
  final dbPath = '${dbDir.path}/${database}_db';

  return await Database.connect(
    backend: StorageBackend.rocksdb,
    path: dbPath,
    namespace: namespace,
    database: database,
  );
}

// Usage example
Future<void> example() async {
  final db = await createFlutterDatabase(
    namespace: 'production',
    database: 'user_data',
  );

  try {
    // Use database...
  } finally {
    await db.close();
  }
}
```

### Error Handling

SurrealDartBprovides a clear exception hierarchy for handling different error scenarios.

#### Exception Types

- `ConnectionException` - Errors during database connection
- `QueryException` - Errors during query execution
- `DatabaseException` - General database errors (base class)
- `AuthenticationException` - Authentication failures
- `ParameterException` - Invalid parameter operations
- `ValidationException` - Schema validation failures

#### Error Handling Pattern

Here's a comprehensive error handling example:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> handleDatabaseErrors() async {
  Database? db;

  try {
    // Attempt to connect
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: '/data/mydb',
      namespace: 'app',
      database: 'main',
    );

    // Attempt a query
    final response = await db.queryQL('SELECT * FROM users WHERE age > 18');
    final results = response.getResults();

    for (final user in results) {
      print('User: ${user['name']}');
    }

  } on ConnectionException catch (e) {
    // Handle connection-specific errors
    print('Failed to connect to database: ${e.message}');
    if (e.errorCode != null) {
      print('Error code: ${e.errorCode}');
    }
    // Maybe try fallback or retry logic

  } on QueryException catch (e) {
    // Handle query-specific errors
    print('Query failed: ${e.message}');
    if (e.errorCode != null) {
      print('Error code: ${e.errorCode}');
    }
    // Maybe log the failed query for debugging

  } on DatabaseException catch (e) {
    // Handle general database errors
    print('Database error: ${e.message}');
    if (e.errorCode != null) {
      print('Error code: ${e.errorCode}');
    }
    // General error handling

  } catch (e) {
    // Handle unexpected errors
    print('Unexpected error: $e');

  } finally {
    // Always clean up resources
    if (db != null) {
      await db.close();
    }
  }
}
```

#### Practical Error Handling in Production

```dart
import 'package:surrealdartb/surrealdartb.dart';

class UserRepository {
  final Database db;

  UserRepository(this.db);

  /// Get user by ID with comprehensive error handling
  Future<Map<String, dynamic>?> getUserById(String id) async {
    try {
      final user = await db.get<Map<String, dynamic>>('user:$id');
      return user;

    } on QueryException catch (e) {
      // Log query error but don't throw - return null instead
      print('Warning: Failed to get user $id: ${e.message}');
      return null;

    } on DatabaseException catch (e) {
      // Log database error and rethrow for higher-level handling
      print('Error: Database error getting user $id: ${e.message}');
      rethrow;
    }
  }

  /// Create user with validation
  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
  }) async {
    try {
      final user = await db.createQL('user', {
        'name': name,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });

      return user;

    } on QueryException catch (e) {
      // Check if error is due to duplicate email
      if (e.message.contains('unique') || e.message.contains('duplicate')) {
        throw Exception('User with email $email already exists');
      }
      rethrow;

    } on DatabaseException catch (e) {
      print('Failed to create user: ${e.message}');
      rethrow;
    }
  }
}
```

### Database Lifecycle

Understanding when to open and close database connections is crucial for resource management.

#### Application Lifecycle

**Mobile Apps (Flutter):**
- Open database during app initialization
- Keep connection open throughout app lifecycle
- Close database in app disposal/termination

```dart
import 'package:flutter/material.dart';
import 'package:surrealdartb/surrealdartb.dart';

class AppDatabase {
  static Database? _instance;

  static Future<Database> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    _instance = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: '/path/to/db',
      namespace: 'app',
      database: 'main',
    );

    return _instance!;
  }

  static Future<void> close() async {
    if (_instance != null) {
      await _instance!.close();
      _instance = null;
    }
  }
}

// In your app's main widget
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Database is initialized on-demand
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.detached) {
      // App is being terminated - close database
      await AppDatabase.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text('App')),
      ),
    );
  }
}
```

**Server/CLI Applications:**
- Open database at startup
- Close database at shutdown
- Use try-finally to ensure cleanup

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'dart:io';

Future<void> main() async {
  Database? db;

  // Setup signal handlers for graceful shutdown
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    if (db != null) {
      await db.close();
    }
    exit(0);
  });

  try {
    // Initialize database
    db = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: './data/server_db',
      namespace: 'server',
      database: 'main',
    );

    print('Server started');

    // Run server operations...
    await runServer(db);

  } finally {
    // Ensure cleanup
    if (db != null) {
      await db.close();
      print('Database closed');
    }
  }
}

Future<void> runServer(Database db) async {
  // Server logic here
  await Future.delayed(Duration(seconds: 10));
}
```

#### Testing Lifecycle

For tests, create a fresh database for each test:

```dart
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  late Database db;

  setUp(() async {
    // Create fresh in-memory database for each test
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    // Clean up after each test
    await db.close();
  });

  test('example test', () async {
    final result = await db.createQL('person', {'name': 'Test'});
    expect(result['name'], equals('Test'));
  });
}
```

---

## Section 2: Basic QL Functions Usage

### Introduction to QL Methods

SurrealDartBprovides "QL" methods as the basic API for interacting with SurrealDB. These methods offer a straightforward, map-based interface for CRUD operations and raw query execution.

**Why "QL" Methods?**
- "QL" stands for "Query Language" methods
- These are the fundamental building blocks for database operations
- They provide a simple, flexible API that directly maps to SurrealDB operations
- Perfect for getting started and for use cases where you don't need type-safe ORM features

**Available QL Methods:**
- `createQL()` - Create new records
- `selectQL()` - Read all records from a table
- `get()` - Get a specific record by ID
- `updateQL()` - Update existing records
- `deleteQL()` - Delete records
- `queryQL()` - Execute raw SurrealQL queries
- `set()` and `unset()` - Manage query parameters

### CRUD Operations

#### Creating Records

Use `createQL()` to create new records in a table:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> createExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a person record
    final person = await db.createQL('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });

    // The returned record includes the generated ID
    print('Created person with ID: ${person['id']}');
    print('Name: ${person['name']}');
    print('Age: ${person['age']}');

    // Create a product record
    final product = await db.createQL('product', {
      'name': 'Laptop',
      'price': 999.99,
      'quantity': 10,
      'category': 'Electronics',
      'tags': ['computer', 'portable', 'work'],
    });

    print('Created product: ${product['name']} - \$${product['price']}');

  } finally {
    await db.close();
  }
}
```

**What gets returned:**
- The created record as a `Map<String, dynamic>`
- Includes all fields you provided
- Includes the auto-generated `id` field
- The `id` field format is `tablename:recordid`

#### Reading Records

Use `selectQL()` to retrieve all records from a table:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> readExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create some test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 35});
    await db.createQL('person', {'name': 'Charlie', 'age': 45});

    // Select all person records
    final persons = await db.selectQL('person');

    print('Found ${persons.length} person(s):');
    for (final person in persons) {
      print('  - ${person['name']}: ${person['age']} years old');
    }

    // selectQL returns List<Map<String, dynamic>>
    // Each map represents one record

  } finally {
    await db.close();
  }
}
```

#### Getting Specific Records

Use `get()` to retrieve a specific record by its ID:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> getExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a record
    final created = await db.createQL('user', {
      'username': 'johndoe',
      'email': 'john@example.com',
      'active': true,
    });

    // Extract the record ID
    final recordId = created['id'] as String;
    print('Created record: $recordId');

    // Get the specific record by ID
    final user = await db.get<Map<String, dynamic>>(recordId);

    if (user != null) {
      print('Retrieved user:');
      print('  Username: ${user['username']}');
      print('  Email: ${user['email']}');
      print('  Active: ${user['active']}');
    } else {
      print('User not found');
    }

    // Try to get a non-existent record
    final nonExistent = await db.get<Map<String, dynamic>>('user:unknown');
    print('Non-existent user: $nonExistent'); // Prints: null

  } finally {
    await db.close();
  }
}
```

**Important Notes:**
- `get()` requires a full record ID in format `table:id`
- Returns `null` if the record doesn't exist (not an error)
- Uses generic type parameter for type safety

#### Updating Records

Use `updateQL()` to modify existing records:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> updateExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a person
    final person = await db.createQL('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });

    final recordId = person['id'] as String;

    // Update the person's age and city
    final updated = await db.updateQL(recordId, {
      'age': 31,
      'city': 'Los Angeles',
    });

    print('Updated record:');
    print('  Name: ${updated['name']}'); // Still 'John Doe'
    print('  Age: ${updated['age']}'); // Now 31
    print('  Email: ${updated['email']}'); // Still john.doe@example.com
    print('  City: ${updated['city']}'); // Now 'Los Angeles'

    // You can also update by adding new fields
    final withNewField = await db.updateQL(recordId, {
      'phone': '+1-555-0123',
      'verified': true,
    });

    print('Added new fields:');
    print('  Phone: ${withNewField['phone']}');
    print('  Verified: ${withNewField['verified']}');

  } finally {
    await db.close();
  }
}
```

**Update Behavior:**
- Only updates the fields you specify
- Existing fields not mentioned remain unchanged
- Can add new fields that didn't exist before
- Returns the complete updated record

#### Deleting Records

Use `deleteQL()` to remove records:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> deleteExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a record
    final person = await db.createQL('person', {
      'name': 'Temporary User',
      'email': 'temp@example.com',
    });

    final recordId = person['id'] as String;
    print('Created record: $recordId');

    // Verify it exists
    var allPersons = await db.selectQL('person');
    print('Records before delete: ${allPersons.length}');

    // Delete the record
    await db.deleteQL(recordId);
    print('Deleted record: $recordId');

    // Verify it's gone
    allPersons = await db.selectQL('person');
    print('Records after delete: ${allPersons.length}');

    // Try to get the deleted record
    final deleted = await db.get<Map<String, dynamic>>(recordId);
    print('Get deleted record: $deleted'); // Prints: null

  } finally {
    await db.close();
  }
}
```

#### Complete CRUD Example

Here's a complete example demonstrating all CRUD operations:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> completeCrudExample() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    print('=== Complete CRUD Example ===\n');

    // CREATE
    print('1. Creating a new user...');
    final user = await db.createQL('user', {
      'username': 'alice',
      'email': 'alice@example.com',
      'age': 28,
      'active': true,
    });
    print('   Created: ${user['username']} (${user['id']})');

    final userId = user['id'] as String;

    // READ - Get specific
    print('\n2. Reading the user...');
    final retrieved = await db.get<Map<String, dynamic>>(userId);
    print('   Retrieved: ${retrieved!['username']}');
    print('   Email: ${retrieved['email']}');

    // READ - Get all
    print('\n3. Reading all users...');
    final allUsers = await db.selectQL('user');
    print('   Total users: ${allUsers.length}');
    for (final u in allUsers) {
      print('   - ${u['username']} (age: ${u['age']})');
    }

    // UPDATE
    print('\n4. Updating the user...');
    final updated = await db.updateQL(userId, {
      'age': 29,
      'email': 'alice.smith@example.com',
      'verified': true,
    });
    print('   Updated age: ${updated['age']}');
    print('   Updated email: ${updated['email']}');
    print('   Added verified: ${updated['verified']}');

    // DELETE
    print('\n5. Deleting the user...');
    await db.deleteQL(userId);
    print('   Deleted: $userId');

    // Verify deletion
    final afterDelete = await db.selectQL('user');
    print('   Remaining users: ${afterDelete.length}');

    print('\n=== CRUD Example Complete ===');

  } finally {
    await db.close();
  }
}
```

### Raw Query Execution

For complex queries or operations not covered by the basic CRUD methods, use `queryQL()` to execute raw SurrealQL queries.

#### Basic Query Execution

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> rawQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 30});
    await db.createQL('person', {'name': 'Charlie', 'age': 35});

    // Execute a raw query with WHERE clause
    final response = await db.queryQL('SELECT * FROM person WHERE age > 25');

    // Extract results from the response
    final results = response.getResults();

    print('People older than 25:');
    for (final person in results) {
      print('  - ${person['name']}: ${person['age']} years old');
    }

  } finally {
    await db.close();
  }
}
```

#### Working with Response Objects

The `queryQL()` method returns a `Response` object with several useful methods:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> responseHandlingExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {'name': 'Laptop', 'price': 999.99});
    await db.createQL('product', {'name': 'Mouse', 'price': 29.99});

    // Execute query
    final response = await db.queryQL('SELECT * FROM product');

    // Get all results
    final results = response.getResults();
    print('Result count: ${results.length}');

    // Check if response is empty
    if (response.isEmpty) {
      print('No results found');
    } else {
      print('Found ${response.resultCount} results');
    }

    // Get first result (or null if empty)
    final firstProduct = response.firstOrNull;
    if (firstProduct != null) {
      print('First product: ${firstProduct['name']}');
    }

    // Iterate through results
    for (final product in results) {
      print('Product: ${product['name']} - \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Multiple Statement Queries

SurrealQL allows executing multiple statements in a single query:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> multipleStatementExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Execute multiple statements
    final response = await db.queryQL('''
      CREATE person SET name = 'Alice', age = 30;
      CREATE person SET name = 'Bob', age = 25;
      SELECT * FROM person;
    ''');

    // The response contains results from all statements
    // Access individual results using takeResult()

    final createResult1 = response.takeResult(0);
    print('First CREATE: ${createResult1}');

    final createResult2 = response.takeResult(1);
    print('Second CREATE: ${createResult2}');

    final selectResult = response.takeResult(2);
    print('SELECT result: $selectResult');

    // Or just get all results at once
    final allResults = response.getResults();
    print('Total result sets: ${allResults.length}');

  } finally {
    await db.close();
  }
}
```

#### Complex Queries

Execute advanced queries with JOINs, aggregations, and more:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> complexQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('order', {
      'customer': 'Alice',
      'amount': 150.00,
      'status': 'completed',
    });
    await db.createQL('order', {
      'customer': 'Alice',
      'amount': 200.00,
      'status': 'completed',
    });
    await db.createQL('order', {
      'customer': 'Bob',
      'amount': 100.00,
      'status': 'pending',
    });

    // Query with aggregation
    final response = await db.queryQL('''
      SELECT
        customer,
        count() as order_count,
        math::sum(amount) as total_spent,
        math::avg(amount) as avg_order
      FROM order
      WHERE status = 'completed'
      GROUP BY customer
    ''');

    final results = response.getResults();

    print('Customer order summary:');
    for (final row in results) {
      print('Customer: ${row['customer']}');
      print('  Orders: ${row['order_count']}');
      print('  Total: \$${row['total_spent']}');
      print('  Average: \$${row['avg_order']}');
    }

  } finally {
    await db.close();
  }
}
```

### Parameter Management

Parameters allow you to safely inject values into queries, preventing SQL injection and making queries more reusable.

#### Setting Parameters

Use `set()` to define query parameters:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> parameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 30});
    await db.createQL('person', {'name': 'Charlie', 'age': 35});

    // Set a parameter
    await db.set('min_age', 25);

    // Use the parameter in a query with $parameter_name syntax
    final response = await db.queryQL(
      'SELECT * FROM person WHERE age >= \$min_age'
    );

    final results = response.getResults();
    print('People with age >= 25:');
    for (final person in results) {
      print('  - ${person['name']}: ${person['age']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Using Multiple Parameters

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> multipleParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {
      'name': 'Laptop',
      'price': 999.99,
      'category': 'electronics',
      'in_stock': true,
    });
    await db.createQL('product', {
      'name': 'Mouse',
      'price': 29.99,
      'category': 'electronics',
      'in_stock': true,
    });
    await db.createQL('product', {
      'name': 'Desk',
      'price': 499.99,
      'category': 'furniture',
      'in_stock': false,
    });

    // Set multiple parameters
    await db.set('category', 'electronics');
    await db.set('max_price', 500.00);
    await db.set('in_stock', true);

    // Use multiple parameters in one query
    final response = await db.queryQL('''
      SELECT * FROM product
      WHERE category = \$category
        AND price <= \$max_price
        AND in_stock = \$in_stock
    ''');

    final results = response.getResults();
    print('Affordable electronics in stock:');
    for (final product in results) {
      print('  - ${product['name']}: \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Complex Parameter Types

Parameters can be strings, numbers, booleans, or complex objects:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> complexParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Set a complex object parameter
    await db.set('filter', {
      'min_age': 25,
      'max_age': 35,
      'status': 'active',
    });

    // Use the complex parameter
    final response = await db.queryQL('RETURN \$filter');
    final result = response.firstOrNull;

    print('Filter parameter:');
    print('  Min age: ${result!['min_age']}');
    print('  Max age: ${result['max_age']}');
    print('  Status: ${result['status']}');

    // You can also use object properties in queries
    await db.set('age_range', {'min': 20, 'max': 40});
    final ageResponse = await db.queryQL('''
      SELECT * FROM person
      WHERE age >= \$age_range.min AND age <= \$age_range.max
    ''');

  } finally {
    await db.close();
  }
}
```

#### Unsetting Parameters

Use `unset()` to remove parameters:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> unsetParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Set a parameter
    await db.set('temp_value', 42);

    // Use the parameter
    var response = await db.queryQL('RETURN \$temp_value');
    print('Parameter value: ${response.firstOrNull}'); // Prints: 42

    // Unset the parameter
    await db.unset('temp_value');

    // Try to use the unset parameter (will return null or error)
    try {
      response = await db.queryQL('RETURN \$temp_value');
      print('After unset: ${response.firstOrNull}'); // May print: null
    } catch (e) {
      print('Parameter no longer exists');
    }

  } finally {
    await db.close();
  }
}
```

### Batch Operations

For inserting multiple records efficiently, use batch operations:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> batchInsertExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Method 1: Multiple createQL calls (simple but less efficient)
    print('Method 1: Individual inserts');
    for (var i = 1; i <= 3; i++) {
      await db.createQL('person', {
        'name': 'Person $i',
        'age': 20 + i,
      });
    }

    // Method 2: Single query with multiple INSERTs (more efficient)
    print('\nMethod 2: Batch insert via query');
    await db.queryQL('''
      INSERT INTO product [
        { name: 'Laptop', price: 999.99, stock: 10 },
        { name: 'Mouse', price: 29.99, stock: 50 },
        { name: 'Keyboard', price: 79.99, stock: 30 }
      ];
    ''');

    // Method 3: Using parameters for batch insert
    print('\nMethod 3: Batch insert with parameters');

    final products = [
      {'name': 'Monitor', 'price': 299.99, 'stock': 15},
      {'name': 'Webcam', 'price': 89.99, 'stock': 25},
      {'name': 'Headset', 'price': 149.99, 'stock': 20},
    ];

    await db.set('products', products);
    await db.queryQL('INSERT INTO product \$products');

    // Verify all inserts
    final allProducts = await db.selectQL('product');
    print('\nTotal products: ${allProducts.length}');

    for (final product in allProducts) {
      print('  - ${product['name']}: \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Bulk Update Operations

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> bulkUpdateExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {'name': 'Product 1', 'price': 100, 'discount': 0});
    await db.createQL('product', {'name': 'Product 2', 'price': 200, 'discount': 0});
    await db.createQL('product', {'name': 'Product 3', 'price': 300, 'discount': 0});

    // Bulk update: Add 10% discount to all products
    await db.queryQL('''
      UPDATE product SET discount = 0.10
    ''');

    // Bulk update with condition
    await db.queryQL('''
      UPDATE product SET discount = 0.20
      WHERE price > 150
    ''');

    // Verify updates
    final products = await db.selectQL('product');
    print('Products after bulk update:');
    for (final product in products) {
      final discount = (product['discount'] as num) * 100;
      print('  - ${product['name']}: ${discount}% discount');
    }

  } finally {
    await db.close();
  }
}
```

### Info Queries

SurrealDB provides special INFO queries to inspect the database schema and structure:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> infoQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create some data first
    await db.createQL('user', {'name': 'Alice'});
    await db.createQL('product', {'name': 'Laptop'});

    // INFO FOR DB - Get database schema information
    print('=== Database Info ===');
    var response = await db.queryQL('INFO FOR DB;');
    var info = response.firstOrNull;
    print('Database schema: $info\n');

    // Get SurrealDB version
    print('=== Version Info ===');
    response = await db.queryQL('SELECT * FROM version();');
    var version = response.firstOrNull;
    print('SurrealDB version: $version\n');

    // INFO FOR TABLE - Get specific table information
    print('=== Table Info ===');
    response = await db.queryQL('INFO FOR TABLE user;');
    var tableInfo = response.firstOrNull;
    print('User table schema: $tableInfo\n');

    // Get namespace info
    print('=== Namespace Info ===');
    response = await db.queryQL('INFO FOR NS;');
    var nsInfo = response.firstOrNull;
    print('Namespace info: $nsInfo');

  } finally {
    await db.close();
  }
}
```

### Complete Working Example

Here's a comprehensive example that demonstrates all the concepts covered in this section:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Initialize database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'example',
    database: 'demo',
  );

  try {
    print('=== SurrealDartBBasic QL Functions Demo ===\n');

    // 1. Create records
    print('1. Creating records...');
    final user1 = await db.createQL('user', {
      'username': 'alice',
      'email': 'alice@example.com',
      'age': 28,
      'active': true,
    });
    final user2 = await db.createQL('user', {
      'username': 'bob',
      'email': 'bob@example.com',
      'age': 32,
      'active': true,
    });
    print('   Created ${user1['username']} and ${user2['username']}\n');

    // 2. Read all records
    print('2. Reading all users...');
    var allUsers = await db.selectQL('user');
    print('   Found ${allUsers.length} users\n');

    // 3. Get specific record
    print('3. Getting specific user...');
    final userId = user1['id'] as String;
    final user = await db.get<Map<String, dynamic>>(userId);
    print('   Retrieved: ${user!['username']}\n');

    // 4. Raw query with WHERE
    print('4. Query users with age > 30...');
    await db.set('min_age', 30);
    var response = await db.queryQL(
      'SELECT * FROM user WHERE age > \$min_age'
    );
    var olderUsers = response.getResults();
    print('   Found ${olderUsers.length} users over 30\n');

    // 5. Update record
    print('5. Updating user...');
    final updated = await db.updateQL(userId, {
      'age': 29,
      'verified': true,
    });
    print('   Updated ${updated['username']}: age=${updated['age']}\n');

    // 6. Batch insert
    print('6. Batch inserting products...');
    await db.queryQL('''
      INSERT INTO product [
        { name: 'Laptop', price: 999.99 },
        { name: 'Mouse', price: 29.99 },
        { name: 'Keyboard', price: 79.99 }
      ];
    ''');
    final products = await db.selectQL('product');
    print('   Inserted ${products.length} products\n');

    // 7. Complex query
    print('7. Aggregating product data...');
    response = await db.queryQL('''
      SELECT
        count() as total,
        math::sum(price) as total_value,
        math::avg(price) as avg_price
      FROM product
    ''');
    final stats = response.firstOrNull;
    print('   Total products: ${stats!['total']}');
    print('   Total value: \$${stats['total_value']}');
    print('   Average price: \$${stats['avg_price']}\n');

    // 8. Delete record
    print('8. Deleting a user...');
    await db.deleteQL(userId);
    allUsers = await db.selectQL('user');
    print('   Remaining users: ${allUsers.length}\n');

    // 9. Info query
    print('9. Getting database info...');
    response = await db.queryQL('INFO FOR DB;');
    print('   Database schema retrieved\n');

    print('=== Demo Complete ===');

  } on QueryException catch (e) {
    print('Query error: ${e.message}');
  } on DatabaseException catch (e) {
    print('Database error: ${e.message}');
  } finally {
    await db.close();
    print('\nDatabase connection closed.');
  }
}
```

---

## Next Steps

Now that you understand the basics of database initialization and QL functions, you can:

1. **Section 3: Table Structures & Schema Definition** - Learn how to define schemas, validate data, and manage migrations
2. **Section 4: Type-Safe Data with Code Generator** - Explore the ORM features and code generation for type-safe operations
3. **Section 5: Vector Operations & Similarity Search** - Implement semantic search and work with vector embeddings

For questions or issues, please refer to:
- [SurrealDB Documentation](https://surrealdb.com/docs)
- [SurrealDartBGitHub Repository](https://github.com/yourusername/surrealdartb)
## Table Structures & Schema Definition

Table structures provide a powerful way to define and validate your database schema in Dart, bringing type safety and compile-time checking to your SurrealDB applications. By defining schemas, you can ensure data integrity, leverage database-level validation, and automate schema migrations.

### Why Use Schemas?

While SurrealDB allows schemaless tables, defining explicit schemas offers several benefits:

- **Data Validation**: Catch invalid data before it reaches the database
- **Type Safety**: Leverage Dart's type system for schema definitions
- **Documentation**: Your schema serves as living documentation of your data model
- **Migration Control**: Automatically detect and apply schema changes
- **Database Constraints**: Use ASSERT clauses for database-level validation
- **Performance**: Indexed fields improve query performance

### Creating a Basic Schema

A table structure consists of a table name and a map of field definitions. Each field has a type and optional constraints.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Define a simple user table
final userSchema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType()),
});

// Connect with the schema
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'app',
  database: 'app',
  tableDefinitions: [userSchema],
  autoMigrate: true,  // Automatically create/update tables
);

// Create a user (validated against schema)
final user = await db.createQL('users', {
  'name': 'Alice Smith',
  'age': 30,
  'email': 'alice@example.com',
});

await db.close();
```

### Field Types

SurrealDartBsupports all SurrealDB data types through a comprehensive type system:

#### Scalar Types

```dart
// String type
final nameField = FieldDefinition(StringType());

// Number types
final anyNumber = FieldDefinition(NumberType());  // Any numeric type
final age = FieldDefinition(NumberType(format: NumberFormat.integer));  // int only
final temperature = FieldDefinition(NumberType(format: NumberFormat.floating));  // float only
final price = FieldDefinition(NumberType(format: NumberFormat.decimal));  // precise decimal

// Boolean type
final isActive = FieldDefinition(BoolType());

// Datetime type
final createdAt = FieldDefinition(DatetimeType());

// Duration type
final sessionDuration = FieldDefinition(DurationType());
```

#### Collection Types

```dart
// Array type with element constraint
final tags = FieldDefinition(ArrayType(StringType()));

// Fixed-length array
final rgb = FieldDefinition(
  ArrayType(NumberType(format: NumberFormat.integer), length: 3),
);

// Nested arrays
final matrix = FieldDefinition(ArrayType(ArrayType(NumberType())));

// Object type (schemaless)
final metadata = FieldDefinition(ObjectType());

// Object with nested schema
final address = FieldDefinition(
  ObjectType(schema: {
    'street': FieldDefinition(StringType()),
    'city': FieldDefinition(StringType()),
    'zipCode': FieldDefinition(StringType()),
    'country': FieldDefinition(StringType(), optional: true),
  }),
);
```

#### Special Types

```dart
// Record type (reference to another table)
final authorId = FieldDefinition(RecordType(table: 'users'));  // Must be from 'users'
final anyRecord = FieldDefinition(RecordType());  // Any table

// Geometry type (GeoJSON)
final location = FieldDefinition(GeometryType(kind: GeometryKind.point));
final boundary = FieldDefinition(GeometryType(kind: GeometryKind.polygon));

// Vector type (for AI embeddings)
final embedding = FieldDefinition(VectorType.f32(1536, normalized: true));

// Any type (accepts any value - use sparingly)
final dynamicData = FieldDefinition(AnyType());
```

### Vector Field Types

Vector fields are specialized for AI/ML embeddings and similarity search:

```dart
// Common embedding formats
final openaiEmbedding = FieldDefinition(
  VectorType.f32(1536, normalized: true),  // OpenAI text-embedding-3-small
);

final bertEmbedding = FieldDefinition(
  VectorType.f32(768),  // BERT-base
);

// Different vector formats
final f32Vector = FieldDefinition(VectorType.f32(384));  // Float32 (most common)
final f64Vector = FieldDefinition(VectorType.f64(768));  // Float64 (high precision)
final i16Vector = FieldDefinition(VectorType.i16(384));  // Int16 (quantized)
final i8Vector = FieldDefinition(VectorType.i8(256));    // Int8 (highly compressed)

// Complete document schema with embeddings
final documentsSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'content': FieldDefinition(StringType()),
  'embedding': FieldDefinition(
    VectorType.f32(1536, normalized: true),
    optional: false,
  ),
  'category': FieldDefinition(StringType(), optional: true),
});
```

### Optional Fields and Default Values

Control which fields are required and provide defaults for optional fields:

```dart
final productsSchema = TableStructure('products', {
  // Required fields (default)
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),

  // Optional fields
  'description': FieldDefinition(StringType(), optional: true),
  'category': FieldDefinition(StringType(), optional: true),

  // Optional with default value
  'in_stock': FieldDefinition(
    BoolType(),
    optional: true,
    defaultValue: true,
  ),
  'views': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,
  ),
  'created_at': FieldDefinition(
    DatetimeType(),
    optional: true,
    defaultValue: 'time::now()',  // SurrealDB function
  ),
});

// Create product without optional fields
final product = await db.createQL('products', {
  'name': 'Widget',
  'price': 19.99,
});
// Result will have in_stock=true, views=0, created_at=(current timestamp)
```

### Indexed Fields

Mark fields as indexed to improve query performance:

```dart
final usersSchema = TableStructure('users', {
  'username': FieldDefinition(
    StringType(),
    indexed: true,  // Fast lookups by username
  ),
  'email': FieldDefinition(
    StringType(),
    indexed: true,  // Fast lookups by email
  ),
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
});

// Queries on indexed fields will be faster
final results = await db.queryQL('SELECT * FROM users WHERE email = "alice@example.com"');
```

### Validation with ASSERT Clauses

ASSERT clauses provide database-level validation using SurrealQL expressions:

```dart
final usersSchema = TableStructure('users', {
  'name': FieldDefinition(StringType()),

  // Age must be between 0 and 150
  'age': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 0 AND $value <= 150',
  ),

  // Email must be valid format
  'email': FieldDefinition(
    StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  ),

  // Username must be alphanumeric and 3-20 characters
  'username': FieldDefinition(
    StringType(),
    assertClause: r'string::len($value) >= 3 AND string::len($value) <= 20',
  ),

  // Password must be at least 8 characters
  'password': FieldDefinition(
    StringType(),
    assertClause: r'string::len($value) >= 8',
  ),
});

// Valid data passes through
final user = await db.createQL('users', {
  'name': 'Alice',
  'age': 30,
  'email': 'alice@example.com',
  'username': 'alice123',
  'password': 'secure_password',
});

// Invalid data throws QueryException
try {
  await db.createQL('users', {
    'name': 'Bob',
    'age': 15,  // Valid age
    'email': 'invalid-email',  // Invalid email format!
    'username': 'bo',  // Too short!
    'password': 'short',  // Too short!
  });
} on QueryException catch (e) {
  print('Validation failed: ${e.message}');
  // The ASSERT clause blocks invalid data at the database level
}
```

### Common Validation Patterns

Here are some useful ASSERT clause patterns:

```dart
final validationExamples = TableStructure('examples', {
  // String validations
  'email': FieldDefinition(
    StringType(),
    assertClause: r'string::is::email($value)',
  ),
  'url': FieldDefinition(
    StringType(),
    assertClause: r'string::is::url($value)',
  ),
  'uuid': FieldDefinition(
    StringType(),
    assertClause: r'string::is::uuid($value)',
  ),

  // Number range validations
  'percentage': FieldDefinition(
    NumberType(format: NumberFormat.floating),
    assertClause: r'$value >= 0 AND $value <= 100',
  ),
  'positive': FieldDefinition(
    NumberType(),
    assertClause: r'$value > 0',
  ),

  // Enum-like validations
  'status': FieldDefinition(
    StringType(),
    assertClause: r"$value IN ['pending', 'active', 'inactive', 'archived']",
  ),
  'role': FieldDefinition(
    StringType(),
    assertClause: r"$value IN ['admin', 'user', 'guest']",
  ),

  // Array validations
  'tags': FieldDefinition(
    ArrayType(StringType()),
    assertClause: r'array::len($value) <= 10',  // Max 10 tags
  ),

  // Vector validations
  'embedding': FieldDefinition(
    VectorType.f32(384, normalized: true),
    assertClause: r'vector::magnitude($value) == 1.0',
  ),

  // Date validations
  'birth_date': FieldDefinition(
    DatetimeType(),
    assertClause: r'$value < time::now()',  // Must be in the past
  ),
  'expiry_date': FieldDefinition(
    DatetimeType(),
    assertClause: r'$value > time::now()',  // Must be in the future
  ),
});
```

### Schema Validation Methods

Before sending data to the database, you can validate it against your schema in Dart:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
});

// Validate data for CREATE operation (all required fields needed)
final userData = {
  'name': 'Alice',
  'age': 30,
};

try {
  schema.validate(userData, partial: false);  // Full validation
  print('Valid data for creation');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  print('Field: ${e.fieldName}');
  print('Constraint: ${e.constraint}');
}

// Validate data for UPDATE operation (partial validation)
final updateData = {
  'age': 31,  // Only updating age
};

try {
  schema.validate(updateData, partial: true);  // Partial validation
  print('Valid data for update');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
}

// Validation catches type mismatches
final invalidData = {
  'name': 'Bob',
  'age': 'thirty',  // Should be a number!
  'email': 'bob@example.com',
};

try {
  schema.validate(invalidData, partial: false);
} on ValidationException catch (e) {
  print(e.message);  // "Field 'age' must be a number, got String"
  print(e.fieldName);  // "age"
  print(e.constraint);  // "type_mismatch"
}
```

### Schema Introspection

Query and inspect your schema definitions at runtime:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
  'phone': FieldDefinition(StringType(), optional: true),
});

// Check if field exists
print(schema.hasField('name'));   // true
print(schema.hasField('salary')); // false

// Get field definition
final emailDef = schema.getField('email');
if (emailDef != null) {
  print('Email type: ${emailDef.type}');
  print('Is optional: ${emailDef.optional}');
  print('Is indexed: ${emailDef.indexed}');
}

// Get lists of required and optional fields
final required = schema.getRequiredFields();
print('Required fields: $required');  // ['name', 'age']

final optional = schema.getOptionalFields();
print('Optional fields: $optional');  // ['email', 'phone']

// Access table name
print('Table name: ${schema.tableName}');  // 'users'

// Access all fields
print('Total fields: ${schema.fields.length}');
for (final entry in schema.fields.entries) {
  print('Field ${entry.key}: ${entry.value.type}');
}
```

### Generating DDL with toSurrealQL

Convert your Dart schema definitions to SurrealDB DDL statements:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
  'created_at': FieldDefinition(DatetimeType()),
});

// Generate SurrealQL DDL
final ddl = schema.toSurrealQL();
print(ddl);

/* Output:
DEFINE TABLE users SCHEMAFULL;
DEFINE FIELD name ON TABLE users TYPE string ASSERT $value != NONE;
DEFINE FIELD age ON TABLE users TYPE int ASSERT $value != NONE;
DEFINE FIELD email ON TABLE users TYPE string;
DEFINE FIELD created_at ON TABLE users TYPE datetime ASSERT $value != NONE;
*/

// Works with complex types too
final complexSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'tags': FieldDefinition(ArrayType(StringType())),
  'embedding': FieldDefinition(VectorType.f32(1536)),
  'metadata': FieldDefinition(ObjectType()),
});

print(complexSchema.toSurrealQL());

/* Output:
DEFINE TABLE documents SCHEMAFULL;
DEFINE FIELD title ON TABLE documents TYPE string ASSERT $value != NONE;
DEFINE FIELD tags ON TABLE documents TYPE array<string> ASSERT $value != NONE;
DEFINE FIELD embedding ON TABLE documents TYPE vector<F32, 1536> ASSERT $value != NONE;
DEFINE FIELD metadata ON TABLE documents TYPE object ASSERT $value != NONE;
*/
```

### Migration Strategies

SurrealDartBprovides two approaches for applying schema changes:

#### Auto-Migration (Development)

Best for rapid development iteration. Schema changes are automatically detected and applied on connection:

```dart
// Define initial schema
final initialSchema = TableStructure('products', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
});

// Connect with auto-migration
var db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'dev',
  database: 'dev',
  tableDefinitions: [initialSchema],
  autoMigrate: true,  // Automatically apply schema changes
);

// Add some data
await db.createQL('products', {
  'name': 'Widget',
  'price': 19.99,
});

await db.close();

// Later: Evolve the schema (add new fields)
final evolvedSchema = TableStructure('products', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  'description': FieldDefinition(StringType(), optional: true),  // New field!
  'stock': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,
  ),  // New field with default!
});

// Reconnect with evolved schema
db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'dev',
  database: 'dev',
  tableDefinitions: [evolvedSchema],
  autoMigrate: true,  // New fields are automatically added
);

// Old data is preserved, new fields available
final products = await db.selectQL('products');
print('Existing product: ${products[0]}');  // Has name and price

// Create new product with all fields
await db.createQL('products', {
  'name': 'Gadget',
  'price': 29.99,
  'description': 'A useful gadget',
  'stock': 50,
});

await db.close();
```

#### Manual Migration (Production)

Best for production environments where you want explicit control over when and how schema changes are applied:

```dart
// Connect WITHOUT auto-migration
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'email': FieldDefinition(StringType(), indexed: true),  // Adding index
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'created_at': FieldDefinition(
    DatetimeType(),
    optional: true,
    defaultValue: 'time::now()',
  ),  // New field with default
});

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'prod',
  database: 'prod',
  tableDefinitions: [schema],
  autoMigrate: false,  // Manual control
);

// Step 1: Preview migration with dry-run
print('Previewing migration changes...');
final previewReport = await db.migrate(dryRun: true);

if (previewReport.success) {
  print('Migration preview:');
  print('  Tables added: ${previewReport.tablesAdded.length}');
  print('  Fields added: ${previewReport.fieldsAdded.length}');
  print('  Fields modified: ${previewReport.fieldsModified.length}');
  print('  Indexes added: ${previewReport.indexesAdded.length}');
  print('  Has destructive changes: ${previewReport.hasDestructiveChanges}');
  print('');
  print('Generated DDL:');
  for (final ddl in previewReport.generatedDDL) {
    print('  $ddl');
  }
  print('');
} else {
  print('Migration would fail: ${previewReport.errorMessage}');
}

// Step 2: Apply migration (if preview looks good)
print('Applying migration...');
final applyReport = await db.migrate(
  dryRun: false,
  allowDestructiveMigrations: false,  // Block destructive changes
);

if (applyReport.success) {
  print('Migration applied successfully!');
  print('Migration ID: ${applyReport.migrationId}');
  print('Applied at: ${DateTime.now()}');
} else {
  print('Migration failed: ${applyReport.errorMessage}');
}

// Step 3: View migration history
final historyResponse = await db.queryQL(
  'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 5',
);
final history = historyResponse.getResults();
print('\nMigration history:');
for (final migration in history) {
  print('  ${migration['migration_id']}: ${migration['status']}');
  print('    Applied: ${migration['applied_at']}');
}

await db.close();
```

### Understanding Migration Reports

Migration operations return a `MigrationReport` with detailed information:

```dart
final report = await db.migrate(dryRun: true);

// Check if migration succeeded
if (report.success) {
  print('Migration would succeed');

  // Check what changed
  print('Tables added: ${report.tablesAdded}');
  print('Tables removed: ${report.tablesRemoved}');
  print('Fields added: ${report.fieldsAdded}');  // Map<table, List<field>>
  print('Fields removed: ${report.fieldsRemoved}');  // Map<table, List<field>>
  print('Fields modified: ${report.fieldsModified}');  // Map<table, List<modification>>
  print('Indexes added: ${report.indexesAdded}');  // Map<table, List<index>>
  print('Indexes removed: ${report.indexesRemoved}');  // Map<table, List<index>>

  // Check if changes are destructive
  if (report.hasDestructiveChanges) {
    print('WARNING: This migration contains destructive changes!');
    print('Destructive changes may result in data loss.');
  }

  // View generated DDL
  print('Generated DDL statements:');
  for (final ddl in report.generatedDDL) {
    print('  $ddl');
  }

  // Get migration hash (unique identifier for this set of changes)
  print('Migration hash: ${report.migrationHash}');

  // Get migration ID (if applied)
  if (report.migrationId != null) {
    print('Migration ID: ${report.migrationId}');
  }
} else {
  print('Migration would fail: ${report.errorMessage}');
  if (report.errorCode != null) {
    print('Error code: ${report.errorCode}');
  }
}
```

### Handling Destructive Changes

Destructive changes (like removing fields or tables) require explicit permission:

```dart
// Schema that removes a field (destructive!)
final oldSchema = TableStructure('items', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  'old_field': FieldDefinition(StringType(), optional: true),
});

final newSchema = TableStructure('items', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  // old_field removed - this is destructive!
});

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
  tableDefinitions: [newSchema],
  autoMigrate: false,
);

// This will fail (blocks destructive changes by default)
try {
  await db.migrate(allowDestructiveMigrations: false);
  print('Should not reach here');
} on MigrationException catch (e) {
  print('Blocked destructive migration: ${e.message}');
  print('Destructive changes detected:');
  print('  - Field removed: old_field');
  print('');
  print('To apply destructive changes:');
  print('  1. Review the changes carefully');
  print('  2. Backup your data');
  print('  3. Use allowDestructiveMigrations: true');
}

// Apply with explicit permission
print('\nApplying with explicit permission...');
final report = await db.migrate(allowDestructiveMigrations: true);
if (report.success) {
  print('Destructive migration applied');
  print('WARNING: Data in removed fields is lost');
}

await db.close();
```

### Complete Example: Multi-Table Schema

Here's a complete example with multiple related tables:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Define schemas for a blog application
  final userSchema = TableStructure('users', {
    'username': FieldDefinition(
      StringType(),
      indexed: true,
      assertClause: r'string::len($value) >= 3',
    ),
    'email': FieldDefinition(
      StringType(),
      indexed: true,
      assertClause: r'string::is::email($value)',
    ),
    'bio': FieldDefinition(StringType(), optional: true),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  final postSchema = TableStructure('posts', {
    'title': FieldDefinition(StringType()),
    'content': FieldDefinition(StringType()),
    'author_id': FieldDefinition(RecordType(table: 'users')),
    'published': FieldDefinition(BoolType(), defaultValue: false),
    'tags': FieldDefinition(ArrayType(StringType()), optional: true),
    'views': FieldDefinition(
      NumberType(format: NumberFormat.integer),
      defaultValue: 0,
      assertClause: r'$value >= 0',
    ),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  final commentSchema = TableStructure('comments', {
    'post_id': FieldDefinition(RecordType(table: 'posts')),
    'author_id': FieldDefinition(RecordType(table: 'users')),
    'content': FieldDefinition(StringType()),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  // Connect with all schemas
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'blog',
    database: 'blog',
    tableDefinitions: [userSchema, postSchema, commentSchema],
    autoMigrate: true,
  );

  try {
    // Create user
    final user = await db.createQL('users', {
      'username': 'alice',
      'email': 'alice@example.com',
      'bio': 'Software developer and blogger',
    });
    print('Created user: ${user['username']}');

    // Create post
    final post = await db.createQL('posts', {
      'title': 'Getting Started with SurrealDB',
      'content': 'SurrealDB is a powerful database...',
      'author_id': user['id'],
      'tags': ['database', 'tutorial', 'surreal'],
    });
    print('Created post: ${post['title']}');

    // Create comment
    final comment = await db.createQL('comments', {
      'post_id': post['id'],
      'author_id': user['id'],
      'content': 'Great post!',
    });
    print('Created comment: ${comment['content']}');

    // Query posts with author info
    final postsResponse = await db.queryQL('''
      SELECT *,
        author_id.username AS author_name,
        author_id.email AS author_email
      FROM posts
      WHERE published = false
    ''');
    final posts = postsResponse.getResults();
    print('\nUnpublished posts: ${posts.length}');
    for (final p in posts) {
      print('  ${p['title']} by ${p['author_name']}');
    }

    // Demonstrate validation failure
    try {
      await db.createQL('users', {
        'username': 'ab',  // Too short! (minimum 3 characters)
        'email': 'invalid-email',  // Invalid format!
      });
    } on QueryException catch (e) {
      print('\nValidation error caught (as expected):');
      print('  ${e.message}');
    }
  } finally {
    await db.close();
  }
}
```

### Best Practices

1. **Start with Schemas Early**: Define schemas from the beginning, even if simple. They serve as documentation and catch errors early.

2. **Use Optional Fields Wisely**: Make fields optional only when they truly can be absent. Required fields ensure data consistency.

3. **Leverage ASSERT Clauses**: Database-level validation is more robust than application-level validation alone.

4. **Index Frequently Queried Fields**: Add `indexed: true` to fields you'll query often (like email, username, foreign keys).

5. **Validate Before Inserting**: Use `schema.validate()` in your application to catch errors before database operations.

6. **Preview Migrations**: Always use `migrate(dryRun: true)` in production to preview changes before applying them.

7. **Version Your Schemas**: Keep your schema definitions in version control alongside your code.

8. **Test Schema Changes**: Test migrations thoroughly in development before deploying to production.

9. **Backup Before Destructive Migrations**: Always backup your data before applying migrations that remove fields or tables.

10. **Use Auto-Migration in Development**: Enable `autoMigrate: true` during development for fast iteration, but use manual migration in production.

### Common Pitfalls

**Pitfall 1: Forgetting to handle optional fields**
```dart
// Bad: No default, may cause null errors
final schema = TableStructure('users', {
  'credits': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
  ),
});

// Good: Provide default value
final schema = TableStructure('users', {
  'credits': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,  // Clear default
  ),
});
```

**Pitfall 2: Over-validating with ASSERT clauses**
```dart
// Bad: Too restrictive, hard to change later
'username': FieldDefinition(
  StringType(),
  assertClause: r'string::len($value) == 8',  // Exactly 8 chars - too rigid!
),

// Good: Reasonable constraints
'username': FieldDefinition(
  StringType(),
  assertClause: r'string::len($value) >= 3 AND string::len($value) <= 20',
),
```

**Pitfall 3: Not using partial validation for updates**
```dart
// Bad: Full validation on updates fails for partial data
schema.validate({'age': 31}, partial: false);  // Fails! Missing 'name'

// Good: Use partial validation for updates
schema.validate({'age': 31}, partial: true);  // OK! Only validates present fields
```

### Next Steps

Now that you understand table structures and schema definition, you can move on to type-safe data access using the code generator. The next section covers:

- Using `@SurrealTable` and `@SurrealField` annotations
- Generating type-safe models with build_runner
- Type-safe query builders
- Working with relationships

Continue to [Section 4: Type-Safe Data with Code Generator](#) →
## Type-Safe Data with Code Generator

SurrealDartBincludes a powerful code generator that transforms your annotated Dart model classes into type-safe, validated database entities. This approach brings compile-time safety, IDE autocomplete, and automatic validation to your database operations.

### Why Use the Code Generator?

The traditional approach using maps is flexible but error-prone:

```dart
// Traditional approach - no type safety, easy to make mistakes
final user = await db.createQL('users', {
  'name': 'John',
  'age': '30',  // Oops! Should be an int, not a String
  'emial': 'john@example.com',  // Typo! No compile-time check
});
```

With the code generator, you get:

- **Compile-time type safety** - Catch errors before runtime
- **IDE autocomplete** - Discover available fields and methods
- **Automatic validation** - Enforce constraints at the Dart level
- **Cleaner code** - Less boilerplate, more readable
- **Refactoring support** - Rename fields with confidence

### Setting Up the Code Generator

#### Step 1: Add Dependencies

Add the code generator to your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^0.0.4

dev_dependencies:
  build_runner: ^2.4.0
```

Run `dart pub get` to install the dependencies.

#### Step 2: Create build.yaml (Optional)

If you want to control which files the generator processes, create a `build.yaml` in your project root:

```yaml
targets:
  $default:
    builders:
      surrealdartb|surreal_table_builder:
        enabled: true
        generate_for:
          - lib/models/**/*.dart
```

This configuration tells the generator to only process Dart files in the `lib/models/` directory.

### Defining Models with Annotations

#### Basic Model Structure

Create a Dart class and annotate it with `@SurrealTable`:

```dart
import 'package:surrealdartb/surrealdartb.dart';

part 'user.surreal.dart';  // Generated file

@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  @SurrealField(
    type: NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 18',
  )
  final int age;

  @SurrealField(
    type: StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  )
  final String email;

  @SurrealField(
    type: StringType(),
    defaultValue: 'active',
  )
  final String status;

  User({
    this.id,
    required this.name,
    required this.age,
    required this.email,
    this.status = 'active',
  });
}
```

#### Understanding Annotations

##### @SurrealTable

Marks a class as a database table model. Takes the table name as a parameter.

```dart
@SurrealTable('users')  // Table name in the database
class User {
  // ...
}
```

##### @SurrealId

Marks the ID field in your model. This field will be used to identify records.

```dart
@SurrealId()
String? id;  // Must be nullable since it's assigned by the database
```

**Important:** The ID field should be nullable because it's typically assigned by SurrealDB when the record is created.

##### @SurrealField

Defines a database field with its type and optional constraints.

**Parameters:**
- `type` - The SurrealDB field type (required)
- `assertClause` - Database-level validation constraint (optional)
- `indexed` - Whether to create an index on this field (optional, default: false)
- `defaultValue` - Default value if not provided (optional)
- `optional` - Whether the field can be null (optional, inferred from Dart type)

**Field Types:**

```dart
// String field
@SurrealField(type: StringType())
final String name;

// Integer field
@SurrealField(type: NumberType(format: NumberFormat.integer))
final int age;

// Floating-point field
@SurrealField(type: NumberType(format: NumberFormat.floating))
final double score;

// Decimal field (precise monetary values)
@SurrealField(type: NumberType(format: NumberFormat.decimal))
final double price;

// Boolean field
@SurrealField(type: BoolType())
final bool isActive;

// DateTime field
@SurrealField(type: DatetimeType())
final DateTime createdAt;

// Duration field
@SurrealField(type: DurationType())
final Duration sessionTime;

// Array field
@SurrealField(type: ArrayType(StringType()))
final List<String> tags;
```

**Field Constraints:**

```dart
// Age must be 18 or older
@SurrealField(
  type: NumberType(format: NumberFormat.integer),
  assertClause: r'$value >= 18',
)
final int age;

// Email validation
@SurrealField(
  type: StringType(),
  assertClause: r'string::is::email($value)',
)
final String email;

// Indexed for fast lookups
@SurrealField(
  type: StringType(),
  indexed: true,
)
final String username;

// Default value
@SurrealField(
  type: StringType(),
  defaultValue: 'active',
)
final String status;

// Optional field (nullable)
@SurrealField(type: StringType(), optional: true)
String? bio;
```

##### @SurrealRecord

Defines a relationship to another table. Used for one-to-one and one-to-many relationships.

```dart
// One-to-one relationship
@SurrealRecord()
Profile? profile;

// One-to-many relationship
@SurrealRecord()
List<Post>? posts;
```

**Relationship Patterns:**
- **One-to-One:** Single object, e.g., `Profile? profile`
- **One-to-Many:** List of objects, e.g., `List<Post>? posts`
- **Nullable relationships:** Optional relationships that must be explicitly loaded
- **Non-nullable relationships:** Automatically loaded (if supported by your query)

### Running the Code Generator

After defining your models, run the code generator:

```bash
# One-time generation
dart run build_runner build

# Watch mode (regenerates on file changes)
dart run build_runner watch

# Clean and rebuild
dart run build_runner build --delete-conflicting-outputs
```

This generates a `.surreal.dart` file for each model with:
- `toSurrealMap()` - Serializes the model to a database-compatible map
- `fromSurrealMap()` - Deserializes a database result to your model
- `validate()` - Validates the model against schema constraints
- `tableDefinition` - A `TableStructure` constant for schema operations
- Query builder classes for type-safe queries

### Using Generated Code

#### Serialization and Deserialization

The generated extension provides methods to convert between your Dart objects and database format:

```dart
// Create a user
final user = User(
  name: 'Alice Johnson',
  age: 28,
  email: 'alice@example.com',
  status: 'active',
);

// Serialize to database format
final map = user.toSurrealMap();
// Result: {'name': 'Alice Johnson', 'age': 28, 'email': 'alice@example.com', 'status': 'active'}

// Save to database
final created = await db.createQL('users', map);
user.id = created['id'];

// Deserialize from database
final retrieved = await db.get('users:123');
final userFromDb = UserORM.fromSurrealMap(retrieved);
print(userFromDb.name);  // 'Alice Johnson'
```

#### Validation

Validate a model instance before saving:

```dart
try {
  // This will throw if age < 18 or email is invalid
  user.validate();

  // If validation passes, safe to save
  await db.createQL('users', user.toSurrealMap());
} on OrmValidationException catch (e) {
  print('Validation failed: ${e.message}');
  print('Field: ${e.field}');
  print('Constraint: ${e.constraint}');
}
```

#### Accessing Table Metadata

The generated code includes static access to table information:

```dart
// Get table name
String tableName = UserORM.tableName;  // 'users'

// Get table structure for schema operations
TableStructure structure = UserORM.tableStructure;

// Use in schema operations
await structure.migrate(db);
```

### Type-Safe Query Builder

The code generator creates type-safe query builders that provide compile-time safety for your queries.

#### Basic Queries

```dart
// Query all active users
final users = await db.query<User>()
  .where((t) => t.status.equals('active'))
  .execute();

// Query with multiple conditions
final youngAdults = await db.query<User>()
  .where((t) => t.age.between(18, 30) & t.status.equals('active'))
  .execute();

// Ordered results with limit
final topUsers = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .orderBy('name', ascending: true)
  .limit(10)
  .execute();

// Get first result or null
final user = await db.query<User>()
  .where((t) => t.email.equals('alice@example.com'))
  .first();
```

#### Available Operators

The where builder provides type-specific operators:

**String Operators:**
```dart
.where((t) => t.name.equals('Alice'))
.where((t) => t.email.contains('@example.com'))
.where((t) => t.name.startsWith('A'))
.where((t) => t.domain.endsWith('.com'))
.where((t) => t.name.ilike('%john%'))  // Case-insensitive pattern match
.where((t) => t.status.inList(['active', 'pending']))
```

**Number Operators:**
```dart
.where((t) => t.age.equals(25))
.where((t) => t.age.greaterThan(18))
.where((t) => t.age.lessThan(65))
.where((t) => t.age.greaterOrEqual(18))
.where((t) => t.age.lessOrEqual(65))
.where((t) => t.age.between(18, 65))
.where((t) => t.score.inList([100, 200, 300]))
```

**Boolean Operators:**
```dart
.where((t) => t.verified.isTrue())
.where((t) => t.deleted.isFalse())
.where((t) => t.active.equals(true))
```

**DateTime Operators:**
```dart
final now = DateTime.now();
final yesterday = now.subtract(Duration(days: 1));
final tomorrow = now.add(Duration(days: 1));

.where((t) => t.createdAt.equals(now))
.where((t) => t.createdAt.before(tomorrow))
.where((t) => t.createdAt.after(yesterday))
.where((t) => t.createdAt.between(yesterday, tomorrow))
```

#### Combining Conditions

Use `&` (AND) and `|` (OR) operators to combine conditions:

**AND Conditions:**
```dart
// Users who are active AND over 18
final adults = await db.query<User>()
  .where((t) =>
    t.status.equals('active') & t.age.greaterThan(18)
  )
  .execute();

// Multiple AND conditions
final filtered = await db.query<User>()
  .where((t) =>
    t.age.between(25, 40) &
    t.status.equals('active') &
    t.verified.isTrue()
  )
  .execute();
```

**OR Conditions:**
```dart
// Users under 18 OR over 65
final nonWorkingAge = await db.query<User>()
  .where((t) =>
    t.age.lessThan(18) | t.age.greaterThan(65)
  )
  .execute();

// Multiple OR conditions (find admins, moderators, or owners)
final privileged = await db.query<User>()
  .where((t) =>
    t.role.equals('admin') |
    t.role.equals('moderator') |
    t.role.equals('owner')
  )
  .execute();
```

**Complex Conditions (Combining AND/OR):**
```dart
// Active users who are either young (< 30) or senior (> 60)
final results = await db.query<User>()
  .where((t) =>
    (t.age.lessThan(30) | t.age.greaterThan(60)) &
    t.status.equals('active')
  )
  .execute();

// Complex business logic
final qualified = await db.query<User>()
  .where((t) =>
    (t.age.greaterOrEqual(18) & t.verified.isTrue()) |
    (t.role.equals('admin') & t.status.equals('active'))
  )
  .execute();
```

**Using reduce() for Dynamic Conditions:**
```dart
// Build a dynamic list of OR conditions
final roles = ['admin', 'moderator', 'owner'];
final conditions = roles
  .map((role) => StringFieldCondition('role').equals(role))
  .toList();

final combined = conditions.reduce((a, b) => a | b);
final users = await db.query(table: 'users', where: combined);
```

#### Query Builder Methods

**limit() - Limit Results:**
```dart
// Get top 10 users
final top10 = await db.query<User>()
  .limit(10)
  .execute();
```

**offset() - Skip Results:**
```dart
// Pagination: get users 11-20
final page2 = await db.query<User>()
  .offset(10)
  .limit(10)
  .execute();
```

**orderBy() - Sort Results:**
```dart
// Ascending order (default)
final ascending = await db.query<User>()
  .orderBy('name')
  .execute();

// Descending order
final descending = await db.query<User>()
  .orderBy('age', ascending: false)
  .execute();
```

**first() - Get Single Result:**
```dart
// Get first match or null
final user = await db.query<User>()
  .where((t) => t.email.equals('alice@example.com'))
  .first();

if (user != null) {
  print('Found: ${user.name}');
} else {
  print('User not found');
}
```

### Working with Relationships

The code generator supports relationships between models through the `@SurrealRecord` annotation.

#### Defining Relationships

```dart
// User model with relationships
@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  // One-to-one: User has one Profile
  @SurrealRecord()
  Profile? profile;

  // One-to-many: User has many Posts
  @SurrealRecord()
  List<Post>? posts;

  User({this.id, required this.name, this.profile, this.posts});
}

// Profile model
@SurrealTable('profiles')
class Profile {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType(), optional: true)
  String? bio;

  @SurrealField(type: StringType(), optional: true)
  String? website;

  @SurrealField(type: StringType(), optional: true)
  String? location;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  Profile({
    this.id,
    this.bio,
    this.website,
    this.location,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// Post model
@SurrealTable('posts')
class Post {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String title;

  @SurrealField(type: StringType())
  final String content;

  @SurrealField(
    type: StringType(),
    defaultValue: 'draft',
  )
  final String status;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  // Reverse relationship: Post belongs to User
  @SurrealRecord()
  User? author;

  Post({
    this.id,
    required this.title,
    required this.content,
    this.status = 'draft',
    DateTime? createdAt,
    this.author,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

#### One-to-One Relationships

A one-to-one relationship is represented by a single nullable object:

```dart
// Create a user
final user = await db.createQL('users', {
  'name': 'Alice Johnson',
  'age': 28,
  'email': 'alice@example.com',
});
final userId = user['id'];

// Create a profile linked to the user
final profile = await db.createQL('profiles', {
  'bio': 'Software engineer passionate about databases',
  'website': 'https://alice.dev',
  'location': 'San Francisco',
  'createdAt': DateTime.now().toIso8601String(),
});
final profileId = profile['id'];

// Link the profile to the user
await db.updateQL(userId, {'profile': profileId});

// Query user with profile
final response = await db.queryQL('SELECT *, profile.* FROM users FETCH profile WHERE id = \$userId');
await db.set('userId', userId);
final users = response.getResults();

// The profile is loaded as a nested object
if (users.isNotEmpty) {
  final userWithProfile = users.first;
  print('User: ${userWithProfile['name']}');

  if (userWithProfile['profile'] is Map) {
    final profileData = userWithProfile['profile'] as Map<String, dynamic>;
    print('Bio: ${profileData['bio']}');
    print('Location: ${profileData['location']}');
  }
}
```

#### One-to-Many Relationships

A one-to-many relationship is represented by a list of objects:

```dart
// Create a user
final user = await db.createQL('users', {
  'name': 'Bob Smith',
  'age': 35,
  'email': 'bob@example.com',
});
final userId = user['id'];

// Create posts for the user
final post1 = await db.createQL('posts', {
  'title': 'Getting Started with SurrealDB',
  'content': 'This is a great database...',
  'status': 'published',
  'createdAt': DateTime.now().toIso8601String(),
  'author': userId,
});

final post2 = await db.createQL('posts', {
  'title': 'Advanced SurrealDB Techniques',
  'content': 'In this post we explore...',
  'status': 'published',
  'createdAt': DateTime.now().toIso8601String(),
  'author': userId,
});

// Query user with posts using a correlated subquery
final response = await db.queryQL('''
  SELECT *,
    (SELECT * FROM posts WHERE author = \$parent.id ORDER BY createdAt DESC) AS posts
  FROM users
  WHERE id = \$userId
''');
await db.set('userId', userId);
final users = response.getResults();

if (users.isNotEmpty) {
  final userWithPosts = users.first;
  print('User: ${userWithPosts['name']}');

  if (userWithPosts['posts'] is List) {
    final posts = userWithPosts['posts'] as List;
    print('Posts: ${posts.length}');
    for (final post in posts) {
      if (post is Map) {
        print('  - ${post['title']} (${post['status']})');
      }
    }
  }
}
```

#### Filtered Includes

You can filter related records using correlated subqueries:

```dart
// Get users with only their published posts
final response = await db.queryQL('''
  SELECT *,
    (SELECT * FROM posts
     WHERE author = \$parent.id AND status = 'published'
     ORDER BY createdAt DESC
     LIMIT 5) AS posts
  FROM users
  WHERE name = 'Bob Smith'
''');

final users = response.getResults();
// Only published posts are included in the results
```

The `$parent.id` reference creates a correlated subquery where each user's posts are filtered based on their ID.

**Pattern for Filtered Includes:**
```
(SELECT * FROM <related_table>
 WHERE <foreign_key> = $parent.id AND <your_conditions>
 ORDER BY <field> [ASC|DESC]
 LIMIT <n>) AS <relationship_field>
```

### Complete Example

Here's a complete example showing model definition, code generation, and usage:

**1. Define the models (lib/models/user.dart):**

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'post.dart';
import 'profile.dart';

part 'user.surreal.dart';

@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  @SurrealField(
    type: NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 18',
  )
  final int age;

  @SurrealField(
    type: StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  )
  final String email;

  @SurrealField(
    type: StringType(),
    defaultValue: 'active',
  )
  final String status;

  @SurrealRecord()
  Profile? profile;

  @SurrealRecord()
  List<Post>? posts;

  User({
    this.id,
    required this.name,
    required this.age,
    required this.email,
    this.status = 'active',
    this.profile,
    this.posts,
  });
}
```

**2. Run the generator:**

```bash
dart run build_runner build
```

**3. Use the generated code:**

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'models/user.dart';

Future<void> main() async {
  // Connect to database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create and validate a user
    final user = User(
      name: 'Alice Johnson',
      age: 28,
      email: 'alice@example.com',
      status: 'active',
    );

    // Validate before saving
    user.validate();  // Throws if invalid

    // Save to database
    final created = await db.createQL('users', user.toSurrealMap());
    user.id = created['id'];
    print('Created user: ${user.id}');

    // Type-safe query
    final activeUsers = await db.query<User>()
      .where((t) => t.status.equals('active') & t.age.greaterThan(18))
      .orderBy('name')
      .execute();

    print('Found ${activeUsers.length} active adult users');
    for (final u in activeUsers) {
      print('  - ${u.name} (${u.age} years old)');
    }

    // Complex query with OR
    final youngOrSenior = await db.query<User>()
      .where((t) =>
        (t.age.lessThan(30) | t.age.greaterThan(60)) &
        t.status.equals('active')
      )
      .execute();

    print('Young or senior users: ${youngOrSenior.length}');

    // Find specific user
    final alice = await db.query<User>()
      .where((t) => t.email.equals('alice@example.com'))
      .first();

    if (alice != null) {
      print('Found user: ${alice.name}');
    }

  } finally {
    await db.close();
  }
}
```

### Best Practices

#### 1. Always Use part Directive

Include the part directive at the top of your model file:

```dart
part 'user.surreal.dart';
```

The generated file will have the same name with `.surreal.dart` extension.

#### 2. Make ID Fields Nullable

ID fields should be nullable since they're assigned by the database:

```dart
@SurrealId()
String? id;  // Correct - nullable

@SurrealId()
String id;   // Wrong - will cause issues on insert
```

#### 3. Validate Before Saving

Always validate models before saving to catch errors early:

```dart
try {
  user.validate();
  await db.createQL('users', user.toSurrealMap());
} on OrmValidationException catch (e) {
  // Handle validation error
}
```

#### 4. Use Type-Safe Queries

Prefer type-safe queries over raw SQL when possible:

```dart
// Good - type-safe
final users = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .execute();

// Avoid - error-prone
final response = await db.queryQL('SELECT * FROM users WHERE age > 18');
```

#### 5. Handle Relationships Carefully

Remember that relationship fields are nullable and loaded separately:

```dart
// Query with explicit relationship loading
final response = await db.queryQL('SELECT *, profile.* FROM users FETCH profile');
final users = response.getResults();

// Check if relationship is loaded
if (userMap['profile'] is Map) {
  final profile = Profile.fromSurrealMap(userMap['profile']);
  // Use profile
}
```

#### 6. Use assert Clauses for Database-Level Validation

Database-level constraints ensure data integrity:

```dart
@SurrealField(
  type: NumberType(format: NumberFormat.integer),
  assertClause: r'$value >= 18',  // Enforced by database
)
final int age;
```

#### 7. Index Frequently Queried Fields

Add indexes to fields you query often:

```dart
@SurrealField(
  type: StringType(),
  indexed: true,  // Creates database index
)
final String email;
```

### Troubleshooting

#### Generated File Not Found

If you get a "part file not found" error:

1. Run the generator: `dart run build_runner build`
2. Check that the part directive matches the generated file name
3. Ensure build_runner is in dev_dependencies

#### Validation Errors

If validation fails unexpectedly:

1. Check that field types match between Dart and annotation
2. Verify assert clauses use correct SurrealQL syntax
3. Test constraints with simple values first

#### Type Conversion Errors

If deserialization fails:

1. Ensure database field types match model types
2. Check that nullable fields are properly marked as optional
3. Verify DateTime fields are in ISO 8601 format

#### Query Builder Not Available

If `db.query<User>()` is not recognized:

1. Run the generator to create query builder classes
2. Import the model file with generated code
3. Check that @SurrealTable annotation is present

### Next Steps

Now that you understand type-safe data modeling with the code generator, you can:

- Learn about [Vector Operations & Similarity Search](section-5-vectors.md) for AI-powered features
- Explore advanced relationship patterns with graph edges
- Implement real-time subscriptions with live queries
- Build complex data validation rules with custom assert clauses

The code generator brings the best of both worlds: the flexibility of SurrealDB's schema and the safety of Dart's type system. Use it to build robust, maintainable database applications.
## Vector Operations & Similarity Search

Vector embeddings are numerical representations of data (text, images, audio, etc.) that capture semantic meaning in high-dimensional space. SurrealDartBprovides comprehensive support for storing, manipulating, and searching vector embeddings, making it ideal for AI/ML applications like semantic search, recommendation systems, and similarity-based retrieval.

### What are Vector Embeddings?

Vector embeddings are arrays of numbers that represent the semantic meaning of content. For example:
- Text embeddings from models like OpenAI's ada-002 (1536 dimensions)
- Sentence embeddings from BERT or sentence-transformers (384-768 dimensions)
- Image embeddings from vision models
- Audio embeddings from speech recognition models

Similar content produces similar embeddings, enabling powerful similarity search capabilities.

### Common Use Cases

- **Semantic Search**: Find documents by meaning rather than exact keywords
- **Recommendation Systems**: Suggest similar products, articles, or content
- **Duplicate Detection**: Identify near-duplicate content
- **Classification**: Group similar items together
- **Retrieval-Augmented Generation (RAG)**: Power AI chatbots with relevant context

---

### Creating Vector Values

SurrealDartBprovides the `VectorValue` class to work with vector embeddings. Vectors can be created in multiple formats to balance precision and memory usage.

#### Basic Vector Creation

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create a Float32 vector (most common for AI/ML)
final embedding = VectorValue.f32([0.1, 0.2, 0.3, 0.4, 0.5]);
print('Dimensions: ${embedding.dimensions}'); // 5
print('Format: ${embedding.format}'); // VectorFormat.f32

// Create from a generic list (defaults to F32)
final vector = VectorValue.fromList([1.0, 2.0, 3.0]);

// Create from string format
final parsed = VectorValue.fromString('[0.1, 0.2, 0.3]');
```

#### Vector Formats

SurrealDartBsupports six vector formats, each optimized for different use cases:

```dart
// F32 (Float32) - Standard for AI/ML embeddings
final f32 = VectorValue.f32([1.5, 2.7, 3.2, 4.1]);
// Memory: 4 bytes × dimensions
// Use case: OpenAI, sentence transformers, most AI models

// F64 (Float64) - High precision
final f64 = VectorValue.f64([1.123456789, 2.987654321]);
// Memory: 8 bytes × dimensions
// Use case: Scientific computing, high precision requirements

// I16 (Int16) - Quantized embeddings
final i16 = VectorValue.i16([100, 200, 300, 400]);
// Memory: 2 bytes × dimensions (50% savings vs F32)
// Use case: Quantized models, memory-constrained devices

// I8 (Int8) - Maximum compression
final i8 = VectorValue.i8([10, 20, 30, 40]);
// Memory: 1 byte × dimensions (75% savings vs F32)
// Use case: Extreme compression, mobile devices

// I32 and I64 also available for integer vectors
final i32 = VectorValue.i32([1000, 2000, 3000]);
final i64 = VectorValue.i64([100000, 200000, 300000]);
```

**Format Selection Guide:**
- **F32**: Default choice for most AI/ML workloads (best balance)
- **F64**: Only when high precision is critical
- **I16/I8**: For quantized models or memory-constrained environments
- **I32/I64**: For specialized integer-based embeddings

#### Memory Comparison

For a 768-dimensional vector (common size):
- **F32**: 3,072 bytes
- **F64**: 6,144 bytes (2x F32)
- **I16**: 1,536 bytes (50% of F32)
- **I8**: 768 bytes (25% of F32)

---

### Vector Operations

#### Basic Properties

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Access dimensions
print(vector.dimensions); // 3

// Check format
print(vector.format); // VectorFormat.f32

// Access raw data
print(vector.data); // Float32List [3.0, 4.0, 0.0]

// Convert to list for storage
final jsonData = vector.toJson();
print(jsonData); // [3.0, 4.0, 0.0]
```

#### Vector Magnitude

The magnitude (or length) of a vector measures its overall size:

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Calculate magnitude (Euclidean norm)
final mag = vector.magnitude();
print('Magnitude: $mag'); // 5.0 (sqrt(3² + 4²))

// Unit vectors have magnitude 1.0
final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
print('Unit magnitude: ${unitVec.magnitude()}'); // 1.0

// Zero vector has magnitude 0.0
final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
print('Zero magnitude: ${zeroVec.magnitude()}'); // 0.0
```

#### Vector Normalization

Normalization converts a vector to unit length (magnitude = 1.0) while preserving its direction. This is essential for cosine similarity and many ML models:

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Normalize to unit vector
final normalized = vector.normalize();
print('Original magnitude: ${vector.magnitude()}'); // 5.0
print('Normalized magnitude: ${normalized.magnitude()}'); // 1.0
print('Normalized values: ${normalized.toJson()}'); // [0.6, 0.8, 0.0]

// Check if already normalized
print('Is normalized: ${vector.isNormalized()}'); // false
print('Is normalized: ${normalized.isNormalized()}'); // true

// Normalization preserves direction
// The ratio between components remains the same
// Original: 3:4 = 0.75
// Normalized: 0.6:0.8 = 0.75
```

**When to normalize:**
- Before storing embeddings for cosine similarity search
- When using models that expect normalized inputs
- When comparing vectors using dot product
- When direction matters more than magnitude

**Important:** Normalizing a zero vector throws a `StateError`:

```dart
final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  zeroVec.normalize(); // Throws StateError
} catch (e) {
  print('Cannot normalize zero vector');
}
```

#### Dot Product

The dot product measures how much two vectors point in the same direction:

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 5.0, 6.0]);

// Calculate dot product: 1*4 + 2*5 + 3*6 = 32
final dot = vec1.dotProduct(vec2);
print('Dot product: $dot'); // 32.0

// Orthogonal vectors have dot product 0
final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
print('Orthogonal dot product: ${vecX.dotProduct(vecY)}'); // 0.0

// For normalized vectors, dot product equals cosine similarity
final norm1 = vec1.normalize();
final norm2 = vec2.normalize();
final dotNorm = norm1.dotProduct(norm2);
final cosine = norm1.cosine(norm2);
print('Dot of normalized: $dotNorm');
print('Cosine similarity: $cosine');
// These will be equal (within floating-point precision)
```

---

### Distance Calculations

Distance metrics measure how similar or different two vectors are. Different metrics are suitable for different use cases.

#### Euclidean Distance

Measures the straight-line distance between two vectors (L2 norm):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

// Calculate Euclidean distance
// sqrt((4-1)² + (6-2)² + (8-3)²) = sqrt(50) ≈ 7.07
final distance = vec1.euclidean(vec2);
print('Euclidean distance: $distance'); // ~7.07

// Identical vectors have distance 0
final vec3 = VectorValue.f32([1.0, 2.0, 3.0]);
print('Distance to self: ${vec1.euclidean(vec3)}'); // 0.0
```

**Best for:**
- General-purpose similarity
- When absolute magnitude matters
- Image embeddings
- General ML embeddings

#### Cosine Similarity

Measures the angle between vectors, ignoring magnitude. Returns value from -1 (opposite) to 1 (identical):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([2.0, 4.0, 6.0]); // Parallel to vec1

// Cosine similarity: parallel vectors = 1.0
print('Parallel vectors: ${vec1.cosine(vec2)}'); // 1.0

// Orthogonal vectors = 0.0
final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
print('Orthogonal vectors: ${vecX.cosine(vecY)}'); // 0.0

// Opposite vectors = -1.0
final vecPos = VectorValue.f32([1.0, 0.0, 0.0]);
final vecNeg = VectorValue.f32([-1.0, 0.0, 0.0]);
print('Opposite vectors: ${vecPos.cosine(vecNeg)}'); // -1.0
```

**Best for:**
- Text embeddings
- Semantic similarity
- Document clustering
- When direction matters more than magnitude

**Important:** Cosine similarity throws `StateError` for zero vectors:

```dart
final vec = VectorValue.f32([1.0, 2.0, 3.0]);
final zero = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  vec.cosine(zero); // Throws StateError
} catch (e) {
  print('Cannot compute cosine with zero vector');
}
```

#### Manhattan Distance

Sum of absolute differences between components (L1 norm):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

// Manhattan distance: |4-1| + |6-2| + |8-3| = 12
final distance = vec1.manhattan(vec2);
print('Manhattan distance: $distance'); // 12.0
```

**Best for:**
- High-dimensional spaces
- Grid-based movement
- Robustness to outliers
- Sparse vectors

#### Comparing Metrics

Different metrics rank similarity differently:

```dart
final query = VectorValue.f32([0.9, 0.1, 0.0]);
final doc1 = VectorValue.f32([1.0, 0.0, 0.0]); // Close to query
final doc2 = VectorValue.f32([0.0, 1.0, 0.0]); // Far from query

print('Document 1 vs Query:');
print('  Euclidean: ${query.euclidean(doc1)}'); // ~0.14
print('  Cosine: ${query.cosine(doc1)}'); // ~1.0 (very similar)
print('  Manhattan: ${query.manhattan(doc1)}'); // ~0.2

print('\nDocument 2 vs Query:');
print('  Euclidean: ${query.euclidean(doc2)}'); // ~1.27
print('  Cosine: ${query.cosine(doc2)}'); // ~0.1 (dissimilar)
print('  Manhattan: ${query.manhattan(doc2)}'); // ~1.8
```

---

### Storing Vectors in Database

Vectors are stored as arrays in SurrealDB and can be included in any table schema.

#### Define Schema with Vector Field

```dart
import 'package:surrealdartb/surrealdartb.dart';

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'ai_app',
  database: 'vectors',
);

// Define table structure with vector field
final documentSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType(), optional: false),
  'content': FieldDefinition(StringType(), optional: false),
  'embedding': FieldDefinition(
    VectorType.f32(768, normalized: true),
    optional: false,
  ),
  'category': FieldDefinition(StringType(), optional: true),
  'created_at': FieldDefinition(DatetimeType(), optional: true),
});

// Apply schema to database
await db.queryQL(documentSchema.toSurrealQL());
```

The `VectorType.f32(768, normalized: true)` specifies:
- Format: Float32 (4 bytes per dimension)
- Dimensions: 768 (common for many AI models)
- Normalized: Vectors should be unit length

#### Storing Records with Vectors

```dart
// Create vector embedding (from your AI model)
final embedding = VectorValue.f32([
  0.123, 0.456, 0.789, // ... 768 dimensions total
]);

// Ensure vector is normalized if required by schema
final normalizedEmbedding = embedding.normalize();

// Store document with embedding
final document = await db.createQL('documents', {
  'title': 'Machine Learning Basics',
  'content': 'Introduction to neural networks and deep learning...',
  'embedding': normalizedEmbedding.toJson(), // Converts to JSON array
  'category': 'AI',
});

print('Stored document: ${document['id']}');
```

#### Retrieving Vectors from Database

```dart
// Get a specific document
final doc = await db.get<Map<String, dynamic>>('documents:abc123');

if (doc != null) {
  // Extract vector from record
  final embeddingData = doc['embedding'] as List;
  final vector = VectorValue.fromJson(embeddingData);

  print('Title: ${doc['title']}');
  print('Vector dimensions: ${vector.dimensions}');
  print('Is normalized: ${vector.isNormalized()}');
}

// Query all documents
final allDocs = await db.selectQL('documents');
for (final doc in allDocs) {
  final embedding = VectorValue.fromJson(doc['embedding']);
  print('${doc['title']}: ${embedding.dimensions} dimensions');
}
```

#### Batch Insert with Vectors

```dart
// Prepare multiple embeddings
final embeddings = [
  VectorValue.f32([...]).normalize(),
  VectorValue.f32([...]).normalize(),
  VectorValue.f32([...]).normalize(),
];

// Set as parameters
await db.set('emb1', embeddings[0].toJson());
await db.set('emb2', embeddings[1].toJson());
await db.set('emb3', embeddings[2].toJson());

// Batch insert
final response = await db.queryQL('''
  INSERT INTO documents [
    {
      title: "Doc 1",
      content: "First document",
      embedding: \$emb1
    },
    {
      title: "Doc 2",
      content: "Second document",
      embedding: \$emb2
    },
    {
      title: "Doc 3",
      content: "Third document",
      embedding: \$emb3
    }
  ]
''');

print('Inserted ${response.getResults().length} documents');
```

---

### Similarity Search API

SurrealDartBprovides high-level methods for vector similarity search, enabling you to find the most similar records to a query vector.

#### Basic Similarity Search

```dart
// Create query vector (from user's search query)
final queryVector = VectorValue.f32([
  0.456, 0.123, 0.789, // ... 768 dimensions
]).normalize();

// Search for similar documents
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

// Process results
print('Found ${results.length} similar documents:\n');
for (final result in results) {
  print('Title: ${result.record['title']}');
  print('Distance: ${result.distance}');
  print('Category: ${result.record['category']}');
  print('---');
}
```

The `searchSimilar` method:
- Returns results ordered by distance (closest first)
- Each result contains the full record and its distance
- Automatically handles vector serialization
- Supports multiple distance metrics

#### Similarity Search with Filtering

Combine similarity search with WHERE conditions to filter results:

```dart
// Search only in active, published documents
final results = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 5,
  where: AndCondition([
    EqualsCondition('status', 'active'),
    EqualsCondition('published', true),
  ]),
);

print('Found ${results.length} active articles');
```

Common filtering patterns:

```dart
// Filter by category
final techArticles = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: EqualsCondition('category', 'technology'),
);

// Filter by date range
final recentArticles = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: AndCondition([
    GreaterThanCondition('published_at', '2024-01-01'),
    LessThanCondition('published_at', '2024-12-31'),
  ]),
);

// Complex filtering
final filtered = await db.searchSimilar(
  table: 'products',
  field: 'description_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 20,
  where: AndCondition([
    EqualsCondition('in_stock', true),
    GreaterThanCondition('price', 10.0),
    LessThanCondition('price', 100.0),
    InCondition('brand', ['BrandA', 'BrandB', 'BrandC']),
  ]),
);
```

#### Working with Similarity Results

```dart
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

for (final result in results) {
  // Access the full record
  final title = result.record['title'];
  final content = result.record['content'];
  final id = result.record['id'];

  // Access the distance/similarity score
  final distance = result.distance;

  // Convert distance to similarity percentage
  // For cosine: higher is more similar (0 to 1)
  final similarity = (distance * 100).toStringAsFixed(1);

  print('$title: $similarity% similar');
  print('ID: $id');
  print('---');
}

// Find the most similar result
if (results.isNotEmpty) {
  final best = results.first;
  print('Most similar: ${best.record['title']}');
  print('Distance: ${best.distance}');
}

// Filter results by similarity threshold
final highSimilarity = results.where((r) => r.distance > 0.8).toList();
print('${highSimilarity.length} documents with >80% similarity');
```

#### Distance Metrics Comparison

Different metrics are suitable for different use cases:

```dart
// Cosine similarity - Best for text embeddings
final cosineResults = await db.searchSimilar(
  table: 'documents',
  field: 'text_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

// Euclidean distance - General purpose
final euclideanResults = await db.searchSimilar(
  table: 'images',
  field: 'image_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 10,
);

// Manhattan distance - High-dimensional spaces
final manhattanResults = await db.searchSimilar(
  table: 'features',
  field: 'feature_vector',
  queryVector: queryVector,
  metric: DistanceMetric.manhattan,
  limit: 10,
);

// Minkowski distance - Specialized applications
final minkowskiResults = await db.searchSimilar(
  table: 'data',
  field: 'vector',
  queryVector: queryVector,
  metric: DistanceMetric.minkowski,
  limit: 10,
);
```

**Metric Selection Guide:**
- **Cosine**: Text embeddings, semantic search, NLP tasks
- **Euclidean**: General similarity, image embeddings, when magnitude matters
- **Manhattan**: High dimensions, sparse vectors, outlier robustness
- **Minkowski**: Specialized ML applications

---

### Batch Similarity Search

Search with multiple query vectors simultaneously:

```dart
// Prepare multiple query vectors
final queryVectors = [
  VectorValue.f32([...]), // Query 1
  VectorValue.f32([...]), // Query 2
  VectorValue.f32([...]), // Query 3
];

// Perform batch search
final results = await db.batchSearchSimilar(
  table: 'products',
  field: 'embedding',
  queryVectors: queryVectors,
  metric: DistanceMetric.cosine,
  limit: 5,
);

// Results are mapped by input index
for (var i = 0; i < queryVectors.length; i++) {
  print('Results for query vector $i:');
  final queryResults = results[i]!;

  for (final result in queryResults) {
    print('  - ${result.record['name']}: ${result.distance}');
  }
  print('');
}
```

**Use cases for batch search:**
- Compare multiple items against catalog
- Multi-query recommendation systems
- Parallel search operations
- A/B testing different embeddings

---

### Vector Index Creation

To optimize similarity search performance, create vector indexes on your embedding fields. SurrealDartBprovides the `IndexDefinition` class to define and manage vector indexes.

#### Index Types

SurrealDB supports three types of vector indexes:

- **FLAT**: Exhaustive search, best for small datasets (<1000 vectors)
- **MTREE**: Balanced tree structure, good for medium datasets (1K-100K vectors)
- **HNSW**: Hierarchical graph, best for large datasets (>100K vectors)
- **AUTO**: Automatically selects the best index type based on dataset size

#### Creating a Vector Index

```dart
// Define a vector index
final index = IndexDefinition(
  indexName: 'idx_documents_embedding',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 768,
  indexType: IndexType.mtree,
  capacity: 40, // MTREE-specific parameter
);

// Create the index in database
await db.queryQL(index.toSurrealQL());
print('Vector index created');
```

#### HNSW Index with Parameters

HNSW (Hierarchical Navigable Small World) is the most advanced index type:

```dart
final hnswIndex = IndexDefinition(
  indexName: 'idx_large_embeddings',
  tableName: 'articles',
  fieldName: 'content_embedding',
  distanceMetric: DistanceMetric.euclidean,
  dimensions: 1536,
  indexType: IndexType.hnsw,
  m: 16,        // Max connections per node (4-64)
  efc: 200,     // Construction candidate list size (100-400)
);

await db.queryQL(hnswIndex.toSurrealQL());
```

**HNSW Parameters:**
- **M**: Maximum connections per node. Higher values = better recall, more memory
- **EFC**: Construction candidate list size. Higher values = better quality, slower build

#### Auto Index Selection

Let the system choose the best index type:

```dart
final autoIndex = IndexDefinition(
  indexName: 'idx_auto',
  tableName: 'vectors',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 384,
  indexType: IndexType.auto,
);

// Provide dataset size hint for better selection
final ddl = autoIndex.toSurrealQL(datasetSize: 50000);
await db.queryQL(ddl);

// Index type selection:
// - < 1,000 vectors → FLAT
// - 1,000 - 100,000 vectors → MTREE
// - > 100,000 vectors → HNSW
```

#### Index for Different Dimensions

Common embedding dimensions:

```dart
// MiniLM sentence transformer (384 dimensions)
final miniLmIndex = IndexDefinition(
  indexName: 'idx_minilm',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 384,
  indexType: IndexType.mtree,
);

// BERT-base embeddings (768 dimensions)
final bertIndex = IndexDefinition(
  indexName: 'idx_bert',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 768,
  indexType: IndexType.hnsw,
  m: 16,
  efc: 200,
);

// OpenAI ada-002 embeddings (1536 dimensions)
final openaiIndex = IndexDefinition(
  indexName: 'idx_openai',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 1536,
  indexType: IndexType.hnsw,
  m: 16,
  efc: 200,
);
```

---

### Performance Optimization

#### Automatic JSON vs Binary Serialization

SurrealDartBautomatically chooses the optimal serialization format based on vector size:

```dart
// Small vectors (≤100 dimensions) use JSON
final smallVector = VectorValue.f32(List.filled(50, 1.0));
final jsonData = smallVector.toBinaryOrJson(); // Returns List (JSON)
print('Small vector uses JSON: ${jsonData is List}'); // true

// Large vectors (>100 dimensions) use binary
final largeVector = VectorValue.f32(List.filled(768, 1.0));
final binaryData = largeVector.toBinaryOrJson(); // Returns Uint8List (binary)
print('Large vector uses binary: ${binaryData is Uint8List}'); // true
```

**Performance Comparison:**

| Dimensions | JSON Time | Binary Time | Speedup |
|------------|-----------|-------------|---------|
| 50         | 0.05ms    | 0.04ms      | 1.25x   |
| 100        | 0.10ms    | 0.07ms      | 1.43x   |
| 384        | 0.35ms    | 0.12ms      | 2.92x   |
| 768        | 0.70ms    | 0.24ms      | 2.92x   |
| 1536       | 1.40ms    | 0.48ms      | 2.92x   |

**Benefits of Binary Serialization:**
- 2.92x faster for typical embedding sizes (384-1536 dims)
- Less memory overhead during transfer
- More efficient for FFI communication
- Automatic selection requires no code changes

#### Configuring the Threshold

You can adjust when binary serialization is used:

```dart
// Default threshold is 100 dimensions
print('Current threshold: ${VectorValue.serializationThreshold}'); // 100

// Increase threshold to favor JSON (easier debugging)
VectorValue.serializationThreshold = 200;

// Decrease threshold to favor binary (better performance)
VectorValue.serializationThreshold = 50;
```

#### Manual Serialization Control

For fine-grained control, use explicit serialization methods:

```dart
final vector = VectorValue.f32(List.filled(768, 1.0));

// Always use JSON
final jsonData = vector.toJson();
print('JSON size: ${jsonData.length} elements');

// Always use binary
final binaryData = vector.toBytes();
print('Binary size: ${binaryData.length} bytes');

// Use automatic selection
final autoData = vector.toBinaryOrJson();
```

#### Best Practices

1. **Use Normalized Vectors for Cosine Similarity**
   ```dart
   final embedding = getEmbeddingFromModel(); // From AI model
   final normalized = embedding.normalize();
   await db.createQL('documents', {
     'embedding': normalized.toJson(),
   });
   ```

2. **Create Indexes Before Bulk Insert**
   ```dart
   // Create index first
   await db.queryQL(index.toSurrealQL());

   // Then insert vectors
   for (final doc in documents) {
     await db.createQL('documents', doc);
   }
   ```

3. **Choose Appropriate Vector Format**
   ```dart
   // F32 for most AI models (good balance)
   final embedding = VectorValue.f32(modelOutput);

   // I16 for memory-constrained devices
   final quantized = VectorValue.i16(quantizedModelOutput);
   ```

4. **Batch Operations When Possible**
   ```dart
   // Use batch search instead of individual searches
   final results = await db.batchSearchSimilar(
     table: 'documents',
     field: 'embedding',
     queryVectors: multipleQueries,
     metric: DistanceMetric.cosine,
     limit: 10,
   );
   ```

---

### Complete Semantic Search Example

Here's a complete example of building a semantic document search system:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // 1. Connect to database
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: '/path/to/database',
    namespace: 'search_app',
    database: 'documents',
  );

  try {
    // 2. Define schema with vector field
    final schema = TableStructure('documents', {
      'title': FieldDefinition(StringType(), optional: false),
      'content': FieldDefinition(StringType(), optional: false),
      'embedding': FieldDefinition(
        VectorType.f32(384, normalized: true), // MiniLM embeddings
        optional: false,
      ),
      'category': FieldDefinition(StringType(), optional: false),
      'published_at': FieldDefinition(DatetimeType(), optional: false),
    });

    await db.queryQL(schema.toSurrealQL());
    print('✓ Schema created');

    // 3. Create vector index for fast similarity search
    final index = IndexDefinition(
      indexName: 'idx_documents_embedding',
      tableName: 'documents',
      fieldName: 'embedding',
      distanceMetric: DistanceMetric.cosine,
      dimensions: 384,
      indexType: IndexType.auto, // Auto-select based on data size
    );

    await db.queryQL(index.toSurrealQL());
    print('✓ Vector index created');

    // 4. Index documents with embeddings
    // In production, embeddings come from an AI model like:
    // - Sentence transformers (sentence-transformers/all-MiniLM-L6-v2)
    // - OpenAI embeddings API
    // - Google Universal Sentence Encoder
    final documents = [
      {
        'title': 'Introduction to Machine Learning',
        'content': 'Machine learning is a subset of AI...',
        'category': 'technology',
        'embedding': await getEmbedding('Machine learning is a subset of AI...'),
      },
      {
        'title': 'Cooking Italian Pasta',
        'content': 'Learn how to make authentic Italian pasta...',
        'category': 'food',
        'embedding': await getEmbedding('Learn how to make authentic Italian pasta...'),
      },
      {
        'title': 'Deep Learning Fundamentals',
        'content': 'Neural networks and deep learning architectures...',
        'category': 'technology',
        'embedding': await getEmbedding('Neural networks and deep learning architectures...'),
      },
    ];

    for (final doc in documents) {
      await db.createQL('documents', doc);
      print('✓ Indexed: ${doc['title']}');
    }

    // 5. Perform semantic search
    print('\n--- Searching for: "AI and neural networks" ---');

    final queryText = 'AI and neural networks';
    final queryEmbedding = await getEmbedding(queryText);

    final results = await db.searchSimilar(
      table: 'documents',
      field: 'embedding',
      queryVector: queryEmbedding,
      metric: DistanceMetric.cosine,
      limit: 3,
    );

    // 6. Display results
    print('\nSearch Results:');
    print('─────────────────────────────────────────');
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final similarity = (result.distance * 100).toStringAsFixed(1);

      print('\n${i + 1}. ${result.record['title']}');
      print('   Category: ${result.record['category']}');
      print('   Similarity: $similarity%');
      print('   Preview: ${result.record['content'].substring(0, 50)}...');
    }

    // 7. Search with filtering
    print('\n--- Filtering by category: technology ---');

    final techResults = await db.searchSimilar(
      table: 'documents',
      field: 'embedding',
      queryVector: queryEmbedding,
      metric: DistanceMetric.cosine,
      limit: 10,
      where: EqualsCondition('category', 'technology'),
    );

    print('Found ${techResults.length} technology documents');
    for (final result in techResults) {
      print('  • ${result.record['title']}');
    }

  } finally {
    await db.close();
    print('\n✓ Database closed');
  }
}

// Mock function - In production, use a real embedding model
Future<VectorValue> getEmbedding(String text) async {
  // This would call your embedding model:
  // - Local: sentence-transformers model
  // - API: OpenAI, Cohere, etc.

  // For demo, return random normalized vector
  final values = List.generate(384, (i) => (i * 0.001) % 1.0);
  return VectorValue.f32(values).normalize();
}
```

**Expected Output:**
```
✓ Schema created
✓ Vector index created
✓ Indexed: Introduction to Machine Learning
✓ Indexed: Cooking Italian Pasta
✓ Indexed: Deep Learning Fundamentals

--- Searching for: "AI and neural networks" ---

Search Results:
─────────────────────────────────────────

1. Deep Learning Fundamentals
   Category: technology
   Similarity: 94.5%
   Preview: Neural networks and deep learning architectures...

2. Introduction to Machine Learning
   Category: technology
   Similarity: 89.2%
   Preview: Machine learning is a subset of AI...

3. Cooking Italian Pasta
   Category: food
   Similarity: 12.3%
   Preview: Learn how to make authentic Italian pasta...

--- Filtering by category: technology ---
Found 2 technology documents
  • Deep Learning Fundamentals
  • Introduction to Machine Learning

✓ Database closed
```

---

### Real-World Integration Examples

#### RAG (Retrieval-Augmented Generation)

```dart
// Build a RAG system for AI chatbots
Future<String> answerQuestion(String question) async {
  // 1. Convert question to embedding
  final queryEmbedding = await getEmbedding(question);

  // 2. Search knowledge base
  final results = await db.searchSimilar(
    table: 'knowledge_base',
    field: 'embedding',
    queryVector: queryEmbedding,
    metric: DistanceMetric.cosine,
    limit: 3, // Top 3 most relevant documents
  );

  // 3. Build context from results
  final context = results
      .map((r) => r.record['content'])
      .join('\n\n');

  // 4. Send to LLM with context
  final prompt = '''
Context:
$context

Question: $question

Answer:''';

  return await callLLM(prompt);
}
```

#### Recommendation System

```dart
// Recommend similar products
Future<List<Map<String, dynamic>>> recommendSimilar(String productId) async {
  // 1. Get the product's embedding
  final product = await db.get<Map<String, dynamic>>('products:$productId');
  if (product == null) return [];

  final productEmbedding = VectorValue.fromJson(product['embedding']);

  // 2. Find similar products
  final similar = await db.searchSimilar(
    table: 'products',
    field: 'embedding',
    queryVector: productEmbedding,
    metric: DistanceMetric.cosine,
    limit: 6, // Get 6 (will exclude self later)
    where: AndCondition([
      EqualsCondition('in_stock', true),
      GreaterThanCondition('rating', 4.0),
    ]),
  );

  // 3. Remove the original product and return recommendations
  return similar
      .where((r) => r.record['id'] != productId)
      .take(5)
      .map((r) => r.record)
      .toList();
}
```

#### Duplicate Detection

```dart
// Find duplicate or near-duplicate content
Future<List<String>> findDuplicates(String newContent) async {
  // 1. Generate embedding for new content
  final embedding = await getEmbedding(newContent);

  // 2. Search for very similar content (>95% similarity)
  final results = await db.searchSimilar(
    table: 'articles',
    field: 'content_embedding',
    queryVector: embedding,
    metric: DistanceMetric.cosine,
    limit: 10,
  );

  // 3. Filter by high similarity threshold
  final duplicates = results
      .where((r) => r.distance > 0.95)
      .map((r) => r.record['id'] as String)
      .toList();

  if (duplicates.isNotEmpty) {
    print('⚠ Found ${duplicates.length} potential duplicates');
  }

  return duplicates;
}
```

---

### Troubleshooting

#### Common Issues

**1. Dimension Mismatch**
```dart
// Error: Vector dimensions don't match index
try {
  await db.searchSimilar(
    table: 'documents',
    field: 'embedding',
    queryVector: VectorValue.f32([1.0, 2.0]), // 2D
    metric: DistanceMetric.cosine,
    limit: 10,
  );
} catch (e) {
  print('Dimension mismatch: $e');
  // Fix: Ensure query vector matches indexed dimension
}
```

**2. Zero Vector Error**
```dart
// Error: Cannot normalize or compute cosine with zero vectors
final zero = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  zero.normalize(); // Throws StateError
} catch (e) {
  print('Cannot normalize zero vector');
}
```

**3. Empty Vector**
```dart
// Error: Cannot create empty vectors
try {
  final empty = VectorValue.f32([]); // Throws ArgumentError
} catch (e) {
  print('Vector cannot be empty');
}
```

**4. NaN or Infinity**
```dart
// Error: Invalid values in vector
try {
  final invalid = VectorValue.f32([1.0, double.nan, 3.0]);
} catch (e) {
  print('Vector contains NaN');
}
```

#### Performance Tips

1. **Create indexes before bulk inserts**
2. **Use normalized vectors for cosine similarity**
3. **Choose appropriate vector format (F32 vs I16 vs I8)**
4. **Adjust serialization threshold based on use case**
5. **Use batch operations for multiple queries**
6. **Filter results with WHERE clauses to reduce search space**

---

### Next Steps

Now that you understand vector operations and similarity search, you can:

1. **Integrate AI Models**: Connect embedding models (OpenAI, sentence-transformers, etc.)
2. **Build Search Systems**: Create semantic search, recommendations, and RAG systems
3. **Optimize Performance**: Tune indexes, serialization, and query strategies
4. **Scale Your Application**: Handle large vector datasets efficiently

For more examples, see the `example/scenarios/vector_embeddings.dart` file in the repository.
