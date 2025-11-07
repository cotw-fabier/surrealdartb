[← Back to Documentation Index](README.md)

# Type-Safe Data with Code Generator

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

---

## Navigation

[← Previous: Schema Definition](03-schema-definition.md) | [Back to Index](README.md) | [Next: Vector Operations →](05-vector-operations.md)

