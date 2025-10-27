# ORM Relationship Patterns

**Status:** ✅ Complete

This guide documents how to work with relationships in the SurrealDartB ORM layer.

## Table of Contents

- [Overview](#overview)
- [Record Link Relationships](#record-link-relationships-surrealrecord)
- [Graph Traversal Relationships](#graph-traversal-relationships-surrealrelation)
- [Edge Tables](#edge-tables-surrealedge)
- [Auto-Include Behavior](#auto-include-for-non-optional-relations)
- [Advanced Include Filtering](#advanced-include-filtering)
- [Nested Includes](#nested-includes)
- [Decision Tree](#relationship-type-decision-tree)

## Overview

SurrealDartB supports three types of relationships that map to SurrealDB's graph database capabilities:

1. **Record Links** (`@SurrealRecord`) - Direct references to other records
2. **Graph Relations** (`@SurrealRelation`) - Bidirectional graph traversal
3. **Edge Tables** (`@SurrealEdge`) - Many-to-many relationships with metadata

## Record Link Relationships (@SurrealRecord)

Record links are the simplest form of relationships, storing direct references to other records.

### Basic Usage

```dart
@SurrealTable('users')
class User {
  final String id;
  final String name;

  // Single optional reference
  @SurrealRecord()
  final Profile? profile;

  // List of references
  @SurrealRecord()
  final List<Post>? posts;

  // Non-optional reference (auto-included)
  @SurrealRecord()
  final Organization organization;
}
```

### How It Works

- **Storage**: Record IDs are stored as strings (`"table:id"` format)
- **Loading**: Generates `FETCH` clauses in SurrealQL
- **Single vs List**: Type system distinguishes between single and multiple references

### Generated SurrealQL

```sql
-- Single reference
SELECT *, FETCH profile FROM users;

-- List reference
SELECT *, FETCH posts FROM users;

-- With filtering
SELECT *, FETCH posts WHERE status = 'published' LIMIT 10 FROM users;
```

### Serialization

```dart
// Serialization (toSurrealMap)
{
  'profile': profile?.id,  // Single reference
  'posts': posts?.map((p) => p.id).toList(),  // List reference
}

// Deserialization (fromSurrealMap)
profile: map['profile'] != null
  ? ProfileORM.fromSurrealMap(map['profile'])
  : null,
posts: (map['posts'] as List?)
  ?.map((p) => PostORM.fromSurrealMap(p))
  .toList(),
```

## Graph Traversal Relationships (@SurrealRelation)

Graph relations use SurrealDB's edge syntax for bidirectional traversal.

### Basic Usage

```dart
@SurrealTable('users')
class User {
  final String id;
  final String name;

  // Outgoing relation
  @SurrealRelation(
    name: 'likes',
    direction: RelationDirection.out,
    targetTable: 'posts',
  )
  final List<Post> likedPosts;

  // Incoming relation
  @SurrealRelation(
    name: 'authored',
    direction: RelationDirection.inbound,
  )
  final List<Post> authoredPosts;

  // Bidirectional relation
  @SurrealRelation(
    name: 'friends',
    direction: RelationDirection.both,
    targetTable: 'users',
  )
  final List<User> friends;
}
```

### Relation Directions

```dart
enum RelationDirection {
  out,     // Outgoing: user->likes->post
  inbound, // Incoming: user<-likes<-post
  both,    // Bidirectional: user<->friends<->user
}
```

### Generated SurrealQL

```sql
-- Outgoing
SELECT *, ->likes->posts AS likedPosts FROM users;

-- Incoming
SELECT *, <-authored<-* AS authoredPosts FROM users;

-- Bidirectional
SELECT *, <->friends<->users AS friends FROM users;

-- With filtering
SELECT *, (->likes->posts WHERE status = 'published') AS likedPosts FROM users;
```

### When to Use Graph Relations

- **Bidirectional relationships**: Friends, followers, connections
- **Traversing edges**: Finding related entities through graph paths
- **Complex graph queries**: Multi-hop traversals
- **Relationship metadata**: When edges themselves have properties

## Edge Tables (@SurrealEdge)

Edge tables are for many-to-many relationships with additional metadata.

### Basic Usage

```dart
@SurrealEdge('user_posts')
class UserPostEdge {
  // Required: Source record
  @SurrealRecord()
  final User user;

  // Required: Target record
  @SurrealRecord()
  final Post post;

  // Edge metadata
  final String role;  // author, editor, reviewer
  final DateTime createdAt;
  final int contributionLevel;
}
```

### Requirements

- Must have **exactly two** `@SurrealRecord` fields
- Additional fields store edge metadata
- Generates `RELATE` statements for creation

### Generated SurrealQL

```dart
// Create edge with metadata
RELATE user:alice->user_posts->post:123
CONTENT {
  role: 'author',
  createdAt: time::now(),
  contributionLevel: 100
};

// Query edges
SELECT * FROM user_posts WHERE role = 'author';

// Traverse edges
SELECT *, ->user_posts->posts AS contributions FROM users;
```

### Creating Edges

```dart
// Using the edge class
final edge = UserPostEdge(
  user: alice,
  post: blogPost,
  role: 'author',
  createdAt: DateTime.now(),
  contributionLevel: 100,
);

await db.createEdge(edge);
```

## Auto-Include for Non-Optional Relations

Non-nullable relationships are automatically included in queries to prevent incomplete objects.

### Example

```dart
@SurrealTable('users')
class User {
  final String id;

  // Auto-included (non-nullable)
  @SurrealRecord()
  final Organization organization;  // Always loaded

  // Not auto-included (nullable)
  @SurrealRecord()
  final Profile? profile;  // Only loaded if explicitly included
}
```

### Behavior

```dart
// Auto-included
final user = await db.query<User>().where(...).execute();
// organization is ALWAYS populated

// Must explicitly include
final user = await db.query<User>()
  .include('profile')
  .where(...)
  .execute();
// Now profile is populated
```

### Rationale

- **Prevents null pointer errors**: Non-optional fields should never be null
- **Ensures data integrity**: Required relationships are always available
- **Explicit opt-out**: Use nullable types when relationships are truly optional

## Advanced Include Filtering

Filter, sort, and limit included relationships independently.

### Basic Filtering

```dart
final users = await db.query<User>()
  .include('posts',
    where: (p) => p.whereStatus(equals: 'published'),
    limit: 10,
    orderBy: 'createdAt',
    descending: true,
  )
  .execute();
```

### Complex WHERE Clauses

```dart
final users = await db.query<User>()
  .include('posts',
    where: (p) =>
      p.whereStatus(equals: 'published') &
      p.whereViewCount(greaterThan: 1000),
    orderBy: 'viewCount',
    descending: true,
  )
  .execute();
```

### IncludeSpec API

```dart
// Using IncludeSpec for more control
final users = await db.query<User>()
  .includeList([
    IncludeSpec('posts',
      where: (p) => p.whereStatus(equals: 'published'),
      limit: 5,
      orderBy: 'createdAt',
      descending: true,
    ),
    IncludeSpec('profile'),
  ])
  .execute();
```

## Nested Includes

Load related entities multiple levels deep with independent filtering at each level.

### Basic Nested Includes

```dart
final users = await db.query<User>()
  .include('posts',
    include: ['comments', 'tags'],
  )
  .execute();
```

### Nested Includes with Filtering

```dart
final users = await db.query<User>()
  .includeList([
    IncludeSpec('posts',
      where: (p) => p.whereStatus(equals: 'published'),
      limit: 5,
      include: [
        IncludeSpec('comments',
          where: (c) => c.whereApproved(equals: true),
          limit: 10,
          orderBy: 'createdAt',
        ),
        IncludeSpec('tags'),
      ],
    ),
    IncludeSpec('profile'),
  ])
  .execute();
```

### Generated SurrealQL

```sql
SELECT *,
  FETCH posts WHERE status = 'published' LIMIT 5 {
    FETCH comments WHERE approved = true LIMIT 10 ORDER BY createdAt,
    FETCH tags
  },
  FETCH profile
FROM users;
```

### Multi-Level Example

```dart
@SurrealTable('users')
class User {
  @SurrealRecord()
  List<Post>? posts;
}

@SurrealTable('posts')
class Post {
  @SurrealRecord()
  List<Comment>? comments;

  @SurrealRecord()
  List<Tag>? tags;
}

@SurrealTable('comments')
class Comment {
  @SurrealRecord()
  User? author;
}

// Query with 3-level nesting
final users = await db.query<User>()
  .includeList([
    IncludeSpec('posts',
      include: [
        IncludeSpec('comments',
          include: [
            IncludeSpec('author'),
          ],
        ),
        IncludeSpec('tags'),
      ],
    ),
  ])
  .execute();
```

## Relationship Type Decision Tree

### When to Use Record Links

- **Simple references**: One-way relationships
- **Known cardinality**: Clear one-to-one or one-to-many
- **No metadata**: Just the reference itself matters
- **Performance**: Fastest option for simple cases

### When to Use Graph Relations

- **Bidirectional**: Relationships go both ways
- **Graph traversals**: Multi-hop queries
- **Flexible queries**: Don't know target table at design time
- **Social networks**: Followers, connections, relationships

### When to Use Edge Tables

- **Rich metadata**: Relationships have their own properties
- **Many-to-many**: Multiple sources to multiple targets
- **Relationship history**: When, how, why relationships formed
- **Weighted graphs**: Relationships have scores, weights, or rankings

### Quick Reference

| Feature | Record Link | Graph Relation | Edge Table |
|---------|-------------|----------------|------------|
| Syntax | `FETCH` | `->relation->` | `RELATE` |
| Direction | One-way | Bidirectional | Either |
| Metadata | No | No | Yes |
| Performance | Fast | Medium | Medium |
| Flexibility | Low | High | High |

## Examples

### Blog System

```dart
// Posts belong to users (record link)
@SurrealTable('posts')
class Post {
  @SurrealRecord()
  final User author;  // Required, auto-included

  @SurrealRecord()
  final List<Comment>? comments;  // Optional
}

// Users can like posts (graph relation)
@SurrealTable('users')
class User {
  @SurrealRelation(name: 'likes', direction: RelationDirection.out)
  final List<Post>? likedPosts;
}
```

### Social Network

```dart
// Friends are bidirectional (graph relation)
@SurrealTable('users')
class User {
  @SurrealRelation(
    name: 'friends',
    direction: RelationDirection.both,
    targetTable: 'users',
  )
  final List<User>? friends;

  // Following with metadata (edge table)
  @SurrealRelation(name: 'follows', direction: RelationDirection.out)
  final List<User>? following;
}

// Follow edge with metadata
@SurrealEdge('follows')
class FollowEdge {
  @SurrealRecord()
  final User follower;

  @SurrealRecord()
  final User followee;

  final DateTime since;
  final bool notifications;
}
```

### Collaboration System

```dart
// Users collaborate on projects (edge table with roles)
@SurrealEdge('collaborations')
class Collaboration {
  @SurrealRecord()
  final User user;

  @SurrealRecord()
  final Project project;

  final String role;  // owner, editor, viewer
  final DateTime joinedAt;
  final int accessLevel;
}

// Query collaborations
final projects = await db.query<Project>()
  .include('collaborators',
    where: (c) => c.whereRole(equals: 'owner'),
  )
  .execute();
```

## Best Practices

### 1. Choose the Right Relationship Type

```dart
// GOOD: Record link for simple ownership
@SurrealRecord()
final User author;

// GOOD: Graph relation for bidirectional social connections
@SurrealRelation(name: 'friends', direction: RelationDirection.both)
final List<User>? friends;

// GOOD: Edge table when metadata matters
@SurrealEdge('user_team_membership')
class TeamMembership {
  @SurrealRecord()
  final User user;

  @SurrealRecord()
  final Team team;

  final String role;
  final DateTime joinedAt;
}
```

### 2. Use Auto-Include Wisely

```dart
// Non-optional for required relationships
@SurrealRecord()
final Organization organization;  // Always needed

// Nullable for optional relationships
@SurrealRecord()
final Profile? profile;  // Loaded on demand
```

### 3. Filter Includes for Performance

```dart
// GOOD: Limit and filter included relationships
final users = await db.query<User>()
  .include('posts',
    where: (p) => p.whereStatus(equals: 'published'),
    limit: 10,
    orderBy: 'createdAt',
    descending: true,
  )
  .execute();

// AVOID: Loading all related records without limits
final users = await db.query<User>()
  .include('posts')  // Could be thousands of posts!
  .execute();
```

### 4. Use Nested Includes Carefully

```dart
// GOOD: Limited depth with filtering
final users = await db.query<User>()
  .include('posts',
    limit: 5,
    include: [
      IncludeSpec('comments', limit: 3),
    ],
  )
  .execute();

// AVOID: Deep nesting without limits
// Can cause performance issues and memory bloat
```

## See Also

- [Migration Guide](./migration_guide.md) - Migrating to the ORM layer
- [Query Patterns](./query_patterns.md) - Complex query building
- [API Documentation](./api_documentation.md) - Complete API reference
