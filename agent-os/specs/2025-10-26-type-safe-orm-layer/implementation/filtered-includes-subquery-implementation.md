# Filtered Includes Using Subqueries - Implementation Plan

**Date:** 2025-10-26
**Status:** 🚧 Pending Implementation
**Priority:** High (Fixes broken example scenario)

## Problem Statement

The ORM example scenario (`example/scenarios/orm_type_safe_crud.dart`) fails with a parse error:

```
QueryException: Parse error: Unexpected token `WHERE`, expected Eof
 --> [1:71]
  |
1 | ...FETCH posts WHERE status = 'published' ORDER BY createdAt DESC
  |              ^^^^^
```

**Root Cause:** SurrealDB does not support WHERE clauses directly on FETCH statements. The syntax `FETCH relationship WHERE condition` is not valid SurrealQL.

**Current Implementation:** The `relationship_loader.dart` generates invalid syntax:
```dart
// In generateFetchClause() at line ~107
if (spec?.where != null && db != null) {
  buffer.write(' WHERE ${spec!.where!.toSurrealQL(db)}');  // ❌ Invalid
}
```

## Solution Overview

**Strategy:** Detect when a filter is present and generate a subquery instead of FETCH.

### Approach 1: Subquery with `$parent` (RECOMMENDED)

**Syntax:**
```sql
SELECT *,
  (SELECT * FROM posts
   WHERE author = $parent.id AND status = 'published'
   ORDER BY createdAt DESC
   LIMIT 10) AS posts
FROM users
```

**Benefits:**
- ✅ Efficient - filters during query, doesn't fetch unnecessary data
- ✅ Supports ORDER BY and LIMIT on filtered results
- ✅ Uses `$parent` keyword for proper correlation
- ✅ Works with any foreign key relationship

### Approach 2: Fetch + Array Filter (Alternative)

**Syntax:**
```sql
SELECT *, posts[WHERE status = 'published'] AS posts
FROM users FETCH posts
```

**Limitations:**
- ⚠️ Less efficient - fetches all, then filters
- ⚠️ ORDER BY/LIMIT applies after fetching
- ✅ Simpler syntax
- ✅ Good for simple filters

**Recommendation:** Use Approach 1 (subquery) as default.

## Technical Details

### SurrealDB Capabilities

1. **Subqueries with `$parent`:**
   - `$parent` references outer query fields
   - Enables correlated subqueries
   - Example: `WHERE author = $parent.id`

2. **Array Filtering:**
   - Syntax: `array[WHERE condition]`
   - Uses `$this` to reference each item
   - Example: `posts[WHERE $this.status = 'published']`

3. **Supported Operations in Subqueries:**
   - WHERE clauses (including AND, OR)
   - ORDER BY with ASC/DESC
   - LIMIT and START
   - All comparison operators

### Implementation Strategy

**Decision Logic:**
```
IF relationship has filter OR orderBy OR limit:
    → Generate subquery: (SELECT ... WHERE foreign_key = $parent.id AND filter)
ELSE:
    → Use simple FETCH: FETCH relationship
```

## Implementation Steps

### Step 1: Update `generateFetchClause()` in `relationship_loader.dart`

**Location:** `lib/src/orm/relationship_loader.dart` lines 100-125

**Current code:**
```dart
String generateFetchClause(RecordLinkMetadata metadata, {
  IncludeSpec? spec,
  Database? db,
}) {
  final buffer = StringBuffer('FETCH ${metadata.fieldName}');

  // ❌ This is invalid SurrealQL
  if (spec?.where != null && db != null) {
    buffer.write(' WHERE ${spec!.where!.toSurrealQL(db)}');
  }

  if (spec?.orderBy != null) {
    buffer.write(' ORDER BY ${spec!.orderBy}');
    if (spec.descending == true) {
      buffer.write(' DESC');
    }
  }

  if (spec?.limit != null) {
    buffer.write(' LIMIT ${spec!.limit}');
  }

  return buffer.toString();
}
```

**New implementation:**
```dart
String generateFetchClause(RecordLinkMetadata metadata, {
  IncludeSpec? spec,
  Database? db,
}) {
  // If no filtering/sorting/limiting, use simple FETCH
  if (spec == null ||
      (spec.where == null && spec.orderBy == null && spec.limit == null)) {
    return 'FETCH ${metadata.fieldName}';
  }

  // If any filter/sort/limit exists, generate subquery
  return generateSubqueryForRelationship(metadata, spec: spec, db: db);
}
```

