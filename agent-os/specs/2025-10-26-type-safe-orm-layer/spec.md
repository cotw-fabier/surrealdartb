# Specification: Type-Safe ORM Layer

## Goal

Provide a type-safe ORM layer on top of the existing table schema generation utility, enabling developers to perform CRUD operations using Dart objects instead of raw Maps and SurrealQL, while maintaining full backward compatibility and leveraging SurrealDB's graph database capabilities for relationships with advanced query filtering.

## User Stories

- As a developer, I want to use `db.create(userObject)` instead of `db.create('users', userMap)` so that I have compile-time type safety
- As a developer, I want the ORM to automatically extract table names from my object types so that I don't have to specify them manually
- As a developer, I want to define relationships between entities using decorators so that I can traverse the graph database naturally
- As a developer, I want to use `db.query<User>().where(...)` instead of writing raw SurrealQL so that I catch errors at compile time
- As a developer, I want to include related objects in my queries using a Serverpod-like syntax so that I can load complete object graphs efficiently
- As a developer, I want to filter included relationships using where clauses so that I can load only the data I need
- As a developer, I want to combine query conditions with AND and OR operators so that I can express complex business logic
- As a developer, I want query results to automatically deserialize into my Dart classes so that I don't have to write manual mapping code
- As a developer, I want non-optional relations to auto-include by default so that I don't get incomplete objects with missing data
- As a developer, I want validation to happen against the table structure before sending to SurrealDB so that I catch schema mismatches early

## Core Requirements

### Functional Requirements

**Type-Safe CRUD Operations**
- New methods: `db.create(object)`, `db.update(object)`, `db.delete(object)` that accept Dart objects
- Automatic table name extraction from `@SurrealTable` annotation
- Automatic field mapping from object properties to database fields
- Object ID field detection (field named 'id' or annotated with `@SurrealId`)
- Validation against TableStructure before sending to database
- Automatic serialization from Dart objects to SurrealDB JSON format
- Automatic deserialization from SurrealDB results to Dart objects

**Backward Compatibility**
- Rename existing CRUD methods with "QL" suffix: `create` -> `createQL`, `select` -> `selectQL`, `update` -> `updateQL`, `delete` -> `deleteQL`
- Map-based methods continue to work for schemaless tables and raw queries
- No breaking changes to existing Database API
- All existing code continues working without modification

**Query Builder System**
- Fluent API: `db.query<User>().where(...).include(...).orderBy(...).limit(10)`
- Direct parameter API: `db.query<User>(where: ..., include: ..., limit: 10)`
- Type-safe query builder generated per entity class
- Query execution returns strongly-typed results
- Support for pagination (limit/offset)
- Support for sorting (orderBy, ascending/descending)

**Relationship Management**
- Three relationship annotations:
  - `@SurrealRecord()` - for record link relationships (single reference or list of references)
  - `@SurrealRelation()` - for graph traversal relationships using `->`/`<-` syntax
  - `@SurrealEdge()` - for edge table definitions with metadata
- Support for one-to-one, one-to-many, many-to-many relationships
- Non-optional relations auto-included by default
- Optional relations return null or empty collections when not included
- Advanced include system with filtering:
  - Basic include: `.include('posts')`
  - Include with where clause: `.include('posts', where: (p) => p.whereStatus(equals: 'published'))`
  - Include with limit: `.include('posts', limit: 10)`
  - Include with orderBy: `.include('posts', orderBy: 'createdAt', descending: true)`
  - Nested includes: `.include('posts', include: ['comments', 'tags'])`
  - Nested includes with conditions: Each nested level supports its own where, limit, orderBy
- Strongly-typed field population (e.g., `user.posts` as `List<Post>`)
- Smart SurrealQL generation based on relationship type

**Where Clause DSL**
- Generated type-safe methods per field: `whereEmail(equals: '...')`, `whereAge(greaterThan: 18)`
- Operators per field type:
  - String: equals, notEquals, contains, ilike, startsWith, endsWith, inList, any
  - Number: equals, notEquals, greaterThan, lessThan, greaterOrEqual, lessOrEqual, between, inList
  - Boolean: equals, isTrue, isFalse
  - DateTime: equals, before, after, between
  - Collections: contains, isEmpty, isNotEmpty, any
- Logical operator combinations:
  - AND operator: `&` for combining conditions
  - OR operator: `|` for alternative conditions
  - Operator precedence: Explicit parentheses for grouping
  - Example: `(t.age.between(0, 10) | t.age.between(90, 100)) & t.status.equals('active')`
