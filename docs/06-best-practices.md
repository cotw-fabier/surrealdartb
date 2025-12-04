[← Back to Documentation Index](README.md)

# Best Practices Guide

This guide provides a comprehensive, self-contained reference for building applications with SurrealDartB using best practices. It emphasizes the ORM-first approach with type-safe models, code generation, and validated queries.

## Philosophy: ORM-First Development

SurrealDartB offers two ways to interact with the database:

1. **ORM Layer** (Recommended): Type-safe models with decorators, generated code, and query builders
2. **QL Methods**: Direct SurrealQL execution with maps and strings

**This guide focuses on the ORM approach** because it provides:

- **Compile-time safety**: Catch errors before runtime
- **IDE autocomplete**: Discover available fields and methods
- **Automatic validation**: Enforce constraints at the Dart level
- **Cleaner code**: Less boilerplate, more readable
- **Refactoring support**: Rename fields with confidence

The QL methods (`createQL`, `selectQL`, `queryQL`, etc.) remain available for edge cases like complex raw queries, but the ORM layer should be your default choice for typical database operations.

---

## Project Setup

### Dependencies

Add SurrealDartB and the code generator to your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^0.0.4
  path_provider: ^2.1.0  # For Flutter apps

dev_dependencies:
  build_runner: ^2.4.0
```

Run `dart pub get` (or `flutter pub get` for Flutter projects) to install dependencies.

### Build Configuration

Create a `build.yaml` file in your project root to configure code generation:

```yaml
targets:
  $default:
    builders:
      surrealdartb|surreal_table_builder:
        enabled: true
        generate_for:
          - lib/models/**/*.dart
```

This configuration tells the generator to process all Dart files in the `lib/models/` directory.

### Recommended Directory Structure

Organize your project with a clear separation of concerns:

```
lib/
  models/              # ORM model classes
    user.dart
    user.surreal.dart  # Generated
    post.dart
    post.surreal.dart  # Generated
    document.dart      # With vector embeddings
    document.surreal.dart
  services/            # Database service layer
    database_service.dart
  repositories/        # Optional: repository pattern
    user_repository.dart
  main.dart
```

### Flutter Setup with path_provider

For Flutter applications, use `path_provider` to get the correct database path on each platform:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:surrealdartb/surrealdartb.dart';

class DatabaseService {
  static Database? _database;
  static bool _initialized = false;

  /// Initialize the database with the correct path for the platform.
  static Future<Database> initialize() async {
    if (_initialized && _database != null) {
      return _database!;
    }

    // Get the appropriate directory for each platform
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String dbPath = '${appDir.path}/surreal_db';

    // Ensure the directory exists
    final dbDirectory = Directory(dbPath);
    if (!await dbDirectory.exists()) {
      await dbDirectory.create(recursive: true);
    }

    // Connect to the database
    _database = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath,
      namespace: 'my_app',
      database: 'production',
    );

    _initialized = true;
    return _database!;
  }

  /// Get the database instance (must call initialize first).
  static Database get db {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  /// Close the database connection.
  static Future<void> close() async {
    await _database?.close();
    _database = null;
    _initialized = false;
  }
}
```

**Platform-specific paths:**
- **iOS/macOS**: `~/Library/Application Support/<app>/surreal_db`
- **Android**: `/data/data/<package>/files/surreal_db`
- **Windows**: `C:\Users\<user>\AppData\Roaming\<app>\surreal_db`
- **Linux**: `~/.local/share/<app>/surreal_db`

### Dart CLI Setup

For command-line applications, you can use a direct path:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<Database> initializeDatabase() async {
  return Database.connect(
    backend: StorageBackend.rocksdb,
    path: './data/surreal_db',
    namespace: 'my_app',
    database: 'main',
  );
}
```

### In-Memory Database for Testing

For unit tests, use the memory backend:

```dart
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);
```

---

## Model Definition Best Practices

### Complete Model Template

Here's a well-structured model following all best practices:

```dart
import 'package:surrealdartb/surrealdartb.dart';

part 'user.surreal.dart';  // Required for code generation