### Step 2: Add `generateSubqueryForRelationship()` Method

**Location:** Add new method to `lib/src/orm/relationship_loader.dart`

```dart
/// Generates a subquery for filtered relationship loading.
///
/// Creates a correlated subquery using $parent to reference the outer query.
/// This is the correct way to filter related records in SurrealDB.
///
/// Example output:
/// ```sql
/// (SELECT * FROM posts
///  WHERE author = $parent.id AND status = 'published'
///  ORDER BY createdAt DESC
///  LIMIT 10) AS posts
/// ```
String generateSubqueryForRelationship(
  RecordLinkMetadata metadata, {
  required IncludeSpec spec,
  Database? db,
}) {
  final buffer = StringBuffer();

  // Start subquery
  buffer.write('(SELECT * FROM ${_getTargetTable(metadata)}');

  // Build WHERE clause with parent correlation
  final whereClauses = <String>[];

  // Add parent correlation (e.g., author = $parent.id)
  // This connects the subquery to the outer query
  final foreignKey = _inferForeignKey(metadata);
  whereClauses.add('$foreignKey = \$parent.id');

  // Add user's filter condition
  if (spec.where != null && db != null) {
    final userFilter = spec.where!.toSurrealQL(db);
    whereClauses.add(userFilter);
  }

  // Combine all WHERE conditions with AND
  buffer.write(' WHERE ${whereClauses.join(' AND ')}');

  // Add ORDER BY if specified
  if (spec.orderBy != null) {
    buffer.write(' ORDER BY ${spec.orderBy}');
    if (spec.descending == true) {
      buffer.write(' DESC');
    }
  }

  // Add LIMIT if specified
  if (spec.limit != null) {
    buffer.write(' LIMIT ${spec.limit}');
  }

  // Close subquery and add alias
  buffer.write(') AS ${metadata.fieldName}');

  return buffer.toString();
}

/// Helper: Infer foreign key field name from relationship.
///
/// Convention examples:
/// - User -> posts: foreign key is "author" or "user_id"
/// - Post -> comments: foreign key is "post" or "post_id"
///
/// TODO: This should be configurable via annotation:
/// @SurrealRecord(foreignKey: 'user_id')
String _inferForeignKey(RecordLinkMetadata metadata) {
  // For now, use a simple convention
  // Future: Add foreignKey parameter to @SurrealRecord annotation

  // Try to infer from parent table name
  if (metadata.parentTableName != null) {
    // Convert "users" -> "user" or keep singular
    final singular = _singularize(metadata.parentTableName!);
    return singular; // e.g., "user", "post", "author"
  }

  // Default fallback (should be made configurable)
  return 'author'; // or throw error requiring explicit configuration
}

/// Helper: Get target table name from metadata.
String _getTargetTable(RecordLinkMetadata metadata) {
  // Use explicit table name if provided
  if (metadata.explicitTableName != null) {
    return metadata.explicitTableName!;
  }

  // Otherwise, pluralize the target type
  // Example: "Post" -> "posts"
  return _pluralize(metadata.targetType.toLowerCase());
}

/// Helper: Convert plural to singular (simple implementation).
String _singularize(String word) {
  if (word.endsWith('s')) {
    return word.substring(0, word.length - 1);
  }
  return word;
}