- Support for nested object property access: `t.location.lat.between(minLat, maxLat)`
- Condition combining patterns:
  - Multiple conditions with reduce: `conditions.reduce((a, b) => a & b)`
  - Builder chaining: `.whereAge(greaterThan: 18).whereStatus(equals: 'active')` (implicit AND)
  - Explicit operators for complex logic: `t.status.equals('publish') | t.userId.equals(currentUser.id)`
- Type validation at compile time

**Code Generation Strategy**
- Generate extension methods on annotated classes for ORM functionality
- Generate query builder classes per entity (e.g., `UserQueryBuilder`)
- Generate include builder classes for relationship filtering
- Generate where condition classes supporting operator overloading
- Generate relationship loading methods
- Single source of truth: the annotated class definition
- Reusable with schema changes (rerun generator to update)
- Integration with existing build_runner workflow

### Non-Functional Requirements

**Performance**
- Generated code has zero runtime overhead (compile-time generation)
- Query building is efficient with minimal allocations
- Serialization/deserialization leverages existing type mapper
- No reflection - all code generation based

**Safety**
- Validation before sending data to SurrealDB prevents invalid queries
- Type-safe query builder prevents SQL injection
- Compile-time errors for type mismatches
- Clear error messages for validation failures

**Maintainability**
- Generated code is readable and debuggable
- Clear separation between user code and generated code
- Follows Dart ecosystem patterns (similar to json_serializable)
- Consistent with existing codebase style

## Reusable Components

### Existing Code to Leverage

**Table Schema Generation System** (`lib/src/schema/`, `lib/generator/`)
- Annotations: `@SurrealTable`, `@SurrealField`, `@JsonField`
- Generator infrastructure: `SurrealTableGenerator`
- Type mapping: `TypeMapper` class
- Schema introspection: Already implemented
- TableStructure and FieldDefinition classes

**Database Layer** (`lib/src/database.dart`)
- Existing CRUD methods (to be renamed with QL suffix)
- Transaction support via `transaction()` method
- Query execution via `query()` method
- Parameter binding via `set()` method
- Connection management
- Error handling patterns

**Type System** (`lib/src/schema/surreal_types.dart`)
- Complete SurrealType hierarchy
- FieldDefinition class
- Validation logic patterns

**Existing Patterns**
- FFI integration patterns
- Future-based async API
- Exception hierarchy in `lib/src/exceptions.dart`

### New Components Required

**ORM Annotations** (`lib/src/schema/orm_annotations.dart`)
- `@SurrealRecord()` - mark record link fields
- `@SurrealRelation()` - mark graph traversal relationships with direction
- `@SurrealEdge()` - mark edge table definitions
- `@SurrealId()` - mark ID field (optional, defaults to field named 'id')
- Why new: Relationship management is distinct from schema definition

**ORM Generator Extension** (`lib/generator/orm_generator.dart`)
- Extend existing generator to create ORM methods
- Generate query builder classes
- Generate include builder classes with where clause support
- Generate where condition classes with operator overloading
- Generate relationship loading code
- Why new: ORM functionality is layered on top of schema generation

**Query Builder Classes** (generated per entity)
- Type-safe query building API
- Generated per annotated class
- Immutable builder pattern for chaining
- Why new: Query building is new functionality

**Include Builder Classes** (generated per relationship)
- Type-safe include filtering API
- Support where, limit, orderBy on included relationships
- Support nested includes with independent conditions
- Generated per relationship field
- Why new: Advanced include filtering is new requirement

**Where Condition Classes** (generated per entity)
- Support for operator overloading (`&` and `|`)
- Chainable condition building
- Type-safe field access with nested properties
- Why new: Logical operator support requires dedicated classes

**Serialization Extensions** (generated per entity)
- `toSurrealMap()` method on entity classes
- `fromSurrealMap()` static method/constructor
- Handles nested objects and relationships
- Why new: Bidirectional mapping is new requirement

**Relationship Loader** (`lib/src/orm/relationship_loader.dart`)
- Logic for determining which relationships to include
- SurrealQL generation for different relationship types
- Result processing and object graph construction
- Support for include filtering (where, limit, orderBy)
- Support for nested includes with conditions
- Why new: Complex relationship handling with filtering requires dedicated logic

## Technical Approach

