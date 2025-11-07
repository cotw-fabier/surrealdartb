[← Back to Documentation Index](README.md)

# Getting Started & Database Initialization

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


---

## Navigation

[← Back to Index](README.md) | [Next: Basic QL Functions Usage →](02-basic-operations.md)