/// Helper: Convert singular to plural (simple implementation).
String _pluralize(String word) {
  // Simple pluralization (enhance as needed)
  if (word.endsWith('s') || word.endsWith('x') || word.endsWith('ch')) {
    return '${word}es';
  }
  if (word.endsWith('y')) {
    return '${word.substring(0, word.length - 1)}ies';
  }
  return '${word}s';
}
```

### Step 3: Update Query Builder Generation

**Location:** `lib/generator/surreal_table_generator.dart`

**Current approach in `_generateExecuteMethod()`:**
```dart
// Builds: SELECT * FROM table WHERE ... FETCH relation
final query = 'SELECT * FROM \$tableName \$whereClause \$fetchClause';
```

**New approach:**
```dart
String _generateExecuteMethod(TableStructure structure) {
  return '''
  Future<List<${structure.className}>> execute() async {
    // Build SELECT with subquery fields for filtered includes
    final selectFields = <String>['*'];

    // Add subquery for each filtered include
    for (final include in _filteredIncludes) {
      final subquery = generateSubqueryForRelationship(include);
      selectFields.add(subquery);
    }

    final selectClause = selectFields.join(', ');
    final query = 'SELECT \$selectClause FROM \$tableName';

    // Add WHERE, ORDER BY, LIMIT from main query
    if (_whereCondition != null) {
      query += ' WHERE \${_whereCondition!.toSurrealQL(_db)}';
    }

    // ... rest of query building

    // Add simple FETCH for non-filtered includes
    if (_simpleFetches.isNotEmpty) {
      query += ' FETCH ' + _simpleFetches.join(', ');
    }

    // Execute query and deserialize
    final response = await _db.queryQL(query);
    return response.getResults()
        .map((m) => ${structure.className}ORM.fromSurrealMap(m))
        .toList();
  }
  ''';
}
```

### Step 4: Enhance Annotations with Foreign Key Configuration

**Location:** `lib/src/schema/orm_annotations.dart`

**Add foreignKey parameter to @SurrealRecord:**
```dart
class SurrealRecord {
  /// Optional explicit table name for the target records.
  /// If not provided, inferred from the field type.
  final String? tableName;

  /// Optional explicit foreign key field name in the target table.
  /// If not provided, inferred from naming conventions.
  ///
  /// Example: For User -> posts relationship, this could be:
  /// - 'author' (if posts table has 'author' field)
  /// - 'user_id' (if posts table has 'user_id' field)
  final String? foreignKey;

  const SurrealRecord({this.tableName, this.foreignKey});
}
```

**Usage example:**
```dart
@SurrealTable('users')
class User {
  @SurrealId()
  String? id;

  // Infers foreign key as 'user' or 'author'
  @SurrealRecord()
  List<Post>? posts;

  // Explicitly specifies foreign key
  @SurrealRecord(foreignKey: 'user_id')
  List<Comment>? comments;
}
```

### Step 5: Fix Example Scenario

**Location:** `example/scenarios/orm_type_safe_crud.dart`

**Replace broken query (around line 270-280):**

```dart
// BEFORE (❌ Broken):
print('Filtered Include (Only published posts):');
print('  ORM: db.query<User>()');
print('        .include(\'posts\',');
print('          where: (p) => p.status.equals(\'published\'),');
print('          orderBy: \'createdAt\',');
print('          descending: true');
print('        )');
print('        .execute()');
print('');
final filteredInclude = await db.queryQL(
  'SELECT *, posts.* FROM users WHERE name = \'Alice Johnson\' '
  'FETCH posts WHERE status = \'published\' ORDER BY createdAt DESC',
);

// AFTER (✅ Working):
print('Filtered Include (Only published posts):');
print('  ORM: db.query<User>()');
print('        .include(\'posts\',');
print('          where: (p) => p.status.equals(\'published\'),');
print('          orderBy: \'createdAt\',');
print('          descending: true');
print('        )');
print('        .execute()');
print('');
print('Generated SurrealQL (uses subquery):');
print('  SELECT *, ');
print('    (SELECT * FROM posts ');
print('     WHERE author = \$parent.id AND status = \'published\'');
print('     ORDER BY createdAt DESC) AS posts');
print('  FROM users WHERE name = \'Alice Johnson\'');
print('');

final filteredInclude = await db.queryQL(
  'SELECT *, '
  '(SELECT * FROM posts WHERE author = \$parent.id AND status = \'published\' '
  'ORDER BY createdAt DESC LIMIT 5) AS posts '
  'FROM users WHERE name = \'Alice Johnson\'',
);
```

**Also update the basic include example (around line 250):**
```dart
// Keep FETCH for simple includes (no filter)
final basicInclude = await db.queryQL(
  'SELECT *, author FROM posts FETCH author'
);
```

### Step 6: Update Tests

**Location:** `test/orm/filtered_include_test.dart`

**Update test expectations:**
```dart
// BEFORE:
test('Generate FETCH clause with WHERE condition', () {
  final clause = generateFetchClause(metadata, spec: spec, db: db);
  expect(clause, 'FETCH posts WHERE status = \'published\'');
});