### Architecture Overview

The ORM layer builds on top of the existing schema generation system by:

1. Extending the generator to produce additional ORM methods
2. Creating query builder classes for type-safe querying
3. Creating include builder classes for relationship filtering
4. Creating where condition classes for logical operators
5. Adding relationship annotations and loading logic
6. Implementing serialization/deserialization extensions
7. Validating all operations against TableStructure before execution

### Relationship Type Design

**Record Links (`@SurrealRecord`)**
- Used for direct references to other records
- Generates FETCH clauses in SurrealQL
- Example: `@SurrealRecord() User author;` -> `FETCH author`
- Supports single references and lists: `@SurrealRecord() List<Post> posts;`
- Supports filtering with where clauses: `FETCH posts WHERE status = 'published'`

**Graph Relations (`@SurrealRelation`)**
- Used for bidirectional graph traversal
- Generates graph syntax: `->edge->`, `<-edge<-`
- Parameters: `name` (relation name), `direction` (out/in/both), `targetTable` (optional constraint)
- Example: `@SurrealRelation(name: 'likes', direction: RelationDirection.out) List<Post> likedPosts;`
- Supports filtering on traversal results

**Edge Tables (`@SurrealEdge`)**
- Used for many-to-many with metadata
- Defines the edge table schema
- Example:
```dart
@SurrealEdge('user_posts')
class UserPostEdge {
  @SurrealRecord() User user;
  @SurrealRecord() Post post;
  DateTime createdAt;
  String role;
}
```

### Query Builder API Design

**Fluent Builder Pattern**
```dart
// Generated query builder for User class
class UserQueryBuilder {
  // Where clause methods (generated per field)
  UserQueryBuilder whereEmail({String? equals, String? contains, List<String>? inList});
  UserQueryBuilder whereAge({int? equals, int? greaterThan, int? lessThan});

  // Advanced where with condition objects
  UserQueryBuilder where(WhereCondition<User> Function(UserWhereBuilder) builder);

  // Relationship inclusion with filtering
  UserQueryBuilder include(String relationName, {
    WhereCondition? where,
    int? limit,
    String? orderBy,
    bool? descending,
    List<String>? include, // Nested includes
  });
  UserQueryBuilder includeList(List<IncludeSpec> includes);

  // Pagination
  UserQueryBuilder limit(int count);
  UserQueryBuilder offset(int count);

  // Sorting
  UserQueryBuilder orderBy(String field, {bool ascending = true});

  // Execution
  Future<List<User>> execute();
  Future<User?> first();
}
```

**Where Condition Builder with Logical Operators**
```dart
// Generated where condition builder
class UserWhereBuilder {
  // Field accessors returning condition builders
  UserFieldCondition<String> get email => UserFieldCondition('email');
  UserFieldCondition<int> get age => UserFieldCondition('age');
  UserFieldCondition<String> get status => UserFieldCondition('status');

  // Nested object access
  UserLocationCondition get location => UserLocationCondition('location');
}

// Generated field condition with operators
class UserFieldCondition<T> {
  final String fieldPath;

  WhereCondition equals(T value) => EqualsCondition(fieldPath, value);
  WhereCondition between(T min, T max) => BetweenCondition(fieldPath, min, max);
  WhereCondition ilike(String pattern) => IlikeCondition(fieldPath, pattern);
  WhereCondition any(List<T> values) => AnyCondition(fieldPath, values);

  // Logical operators
  WhereCondition operator &(WhereCondition other) => AndCondition(this, other);
  WhereCondition operator |(WhereCondition other) => OrCondition(this, other);
}

// Usage examples
final users = await db.query<User>()
  .where((t) => t.age.between(18, 65) & t.status.equals('active'))
  .execute();

// Complex OR conditions
final users = await db.query<User>()
  .where((t) => (t.age.between(0, 10) | t.age.between(90, 100)) & t.verified.equals(true))
  .execute();

// Nested property access
final users = await db.query<User>()
  .where((t) =>
    (t.location.lat.between(minLat, maxLat)) &
    (t.location.lon.between(minLon, maxLon))
  )
  .execute();

// Combining multiple conditions
final conditions = [
  (t) => t.status.equals('publish'),
  (t) => t.userId.equals(currentUser.id),
];
final combined = conditions.map((fn) => fn(whereBuilder)).reduce((a, b) => a | b);
```

