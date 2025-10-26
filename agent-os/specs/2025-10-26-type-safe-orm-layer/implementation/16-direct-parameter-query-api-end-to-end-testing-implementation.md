# Task 16: Direct Parameter Query API & End-to-End Testing

## Overview
**Task Reference:** Task #16 from `agent-os/specs/2025-10-26-type-safe-orm-layer/tasks.md`
**Implemented By:** api-engineer
**Date:** 2025-10-26
**Status:** Complete

### Task Description
Implement the direct parameter query API for the ORM layer, enabling developers to use a single method call with named parameters to execute type-safe queries with where clauses, includes, sorting, and pagination. This task also includes comprehensive end-to-end testing to verify the query API works correctly with all parameters.

## Implementation Summary

I implemented a direct parameter API for querying that accepts all query configuration as named parameters in a single method call. The implementation provides an alternative to the fluent builder API that will be developed in future task groups. This direct API is simpler and more concise for straightforward queries while still supporting complex where clauses using logical operators (AND/OR).

The implementation includes:
1. Created `WhereCondition` base class with operator overloading for `&` (AND) and `|` (OR)
2. Created `IncludeSpec` class for relationship filtering configuration
3. Added `query()` method to `Database` class with named parameters
4. Implemented SurrealQL generation from where conditions and parameters
5. Wrote 13 comprehensive tests covering all query patterns and edge cases

All tests pass successfully, demonstrating that the direct parameter query API works correctly for simple queries, complex where clauses with logical operators, sorting, pagination, and placeholder include support.

## Files Changed/Created

### New Files
- `lib/src/orm/where_condition.dart` - Base class and implementations for type-safe where conditions with logical operator support
- `lib/src/orm/include_spec.dart` - Specification class for relationship includes with filtering, sorting, and limiting
- `test/unit/orm_direct_query_api_test.dart` - Comprehensive tests for the direct parameter query API (13 tests)

### Modified Files
- `lib/src/database.dart` - Added imports for ORM classes and implemented `query()` method with named parameters
- `lib/surrealdartb.dart` - Exported `WhereCondition`, condition classes, and `IncludeSpec` for public API

## Key Implementation Details

### WhereCondition Base Class and Hierarchy
**Location:** `lib/src/orm/where_condition.dart`

Created an abstract base class `WhereCondition` that defines the interface for all where conditions. The key design decision was to implement operator overloading for `&` (AND) and `|` (OR) to enable natural composition of conditions:

```dart
abstract class WhereCondition {
  String toSurrealQL(Database db);
  WhereCondition operator &(WhereCondition other) => AndCondition(this, other);
  WhereCondition operator |(WhereCondition other) => OrCondition(this, other);
}
```

Implemented concrete condition classes:
- `AndCondition` and `OrCondition` for logical operators with proper precedence (parentheses)
- `EqualsCondition<T>` for equality comparisons
- `GreaterThanCondition<T>` and `LessThanCondition<T>` for numeric comparisons
- `BetweenCondition<T>` for range queries
- `ContainsCondition` for string pattern matching

**Rationale:** Operator overloading provides an intuitive and type-safe way to combine conditions. The precedence is automatically handled by Dart's operator precedence rules, and parentheses in user code translate directly to parentheses in the generated SQL.

### IncludeSpec Configuration Class
**Location:** `lib/src/orm/include_spec.dart`

Created a configuration class for specifying relationship includes with optional filtering:

```dart
class IncludeSpec {
  final String relationName;
  final WhereCondition? where;
  final int? limit;
  final String? orderBy;
  final bool? descending;
  final List<IncludeSpec>? include; // Nested includes
}
```

**Rationale:** This provides a clean API for configuring relationship loading that matches Serverpod's pattern. The class is simple and immutable, making it easy to construct and compose. The nested `include` field enables multi-level relationship loading with independent filtering at each level.

### Direct Parameter Query Method
**Location:** `lib/src/database.dart` (lines 1271-1390)

Implemented the `query()` method with all parameters as named arguments:

```dart
Future<List<Map<String, dynamic>>> query({
  required String table,
  WhereCondition? where,
  List<IncludeSpec>? include,
  String? orderBy,
  bool ascending = true,
  int? limit,
  int? offset,
}) async
```

The method builds a SurrealQL query string by:
1. Starting with `SELECT * FROM {table}`
2. Adding `WHERE` clause if `where` is provided
3. Adding `ORDER BY` clause if `orderBy` is provided
4. Adding `LIMIT` clause if `limit` is provided
5. Adding `START` (offset) clause if `offset` is provided

**Rationale:** This direct parameter approach is simpler than a fluent builder for straightforward queries. All parameters are optional except the table name, making it easy to use for simple cases while still supporting complex queries. The method reuses existing query infrastructure (`dbQuery()` and `_processResponse()`) to avoid code duplication.

### SurrealQL Generation from Conditions
**Location:** `lib/src/orm/where_condition.dart` (various `toSurrealQL` methods)

Each condition class implements `toSurrealQL()` to convert itself to a SurrealQL string fragment:

```dart
// EqualsCondition
String toSurrealQL(Database db) {
  return '$fieldPath = ${_formatValue(value)}';
}

// AndCondition
String toSurrealQL(Database db) {
  return '(${left.toSurrealQL(db)} AND ${right.toSurrealQL(db)})';
}
```

The `_formatValue()` helper properly escapes strings and formats different value types for SurrealQL.

**Rationale:** Having each condition generate its own SQL fragment is clean and composable. The recursive nature of `toSurrealQL()` in `AndCondition` and `OrCondition` naturally handles nested conditions. Proper value formatting prevents SQL injection and ensures correct query syntax.

## Testing

### Test Files Created/Updated
- `test/unit/orm_direct_query_api_test.dart` - All 13 tests for direct query API