// AFTER:
test('Generate subquery for filtered include', () {
  final clause = generateFetchClause(metadata, spec: spec, db: db);
  expect(clause, contains('(SELECT * FROM posts'));
  expect(clause, contains('WHERE author = \$parent.id'));
  expect(clause, contains('AND status = \'published\''));
  expect(clause, endsWith(') AS posts'));
});
```

**Location:** `test/orm/record_link_relationship_test.dart`

**Update similar tests:**
```dart
test('Generate filtered include with ORDER BY and LIMIT', () {
  final clause = generateFetchClause(metadata, spec: spec, db: db);
  expect(clause, contains('(SELECT * FROM posts'));
  expect(clause, contains('ORDER BY createdAt DESC'));
  expect(clause, contains('LIMIT 10'));
});
```

## Files to Modify

### Core Implementation (Required)

1. **`lib/src/orm/relationship_loader.dart`**
   - Modify `generateFetchClause()` to detect filters
   - Add `generateSubqueryForRelationship()` method
   - Add helper methods: `_inferForeignKey()`, `_getTargetTable()`, `_singularize()`, `_pluralize()`

2. **`lib/generator/surreal_table_generator.dart`**
   - Update `_generateExecuteMethod()` to use subqueries for filtered includes
   - Track filtered vs simple includes separately

3. **`lib/src/schema/orm_annotations.dart`**
   - Add `foreignKey` parameter to `SurrealRecord` annotation

### Examples (Required to Fix Error)

4. **`example/scenarios/orm_type_safe_crud.dart`**
   - Fix broken FETCH WHERE queries around line 270-280
   - Use valid subquery syntax
   - Add explanatory comments

### Tests (Required for Verification)

5. **`test/orm/filtered_include_test.dart`**
   - Update 8 tests to expect subquery syntax
   - Verify `$parent` correlation
   - Test ORDER BY, LIMIT in subqueries

6. **`test/orm/record_link_relationship_test.dart`**
   - Update tests to expect subquery syntax
   - Add tests for simple FETCH (no filter)

### RelationshipMetadata Enhancement (Optional)

7. **`lib/src/orm/relationship_metadata.dart`**
   - Add `foreignKey` field to `RecordLinkMetadata`
   - Add `parentTableName` field for inference
   - Update constructors

## Testing Strategy

### Unit Tests

1. **Simple includes (no filter):**
   ```dart
   test('Simple include uses FETCH', () {
     final clause = generateFetchClause(metadata); // No spec
     expect(clause, 'FETCH posts');
   });
   ```

2. **Filtered includes:**
   ```dart
   test('Filtered include uses subquery', () {
     final spec = IncludeSpec('posts', where: EqualsCondition('status', 'published'));
     final clause = generateFetchClause(metadata, spec: spec, db: db);
     expect(clause, contains('(SELECT * FROM posts'));
     expect(clause, contains('\$parent.id'));
   });
   ```

3. **Complex filters with ORDER BY and LIMIT:**
   ```dart
   test('Subquery includes ORDER BY and LIMIT', () {
     final spec = IncludeSpec(
       'posts',
       where: EqualsCondition('status', 'published'),
       orderBy: 'createdAt',
       descending: true,
       limit: 5,
     );
     final clause = generateFetchClause(metadata, spec: spec, db: db);
     expect(clause, contains('ORDER BY createdAt DESC'));
     expect(clause, contains('LIMIT 5'));
   });
   ```

### Integration Tests

1. **Run ORM example scenario:**
   ```bash
   dart run example/cli_example.dart
   # Select option 6: Type-Safe ORM Layer
   # Should complete without parse errors
   ```

2. **Test with real database:**
   ```dart
   test('Filtered include works with real database', () async {
     final db = await Database.connect(...);

     // Create test data
     await db.createQL('users', {'name': 'Alice'});
     await db.createQL('posts', {'title': 'Post 1', 'status': 'published'});

     // Query with filtered include using generated code
     final query = 'SELECT *, (SELECT * FROM posts WHERE author = \$parent.id AND status = \'published\') AS posts FROM users';
     final result = await db.queryQL(query);

     expect(result.getResults(), isNotEmpty);
   });
   ```

### Manual Testing

1. Test example scenario runs without errors
2. Verify subquery generates correct results
3. Check filtered includes return only matching records
4. Confirm ORDER BY and LIMIT work in subqueries

## Benefits of This Implementation

### Technical Benefits

1. **✅ Works with Current SurrealDB** - Uses supported subquery syntax
2. **✅ More Efficient** - Filters during query, doesn't fetch unnecessary data
3. **✅ Full Feature Support** - ORDER BY, LIMIT, complex WHERE all work
4. **✅ Type-Safe** - Maintains compile-time safety of ORM
5. **✅ Flexible** - Supports custom foreign key configuration

### User Experience Benefits

1. **✅ Clean API** - `.include('posts', where: ...)` stays the same
2. **✅ No Breaking Changes** - Existing code continues to work
3. **✅ Automatic** - Code generation handles complexity
4. **✅ Configurable** - Can specify custom foreign keys when needed
5. **✅ Performant** - Generates optimal queries

### Implementation Benefits

1. **✅ Extensible** - Easy to add more features later
2. **✅ Testable** - Clear separation of concerns
3. **✅ Maintainable** - Well-documented code
4. **✅ Future-Proof** - Can adapt if SurrealDB adds native support

## Migration Path

### For End Users (No Changes Required)

```dart
// This code doesn't change:
final users = await db.query<User>()
  .include('posts',
    where: (p) => p.status.equals('published'),
    orderBy: 'createdAt',
    limit: 5
  )
  .execute();