**Include Specification with Filtering**
```dart
// Serverpod-style include with where clauses
class IncludeSpec {
  final String relationName;
  final WhereCondition? where;
  final int? limit;
  final String? orderBy;
  final bool? descending;
  final List<IncludeSpec>? include; // Nested includes

  IncludeSpec(this.relationName, {
    this.where,
    this.limit,
    this.orderBy,
    this.descending,
    this.include,
  });
}

// Usage examples
final users = await db.query<User>()
  .include('posts',
    where: (p) => p.whereStatus(equals: 'published'),
    limit: 10,
    orderBy: 'createdAt',
    descending: true,
  )
  .execute();

// Nested includes with independent conditions
final users = await db.query<User>()
  .include('cities',
    where: (c) => c.wherePopulation(greaterThan: 100000),
    include: ['regions', 'districts'],
  )
  .execute();

// Complex nested includes
final users = await db.query<User>()
  .includeList([
    IncludeSpec('posts',
      where: (p) => p.whereStatus(equals: 'published'),
      limit: 5,
      include: [
        IncludeSpec('comments',
          where: (c) => c.whereApproved(equals: true),
          limit: 10,
        ),
        IncludeSpec('tags'),
      ],
    ),
    IncludeSpec('profile'),
  ])
  .execute();
```

**Direct Parameter Pattern**
```dart
final users = await db.query<User>(
  where: (t) => t.whereAge(greaterThan: 18) & t.whereStatus(equals: 'active'),
  include: [
    IncludeSpec('posts',
      where: (p) => p.whereStatus(equals: 'published'),
      limit: 10,
    ),
  ],
  limit: 10,
  orderBy: 'createdAt',
);
```

### Code Generation Strategy

**Extension Methods on Entity Classes**
```dart
// Generated in user.surreal.dart
extension UserORM on User {
  // Serialization
  Map<String, dynamic> toSurrealMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'posts': posts?.map((p) => p.id).toList(), // Record links
    };
  }

  // Deserialization
  static User fromSurrealMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      // posts loaded separately via includes
    );
  }

  // Validation
  void validate() {
    userTableDefinition.validate(toSurrealMap());
  }
}
```

**Query Builder Generation**
```dart
// Generated query builder
class UserQueryBuilder {
  final Database _db;
  final List<WhereCondition> _whereConditions = [];
  final List<IncludeSpec> _includes = [];
  int? _limit;
  int? _offset;
  String? _orderBy;
  bool _ascending = true;

  UserQueryBuilder(this._db);

  // Where with condition builder
  UserQueryBuilder where(WhereCondition Function(UserWhereBuilder) builder) {
    final condition = builder(UserWhereBuilder());
    _whereConditions.add(condition);
    return this;
  }

  // Legacy simple where methods (still generated for convenience)
  UserQueryBuilder whereEmail({String? equals, String? contains}) {
    if (equals != null) {
      _whereConditions.add(EqualsCondition('email', equals));
    }
    if (contains != null) {
      _whereConditions.add(ContainsCondition('email', contains));
    }
    return this;
  }

  // Include with filtering support
  UserQueryBuilder include(String relationName, {
    WhereCondition? where,
    int? limit,
    String? orderBy,
    bool? descending,
    List<String>? include,
  }) {
    _includes.add(IncludeSpec(relationName,
      where: where,
      limit: limit,
      orderBy: orderBy,
      descending: descending,
      include: include?.map((i) => IncludeSpec(i)).toList(),
    ));
    return this;
  }

  Future<List<User>> execute() async {
    final query = _buildQuery();
    final response = await _db.query(query);
    return response.getResults()
      .map((map) => UserORM.fromSurrealMap(map))
      .toList();
  }

  String _buildQuery() {
    final buffer = StringBuffer('SELECT * FROM user');

    // Build WHERE clause with logical operators
    if (_whereConditions.isNotEmpty) {
      buffer.write(' WHERE ');
      buffer.write(_buildWhereClause(_whereConditions));
    }

    // Build FETCH/INCLUDE clauses with filtering
    if (_includes.isNotEmpty) {
      buffer.write(' ');
      buffer.write(_buildIncludeClauses(_includes));
    }

    // Add ORDER BY, LIMIT, OFFSET
    if (_orderBy != null) {
      buffer.write(' ORDER BY $_orderBy ${_ascending ? 'ASC' : 'DESC'}');
    }
    if (_limit != null) {
      buffer.write(' LIMIT $_limit');
    }
    if (_offset != null) {
      buffer.write(' START $_offset');
    }

    return buffer.toString();
  }
}
```

