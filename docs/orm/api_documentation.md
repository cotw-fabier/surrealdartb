# ORM Layer API Documentation

## Overview

The SurrealDartB ORM Layer provides type-safe database operations through code generation and annotations. This document covers the **implemented foundation** (Phases 1-2) and previews the upcoming features (Phases 3-7).

## Current Implementation Status

**✅ Implemented (v1.2.0):**
- Database API method renaming
- ORM annotations
- Exception hierarchy
- Serialization code generation

**⏳ Coming Soon:**
- Type-safe CRUD operations
- Query builder with fluent API
- Where clause DSL with logical operators
- Relationship loading
- Advanced filtering

## Annotations

### @SurrealTable

Marks a class as a database table entity.

**Signature:**
```dart
@SurrealTable(String tableName)
class EntityName { ... }
```

**Parameters:**
- `tableName` (String): The database table name

**Example:**
```dart
@SurrealTable('users')
class User {
  final String id;
  final String name;
  final int age;
  
  User({required this.id, required this.name, required this.age});
}
```

**Generated Code:**
- Extension methods on the entity class
- Serialization methods (toSurrealMap, fromSurrealMap)
- Validation methods
- ID accessor

---

### @SurrealRecord

Marks a field as a record link relationship (direct reference).

**Signature:**
```dart
@SurrealRecord({String? tableName})
final Type fieldName;
```

**Parameters:**
- `tableName` (String?, optional): Explicit target table name (defaults to inferred from type)

**Example:**
```dart
@SurrealRecord()
final Profile? profile; // Single reference

@SurrealRecord(tableName: 'blog_posts')
final List<Post>? posts; // List of references
```

**Behavior:**
- Generates FETCH clauses in queries (when query builder is implemented)
- Single references: `@SurrealRecord() Type field`
- List references: `@SurrealRecord() List<Type> field`
- Non-optional relations are auto-included in queries

---

### @SurrealRelation

Marks a field as a graph traversal relationship.

**Signature:**
```dart
@SurrealRelation({
  required String name,
  required RelationDirection direction,
  String? targetTable,
})
final Type fieldName;
```

**Parameters:**
- `name` (String, required): The relation/edge name
- `direction` (RelationDirection, required): Traversal direction
- `targetTable` (String?, optional): Target table constraint

**Direction Options:**
```dart
enum RelationDirection {
  out,     // Outgoing: ->relation->
  inbound, // Incoming: <-relation<-
  both,    // Bidirectional: <->relation<->
}
```

**Example:**
```dart
@SurrealRelation(
  name: 'likes',
  direction: RelationDirection.out,
  targetTable: 'posts',
)
final List<Post> likedPosts;

@SurrealRelation(
  name: 'authored',
  direction: RelationDirection.inbound,
)
final List<Post> authoredPosts;
```

**Behavior:**
- Generates graph traversal syntax (when query builder is implemented)
- Supports filtering on traversal results
- Can constrain to specific target tables

---

### @SurrealEdge

Marks a class as an edge table definition (many-to-many with metadata).

**Signature:**
```dart
@SurrealEdge(String edgeTableName)
class EdgeClass { ... }
```

**Parameters:**
- `edgeTableName` (String): The database edge table name

**Example:**
```dart
@SurrealEdge('user_posts')
class UserPostEdge {
  @SurrealRecord()
  final User user;
  
  @SurrealRecord()
  final Post post;
  
  @SurrealField(type: StringType())
  final String role; // Edge metadata
  
  @SurrealField(type: DatetimeType())
  final DateTime createdAt; // Edge metadata
}
```

**Requirements:**
- Must have exactly two `@SurrealRecord` fields (source and target)
- Can have additional fields for edge metadata
- Generates RELATE statements (when implemented)

---

### @SurrealId

Marks a field as the record ID.

**Signature:**
```dart
@SurrealId()
final String fieldName;
```

**Example:**
```dart
class User {
  @SurrealId()
  final String userId; // Custom ID field name
  
  final String name;
}
```

**Behavior:**
- Overrides default ID field detection (which looks for field named 'id')
- Used for extracting record IDs in CRUD operations
- Generates `recordId` getter on extension

**Default Behavior (without @SurrealId):**
```dart
class User {
  final String id; // Auto-detected as ID field
  final String name;
}
```

## Generated Code

When you annotate a class with `@SurrealTable`, the code generator creates an extension with several methods:

### Extension Methods

#### toSurrealMap()

Converts the Dart object to a SurrealDB-compatible Map.

**Signature:**
```dart
Map<String, dynamic> toSurrealMap()
```

