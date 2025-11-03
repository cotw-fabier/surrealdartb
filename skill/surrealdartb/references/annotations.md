# Code Generation Annotations

**Files:**
- `lib/src/schema/annotations.dart` - Schema annotations
- `lib/src/schema/orm_annotations.dart` - ORM annotations

## Build Configuration

**File:** `build.yaml` (project root)

```yaml
targets:
  $default:
    builders:
      surrealdartb|surreal_table_generator:
        enabled: true
        options:
          generate_for:
            - lib/models/*.dart
```

**Run code generation:**
```bash
dart run build_runner build
# or watch mode
dart run build_runner watch
```

## @SurrealTable

Mark class as database table.

```dart
@SurrealTable('table_name')  // Custom table name
@SurrealTable()             // Use class name (lowercase)
```

**Example:**
```dart
@SurrealTable('users')
class User {
  final String? id;
  final String name;
  final int age;
}
```

**Generates:**
- `UserTableDefinition` (TableStructure)
- `UserORM` extension
- `UserQueryBuilder`
- `UserWhereBuilder`

## @SurrealField

Define field with type and constraints.

```dart
@SurrealField({
  required SurrealType type,
  dynamic defaultValue,
  String? assertClause,
  bool indexed = false,
  bool optional = false,
  int? dimensions,  // For vectors
})
```

**Parameters:**
- `type` - SurrealDB type (StringType(), NumberType(), etc.)
- `defaultValue` - Default value when not provided
- `assertClause` - SurrealQL validation (e.g., `'$value > 0'`)
- `indexed` - Create index on field
- `optional` - Allow null values
- `dimensions` - Vector dimensions (for VectorType)

**Examples:**
```dart
@SurrealField(type: StringType())
final String name;

@SurrealField(
  type: NumberType(),
  assertClause: r'$value >= 0',
  indexed: true,
)
final double price;

@SurrealField(
  type: StringType(),
  optional: true,
  defaultValue: 'pending',
)
final String? status;

@SurrealField(
  type: VectorType(VectorFormat.f32, 384),
  dimensions: 384,
)
final List<double> embedding;
```

## @SurrealRecord

Direct record reference (foreign key).

```dart
@SurrealRecord()  // Infer table from type
@SurrealRecord('table_name')  // Explicit table
```

**Example:**
```dart
class Post {
  @SurrealRecord('users')
  final RecordId? author;  // Single reference

  @SurrealRecord('categories')
  final List<RecordId>? categories;  // Multiple references
}
```

**Generated schema:**
```dart
'author': FieldDefinition(RecordType(table: 'users'))
'categories': FieldDefinition(ArrayType(RecordType(table: 'categories')))
```

## @SurrealRelation

Graph relationship with traversal.

```dart
@SurrealRelation({
  required String name,
  required String edgeTable,
  required RelationDirection direction,
  String? targetTable,
})
```

**Parameters:**
- `name` - Relationship name (method name in generated code)
- `edgeTable` - Name of edge table
- `direction` - `outgoing`, `incoming`, or `both`
- `targetTable` - Target table (optional if inferrable)

**Example:**
```dart
class User {
  @SurrealRelation(
    name: 'posts',
    edgeTable: 'wrote',
    direction: RelationDirection.outgoing,
    targetTable: 'posts',
  )
  void _postsRelation() {}  // Marker method

  @SurrealRelation(
    name: 'followers',
    edgeTable: 'follows',
    direction: RelationDirection.incoming,
    targetTable: 'users',
  )
  void _followersRelation() {}
}
```

**Generated methods:**
```dart
extension UserORM on User {
  Future<List<Post>> getPosts(Database db) async { }
  Future<List<User>> getFollowers(Database db) async { }
}
```

## @SurrealEdge

Define edge table with metadata.

```dart
@SurrealEdge('edge_table_name')
```

**Example:**
```dart
@SurrealEdge('follows')
class FollowsEdge {
  final RecordId? in_;    // Reserved: destination
  final RecordId? out;    // Reserved: source
  final DateTime createdAt;
  final bool notificationEnabled;
}
```

**Generated schema:**
```dart
TableStructure('follows', {
  'in': FieldDefinition(RecordType()),
  'out': FieldDefinition(RecordType()),
  'created_at': FieldDefinition(DatetimeType()),
  'notification_enabled': FieldDefinition(BoolType()),
})
```

## @SurrealId

Mark non-standard ID field.

```dart
@SurrealId()
final String? myCustomId;
```

**Default behavior:** Looks for `id` or `_id` field
**Use @SurrealId:** When using custom field name

## @JsonField

Serialize complex types as JSON.

```dart
@JsonField()
final Map<String, dynamic> metadata;

@JsonField()
final CustomClass config;
```

**Generates:** JSON serialization in `toSurrealMap()` and `fromSurrealMap()`

## Generated Artifacts