**Where Condition Classes Generation**
```dart
// Base condition class
abstract class WhereCondition {
  String toSurrealQL(Database db);

  WhereCondition operator &(WhereCondition other) => AndCondition(this, other);
  WhereCondition operator |(WhereCondition other) => OrCondition(this, other);
}

// Logical operator conditions
class AndCondition extends WhereCondition {
  final WhereCondition left;
  final WhereCondition right;

  AndCondition(this.left, this.right);

  @override
  String toSurrealQL(Database db) {
    return '(${left.toSurrealQL(db)} AND ${right.toSurrealQL(db)})';
  }
}

class OrCondition extends WhereCondition {
  final WhereCondition left;
  final WhereCondition right;

  OrCondition(this.left, this.right);

  @override
  String toSurrealQL(Database db) {
    return '(${left.toSurrealQL(db)} OR ${right.toSurrealQL(db)})';
  }
}

// Field conditions
class EqualsCondition<T> extends WhereCondition {
  final String fieldPath;
  final T value;

  EqualsCondition(this.fieldPath, this.value);

  @override
  String toSurrealQL(Database db) {
    final paramName = db.generateParamName();
    db.set(paramName, value);
    return '$fieldPath = \$$paramName';
  }
}

class BetweenCondition<T> extends WhereCondition {
  final String fieldPath;
  final T min;
  final T max;

  BetweenCondition(this.fieldPath, this.min, this.max);

  @override
  String toSurrealQL(Database db) {
    final minParam = db.generateParamName();
    final maxParam = db.generateParamName();
    db.set(minParam, min);
    db.set(maxParam, max);
    return '$fieldPath >= \$$minParam AND $fieldPath <= \$$maxParam';
  }
}
```

### Database API Extensions

**Type-Safe CRUD Methods** (extend `lib/src/database.dart`)
```dart
// New type-safe create
Future<T> create<T>(T object) async {
  final table = _extractTableName<T>();
  final schema = _getTableStructure<T>();
  final extension = object as dynamic; // Access generated extension

  // Validate before sending
  extension.validate();

  // Serialize
  final map = extension.toSurrealMap();

  // Use existing createQL
  final result = await createQL(table, map);

  // Deserialize
  return T.fromSurrealMap(result);
}

// Query builder factory
QueryBuilder<T> query<T>({
  WhereCondition Function(TWhereBuilder)? where,
  List<IncludeSpec>? include,
  int? limit,
  int? offset,
  String? orderBy,
  bool ascending = true,
}) {
  final builder = T.createQueryBuilder(this); // Generated static method

  if (where != null) {
    builder.where(where);
  }
  if (include != null) {
    builder.includeList(include);
  }
  if (limit != null) {
    builder.limit(limit);
  }
  if (offset != null) {
    builder.offset(offset);
  }
  if (orderBy != null) {
    builder.orderBy(orderBy, ascending: ascending);
  }

  return builder;
}
```

**Method Renaming Strategy**
- Add "QL" suffix to all existing CRUD methods
- Implement new methods without suffix for type-safe API
- Maintain identical behavior in QL methods
- Update documentation to explain the dual API

### Relationship Loading Logic

**Auto-Include Non-Optional Relations**
```dart
// Determine which relations to include
Set<String> _determineAutoIncludes<T>() {
  final includes = <String>{};
  final fields = T.tableDefinition.fields;

  for (final entry in fields.entries) {
    final field = entry.value;
    if (field is RelationField && !field.optional) {
      includes.add(entry.key);
    }
  }

  return includes;
}
```