// Behind the scenes:
// BEFORE: Generated invalid FETCH WHERE (broken)
// AFTER: Generates working subquery (fixed)
```

### For Library Developers

1. Update `relationship_loader.dart` with new logic
2. Update tests to expect subquery syntax
3. Fix example scenario
4. Document subquery approach
5. Consider adding `foreignKey` configuration

## Future Enhancements

### Short Term

1. **Smart Foreign Key Inference**
   - Analyze field names in target table
   - Use TableStructure metadata
   - Fallback to conventions

2. **Validation**
   - Warn if foreign key doesn't exist in target table
   - Suggest correct foreign key names
   - Lint rules for common mistakes

### Medium Term

3. **Bidirectional Inference**
   - Detect reverse relationships automatically
   - Generate both sides of relationship
   - Maintain referential integrity

4. **Performance Optimization**
   - Cache foreign key mappings
   - Optimize subquery generation
   - Batch relationship loading

### Long Term

5. **GraphQL-Style Includes**
   - Nested include specifications
   - Field selection within includes
   - Recursive depth limits

6. **Query Optimization**
   - Detect N+1 queries
   - Automatic batching
   - Connection pooling awareness

## References

### SurrealDB Documentation

- **Subqueries:** https://surrealdb.com/docs/surrealql/statements/select
- **$parent keyword:** Used in correlated subqueries to reference outer query
- **Array filtering:** `array[WHERE condition]` syntax
- **Record links:** https://surrealdb.com/docs/surrealql/datamodel/records

### Related Issues

- Example error: `QueryException: Parse error: Unexpected token 'WHERE'`
- SurrealDB Issue #1372: "How to refer parent fields in a Sub query?"
- Blog: "Thinking Inside The Box: Relational Style Joins in SurrealDB"

### Implementation Examples

```sql
-- Correlated subquery (RECOMMENDED)
SELECT *,
  (SELECT * FROM posts
   WHERE author = $parent.id AND status = 'published'
   ORDER BY createdAt DESC LIMIT 5) AS posts
FROM users;

-- Array filtering (ALTERNATIVE)
SELECT *, posts[WHERE status = 'published'] AS filtered_posts
FROM users FETCH posts;

-- Simple FETCH (NO FILTER)
SELECT * FROM users FETCH posts, profile;
```

## Implementation Checklist

- [ ] Update `generateFetchClause()` in `relationship_loader.dart`
- [ ] Add `generateSubqueryForRelationship()` method
- [ ] Add helper methods for table/key inference
- [ ] Update query builder in `surreal_table_generator.dart`
- [ ] Add `foreignKey` parameter to `@SurrealRecord` annotation
- [ ] Fix example scenario queries
- [ ] Update test expectations
- [ ] Run tests to verify all pass
- [ ] Test example scenario manually
- [ ] Update documentation
- [ ] Commit changes

## Notes for Future Developer

- The key insight is that `FETCH` doesn't support WHERE, but subqueries do
- `$parent` is the magic keyword that makes correlated subqueries work
- Always add `foreign_key = $parent.id` to correlate inner and outer queries
- Simple includes (no filter) should still use FETCH for efficiency
- Foreign key inference is convention-based but should be configurable
- Tests mock the subquery generation, make sure they test real database too

---

**Ready to implement!** This document contains everything needed to fix the filtered includes issue and make the ORM example work correctly.