**Example:**
```dart
final user = User(id: 'users:1', name: 'Alice', age: 30);
final map = user.toSurrealMap();
// Returns: {'id': 'users:1', 'name': 'Alice', 'age': 30}
```

**Type Conversions:**
- `DateTime` → ISO 8601 string via `toIso8601String()`
- `Duration` → microseconds via `inMicroseconds`
- Primitives → direct assignment
- Nullable fields → null-safe handling

---

#### fromSurrealMap()

Creates a Dart object from a SurrealDB Map result.

**Signature:**
```dart
static EntityType fromSurrealMap(Map<String, dynamic> map)
```

**Example:**
```dart
final map = {'id': 'users:1', 'name': 'Alice', 'age': 30};
final user = UserORM.fromSurrealMap(map);
// Returns: User(id: 'users:1', name: 'Alice', age: 30)
```

**Behavior:**
- Validates all required fields are present
- Throws `OrmSerializationException` if fields are missing
- Performs type-safe casting
- Handles DateTime parsing and Duration reconstruction

---

#### validate()

Validates the object against the table schema.

**Signature:**
```dart
void validate()
```

**Example:**
```dart
final user = User(id: 'users:1', name: 'Alice', age: -5);

try {
  user.validate();
} on OrmValidationException catch (e) {
  print('Validation failed: ${e.field} - ${e.constraint}');
  // Output: Validation failed: age - greaterThan(0)
}
```

**Throws:**
- `OrmValidationException` when validation fails
- Includes field name, constraint, and value information

---

#### recordId

Provides access to the record's ID.

**Signature:**
```dart
String get recordId
```

**Example:**
```dart
final user = User(id: 'users:alice', name: 'Alice', age: 30);
print(user.recordId); // Output: users:alice
```

## Database API Methods

### QL-Suffixed Methods (Current Implementation)

All CRUD methods have been renamed with a `QL` suffix to maintain backward compatibility:

#### createQL()

Creates a new record using a Map.

**Signature:**
```dart
Future<Map<String, dynamic>> createQL(
  String table,
  Map<String, dynamic> data, {
  TableStructure? schema,
})
```

**Example:**
```dart
final user = User(id: 'users:1', name: 'Alice', age: 30);
final created = await db.createQL('users', user.toSurrealMap());
final userFromDb = UserORM.fromSurrealMap(created);
```

---

#### selectQL()

Selects all records from a table.

**Signature:**
```dart
Future<List<Map<String, dynamic>>> selectQL(String table)
```

**Example:**
```dart
final results = await db.selectQL('users');
final users = results.map((r) => UserORM.fromSurrealMap(r)).toList();
```

---

#### updateQL()

Updates a record by ID.

**Signature:**
```dart
Future<Map<String, dynamic>> updateQL(
  String id,
  Map<String, dynamic> data, {
  TableStructure? schema,
})
```

**Example:**
```dart
final updated = user.copyWith(age: 31);
await db.updateQL(user.id, updated.toSurrealMap());
```

---

#### deleteQL()

Deletes a record by ID.

**Signature:**
```dart
Future<void> deleteQL(String id)
```

**Example:**
```dart
await db.deleteQL(user.id);
```

---

#### queryQL()

Executes a raw SurrealQL query.

**Signature:**
```dart
Future<Response> queryQL(String sql)
```

**Example:**
```dart
final response = await db.queryQL('SELECT * FROM users WHERE age > 25');
final results = response.getResults();
final users = results.map((r) => UserORM.fromSurrealMap(r)).toList();
```

### Type-Safe CRUD Methods (Coming in Phase 2)

These methods will be available once Phase 2 is complete:

#### create() - Not Yet Implemented

Will create a record using a typed object.

**Planned Signature:**
```dart
Future<T> create<T>(T object)
```

**Planned Example:**
```dart
final user = User(id: 'users:1', name: 'Alice', age: 30);
final created = await db.create(user); // Type-safe!
```

---

#### update() - Not Yet Implemented

Will update a record using a typed object.

**Planned Signature:**
```dart
Future<T> update<T>(T object)
```

**Planned Example:**
```dart
final updated = user.copyWith(age: 31);
await db.update(updated);
```

---

#### delete() - Not Yet Implemented

Will delete a record using a typed object.

**Planned Signature:**
```dart
Future<void> delete<T>(T object)
```

**Planned Example:**
```dart
await db.delete(user);
```

---

#### query() - Not Yet Implemented

Will return a type-safe query builder.

**Planned Signature:**
```dart
QueryBuilder<T> query<T>({
  WhereCondition Function(TWhereBuilder)? where,
  List<IncludeSpec>? include,
  int? limit,
  int? offset,
  String? orderBy,
  bool ascending = true,
})
```