**SurrealQL Generation Based on Annotation Type**
```dart
String _generateIncludeSyntax(RelationField field, IncludeSpec? spec) {
  if (field is RecordLinkField) {
    var fetch = 'FETCH ${field.name}';

    // Add filtering if specified
    if (spec?.where != null) {
      fetch += ' WHERE ${spec.where!.toSurrealQL(_db)}';
    }
    if (spec?.limit != null) {
      fetch += ' LIMIT ${spec.limit}';
    }
    if (spec?.orderBy != null) {
      fetch += ' ORDER BY ${spec.orderBy} ${spec.descending == true ? 'DESC' : 'ASC'}';
    }

    return fetch;
  } else if (field is GraphRelationField) {
    var traversal = '';
    switch (field.direction) {
      case RelationDirection.out:
        traversal = '->${field.relationName}->${field.targetTable ?? '*'}';
        break;
      case RelationDirection.in:
        traversal = '<-${field.relationName}<-${field.targetTable ?? '*'}';
        break;
      case RelationDirection.both:
        traversal = '<->${field.relationName}<->${field.targetTable ?? '*'}';
        break;
    }

    // Apply filtering on traversal results
    if (spec?.where != null) {
      traversal = '($traversal WHERE ${spec.where!.toSurrealQL(_db)})';
    }

    return traversal;
  } else if (field is EdgeTableField) {
    // Edge tables use RELATE syntax
    return _generateEdgeQuery(field, spec);
  }
}

// Handle nested includes with their own conditions
String _buildIncludeClauses(List<IncludeSpec> includes) {
  final clauses = <String>[];

  for (final include in includes) {
    final field = _getRelationField(include.relationName);
    var clause = _generateIncludeSyntax(field, include);

    // Add nested includes recursively
    if (include.include != null && include.include!.isNotEmpty) {
      clause += ' { ${_buildNestedIncludes(include.include!)} }';
    }

    clauses.add(clause);
  }

  return clauses.join(', ');
}
```

### Validation Strategy

**Pre-Send Validation**
```dart
// Validate object before every create/update
void _validateObject<T>(T object) {
  final schema = _getTableStructure<T>();
  final map = (object as dynamic).toSurrealMap();

  try {
    schema.validate(map);
  } on ValidationException catch (e) {
    throw OrmValidationException(
      'Validation failed for ${T.toString()}',
      field: e.fieldName,
      constraint: e.constraint,
      cause: e,
    );
  }
}
```

## Implementation Phases

### Phase 1: Foundation & Method Renaming (Week 1)

**Tasks:**
- Rename existing CRUD methods with "QL" suffix in `Database` class
- Add new ORM annotations: `@SurrealRecord`, `@SurrealRelation`, `@SurrealEdge`, `@SurrealId`
- Create exception types: `OrmValidationException`, `OrmSerializationException`
- Write unit tests for annotations
- Update documentation to explain dual API

**Deliverable:** Backward-compatible API with new annotations defined

### Phase 2: Serialization & Basic CRUD (Week 2)

**Tasks:**
- Extend generator to produce `toSurrealMap()` methods
- Extend generator to produce `fromSurrealMap()` methods
- Implement type-safe `create()` method
- Implement type-safe `update()` method
- Implement type-safe `delete()` method
- Handle ID field detection and extraction
- Write unit tests for serialization/deserialization
- Write integration tests for basic CRUD

**Deliverable:** Type-safe CRUD operations working with simple objects

### Phase 3: Query Builder Foundation (Week 3)

**Tasks:**
- Design query builder base class
- Generate query builder classes per entity
- Implement basic where clause generation (equals only)
- Implement limit/offset support
- Implement orderBy support
- Implement query execution with deserialization
- Write unit tests for query builder
- Write integration tests for basic queries

**Deliverable:** Query builder working with simple where clauses

### Phase 4: Advanced Where Clause DSL with Logical Operators (Week 4)

**Tasks:**
- Design WhereCondition base class hierarchy
- Generate where builder classes per entity
- Generate field condition classes with operators
- Implement all operators: equals, contains, between, ilike, any, etc.
- Implement AND operator (`&`) with proper precedence
- Implement OR operator (`|`) with proper precedence
- Support nested object property access (e.g., `t.location.lat`)
- Generate SurrealQL with proper parameter bindings
- Implement condition reduce pattern for combining multiple conditions
- Write unit tests for all operators and combinations
- Write integration tests for complex queries with AND/OR

**Deliverable:** Complete type-safe where clause DSL with logical operators

### Phase 5: Relationship System (Week 5)

**Tasks:**
- Implement record link relationship loading
- Implement graph traversal relationship loading
- Implement edge table relationship support
- Implement auto-include logic for non-optional relations
- Implement basic include methods (by name only)
- Generate relationship field detection
- Handle nested object deserialization
- Write unit tests for relationship logic
- Write integration tests for all relationship types

**Deliverable:** Core relationship system with all three types supported

### Phase 6: Advanced Include System with Filtering (Week 6)

