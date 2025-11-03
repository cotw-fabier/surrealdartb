# ORM Relationships

## Relationship Types

**File:** `lib/src/orm/relationship_metadata.dart`

Three relationship patterns supported:

1. **RecordLink** - Direct record references (foreign keys)
2. **GraphRelation** - Graph traversal with `->`, `<-`, `<->`
3. **EdgeTable** - Edge tables with metadata

## RecordLinkMetadata

Direct references to other records.

```dart
class RecordLinkMetadata {
  final String fieldName;
  final String targetTable;
  final bool isList;  // Single reference or list
}
```

**Schema:**
```dart
'author': FieldDefinition(RecordType(table: 'users'))
'categories': FieldDefinition(ArrayType(RecordType(table: 'categories')))
```

**Query:**
```dart
// Automatic FETCH generation
final posts = await db.queryQL('''
  SELECT *, author.* FROM posts
''');
```

## GraphRelationMetadata

Graph traversal using SurrealDB's graph syntax.

```dart
class GraphRelationMetadata {
  final String relationName;
  final String edgeTable;
  final RelationDirection direction;
  final String targetTable;
}

enum RelationDirection {
  outgoing,  // ->
  incoming,  // <-
  both,      // <->
}
```

**Directions:**
- `->` (outgoing): "this record points to"
- `<-` (incoming): "points to this record"
- `<->` (both): bidirectional

**Example:**
```dart
// User -> FOLLOWS -> User
GraphRelationMetadata(
  relationName: 'followers',
  edgeTable: 'follows',
  direction: RelationDirection.incoming,
  targetTable: 'users',
)

// Query: user <-follows<- users (who follows this user)
```

## EdgeTableMetadata

Edge tables with additional metadata.

```dart
class EdgeTableMetadata {
  final String edgeTableName;
  final String fromField;
  final String toField;
  final Map<String, FieldDefinition>? edgeFields;  // Metadata on edge
}
```

**Schema for edge table:**
```dart
final followsTable = TableStructure('follows', {
  'in': FieldDefinition(RecordType(table: 'users')),
  'out': FieldDefinition(RecordType(table: 'users')),
  'since': FieldDefinition(DatetimeType()),  // Edge metadata
  'notification_enabled': FieldDefinition(BoolType()),
});
```

**Create edge:**
```dart
await db.queryQL('''
  RELATE users:alice->follows->users:bob
  SET since = time::now(), notification_enabled = true
''');
```

## IncludeSpec

**File:** `lib/src/orm/include_spec.dart`

Specify related data to include in queries.

```dart
class IncludeSpec {
  final String fieldPath;
  final String? as;              // Alias for result
  final WhereCondition? where;   // Filter related records
  final List<IncludeSpec>? nested;  // Nested includes
}
```

**Example:**
```dart
// Include author
IncludeSpec(fieldPath: 'author')

// Include with alias
IncludeSpec(fieldPath: 'author', as: 'creator')

// Include with filter
IncludeSpec(
  fieldPath: 'comments',
  where: BoolFieldCondition('approved').isTrue(),
)

// Nested include
IncludeSpec(
  fieldPath: 'comments',
  nested: [
    IncludeSpec(fieldPath: 'author'),
  ],
)
```

## Relationship Loader

**File:** `lib/src/orm/relationship_loader.dart`

Utilities for loading relationships.

### generateFetchClause()

Generate FETCH clause for record links.

```dart
String generateFetchClause(List<IncludeSpec> includes)
```

**Example:**
```dart
final clause = generateFetchClause([
  IncludeSpec(fieldPath: 'author'),
  IncludeSpec(fieldPath: 'category'),
]);
// → FETCH author, category
```

### generateGraphTraversal()

Generate graph query for relations.

```dart
String generateGraphTraversal(
  GraphRelationMetadata relation,
  {WhereCondition? where}
)
```

**Example:**
```dart
final traversal = generateGraphTraversal(followersRelation);
// → <-follows<- users
```

### generateRelateStatement()

Generate RELATE statement for edges.

```dart
String generateRelateStatement({
  required String fromRecord,
  required String edgeTable,
  required String toRecord,
  Map<String, dynamic>? edgeData,
})
```

**Example:**
```dart
final stmt = generateRelateStatement(
  fromRecord: 'users:alice',
  edgeTable: 'follows',
  toRecord: 'users:bob',
  edgeData: {'since': DateTime.now()},
);
// → RELATE users:alice->follows->users:bob SET since = ...
```

## Common Patterns

### One-to-One Relationship

**Schema:**
```dart
// User has one profile
'profile': FieldDefinition(RecordType(table: 'profiles'))
```

**Query:**
```dart
final users = await db.queryQL('''
  SELECT *, profile.* FROM users
''');
```

### One-to-Many Relationship

**Schema:**
```dart
// Post has one author, author has many posts
'author': FieldDefinition(RecordType(table: 'users'))
```