**Planned Example:**
```dart
final adults = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .limit(10)
  .execute();
```

## Exceptions

### OrmException

Base class for all ORM-specific exceptions.

**Hierarchy:**
```
DatabaseException
  └─ OrmException
      ├─ OrmValidationException
      ├─ OrmSerializationException
      ├─ OrmRelationshipException
      └─ OrmQueryException
```

---

### OrmValidationException

Thrown when object validation fails.

**Fields:**
- `message` (String): Error description
- `field` (String?): Field that failed validation
- `constraint` (String?): Constraint that was violated
- `value` (dynamic): The invalid value
- `cause` (Exception?): Underlying validation exception

**Example:**
```dart
try {
  user.validate();
} on OrmValidationException catch (e) {
  print('Field: ${e.field}');
  print('Constraint: ${e.constraint}');
  print('Value: ${e.value}');
}
```

---

### OrmSerializationException

Thrown when serialization/deserialization fails.

**Fields:**
- `message` (String): Error description
- `type` (String?): Entity type name
- `field` (String?): Field that caused the error
- `cause` (Exception?): Underlying exception

**Example:**
```dart
try {
  final user = UserORM.fromSurrealMap(invalidMap);
} on OrmSerializationException catch (e) {
  print('Type: ${e.type}');
  print('Field: ${e.field}');
  print('Cause: ${e.cause}');
}
```

---

### OrmRelationshipException

Thrown when relationship loading fails.

**Fields:**
- `message` (String): Error description
- `relationName` (String?): Name of the relationship
- `sourceType` (String?): Source entity type
- `targetType` (String?): Target entity type
- `cause` (Exception?): Underlying exception

**Example:**
```dart
try {
  // When relationship loading is implemented
  final userWithPosts = await db.query<User>()
    .include('posts')
    .execute();
} on OrmRelationshipException catch (e) {
  print('Relation: ${e.relationName}');
  print('Source: ${e.sourceType}');
  print('Target: ${e.targetType}');
}
```

---

### OrmQueryException

Thrown when query building or execution fails.

**Fields:**
- `message` (String): Error description
- `queryType` (String?): Type of query (select, update, etc.)
- `constraint` (String?): Constraint that failed
- `cause` (Exception?): Underlying exception

**Example:**
```dart
try {
  // When query builder is implemented
  final users = await db.query<User>()
    .where((t) => t.invalidField.equals('value'))
    .execute();
} on OrmQueryException catch (e) {
  print('Query type: ${e.queryType}');
  print('Constraint: ${e.constraint}');
}
```

## Code Generation

### Setup

Add build_runner dependency:

```yaml
dev_dependencies:
  build_runner: ^2.4.0
```

### Running the Generator

```bash
# One-time generation
dart run build_runner build

# Watch mode (regenerates on file changes)
dart run build_runner watch

# Clean and rebuild
dart run build_runner build --delete-conflicting-outputs
```

### Generated Files

For each `@SurrealTable` annotated class, a `.surreal.dart` file is generated:

**Input:** `lib/models/user.dart`
```dart
@SurrealTable('users')
class User {
  final String id;
  final String name;
  final int age;
}
```

**Generated:** `lib/models/user.surreal.dart`
```dart
extension UserORM on User {
  Map<String, dynamic> toSurrealMap() { ... }
  static User fromSurrealMap(Map<String, dynamic> map) { ... }
  void validate() { ... }
  String get recordId => id;
}
```

## Best Practices

### 1. Always Validate Before Saving

```dart
final user = User(id: 'users:1', name: 'Alice', age: 30);
user.validate(); // Catch errors early
await db.createQL('users', user.toSurrealMap());
```

### 2. Use Type-Safe Deserialization

```dart
// GOOD: Type-safe
final users = results.map((r) => UserORM.fromSurrealMap(r)).toList();

// BAD: Manual casting
final users = results.map((r) => User(
  id: r['id'] as String,
  name: r['name'] as String,
  age: r['age'] as int,
)).toList();
```

### 3. Handle Serialization Exceptions

```dart
try {
  final user = UserORM.fromSurrealMap(map);
} on OrmSerializationException catch (e) {
  // Log error with context
  print('Failed to deserialize User: ${e.message}');
  print('Missing/invalid field: ${e.field}');
  // Provide fallback or re-throw
}
```

### 4. Use Generated Extensions

```dart
// Access generated extension methods
final map = user.toSurrealMap();
final id = user.recordId;
user.validate();
```

## See Also

- [Migration Guide](./migration_guide.md) - Migrating from Map-based API
- [Query Patterns](./query_patterns.md) - Building complex queries (when implemented)
- [Relationships](./relationships.md) - Working with relationships (when implemented)
