# ORM Query Patterns

**Status:** ✅ Complete

This guide documents how to build complex queries using the type-safe query builder with comprehensive where clause DSL support.

## Table of Contents

- [Type-Safe Query Builder](#type-safe-query-builder)
- [Logical Operators (AND, OR)](#logical-operators-and-or)
- [Operator Precedence](#operator-precedence)
- [Field-Specific Operators](#field-specific-operators)
- [Nested Property Access](#nested-property-access)
- [Condition Reduce Pattern](#condition-reduce-pattern)
- [Legacy Where Methods](#legacy-where-methods-backward-compatibility)
- [Direct Parameter API](#direct-parameter-api)

## Type-Safe Query Builder

The query builder provides a fluent API for constructing type-safe queries with compile-time safety:

```dart
final users = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .orderBy('name')
  .limit(10)
  .execute();
```

## Logical Operators (AND, OR)

Combine conditions using the `&` (AND) and `|` (OR) operators for complex query logic:

### AND Operator (`&`)

The `&` operator creates a condition that requires **both** operands to be true:

```dart
// Find active users older than 18
final adults = await db.query<User>()
  .where((t) => t.age.greaterThan(18) & t.status.equals('active'))
  .execute();
```

**Generated SurrealQL:**
```sql
SELECT * FROM users WHERE (age > 18 AND status = 'active')
```

### OR Operator (`|`)

The `|` operator creates a condition that requires **either** operand to be true:

```dart
// Find users who are either very young or very old
final special = await db.query<User>()
  .where((t) => (t.age.lessThan(10) | t.age.greaterThan(90)))
  .execute();
```

**Generated SurrealQL:**
```sql
SELECT * FROM users WHERE (age < 10 OR age > 90)
```

### Complex Combinations

Combine AND and OR operators for sophisticated business logic:

```dart
// Find verified users who are either very young or very old
final complex = await db.query<User>()
  .where((t) =>
    (t.age.between(0, 10) | t.age.between(90, 100)) &
    t.verified.equals(true)
  )
  .execute();
```

**Generated SurrealQL:**
```sql
SELECT * FROM users
WHERE ((age >= 0 AND age <= 10 OR age >= 90 AND age <= 100) AND verified = true)
```

## Operator Precedence

Understanding operator precedence is crucial for building correct queries.

### Default Precedence

In Dart (and most languages), the `&` operator has **higher precedence** than `|`:

```dart
// This expression: a | b & c
// Is evaluated as: a | (b & c)

final condition = t.roleA.equals('admin') |
                  t.roleB.equals('editor') & t.verified.isTrue();

// Equivalent to:
final condition = t.roleA.equals('admin') |
                  (t.roleB.equals('editor') & t.verified.isTrue());
```

### Using Parentheses for Clarity

**Always use parentheses** to explicitly control precedence and improve readability:

```dart
// WITHOUT parentheses (relies on default precedence)
t.status.equals('active') | t.status.equals('pending') & t.verified.isTrue()
// Evaluated as: active | (pending & verified)

// WITH parentheses (explicit intent)
(t.status.equals('active') | t.status.equals('pending')) & t.verified.isTrue()
// Evaluated as: (active | pending) & verified
```

### Best Practices

1. **Always use parentheses** when combining AND and OR operators
2. **Group related conditions** together for clarity
3. **Test complex conditions** with unit tests to verify behavior
4. **Use comments** to explain complex business logic

## Field-Specific Operators

The query builder generates type-specific methods based on each field's type:

### String Fields

```dart
// Available operators:
t.email.equals('user@example.com')
t.email.notEquals('banned@example.com')
t.email.contains('@example.com')
t.email.ilike('%john%')                    // Case-insensitive pattern matching
t.email.startsWith('admin')
t.email.endsWith('.com')
t.status.inList(['active', 'pending'])
```

### Number Fields (int, double, num)

```dart
// Available operators:
t.age.equals(25)
t.age.notEquals(0)
t.age.greaterThan(18)
t.age.lessThan(65)
t.age.greaterOrEqual(21)
t.age.lessOrEqual(100)
t.age.between(18, 65)                     // Inclusive range
t.priority.inList([1, 2, 3])
```

### Boolean Fields

```dart
// Available operators:
t.verified.equals(true)
t.active.equals(false)
t.verified.isTrue()
t.active.isFalse()
```

### DateTime Fields

```dart
// Available operators:
t.createdAt.equals(DateTime.now())
t.createdAt.before(DateTime(2024, 1, 1))
t.createdAt.after(DateTime(2023, 1, 1))
t.createdAt.between(startDate, endDate)
```

## Nested Property Access

Access nested object properties using dot notation:

```dart
@SurrealTable('users')
class User {
  final String id;
  final String name;
  final Location location;  // Nested object
}

class Location {
  final double lat;
  final double lon;
  final String city;
}

// Query using nested properties:
final nearbyUsers = await db.query<User>()
  .where((t) =>
    (t.location.lat.between(40.0, 41.0)) &
    (t.location.lon.between(-74.0, -73.0))
  )
  .execute();
```

**Generated SurrealQL:**
```sql
SELECT * FROM users
WHERE (location.lat >= 40.0 AND location.lat <= 41.0 AND
       location.lon >= -74.0 AND location.lon <= -73.0)
```

### Multi-Level Nesting

Nest as deeply as needed:

```dart
t.user.profile.settings.notifications.email.enabled.isTrue()
```

## Condition Reduce Pattern

Dynamically combine multiple conditions when you don't know how many conditions you'll have at compile time:

### Using AND to Combine Conditions

```dart
// Example: Build filters from user selections
final filters = <WhereCondition Function(UserWhereBuilder)>[];

if (minAge != null) {
  filters.add((t) => t.age.greaterOrEqual(minAge));
}
if (maxAge != null) {
  filters.add((t) => t.age.lessOrEqual(maxAge));
}
if (status != null) {
  filters.add((t) => t.status.equals(status));
}

// Combine all filters with AND
if (filters.isNotEmpty) {
  final whereBuilder = UserWhereBuilder();
  final combinedCondition = filters
    .map((fn) => fn(whereBuilder))
    .reduce((a, b) => a & b);

  final users = await db.query<User>()
    .where((_) => combinedCondition)
    .execute();
}
```

### Using OR to Combine Conditions

```dart
// Example: Search across multiple fields
final searchTerm = 'john';
final conditions = [
  (t) => t.firstName.contains(searchTerm),
  (t) => t.lastName.contains(searchTerm),
  (t) => t.email.contains(searchTerm),
];

final whereBuilder = UserWhereBuilder();
final searchCondition = conditions
  .map((fn) => fn(whereBuilder))
  .reduce((a, b) => a | b);

final results = await db.query<User>()
  .where((_) => searchCondition)
  .execute();
```

**Generated SurrealQL:**
```sql
SELECT * FROM users
WHERE (firstName CONTAINS 'john' OR lastName CONTAINS 'john' OR email CONTAINS 'john')
```

### Combining Multiple Reduces

```dart
// Combine required filters (AND) with optional searches (OR)
final requiredFilters = [
  (t) => t.status.equals('active'),
  (t) => t.verified.isTrue(),
];

final optionalSearches = [
  (t) => t.name.contains(searchTerm),
  (t) => t.email.contains(searchTerm),
];

final whereBuilder = UserWhereBuilder();

final required = requiredFilters
  .map((fn) => fn(whereBuilder))
  .reduce((a, b) => a & b);

final optional = optionalSearches
  .map((fn) => fn(whereBuilder))
  .reduce((a, b) => a | b);

// Combine: (required AND optional)
final combined = required & optional;

final results = await db.query<User>()
  .where((_) => combined)
  .execute();
```

## Legacy Where Methods (Backward Compatibility)

For simple equality checks, legacy `where{FieldName}Equals()` methods are still available:

```dart
// Legacy method (still works)
final users = await db.query<User>()
  .whereStatusEquals('active')
  .whereVerifiedEquals(true)
  .execute();

// Equivalent modern DSL approach (recommended)
final users = await db.query<User>()
  .where((t) => t.status.equals('active') & t.verified.isTrue())
  .execute();
```

**Why use the modern DSL?**
- Supports OR operators
- Supports all comparison operators (>, <, BETWEEN, etc.)
- Better readability for complex queries
- Consistent with relationship filtering syntax

**When to use legacy methods:**
- Simple, single-field equality checks
- Migrating existing code incrementally
- Personal preference for simple queries

## Direct Parameter API

Alternative to the fluent builder pattern, useful for one-off queries:

```dart
// Direct API
final users = await db.query(
  table: 'users',
  where: GreaterThanCondition('age', 18) & EqualsCondition('status', 'active'),
  orderBy: 'name',
  limit: 10,
  offset: 0,
);

// Equivalent fluent API
final users = await db.query<User>()
  .where((t) => t.age.greaterThan(18) & t.status.equals('active'))
  .orderBy('name', ascending: true)
  .limit(10)
  .offset(0)
  .execute();
```

Both approaches generate identical SurrealQL and have the same performance characteristics.

## Complete Examples

### Example 1: E-commerce Product Search

```dart
// Find active products in a price range with specific tags
final products = await db.query<Product>()
  .where((t) =>
    t.status.equals('active') &
    t.price.between(10.0, 100.0) &
    (t.category.equals('Electronics') | t.category.equals('Computers'))
  )
  .orderBy('price', ascending: true)
  .limit(20)
  .execute();
```

### Example 2: User Access Control

```dart
// Find users with admin access OR users who own the resource
final authorizedUsers = await db.query<User>()
  .where((t) =>
    t.role.equals('admin') |
    (t.id.equals(resourceOwnerId) & t.verified.isTrue())
  )
  .execute();
```

### Example 3: Dynamic Search Filters

```dart
// Build query from UI filter selections
Future<List<User>> searchUsers({
  int? minAge,
  int? maxAge,
  List<String>? statuses,
  String? searchTerm,
}) async {
  final conditions = <WhereCondition Function(UserWhereBuilder)>[];

  // Add age filters if provided
  if (minAge != null) {
    conditions.add((t) => t.age.greaterOrEqual(minAge));
  }
  if (maxAge != null) {
    conditions.add((t) => t.age.lessOrEqual(maxAge));
  }

  // Add status filter if provided
  if (statuses != null && statuses.isNotEmpty) {
    conditions.add((t) => t.status.inList(statuses));
  }

  // Add search filter if provided
  if (searchTerm != null && searchTerm.isNotEmpty) {
    conditions.add((t) =>
      t.firstName.contains(searchTerm) |
      t.lastName.contains(searchTerm) |
      t.email.contains(searchTerm)
    );
  }

  // Combine all conditions with AND
  if (conditions.isEmpty) {
    // No filters - return all users
    return await db.query<User>().execute();
  }

  final whereBuilder = UserWhereBuilder();
  final combinedCondition = conditions
    .map((fn) => fn(whereBuilder))
    .reduce((a, b) => a & b);

  return await db.query<User>()
    .where((_) => combinedCondition)
    .orderBy('lastName', ascending: true)
    .execute();
}

// Usage:
final results = await searchUsers(
  minAge: 21,
  statuses: ['active', 'pending'],
  searchTerm: 'john',
);
```

## See Also

- [Migration Guide](./migration_guide.md) - Migrating from raw queries to ORM
- [Relationships](./relationships.md) - Working with related entities
- [API Documentation](../../README.md) - Full API reference

## Summary

The where clause DSL provides:

- **Type safety** - Compile-time errors for type mismatches
- **Logical operators** - Combine conditions with `&` (AND) and `|` (OR)
- **Field-specific operators** - Different operators for strings, numbers, booleans, dates
- **Nested property access** - Query nested object fields with dot notation
- **Dynamic queries** - Build conditions programmatically with reduce pattern
- **SQL injection prevention** - Automatic parameter binding
- **Readability** - Natural Dart syntax that's easy to understand

All queries are validated at compile-time and generate optimized SurrealQL for efficient database operations.