**Tasks:**
- Design IncludeSpec class for include configuration
- Implement where clause support on includes
- Implement limit support on includes
- Implement orderBy support on includes
- Implement nested includes with independent conditions
- Generate SurrealQL for filtered includes
- Support multi-level nesting with filtering at each level
- Write unit tests for include filtering
- Write integration tests for complex nested includes
- Performance testing for deep nested queries

**Deliverable:** Complete Serverpod-style include system with filtering

### Phase 7: Integration & Documentation (Week 7)

**Tasks:**
- End-to-end integration testing with complex schemas
- Test complex combinations of where, include, logical operators
- Performance testing and optimization
- Write comprehensive user documentation
- Write migration guide from raw CRUD to ORM
- Create example applications demonstrating all features:
  - Complex where clauses with AND/OR
  - Filtered includes with nested conditions
  - Combining multiple query patterns
- Update README with ORM examples
- Update CHANGELOG with new features
- Write best practices guide

**Deliverable:** Production-ready ORM layer with complete documentation

## Out of Scope

**Future Enhancements (Separate Specs)**
- Lazy loading of relationships (everything eager by default)
- Query result caching layer
- Optimistic locking and concurrency control
- Batch operations (createAll, updateAll, deleteAll)
- Soft delete support
- Audit trail and change tracking
- Custom type converters beyond built-in types
- Query pagination helpers (page-based vs cursor-based)
- Aggregation query builders (COUNT, SUM, AVG, etc.)
- Complex JOIN operations beyond relationships

**Explicitly Excluded**
- Runtime reflection (all code generation based)
- Dynamic query building from strings
- Schema migration in ORM layer (already handled by schema generation spec)
- Raw SQL escape hatches (use QL methods instead)
- Active Record pattern (prefer repository/DAO pattern)

## Success Criteria

**Developer Experience**
- Developers can perform CRUD operations with 50% less code compared to raw methods
- Compile-time type safety catches mismatched types before runtime
- Relationship traversal is intuitive and feels natural
- Filtered includes work exactly like Serverpod examples user provided
- Logical operators (AND/OR) work seamlessly in complex queries
- Generated query builder API is discoverable via IDE autocomplete
- Error messages clearly indicate what went wrong and how to fix it

**Code Quality**
- 90%+ test coverage for generator and ORM logic
- Zero breaking changes to existing Database API
- Generated code passes all linters and analyzer checks
- No runtime performance penalty compared to raw methods
- Clear separation between generated and handwritten code

**Functionality**
- All three relationship types work correctly
- Non-optional relations always included by default
- Where clause DSL supports all common operators including AND (`&`) and OR (`|`)
- Include system supports where, limit, orderBy on relationships
- Nested includes work with independent filtering at each level
- Logical operator precedence works correctly with parentheses
- Nested object property access works in where clauses (e.g., `t.location.lat`)
- Condition combining with reduce pattern works as expected
- Query results correctly deserialize into Dart objects
- Validation prevents invalid data from reaching database
- Both fluent and direct parameter APIs work identically

**Documentation**
- Complete API documentation for all public methods
- Migration guide shows before/after code examples
- Relationship types explained with clear examples
- Include filtering documented with Serverpod-style examples
- Logical operator usage documented with precedence rules
- Best practices documented for common patterns
- Example app demonstrates all major features including:
  - Complex where clauses with AND/OR
  - Filtered includes with nested conditions
  - Condition reduce patterns

## Visual Design

No visual mockups provided. This is a programmatic API feature.

## Technical Considerations

### Where Clause Operator Generation

Generate operators based on field type:

**String Fields:**
```dart
UserQueryBuilder whereEmail({
  String? equals,
  String? notEquals,
  String? contains,
  String? ilike,
  String? startsWith,
  String? endsWith,
  List<String>? inList,
});

// Also generate condition builder methods
class UserFieldCondition<String> {
  WhereCondition equals(String value);
  WhereCondition ilike(String pattern);
  WhereCondition any(List<String> values);
  // ... other operators
}
```

**Number Fields:**
```dart
UserQueryBuilder whereAge({
  int? equals,
  int? notEquals,
  int? greaterThan,
  int? lessThan,
  int? greaterOrEqual,
  int? lessOrEqual,
  int? between_min,
  int? between_max,
  List<int>? inList,
});

// Condition builder
class UserFieldCondition<int> {
  WhereCondition equals(int value);
  WhereCondition between(int min, int max);
  // ... other operators
}
```