**Query with include:**
```dart
// Get posts with author info
final posts = await db.queryQL('''
  SELECT *, author.* FROM posts
''');

// Get user with their posts
final user = await db.queryQL('''
  SELECT *, ->wrote->posts.* FROM users:alice
''');
```

### Many-to-Many with Edge Table

**Schema:**
```dart
// Users follow users
final followsEdge = TableStructure('follows', {
  'in': FieldDefinition(RecordType(table: 'users')),
  'out': FieldDefinition(RecordType(table: 'users')),
  'created_at': FieldDefinition(DatetimeType()),
  'notification_enabled': FieldDefinition(BoolType()),
});
```

**Create relationship:**
```dart
await db.queryQL('''
  RELATE users:alice->follows->users:bob
  SET created_at = time::now(), notification_enabled = true
''');
```

**Query:**
```dart
// Get followers
final followers = await db.queryQL('''
  SELECT <-follows<-.* as followers FROM users:alice
''');

// Get following
final following = await db.queryQL('''
  SELECT ->follows->.* as following FROM users:alice
''');

// Get mutual followers
final mutual = await db.queryQL('''
  SELECT ->follows->users<-follows<- users:alice as mutual
''');
```

### Graph Traversal

**Multi-hop traversal:**
```dart
// Friends of friends
await db.queryQL('''
  SELECT ->friend->user->friend->user.* FROM users:alice
''');

// Posts by followed users
await db.queryQL('''
  SELECT ->follows->user->wrote->posts.* FROM users:alice
''');
```

**With filtering:**
```dart
// Active followers
await db.queryQL('''
  SELECT <-follows<-(users WHERE active = true).* FROM users:alice
''');
```

### Filtered Includes

**Using WhereCondition:**
```dart
final posts = await db.queryQL('''
  SELECT *,
    ->commented_on<-(comments WHERE approved = true).* as approved_comments
  FROM posts
''');
```

### Nested Includes

**Multiple levels:**
```dart
// Posts with author and author's profile
await db.queryQL('''
  SELECT *,
    author.*,
    author.profile.*
  FROM posts
''');
```

## Edge Metadata Patterns

### Timestamped Relationships

```dart
final likesEdge = TableStructure('likes', {
  'in': FieldDefinition(RecordType(table: 'posts')),
  'out': FieldDefinition(RecordType(table: 'users')),
  'created_at': FieldDefinition(DatetimeType()),
});

await db.queryQL('''
  RELATE users:alice->likes->posts:123
  SET created_at = time::now()
''');
```

### Weighted Relationships

```dart
final friendEdge = TableStructure('friend', {
  'in': FieldDefinition(RecordType(table: 'users')),
  'out': FieldDefinition(RecordType(table: 'users')),
  'strength': FieldDefinition(NumberType()),  // 1-10
  'since': FieldDefinition(DatetimeType()),
});
```

### Conditional Relationships

```dart
final accessEdge = TableStructure('can_access', {
  'in': FieldDefinition(RecordType(table: 'resources')),
  'out': FieldDefinition(RecordType(table: 'users')),
  'permission': FieldDefinition(StringType()),  // read, write, admin
  'expires_at': FieldDefinition(DatetimeType(), optional: true),
});
```

## Advanced Query Patterns

### Aggregations on Relationships

```dart
// Count followers
await db.queryQL('''
  SELECT id, count(<-follows<-) as follower_count FROM users
''');

// Sum of edge weights
await db.queryQL('''
  SELECT sum(->friend->friendship.strength) as total_friend_strength
  FROM users:alice
''');
```

### Conditional Traversal

```dart
// Only traverse active relationships
await db.queryQL('''
  SELECT ->follows(WHERE active = true)->users.*
  FROM users:alice
''');
```

### Bidirectional Queries

```dart
// Mutual follows (both directions)
await db.queryQL('''
  SELECT ->follows->users<-follows<- users:alice as mutuals
''');
```

### Path Queries

```dart
// Shortest path between users
await db.queryQL('''
  SELECT * FROM users:alice->friend*..5->users:bob
''');

// All paths up to depth 3
await db.queryQL('''
  SELECT * FROM users:alice->friend*1..3->users.*
''');
```

## Generated ORM Methods

Code generation creates relationship helpers (see annotations.md):

```dart
// Generated for @SurrealRelation
class User {
  Future<List<Post>> getPosts(Database db) async {
    // Automatically generated relationship query
  }

  Future<void> addFollower(Database db, User other) async {
    // Generate RELATE statement
  }
}
```

## Gotchas

1. **FETCH Limitations:** FETCH only works for direct record links, not graph traversal
2. **Graph Direction:** `->` vs `<-` matters - reversed direction = different results
3. **Edge Table Naming:** Edge tables typically singular (e.g., `follows` not `follow`)
4. **Circular References:** Be careful with deep nested includes
5. **Performance:** Deep graph traversals can be slow - use depth limits
6. **Null Handling:** Missing relationships return empty arrays, not null
7. **Record IDs in Edges:** `in` and `out` fields must be RecordType in edge tables