@SurrealTable('users')
class User {
  // 1. ID field - always nullable, placed at top
  @SurrealId()
  String? id;

  // 2. Required fields with types
  @SurrealField(type: StringType())
  final String name;

  // 3. Fields with validation constraints
  @SurrealField(
    type: NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 18',
  )
  final int age;

  // 4. Indexed fields for fast lookups
  @SurrealField(
    type: StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  )
  final String email;

  // 5. Fields with default values
  @SurrealField(
    type: StringType(),
    defaultValue: 'active',
  )
  final String status;

  // 6. DateTime fields
  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  // 7. Optional fields
  @SurrealField(type: DatetimeType(), optional: true)
  DateTime? updatedAt;

  // 8. Relationships
  @SurrealRecord()
  Profile? profile;

  @SurrealRecord()
  List<Post>? posts;

  // Constructor
  User({
    this.id,
    required this.name,
    required this.age,
    required this.email,
    this.status = 'active',
    DateTime? createdAt,
    this.updatedAt,
    this.profile,
    this.posts,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

### Naming Conventions

**Table Names (@SurrealTable):**
- Use lowercase, plural names: `'users'`, `'posts'`, `'order_items'`
- Separate words with underscores
- Match the Dart class name to the table (User → users)

**Field Names:**
- Use camelCase in Dart, which maps to the database automatically
- Avoid reserved words

### @SurrealId Best Practices

```dart
// CORRECT: Nullable, at top of class
@SurrealId()
String? id;

// WRONG: Non-nullable will cause issues on create
@SurrealId()
String id;  // Don't do this!
```

The ID is assigned by SurrealDB when the record is created, so it must be nullable in your model.

### Field Types Reference

```dart
// String
@SurrealField(type: StringType())
final String name;

// Integer
@SurrealField(type: NumberType(format: NumberFormat.integer))
final int age;

// Float
@SurrealField(type: NumberType(format: NumberFormat.floating))
final double temperature;

// Decimal (precise, for monetary values)
@SurrealField(type: NumberType(format: NumberFormat.decimal))
final double price;

// Boolean
@SurrealField(type: BoolType())
final bool isActive;

// DateTime
@SurrealField(type: DatetimeType())
final DateTime createdAt;

// Duration
@SurrealField(type: DurationType())
final Duration sessionTime;

// Array
@SurrealField(type: ArrayType(StringType()))
final List<String> tags;

// Fixed-length array
@SurrealField(type: ArrayType(NumberType(), length: 3))
final List<int> rgb;

// Object (schemaless)
@SurrealField(type: ObjectType())
@JsonField()
final Map<String, dynamic> metadata;

// Object with schema
@SurrealField(type: ObjectType(schema: {
  'street': FieldDefinition(StringType()),
  'city': FieldDefinition(StringType()),
  'zipCode': FieldDefinition(StringType()),
}))
@JsonField()
final Map<String, dynamic> address;

// Record reference
@SurrealField(type: RecordType(table: 'users'))
final String authorId;

// Vector (for AI embeddings)
@SurrealField(type: VectorType.f32(768, normalized: true))
final List<double> embedding;
```

### Common Validation Patterns

```dart
// Email validation
@SurrealField(
  type: StringType(),
  assertClause: r'string::is::email($value)',
)
final String email;

// Age range
@SurrealField(
  type: NumberType(format: NumberFormat.integer),
  assertClause: r'$value >= 0 AND $value <= 150',
)
final int age;

// Minimum length
@SurrealField(
  type: StringType(),
  assertClause: r'string::len($value) >= 3',
)
final String username;

// Maximum length
@SurrealField(
  type: StringType(),
  assertClause: r'string::len($value) <= 500',
)
final String bio;

// Enum-like values
@SurrealField(
  type: StringType(),
  assertClause: r"$value IN ['pending', 'active', 'suspended', 'deleted']",
)
final String status;

// URL validation
@SurrealField(
  type: StringType(),
  assertClause: r'string::is::url($value)',
)
final String website;

// Positive number
@SurrealField(
  type: NumberType(format: NumberFormat.decimal),
  assertClause: r'$value > 0',
)
final double price;

// Percentage
@SurrealField(
  type: NumberType(format: NumberFormat.floating),
  assertClause: r'$value >= 0 AND $value <= 100',
)
final double percentage;
```

---

## Relationship Definitions

### One-to-One Relationships

Use `@SurrealRecord()` with a single nullable object:

```dart
@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  // One-to-one: User has one Profile
  @SurrealRecord()
  Profile? profile;

  User({this.id, required this.name, this.profile});
}

@SurrealTable('profiles')
class Profile {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType(), optional: true)
  String? bio;

  @SurrealField(type: StringType(), optional: true)
  String? avatarUrl;

  Profile({this.id, this.bio, this.avatarUrl});
}
```

### One-to-Many Relationships

Use `@SurrealRecord()` with a list:

```dart
@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  // One-to-many: User has many Posts
  @SurrealRecord()
  List<Post>? posts;

  User({this.id, required this.name, this.posts});
}

@SurrealTable('posts')
class Post {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String title;

  @SurrealField(type: StringType())
  final String content;

  // Reverse relationship: Post belongs to User
  @SurrealRecord()
  User? author;

  Post({this.id, required this.title, required this.content, this.author});
}
```

### Graph Relationships

Use `@SurrealRelation()` for graph traversals:

```dart
@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  // Outgoing: Posts this user likes
  @SurrealRelation(name: 'likes', direction: RelationDirection.out)
  List<Post>? likedPosts;

  // Bidirectional: Users this user is connected to
  @SurrealRelation(
    name: 'follows',
    direction: RelationDirection.both,
    targetTable: 'users',
  )
  List<User>? connections;

  User({this.id, required this.name, this.likedPosts, this.connections});
}
```

### Many-to-Many with Edge Metadata

Use `@SurrealEdge()` when you need to store data on the relationship:

```dart
@SurrealEdge('user_projects')
class UserProjectEdge {
  // Source record
  @SurrealRecord()
  final User user;

  // Target record
  @SurrealRecord()
  final Project project;

  // Metadata on the relationship
  @SurrealField(type: StringType())
  final String role;

  @SurrealField(type: DatetimeType())
  final DateTime joinedAt;

  UserProjectEdge({
    required this.user,
    required this.project,
    required this.role,
    required this.joinedAt,
  });
}
```

---

## Code Generation Workflow

### Running the Generator

After defining your models, generate the ORM code:

```bash
# One-time generation
dart run build_runner build

# Watch mode (regenerates on file changes)
dart run build_runner watch

# Clean and rebuild (when you have issues)
dart run build_runner build --delete-conflicting-outputs
```

### Part File Pattern

Every model file must include the part directive:

```dart
import 'package:surrealdartb/surrealdartb.dart';

part 'user.surreal.dart';  // This line is required!

@SurrealTable('users')
class User {
  // ...
}
```

The generated file (`user.surreal.dart`) will contain:
- `UserORM` extension with `toSurrealMap()`, `fromSurrealMap()`, `validate()`
- `UserQueryBuilder` for type-safe queries
- `UserWhereBuilder` for complex where clauses
- Static helpers for table metadata

### What Gets Generated

For a model named `User`, the generator creates:

```dart
// Extension on User class
extension UserORM on User {
  // Serialize to database format
  Map<String, dynamic> toSurrealMap();

  // Deserialize from database
  static User fromSurrealMap(Map<String, dynamic> map);

  // Validate against schema
  void validate();

  // Access record ID
  String? get recordId => id;

  // Static table info
  static String get tableName => 'users';
  static TableStructure get tableStructure => userTableDefinition;

  // Create query builder
  static UserQueryBuilder createQueryBuilder(Database db);
}

// Type-safe query builder
class UserQueryBuilder {
  UserQueryBuilder where(WhereCondition Function(UserWhereBuilder) builder);
  UserQueryBuilder limit(int count);
  UserQueryBuilder offset(int count);
  UserQueryBuilder orderBy(String field, {bool ascending = true});
  Future<List<User>> execute();
  Future<User?> first();
}

// Type-safe where builder
class UserWhereBuilder {
  StringFieldCondition get name => StringFieldCondition('name');
  NumberFieldCondition<int> get age => NumberFieldCondition<int>('age');
  StringFieldCondition get email => StringFieldCondition('email');
  StringFieldCondition get status => StringFieldCondition('status');
  // ...
}
```

---

## Type-Safe Queries

### Basic Query Pattern

Use the generated query builder for type-safe database queries:

```dart
// Get all users
final allUsers = await db.query<User>().execute();

// Get with a simple condition
final activeUsers = await db.query<User>()
  .where((t) => t.status.equals('active'))
  .execute();

// Get single result
final user = await db.query<User>()
  .where((t) => t.email.equals('alice@example.com'))
  .first();
```

### String Field Operators

```dart
.where((t) => t.name.equals('Alice'))           // name = 'Alice'
.where((t) => t.name.contains('lic'))           // name CONTAINS 'lic'
.where((t) => t.name.startsWith('Al'))          // name starts with 'Al'
.where((t) => t.name.endsWith('ce'))            // name ends with 'ce'
.where((t) => t.name.ilike('%alice%'))          // case-insensitive match
.where((t) => t.role.inList(['admin', 'mod']))  // role IN ['admin', 'mod']
```

### Number Field Operators

```dart
.where((t) => t.age.equals(25))                 // age = 25
.where((t) => t.age.greaterThan(18))            // age > 18
.where((t) => t.age.lessThan(65))               // age < 65
.where((t) => t.age.greaterOrEqual(18))         // age >= 18
.where((t) => t.age.lessOrEqual(65))            // age <= 65
.where((t) => t.age.between(18, 65))            // age >= 18 AND age <= 65
.where((t) => t.score.inList([100, 200, 300]))  // score IN [100, 200, 300]
```

### Boolean Field Operators

```dart
.where((t) => t.verified.isTrue())              // verified = true
.where((t) => t.deleted.isFalse())              // deleted = false
.where((t) => t.active.equals(true))            // active = true
```

### DateTime Field Operators

```dart
final now = DateTime.now();
final yesterday = now.subtract(Duration(days: 1));
final tomorrow = now.add(Duration(days: 1));

.where((t) => t.createdAt.equals(now))          // exact match
.where((t) => t.createdAt.before(tomorrow))     // createdAt < tomorrow
.where((t) => t.createdAt.after(yesterday))     // createdAt > yesterday
.where((t) => t.createdAt.between(yesterday, tomorrow))
```

### Combining Conditions

Use `&` for AND and `|` for OR:

```dart
// AND: Active users over 18
final adults = await db.query<User>()
  .where((t) => t.status.equals('active') & t.age.greaterThan(18))
  .execute();

// OR: Admins or moderators
final privileged = await db.query<User>()
  .where((t) => t.role.equals('admin') | t.role.equals('moderator'))
  .execute();

// Complex: Active users who are young OR senior
final results = await db.query<User>()
  .where((t) =>
    (t.age.lessThan(30) | t.age.greaterThan(60)) &
    t.status.equals('active')
  )
  .execute();
```

### Ordering and Pagination

```dart
// Order by name ascending
final sorted = await db.query<User>()
  .orderBy('name', ascending: true)
  .execute();

// Order by age descending
final oldest = await db.query<User>()
  .orderBy('age', ascending: false)
  .execute();

// Pagination: page 2, 10 items per page
final page2 = await db.query<User>()
  .orderBy('createdAt', ascending: false)
  .limit(10)
  .offset(10)
  .execute();
```

### Getting a Single Result

Use `.first()` to get the first matching result or null:

```dart
final user = await db.query<User>()
  .where((t) => t.email.equals('alice@example.com'))
  .first();

if (user != null) {
  print('Found user: ${user.name}');
} else {
  print('User not found');
}
```

---

## Relationship Loading

### Simple Includes

Use FETCH to load related records:

```dart
// Query with relationships loaded
final response = await db.queryQL('SELECT *, author.* FROM posts FETCH author');
final posts = response.getResults();

for (final post in posts) {
  final author = post['author'] as Map?;
  print('${post['title']} by ${author?['name']}');
}
```

### Filtered Includes with Correlated Subqueries

Load only specific related records using correlated subqueries:

```dart
// Get users with only their published posts
final response = await db.queryQL('''
  SELECT *,
    (SELECT * FROM posts
     WHERE author = \$parent.id AND status = 'published'
     ORDER BY createdAt DESC
     LIMIT 5) AS posts
  FROM users
  WHERE name = 'Alice'
''');
```

**Pattern for filtered includes:**
```
(SELECT * FROM <related_table>
 WHERE <foreign_key> = $parent.id AND <your_conditions>
 ORDER BY <field> [ASC|DESC]
 LIMIT <n>) AS <relationship_field>
```

### Nested Includes

Load multi-level relationships:

```dart
// Get users with their posts and each post's comments
final response = await db.queryQL('''
  SELECT *,
    (SELECT *,
       (SELECT * FROM comments WHERE post = \$parent.id LIMIT 10) AS comments
     FROM posts
     WHERE author = \$parent.id AND status = 'published'
     ORDER BY createdAt DESC) AS posts
  FROM users
''');
```

---

## Index Definition

### Field Indexes

Index frequently queried fields for better performance:

```dart
@SurrealField(
  type: StringType(),
  indexed: true,  // Creates an index on this field
)
final String email;

@SurrealField(
  type: StringType(),
  indexed: true,
)
final String username;
```

**When to index:**
- Fields used in WHERE clauses frequently
- Fields used for sorting (ORDER BY)
- Foreign key fields
- Unique identifiers like email or username

**When not to index:**
- Fields that are rarely queried
- Fields with low cardinality (few unique values)
- Fields that are updated frequently

### Vector Indexes

For AI/ML applications with vector embeddings, create specialized vector indexes:

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Define a vector index
final index = IndexDefinition(
  indexName: 'idx_documents_embedding',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 768,
  indexType: IndexType.mtree,  // Good for 1K-100K vectors
  capacity: 40,
);

// Create the index
await db.queryQL(index.toSurrealQL());
```

**Index Type Selection:**

| Dataset Size | Index Type | Use Case |
|-------------|------------|----------|
| < 1,000 | FLAT | Small datasets, exact search |
| 1K - 100K | MTREE | Medium datasets, balanced |
| > 100K | HNSW | Large datasets, approximate |

**HNSW Configuration for Large Datasets:**

```dart
final hnswIndex = IndexDefinition(
  indexName: 'idx_large_embeddings',
  tableName: 'articles',
  fieldName: 'content_embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 1536,
  indexType: IndexType.hnsw,
  m: 16,        // Max connections per node (4-64)
  efc: 200,     // Construction candidate list (100-400)
);
```

---

## Vector Operations

### Schema Pattern

Define vector fields in your models:

```dart
@SurrealTable('documents')
class Document {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String title;

  @SurrealField(type: StringType())
  final String content;

  @SurrealField(
    type: VectorType.f32(768, normalized: true),  // 768-dim normalized F32
  )
  final List<double> embedding;

  @SurrealField(type: StringType(), optional: true)
  String? category;

  Document({
    this.id,
    required this.title,
    required this.content,
    required this.embedding,
    this.category,
  });
}
```

### Creating and Normalizing Vectors

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create a vector from embedding model output
final embedding = VectorValue.f32([0.1, 0.2, 0.3, /* ... 768 dims */]);

// Normalize for cosine similarity (required!)
final normalized = embedding.normalize();

// Check if already normalized
if (!embedding.isNormalized()) {
  // Normalize before storing
}

// Store in database
await db.createQL('documents', {
  'title': 'Machine Learning Basics',
  'content': 'Introduction to neural networks...',
  'embedding': normalized.toJson(),
  'category': 'AI',
});
```

### Similarity Search Pattern

```dart
// 1. Create query vector (from user's search query)
final queryEmbedding = await getEmbeddingFromModel(userQuery);
final queryVector = VectorValue.f32(queryEmbedding).normalize();

// 2. Search for similar documents
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

// 3. Process results
for (final result in results) {
  final title = result.record['title'];
  final similarity = (result.distance * 100).toStringAsFixed(1);
  print('$title: $similarity% similar');
}
```

### Similarity Search with Filtering

```dart
// Search only in specific category
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: EqualsCondition('category', 'technology'),
);

// Complex filtering
final filtered = await db.searchSimilar(
  table: 'products',
  field: 'description_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 20,
  where: AndCondition([
    EqualsCondition('in_stock', true),
    GreaterThanCondition('price', 10.0),
    LessThanCondition('price', 100.0),
  ]),
);
```

### Distance Metric Selection

| Metric | Best For | Range |
|--------|----------|-------|
| Cosine | Text embeddings, semantic search | 0 to 1 (higher = more similar) |
| Euclidean | Image embeddings, general purpose | 0 to infinity (lower = more similar) |
| Manhattan | High-dimensional, sparse vectors | 0 to infinity (lower = more similar) |

---

## Complete Application Example

Here's a complete example showing how to structure an ORM-based application:

### Project Structure

```
lib/
  models/
    user.dart
    user.surreal.dart       # Generated
    post.dart
    post.surreal.dart       # Generated
    document.dart           # With vector embeddings
    document.surreal.dart   # Generated
  services/
    database_service.dart
  main.dart
```

### Database Service (lib/services/database_service.dart)

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:surrealdartb/surrealdartb.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../models/document.dart';

/// Singleton database service for the application.
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  /// Get the singleton instance.
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Initialize the database connection.
  Future<void> initialize() async {
    if (_database != null) return;

    // Get platform-appropriate path
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = '${appDir.path}/my_app_db';

    // Ensure directory exists
    final dir = Directory(dbPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Connect to database
    _database = await Database.connect(
      backend: StorageBackend.rocksdb,
      path: dbPath,
      namespace: 'my_app',
      database: 'production',
      tableDefinitions: [
        UserORM.tableStructure,
        PostORM.tableStructure,
        DocumentORM.tableStructure,
      ],
      autoMigrate: true,
    );

    // Create vector index if needed
    await _createVectorIndex();
  }

  Future<void> _createVectorIndex() async {
    final index = IndexDefinition(
      indexName: 'idx_document_embedding',
      tableName: 'documents',
      fieldName: 'embedding',
      distanceMetric: DistanceMetric.cosine,
      dimensions: 768,
      indexType: IndexType.auto,
    );

    try {
      await _database!.queryQL(index.toSurrealQL());
    } catch (e) {
      // Index may already exist
    }
  }

  /// Get the database instance.
  Database get db {
    if (_database == null) {
      throw StateError('Database not initialized');
    }
    return _database!;
  }

  // ==================== User Operations ====================

  /// Create a new user.
  Future<User> createUser(User user) async {
    user.validate();
    final result = await db.createQL('users', user.toSurrealMap());
    user.id = result['id'];
    return user;
  }

  /// Get user by ID.
  Future<User?> getUserById(String id) async {
    final result = await db.get<Map<String, dynamic>>(id);
    if (result == null) return null;
    return UserORM.fromSurrealMap(result);
  }

  /// Get user by email.
  Future<User?> getUserByEmail(String email) async {
    return db.query<User>()
      .where((t) => t.email.equals(email))
      .first();
  }

  /// Get all active users.
  Future<List<User>> getActiveUsers({int limit = 50, int offset = 0}) async {
    return db.query<User>()
      .where((t) => t.status.equals('active'))
      .orderBy('createdAt', ascending: false)
      .limit(limit)
      .offset(offset)
      .execute();
  }

  /// Update user.
  Future<User> updateUser(User user) async {
    if (user.id == null) {
      throw ArgumentError('User must have an ID to update');
    }
    user.validate();
    await db.updateQL(user.id!, user.toSurrealMap());
    return user;
  }

  /// Delete user.
  Future<void> deleteUser(String id) async {
    await db.deleteQL(id);
  }

  // ==================== Post Operations ====================

  /// Create a post for a user.
  Future<Post> createPost(Post post, String authorId) async {
    post.validate();
    final data = post.toSurrealMap();
    data['author'] = authorId;
    final result = await db.createQL('posts', data);
    post.id = result['id'];
    return post;
  }

  /// Get posts by author.
  Future<List<Post>> getPostsByAuthor(String authorId, {
    String? status,
    int limit = 20,
  }) async {
    var query = db.query<Post>()
      .where((t) => t.author.equals(authorId));

    if (status != null) {
      query = query.where((t) => t.status.equals(status));
    }

    return query
      .orderBy('createdAt', ascending: false)
      .limit(limit)
      .execute();
  }

  // ==================== Document Operations (Vector) ====================

  /// Create a document with embedding.
  Future<Document> createDocument(Document doc) async {
    doc.validate();
    final data = doc.toSurrealMap();

    // Ensure embedding is normalized
    final embedding = VectorValue.f32(doc.embedding);
    data['embedding'] = embedding.normalize().toJson();

    final result = await db.createQL('documents', data);
    doc.id = result['id'];
    return doc;
  }

  /// Search for similar documents.
  Future<List<SimilarityResult<Map<String, dynamic>>>> searchDocuments(
    List<double> queryEmbedding, {
    String? category,
    int limit = 10,
  }) async {
    final queryVector = VectorValue.f32(queryEmbedding).normalize();

    return db.searchSimilar(
      table: 'documents',
      field: 'embedding',
      queryVector: queryVector,
      metric: DistanceMetric.cosine,
      limit: limit,
      where: category != null ? EqualsCondition('category', category) : null,
    );
  }

  /// Close the database connection.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
```

### User Model (lib/models/user.dart)

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'post.dart';

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
    assertClause: r"$value IN ['active', 'suspended', 'deleted']",
  )
  final String status;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  @SurrealRecord()
  List<Post>? posts;

  User({
    this.id,
    required this.name,
    required this.age,
    required this.email,
    this.status = 'active',
    DateTime? createdAt,
    this.posts,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}
```

### Post Model (lib/models/post.dart)

```dart
import 'package:surrealdartb/surrealdartb.dart';
import 'user.dart';

part 'post.surreal.dart';

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
    assertClause: r"$value IN ['draft', 'published', 'archived']",
  )
  final String status;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  @SurrealField(type: DatetimeType(), optional: true)
  DateTime? publishedAt;

  @SurrealRecord()
  User? author;

  Post({
    this.id,
    required this.title,
    required this.content,
    this.status = 'draft',
    DateTime? createdAt,
    this.publishedAt,
    this.author,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

### Document Model with Vector (lib/models/document.dart)

```dart
import 'package:surrealdartb/surrealdartb.dart';

part 'document.surreal.dart';

@SurrealTable('documents')
class Document {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String title;

  @SurrealField(type: StringType())
  final String content;

  @SurrealField(type: VectorType.f32(768, normalized: true))
  final List<double> embedding;

  @SurrealField(type: StringType(), optional: true)
  String? category;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  Document({
    this.id,
    required this.title,
    required this.content,
    required this.embedding,
    this.category,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
```

### Main Application (lib/main.dart)

```dart
import 'services/database_service.dart';
import 'models/user.dart';
import 'models/post.dart';
import 'models/document.dart';

Future<void> main() async {
  final dbService = DatabaseService.instance;

  try {
    // Initialize database
    await dbService.initialize();
    print('Database initialized');

    // Create a user
    final user = User(
      name: 'Alice Johnson',
      age: 28,
      email: 'alice@example.com',
    );
    final createdUser = await dbService.createUser(user);
    print('Created user: ${createdUser.id}');

    // Create posts
    final post = Post(
      title: 'Getting Started with SurrealDB',
      content: 'Learn how to use this powerful database...',
      status: 'published',
      publishedAt: DateTime.now(),
    );
    await dbService.createPost(post, createdUser.id!);
    print('Created post');

    // Query users
    final activeUsers = await dbService.getActiveUsers(limit: 10);
    print('Found ${activeUsers.length} active users');

    // Find user by email
    final foundUser = await dbService.getUserByEmail('alice@example.com');
    if (foundUser != null) {
      print('Found user: ${foundUser.name}');
    }

    // Create document with embedding
    final embedding = List.generate(768, (i) => (i * 0.001) % 1.0);
    final doc = Document(
      title: 'AI Fundamentals',
      content: 'Introduction to machine learning concepts...',
      embedding: embedding,
      category: 'technology',
    );
    await dbService.createDocument(doc);
    print('Created document with embedding');

    // Search similar documents
    final queryEmbedding = List.generate(768, (i) => (i * 0.001) % 1.0);
    final results = await dbService.searchDocuments(
      queryEmbedding,
      category: 'technology',
      limit: 5,
    );
    print('Found ${results.length} similar documents');
    for (final result in results) {
      final similarity = (result.distance * 100).toStringAsFixed(1);
      print('  - ${result.record['title']}: $similarity% similar');
    }

  } finally {
    await dbService.close();
    print('Database closed');
  }
}
```

---

## Common Pitfalls to Avoid

### 1. Forgetting the Part Directive

```dart
// WRONG: Missing part directive
import 'package:surrealdartb/surrealdartb.dart';

@SurrealTable('users')
class User { ... }  // Will fail - no generated code

// CORRECT: Include the part directive
import 'package:surrealdartb/surrealdartb.dart';

part 'user.surreal.dart';  // Required!

@SurrealTable('users')
class User { ... }
```

### 2. Non-Nullable ID Field

```dart
// WRONG: ID should be nullable
@SurrealId()
String id;  // Causes issues on create

// CORRECT: ID is assigned by database
@SurrealId()
String? id;
```

### 3. Skipping Validation

```dart
// WRONG: No validation before save
await db.createQL('users', user.toSurrealMap());

// CORRECT: Validate first
try {
  user.validate();
  await db.createQL('users', user.toSurrealMap());
} on OrmValidationException catch (e) {
  print('Validation failed: ${e.message}');
}
```

### 4. Over-Validating with Assert Clauses

```dart
// WRONG: Too restrictive
@SurrealField(
  type: StringType(),
  assertClause: r'string::len($value) == 8',  // Exactly 8 chars
)
final String username;

// CORRECT: Reasonable constraints
@SurrealField(
  type: StringType(),
  assertClause: r'string::len($value) >= 3 AND string::len($value) <= 30',
)
final String username;
```

### 5. Using Raw QL When ORM is Available

```dart
// AVOID: Raw queries when ORM works
final result = await db.queryQL('SELECT * FROM users WHERE age > 18');

// PREFER: Type-safe query builder
final users = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .execute();
```

### 6. Not Indexing Frequently Queried Fields

```dart
// WRONG: Email queried often but not indexed
@SurrealField(type: StringType())
final String email;

// CORRECT: Index for fast lookups
@SurrealField(
  type: StringType(),
  indexed: true,
)
final String email;
```

### 7. Forgetting to Normalize Vectors

```dart
// WRONG: Storing non-normalized vectors for cosine similarity
final embedding = VectorValue.f32([0.5, 0.8, 0.3]);
await db.createQL('documents', {
  'embedding': embedding.toJson(),
});

// CORRECT: Normalize before storing
final embedding = VectorValue.f32([0.5, 0.8, 0.3]);
await db.createQL('documents', {
  'embedding': embedding.normalize().toJson(),
});
```

### 8. Not Using Filtered Includes

```dart
// WRONG: Loading all posts then filtering in Dart
final user = await db.queryQL('SELECT *, posts.* FROM users FETCH posts');
final publishedPosts = user['posts'].where((p) => p['status'] == 'published');

// CORRECT: Filter at database level
final user = await db.queryQL('''
  SELECT *,
    (SELECT * FROM posts WHERE author = \$parent.id AND status = 'published') AS posts
  FROM users
''');
```

---

## Navigation

[← Previous: Vector Operations](05-vector-operations.md) | [Back to Index](README.md)