**Boolean Fields:**
```dart
UserQueryBuilder whereActive({
  bool? equals,
  bool? isTrue,
  bool? isFalse,
});
```

### Logical Operator Implementation

**Operator Overloading Strategy:**
```dart
// Enable & and | operators on WhereCondition
abstract class WhereCondition {
  String toSurrealQL(Database db);

  WhereCondition operator &(WhereCondition other) => AndCondition(this, other);
  WhereCondition operator |(WhereCondition other) => OrCondition(this, other);
}

// Usage
final condition = t.age.between(18, 65) & t.status.equals('active');
final condition2 = (t.age.between(0, 10) | t.age.between(90, 100));
```

**Precedence Handling:**
- Parentheses in user code map to parentheses in generated SQL
- AND has higher precedence than OR (standard SQL precedence)
- Use explicit AndCondition/OrCondition classes to maintain structure

### Include Filtering Implementation

**IncludeSpec Class Design:**
```dart
class IncludeSpec {
  final String relationName;
  final WhereCondition Function(RelationWhereBuilder)? where;
  final int? limit;
  final String? orderBy;
  final bool? descending;
  final List<IncludeSpec>? include;

  // Generated factory methods per relationship
  static IncludeSpec posts({
    WhereCondition Function(PostWhereBuilder)? where,
    int? limit,
    String? orderBy,
    bool? descending,
    List<IncludeSpec>? include,
  }) {
    return IncludeSpec('posts',
      where: where,
      limit: limit,
      orderBy: orderBy,
      descending: descending,
      include: include,
    );
  }
}
```

**SurrealQL Generation for Filtered Includes:**
```dart
// Record link with filter
FETCH posts WHERE status = 'published' LIMIT 10 ORDER BY createdAt DESC

// Nested includes with independent filters
FETCH posts WHERE status = 'published' {
  FETCH comments WHERE approved = true LIMIT 10,
  FETCH tags
} LIMIT 5
```

### Relationship Direction Enum

```dart
enum RelationDirection {
  out,  // Outgoing: ->
  in,   // Incoming: <-
  both, // Bidirectional: <->
}
```

### ID Field Detection Algorithm

```dart
String? _findIdField(ClassElement classElement) {
  // 1. Look for @SurrealId annotation
  for (final field in classElement.fields) {
    if (hasAnnotation(field, SurrealId)) {
      return field.name;
    }
  }

  // 2. Look for field named 'id'
  for (final field in classElement.fields) {
    if (field.name == 'id') {
      return field.name;
    }
  }

  // 3. No ID field found
  return null;
}
```

### Null Safety for Optional Relations

```dart
class User {
  String id;
  String name;

  // Optional relation - nullable
  @SurrealRecord()
  Profile? profile;

  // Optional relation - empty list
  @SurrealRecord()
  List<Post>? posts;

  // Non-optional relation - auto-included
  @SurrealRecord()
  Organization organization;
}
```

### Nested Object Property Access

```dart
// Support for nested properties in where clauses
class LocationCondition {
  UserFieldCondition<double> get lat => UserFieldCondition('location.lat');
  UserFieldCondition<double> get lon => UserFieldCondition('location.lon');
}

// Usage
final users = await db.query<User>()
  .where((t) =>
    (t.location.lat.between(minLat, maxLat)) &
    (t.location.lon.between(minLon, maxLon))
  )
  .execute();
```

## Standards Compliance

**Tech Stack (tech-stack.md):**
- Using Dart 3.x features (sealed classes, pattern matching, records)
- Code generation via build_runner and source_gen
- Minimal dependencies (leverage existing infrastructure)
- Integration with existing FFI layer

**Conventions (conventions.md):**
- Package structure follows Dart standards
- Generated files follow naming patterns
- Comprehensive documentation on all public APIs
- CHANGELOG.md updated with all ORM features

**Error Handling (error-handling.md):**
- Custom exception hierarchy for ORM-specific errors
- Clear error messages with context
- Validation errors are descriptive with field names
- Never ignore errors from native layer

---

**Final Note**: This specification provides a complete blueprint for implementing a type-safe ORM layer on top of the existing schema generation system. The ORM maintains full backward compatibility while providing a modern, type-safe API with advanced query filtering inspired by Serverpod. Key additions include comprehensive logical operator support (AND/OR), where clause filtering on included relationships, nested includes with independent conditions at each level, and support for complex query patterns. Implementation should proceed in phases, with each phase fully tested before moving to the next.