### TableDefinition

```dart
class UserTableDefinition extends TableStructure {
  UserTableDefinition() : super('users', {
    'name': FieldDefinition(StringType()),
    'age': FieldDefinition(NumberType()),
    // ...
  });
}

// Usage
final userTableDef = UserTableDefinition();
```

### ORM Extension

```dart
extension UserORM on User {
  // Serialization
  Map<String, dynamic> toSurrealMap();
  static User fromSurrealMap(Map<String, dynamic> map);

  // Validation
  void validate();

  // Getters
  RecordId? get recordId;
  static String get tableName => 'users';
  static TableStructure get tableStructure => UserTableDefinition();

  // Query builder
  static UserQueryBuilder createQueryBuilder(Database db);

  // Relationship methods (if @SurrealRelation used)
  Future<List<Post>> getPosts(Database db);
  Future<void> addFollower(Database db, User other);
}
```

### QueryBuilder

```dart
class UserQueryBuilder {
  Future<List<User>> select({WhereCondition? where, int? limit});
  Future<User?> get(String id);
  Future<User> create(User user);
  Future<User?> update(String id, User user);
  Future<User?> delete(String id);
}

// Usage
final users = await User.createQueryBuilder(db).select(
  where: StringFieldCondition('name').contains('Alice'),
  limit: 10,
);
```

### WhereBuilder

```dart
class UserWhereBuilder {
  StringFieldCondition name;
  NumberFieldCondition age;
  // ... one for each field
}

// Usage
final builder = UserWhereBuilder();
final condition = builder.name.equals('Alice') & builder.age.greaterThan(18);
```

## Complete Example

**Model file:** `lib/models/user.dart`

```dart
import 'package:surrealdartb/surrealdartb.dart';

@SurrealTable('users')
class User {
  @SurrealId()
  final String? id;

  @SurrealField(type: StringType(), indexed: true)
  final String name;

  @SurrealField(type: NumberType(), assertClause: r'$value >= 18')
  final int age;

  @SurrealField(type: StringType(), optional: true)
  final String? email;

  @SurrealRecord('profiles')
  final RecordId? profile;

  @SurrealField(
    type: VectorType(VectorFormat.f32, 384),
    dimensions: 384,
  )
  final List<double>? embedding;

  @SurrealRelation(
    name: 'posts',
    edgeTable: 'wrote',
    direction: RelationDirection.outgoing,
    targetTable: 'posts',
  )
  void _postsRelation() {}

  User({
    this.id,
    required this.name,
    required this.age,
    this.email,
    this.profile,
    this.embedding,
  });
}
```

**Generated:** `lib/models/user.surreal.dart`

**Usage:**
```dart
import 'package:myapp/models/user.dart';
import 'package:myapp/models/user.surreal.dart';  // Generated

// Create with validation
final user = User(name: 'Alice', age: 30);
user.validate();  // Throws if invalid

// Save
await db.createQL('users', user.toSurrealMap());

// Query with builder
final users = await User.createQueryBuilder(db).select(
  where: UserWhereBuilder().age.greaterThan(18),
);

// Load relationships
final posts = await user.getPosts(db);

// Use in migrations
final db = await Database.connect(
  tableDefinitions: [UserTableDefinition()],
  autoMigrate: true,
);
```

## Type Mapping

Automatic Dart → SurrealDB type inference:

| Dart Type | Generated SurrealType |
|-----------|----------------------|
| String | StringType() |
| int, double, num | NumberType() |
| bool | BoolType() |
| DateTime | DatetimeType() |
| Duration | DurationType() |
| List | ArrayType(elementType) |
| Map | ObjectType() |
| RecordId | RecordType() |
| List\<double\> with @SurrealField(dimensions:) | VectorType() |

**Override with explicit @SurrealField:**
```dart
@SurrealField(type: NumberType(format: NumberFormat.integer))
final int count;  // Explicitly integer
```

## Build Runner Commands

```bash
# One-time build
dart run build_runner build

# Watch mode (rebuilds on file changes)
dart run build_runner watch

# Clean generated files
dart run build_runner clean

# Force rebuild
dart run build_runner build --delete-conflicting-outputs
```

## Gotchas

1. **Import Generated File:** Must import `.surreal.dart` to use generated methods
2. **Rebuild Required:** Run build_runner after annotation changes
3. **Part Directive:** Don't use `part` - generated file is separate import
4. **Constructor Required:** Class must have constructor matching all fields
5. **Null Safety:** Optional fields must be nullable (`String?` not `String`)
6. **Vector Dimensions:** Must match actual embedding size
7. **Reserved Names:** Avoid `in` (use `in_`) and `id` conflicts
8. **Build Config:** Ensure `build.yaml` includes your model directory
9. **Relationship Markers:** Relation marker methods should be `void` and empty
10. **Edge Tables:** Must have `in` and `out` fields of RecordType
