# Parameters & Functions

## Parameter Management

### set()

Set query parameter value.

```dart
Future<void> set(String name, dynamic value)
```

**Example:**
```dart
await db.set('minAge', 18);
await db.set('status', 'active');
await db.set('tags', ['flutter', 'dart']);
```

**Usage in queries:**
```dart
await db.set('threshold', 100);

final result = await db.queryQL('''
  SELECT * FROM products WHERE price > \$threshold
''');
```

### unset()

Remove parameter.

```dart
Future<void> unset(String name)
```

**Example:**
```dart
await db.unset('minAge');
```

## Parameter Syntax

Parameters referenced with `$` prefix in SurrealQL:

```dart
await db.set('name', 'Alice');
await db.set('age', 30);

await db.queryQL('''
  CREATE users SET name = \$name, age = \$age
''');
```

## Alternative: Inline Parameters

Use bindings map in queryQL():

```dart
await db.queryQL('''
  SELECT * FROM users WHERE age > \$minAge AND status = \$status
''', {
  'minAge': 18,
  'status': 'active',
});
```

**Comparison:**

| Method | Scope | Usage |
|--------|-------|-------|
| `set()` | Global (all queries) | Persistent values |
| Bindings | Single query | One-time values |

## Function Execution

### run()

Execute SurrealDB functions.

```dart
Future<T?> run<T>(String functionName, [List<dynamic>? args])
```

**Example:**
```dart
// No arguments
final version = await db.run<String>('version');

// With arguments
final result = await db.run<double>('math::sqrt', [16]);  // 4.0
final upper = await db.run<String>('string::uppercase', ['hello']);  // HELLO
```

## Built-in Functions

### Version Functions

```dart
await db.version()  // Shorthand for run('version')
// → "surrealdb-2.3.10"

await db.run<String>('version')
```

### Math Functions

```dart
await db.run<double>('math::abs', [-5])        // 5.0
await db.run<double>('math::ceil', [4.3])      // 5.0
await db.run<double>('math::floor', [4.7])     // 4.0
await db.run<double>('math::round', [4.5])     // 5.0
await db.run<double>('math::sqrt', [16])       // 4.0
await db.run<double>('math::pow', [2, 3])      // 8.0
await db.run<double>('math::max', [1, 5, 3])   // 5.0
await db.run<double>('math::min', [1, 5, 3])   // 1.0
```

### String Functions

```dart
await db.run<String>('string::uppercase', ['hello'])     // HELLO
await db.run<String>('string::lowercase', ['WORLD'])     // world
await db.run<String>('string::trim', ['  text  '])      // text
await db.run<int>('string::length', ['hello'])           // 5
await db.run<bool>('string::contains', ['hello', 'ell']) // true
await db.run<String>('string::slice', ['hello', 1, 4])   // ell
await db.run<List>('string::split', ['a,b,c', ','])      // [a, b, c]
await db.run<String>('string::join', [['a', 'b'], '-'])  // a-b
```

### Array Functions

```dart
await db.run<int>('array::len', [[1, 2, 3]])                // 3
await db.run<List>('array::add', [[1, 2], 3])               // [1, 2, 3]
await db.run<List>('array::append', [[1, 2], [3, 4]])       // [1, 2, 3, 4]
await db.run<dynamic>('array::first', [[1, 2, 3]])          // 1
await db.run<dynamic>('array::last', [[1, 2, 3]])           // 3
await db.run<List>('array::reverse', [[1, 2, 3]])           // [3, 2, 1]
await db.run<List>('array::sort', [[3, 1, 2]])              // [1, 2, 3]
await db.run<List>('array::distinct', [[1, 2, 2, 3]])       // [1, 2, 3]
```

### Time Functions

```dart
await db.run<String>('time::now')                           // Current timestamp
await db.run<int>('time::unix')                             // Unix timestamp
await db.run<String>('time::format', [DateTime.now(), '%Y-%m-%d'])
await db.run<int>('time::day', [DateTime.now()])            // Day of month
await db.run<int>('time::month', [DateTime.now()])          // Month number
await db.run<int>('time::year', [DateTime.now()])           // Year
```

### Random Functions

```dart
await db.run<double>('rand::float')                   // 0.0 to 1.0
await db.run<int>('rand::int', [1, 100])             // Random 1-100
await db.run<String>('rand::uuid')                    // UUID v4
await db.run<String>('rand::ulid')                    // ULID
```

### Crypto Functions

