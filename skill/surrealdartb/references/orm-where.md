# ORM & Type-Safe Where Conditions

**Primary File:** `lib/src/orm/where_condition.dart`

## WhereCondition Base

Abstract base class for type-safe query conditions.

```dart
abstract class WhereCondition {
  String toSurrealQL(Database db);

  WhereCondition operator &(WhereCondition other);  // AND
  WhereCondition operator |(WhereCondition other);  // OR
}
```

**Usage with similarity search:**
```dart
final results = await db.searchSimilar(
  table: 'products',
  field: 'embedding',
  queryVector: vec,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: condition,  // WhereCondition
);
```

## Logical Operators

### AndCondition

```dart
AndCondition(WhereCondition left, WhereCondition right)
```

**Example:**
```dart
final cond = AndCondition(
  EqualsCondition('status', 'active'),
  GreaterThanCondition('age', 18),
);
```

**Operator shorthand:**
```dart
final cond = EqualsCondition('status', 'active') &
             GreaterThanCondition('age', 18);
```

### OrCondition

```dart
OrCondition(WhereCondition left, WhereCondition right)
```

**Example:**
```dart
final cond = EqualsCondition('role', 'admin') |
             EqualsCondition('role', 'moderator');
```

## Equality Conditions

### EqualsCondition

```dart
EqualsCondition(String field, dynamic value)
```

**Example:**
```dart
EqualsCondition('status', 'active')
EqualsCondition('count', 5)
EqualsCondition('verified', true)
```

### NotEqualsCondition

```dart
NotEqualsCondition(String field, dynamic value)
```

**Example:**
```dart
NotEqualsCondition('status', 'deleted')
```

## Comparison Conditions

### GreaterThanCondition

```dart
GreaterThanCondition(String field, num value)
```

**Example:**
```dart
GreaterThanCondition('age', 18)
GreaterThanCondition('price', 99.99)
```

### LessThanCondition

```dart
LessThanCondition(String field, num value)
```

### GreaterOrEqualCondition

```dart
GreaterOrEqualCondition(String field, num value)
```

### LessOrEqualCondition

```dart
LessOrEqualCondition(String field, num value)
```

### BetweenCondition

```dart
BetweenCondition(String field, num min, num max)
```

**Example:**
```dart
BetweenCondition('age', 18, 65)
BetweenCondition('price', 10.0, 100.0)
```

## String Conditions

### ContainsCondition

```dart
ContainsCondition(String field, String substring)
```

**Example:**
```dart
ContainsCondition('title', 'flutter')
```

### IlikeCondition

Case-insensitive pattern matching.

```dart
IlikeCondition(String field, String pattern)
```

**Example:**
```dart
IlikeCondition('email', '%@gmail.com')
```

### StartsWithCondition

```dart
StartsWithCondition(String field, String prefix)
```

**Example:**
```dart
StartsWithCondition('name', 'John')
```

### EndsWithCondition

```dart
EndsWithCondition(String field, String suffix)
```

**Example:**
```dart
EndsWithCondition('filename', '.pdf')
```

## Collection Conditions

### InListCondition

```dart
InListCondition(String field, List<dynamic> values)
```

**Example:**
```dart
InListCondition('status', ['active', 'pending', 'verified'])
InListCondition('priority', [1, 2, 3])
```

## Type-Safe Field Builders

**File:** `lib/src/orm/where_builder.dart`

Fluent API for building conditions with type safety.

### StringFieldCondition

```dart
StringFieldCondition(String field)
```

**Methods:**
```dart
.equals(String value)              → EqualsCondition
.contains(String substring)        → ContainsCondition
.startsWith(String prefix)         → StartsWithCondition
.endsWith(String suffix)           → EndsWithCondition
.ilike(String pattern)             → IlikeCondition
```

**Example:**
```dart
final cond = StringFieldCondition('email')
  .contains('@gmail.com');

final pattern = StringFieldCondition('name')
  .ilike('john%');
```

### NumberFieldCondition

```dart
NumberFieldCondition(String field)
```

**Methods:**
```dart
.equals(num value)                 → EqualsCondition
.greaterThan(num value)            → GreaterThanCondition
.lessThan(num value)               → LessThanCondition
.greaterOrEqual(num value)         → GreaterOrEqualCondition
.lessOrEqual(num value)            → LessOrEqualCondition
.between(num min, num max)         → BetweenCondition
```