### Test Coverage
- Unit tests: Complete (13 tests covering all query patterns)
- Integration tests: Complete (end-to-end database operations)
- Edge cases covered:
  - Empty table name validation
  - Non-existent table handling
  - Simple queries with single parameter
  - Complex queries with all parameters combined
  - AND operator combinations
  - OR operator combinations
  - Mixed AND/OR with proper precedence
  - Sorting (ascending and descending)
  - Pagination (limit and offset)
  - Include placeholder functionality

### Manual Testing Performed
All 13 tests pass successfully:

```
dart test test/unit/orm_direct_query_api_test.dart
00:09 +13: All tests passed!
```

Tests verified:
1. Simple query with table parameter only - creates data and retrieves all records
2. Query with limit parameter - verifies only requested number of records returned
3. Query with orderBy parameter - verifies results sorted correctly
4. Query with orderBy descending - verifies descending sort order
5. Query with simple where condition - filters by single field
6. Query with AND condition using & operator - combines two conditions
7. Query with OR condition using | operator - alternative conditions
8. Query with complex combined conditions - nested AND/OR with precedence
9. Query with all parameters combined - comprehensive integration test
10. Query with offset parameter - pagination support
11. Query with empty table name throws ArgumentError - validation
12. Query returns empty list for non-existent table - graceful handling
13. Query with IncludeSpec placeholder - future functionality acknowledged

## User Standards & Preferences Compliance

### Coding Style (coding-style.md)
My implementation follows Effective Dart guidelines:
- Used `camelCase` for variable and method names (`query`, `whereCondition`, `orderBy`)
- Used `PascalCase` for class names (`WhereCondition`, `IncludeSpec`, `AndCondition`)
- Kept functions focused and single-purpose (each condition class has one responsibility)
- Used arrow syntax for simple one-line methods where appropriate
- Marked all variables `final` unless they need to be reassigned
- Provided explicit type annotations for all public APIs

**Deviations:** None

### Conventions (conventions.md)
Followed Dart package conventions:
- Placed ORM classes in `lib/src/orm/` subdirectory
- Used library-level documentation comments
- Exported public APIs through `lib/surrealdartb.dart`
- Provided comprehensive dartdoc documentation on all public classes and methods
- Included example code in documentation

**Deviations:** None

### Error Handling (error-handling.md)
Implemented proper error handling:
- Validated input parameters (`ArgumentError` for empty table name)
- Used existing exception hierarchy (`QueryException` for query failures)
- Preserved database errors and error context
- Clear error messages that guide users to the problem

**Deviations:** None

### Tech Stack (tech-stack.md)
Used Dart 3.x features appropriately:
- Null safety throughout (nullable parameters with `?`)
- Named parameters with clear semantics
- Generic types for type-safe conditions (`WhereCondition<T>`)
- Future-based async API consistent with existing codebase

**Deviations:** None

## Integration Points

### APIs/Endpoints
The `query()` method integrates with existing Database infrastructure:
- Uses `dbQuery()` FFI binding for query execution
- Uses `_processResponse()` for result deserialization
- Reuses parameter binding infrastructure
- Returns `Future<List<Map<String, dynamic>>>` consistent with `selectQL()`

### Internal Dependencies
- Depends on existing FFI bindings (`dbQuery`, `_processResponse`)
- Depends on existing exception types (`QueryException`, `ArgumentError`)
- Works within existing connection management and resource handling

## Known Issues & Limitations

### Limitations
1. **Include Filtering Not Yet Implemented**
   - Description: The `include` parameter accepts `IncludeSpec` objects but doesn't yet generate FETCH clauses
   - Reason: Full implementation requires relationship detection from Task Groups 11-15
   - Future Consideration: Will be implemented when relationship system is complete
   - Workaround: Includes are accepted but currently ignored; documented in method comments

2. **Parameter Binding Not Yet Implemented**
   - Description: Where conditions use string formatting instead of parameter binding via `db.set()`
   - Reason: Simplified implementation for Task Group 16; proper parameter binding will be added in future task groups
   - Future Consideration: Will implement parameter binding when query builder infrastructure is complete
   - Workaround: Values are escaped using `_formatValue()` to prevent basic injection

3. **Returns Map Instead of Typed Objects**
   - Description: Query method returns `Future<List<Map<String, dynamic>>>` instead of typed objects
   - Reason: Object deserialization requires code generation from Task Groups 4-5
   - Future Consideration: Will return typed objects once serialization is implemented
   - Workaround: Users work with Maps, which is already familiar from `selectQL()`

## Performance Considerations
- Direct parameter approach has minimal overhead compared to fluent builder (no intermediate objects)
- Query string building is efficient using `StringBuffer`
- Reuses existing FFI infrastructure without additional allocations
- Where condition composition creates lightweight wrapper objects

## Security Considerations
- Value formatting in `_formatValue()` escapes single quotes to prevent basic SQL injection
- ArgumentError validation prevents empty table names
- Future parameter binding will provide complete SQL injection protection

## Dependencies for Other Tasks
- Task Group 6 (Query Builder Base Classes) will use `WhereCondition` hierarchy
- Task Group 7 (Database query() Factory Method) will create builders that return `WhereCondition` instances
- Task Groups 8-10 (Advanced Where Clause DSL) will extend the condition classes
- Task Groups 14-15 (Include System) will use `IncludeSpec` for relationship loading

## Notes
- This implementation provides a working direct parameter API that can be used immediately
- The API surface is stable and won't change when fluent builders are added
- Tests demonstrate the API works end-to-end with real database operations
- Include placeholder acknowledges future functionality without breaking the API
- Implementation is intentionally simple to avoid over-engineering before full ORM infrastructure is in place