```dart
await db.run<String>('crypto::md5', ['text'])
await db.run<String>('crypto::sha1', ['text'])
await db.run<String>('crypto::sha256', ['text'])
await db.run<String>('crypto::sha512', ['text'])
await db.run<String>('crypto::argon2::generate', ['password'])
await db.run<bool>('crypto::argon2::compare', ['hash', 'password'])
```

## User-Defined Functions

Define custom functions in SurrealQL:

```dart
// Define function
await db.queryQL('''
  DEFINE FUNCTION fn::calculate_tax(\$amount: number) {
    RETURN \$amount * 0.1;
  };
''');

// Call function
final tax = await db.run<double>('fn::calculate_tax', [100]);
// → 10.0
```

**In queries:**
```dart
await db.queryQL('''
  SELECT *, fn::calculate_tax(price) as tax FROM products
''');
```

## Common Patterns

### Parameterized Queries

```dart
// Set common filters
await db.set('activeStatus', 'active');
await db.set('minAge', 18);

// Reuse across queries
final users = await db.queryQL('SELECT * FROM users WHERE status = \$activeStatus');
final adults = await db.queryQL('SELECT * FROM users WHERE age >= \$minAge');
```

### Dynamic Query Building

```dart
Future<List> searchUsers({
  String? name,
  int? minAge,
  String? status,
}) async {
  final params = <String, dynamic>{};
  final conditions = <String>[];

  if (name != null) {
    params['name'] = name;
    conditions.add('name CONTAINS \$name');
  }

  if (minAge != null) {
    params['minAge'] = minAge;
    conditions.add('age >= \$minAge');
  }

  if (status != null) {
    params['status'] = status;
    conditions.add('status = \$status');
  }

  final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

  return await db.queryQL('SELECT * FROM users $where', params)
    .then((r) => r.getResults());
}
```

### Function Composition

```dart
// Combine multiple functions
await db.queryQL('''
  SELECT
    string::uppercase(name) as name_upper,
    math::round(price * 1.1, 2) as price_with_tax,
    time::format(created_at, '%Y-%m-%d') as created_date
  FROM products
''');
```

### Validation with Functions

```dart
await db.queryQL('''
  CREATE users SET
    email = \$email,
    email_valid = string::contains(\$email, '@'),
    age = \$age,
    age_valid = \$age >= 18
''', {
  'email': 'user@example.com',
  'age': 25,
});
```

### Custom Business Logic

```dart
// Define discount function
await db.queryQL('''
  DEFINE FUNCTION fn::calculate_discount(\$price: number, \$tier: string) {
    RETURN IF \$tier = 'gold' THEN
      \$price * 0.2
    ELSE IF \$tier = 'silver' THEN
      \$price * 0.1
    ELSE
      0
    END;
  };
''');

// Use in query
await db.queryQL('''
  SELECT
    name,
    price,
    fn::calculate_discount(price, \$userTier) as discount
  FROM products
''', {'userTier': 'gold'});
```

## Exception Handling

**Exception:** `ParameterException`, `QueryException`

```dart
// Parameter error
try {
  await db.set('invalid name', 123);  // Spaces not allowed
} on ParameterException catch (e) {
  print('Parameter error: ${e.message}');
}

// Function error
try {
  await db.run('nonexistent::function');
} on QueryException catch (e) {
  print('Function not found: ${e.message}');
}
```

## Type Safety

```dart
// Type parameter enforces return type
final count = await db.run<int>('array::len', [[1, 2, 3]]);
// count is int

final name = await db.run<String>('string::uppercase', ['hello']);
// name is String

// Runtime type mismatch throws
try {
  final wrong = await db.run<String>('array::len', [[1, 2, 3]]);
  // Throws: expected String, got int
} catch (e) {
  print('Type mismatch: $e');
}
```

## Gotchas

1. **Parameter Names:** No spaces or special characters (use snake_case or camelCase)
2. **Parameter Scope:** `set()` parameters persist across queries
3. **Function Namespace:** Use `::` separator (e.g., `math::sqrt`)
4. **Null Parameters:** Null values allowed but may cause query errors
5. **Type Conversion:** Functions may return different types than expected
6. **Custom Functions:** Must be defined before use
7. **Parameter Cleanup:** Use `unset()` to avoid parameter pollution
8. **Case Sensitivity:** Function names are case-sensitive
9. **Argument Order:** Match function signature exactly
10. **Return Type:** Specify correct type parameter for `run<T>()`