**Example:**
```dart
final cond = NumberFieldCondition('age')
  .between(18, 65);

final price = NumberFieldCondition('price')
  .greaterOrEqual(10.0);
```

### BoolFieldCondition

```dart
BoolFieldCondition(String field)
```

**Methods:**
```dart
.isTrue()                          → EqualsCondition(field, true)
.isFalse()                         → EqualsCondition(field, false)
```

**Example:**
```dart
final active = BoolFieldCondition('active').isTrue();
final deleted = BoolFieldCondition('deleted').isFalse();
```

### DateTimeFieldCondition

```dart
DateTimeFieldCondition(String field)
```

**Methods:**
```dart
.equals(DateTime date)             → EqualsCondition
.after(DateTime date)              → GreaterThanCondition
.before(DateTime date)             → LessThanCondition
.between(DateTime start, DateTime end) → BetweenCondition
```

**Example:**
```dart
final recent = DateTimeFieldCondition('created_at')
  .after(DateTime(2024, 1, 1));

final range = DateTimeFieldCondition('published')
  .between(startDate, endDate);
```

## Complex Condition Composition

### Combining Multiple Conditions

```dart
// Age between 18-65 AND status active
final cond1 = NumberFieldCondition('age').between(18, 65);
final cond2 = StringFieldCondition('status').equals('active');
final combined = cond1 & cond2;
```

### Nested Logical Operators

```dart
// (role = admin OR role = moderator) AND active = true
final roleCondition =
  StringFieldCondition('role').equals('admin') |
  StringFieldCondition('role').equals('moderator');

final activeCondition = BoolFieldCondition('active').isTrue();

final final = roleCondition & activeCondition;
```

### With Vector Search

```dart
final categoryFilter = StringFieldCondition('category')
  .equals('electronics');

final priceFilter = NumberFieldCondition('price')
  .between(100, 1000);

final results = await db.searchSimilar(
  table: 'products',
  field: 'embedding',
  queryVector: queryVec,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: categoryFilter & priceFilter,
);
```

## Common Patterns

### Active Records

```dart
final active = BoolFieldCondition('active').isTrue() &
               NotEqualsCondition('deleted_at', null);
```

### Date Ranges

```dart
final thisYear = DateTimeFieldCondition('created_at')
  .between(DateTime(2024, 1, 1), DateTime(2024, 12, 31));
```

### Multi-Status Filter

```dart
final validStatuses = InListCondition('status',
  ['active', 'pending', 'processing']
);
```

### Price Range with Category

```dart
final filter =
  StringFieldCondition('category').equals('books') &
  NumberFieldCondition('price').between(10, 50);
```

### Search with Exclusions

```dart
final filter =
  ContainsCondition('title', 'flutter') &
  NotEqualsCondition('status', 'archived');
```

### Complex Business Logic

```dart
// Premium users OR users with high engagement
final premium = BoolFieldCondition('is_premium').isTrue();
final highEngagement = NumberFieldCondition('posts_count').greaterThan(100);
final targetUsers = premium | highEngagement;

// Active and verified
final verified = BoolFieldCondition('verified').isTrue();
final active = StringFieldCondition('status').equals('active');

// Final condition
final final = targetUsers & verified & active;
```

## Generated WHERE Clause

Conditions automatically convert to SurrealQL:

```dart
EqualsCondition('status', 'active')
// → status = 'active'

NumberFieldCondition('age').between(18, 65)
// → age >= 18 AND age <= 65

StringFieldCondition('email').contains('@gmail')
// → email CONTAINS '@gmail'

InListCondition('role', ['admin', 'mod'])
// → role IN ['admin', 'mod']

complex & condition
// → (complex) AND (condition)
```

## Usage in Raw Queries

While primarily used with ORM features, can generate SQL:

```dart
final condition = EqualsCondition('active', true);
final sql = condition.toSurrealQL(db);

await db.queryQL('SELECT * FROM users WHERE $sql');
```

## Gotchas

1. **Type Safety:** Use typed builders (StringFieldCondition, etc.) for compile-time safety
2. **Null Handling:** SurrealDB null handling differs from Dart - use carefully
3. **String Escaping:** Values automatically escaped in SurrealQL generation
4. **Operator Precedence:** Use parentheses (via & and |) for complex logic
5. **Date Formatting:** DateTime automatically converted to SurrealDB datetime format
6. **In List:** Empty list in InListCondition creates valid but matches-nothing query
