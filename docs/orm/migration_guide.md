# ORM Migration Guide

## Overview

This guide helps you migrate from the raw Map-based API to the new type-safe ORM layer in SurrealDartB. The ORM layer provides compile-time type safety, automatic serialization/deserialization, and validation while maintaining full backward compatibility.

## Current Status

As of version 1.2.0, the ORM Layer **Foundation** (Phase 1-2) has been implemented:

**Implemented:**
- ✅ Database API method renaming with QL suffix
- ✅ ORM annotations (@SurrealRecord, @SurrealRelation, @SurrealEdge, @SurrealId)
- ✅ ORM exception hierarchy
- ✅ Serialization code generation (toSurrealMap/fromSurrealMap)
- ✅ ID field detection
- ✅ Validation integration

**Not Yet Implemented (Future Phases 3-7):**
- ⏳ Type-safe CRUD operations (create, update, delete with objects)
- ⏳ Query builder with fluent API
- ⏳ Where clause DSL with logical operators
- ⏳ Relationship loading system
- ⏳ Advanced include filtering

## Why Migrate?

### Current Map-Based API (Raw QL Methods)

```dart
// Manual map construction - no type safety
final userData = {
  'name': 'Alice',
  'age': 30,
  'email': 'alice@example.com',
};

// Create with raw map
final user = await db.createQL('users', userData);

// Manual type casting required
final name = user['name'] as String;
final age = user['age'] as int;

// Query with raw SurrealQL strings
final response = await db.queryQL(
  'SELECT * FROM users WHERE age > 18',
);
final results = response.getResults();
```

**Problems:**
- No compile-time type checking
- Manual Map construction
- Runtime type casting errors
- No IDE autocomplete
- No validation before database call

### Future Type-Safe ORM API (When Fully Implemented)

```dart
// Define entity with annotations
@SurrealTable('users')
class User {
  final String id;
  final String name;
  final int age;
  final String email;
  
  User({
    required this.id,
    required this.name,
    required this.age,
    required this.email,
  });
}

// Type-safe create - coming in Phase 2
final user = await db.create(User(
  id: 'user:alice',
  name: 'Alice',
  age: 30,
  email: 'alice@example.com',
));

// Type-safe query - coming in Phase 3
final adults = await db.query<User>()
  .where((t) => t.age.greaterThan(18))
  .execute();

// Type-safe property access
for (final user in adults) {
  print(user.name); // IDE autocomplete!
}
```

**Benefits:**
- Compile-time type safety
- IDE autocomplete and refactoring
- Automatic serialization/deserialization
- Validation before database calls
- Clean, readable code

## Migration Strategy

### 1. Backward Compatibility (Current State)

The ORM layer maintains 100% backward compatibility. All existing code continues working:

```dart
// OLD API - Still works!
final user = await db.createQL('users', {
  'name': 'Bob',
  'age': 25,
});

// NEW API - Coming soon
// final user = await db.create(userObject);
```

### 2. Incremental Migration

You can migrate one table at a time:

**Step 1: Add Annotations (Available Now)**

```dart
import 'package:surrealdartb/surrealdartb.dart';

@SurrealTable('users')
class User {
  @SurrealField(type: StringType())
  final String id;
  
  @SurrealField(type: StringType())
  final String name;
  
  @SurrealField(type: NumberType(format: NumberFormat.integer))
  final int age;
  
  User({
    required this.id,
    required this.name,
    required this.age,
  });
}
```

**Step 2: Generate Code (Available Now)**

```bash
dart run build_runner build
```

This generates `user.surreal.dart` with:
- `toSurrealMap()` - Converts User to Map
- `fromSurrealMap()` - Creates User from Map
- `validate()` - Validates against schema
- `recordId` getter - Access to record ID

**Step 3: Use Generated Methods Manually (Available Now)**

```dart
// Manual use of generated serialization
final user = User(id: 'user:1', name: 'Alice', age: 30);

// Serialize to map
final map = user.toSurrealMap();

// Use with existing QL API
final created = await db.createQL('users', map);

// Deserialize from map
final userFromDb = UserORM.fromSurrealMap(created);
```

**Step 4: Use Type-Safe CRUD (Coming in Phase 2)**

```dart
// Once Phase 2 is complete:
final user = User(id: 'user:1', name: 'Alice', age: 30);
final created = await db.create(user);  // Type-safe!
```

### 3. Method Renaming

To prepare for the ORM layer, all existing CRUD methods have been renamed with a `QL` suffix:

| Old Method | New Method | Status |
|------------|------------|--------|
| `create(table, data)` | `createQL(table, data)` | ✅ Renamed |
| `select(table)` | `selectQL(table)` | ✅ Renamed |
| `update(id, data)` | `updateQL(id, data)` | ✅ Renamed |
| `delete(id)` | `deleteQL(id)` | ✅ Renamed |
| `query(sql)` | `queryQL(sql)` | ✅ Renamed |

**Migration:**

```dart
// BEFORE (deprecated but still works)
final user = await db.create('users', userData);

// AFTER (recommended)
final user = await db.createQL('users', userData);
```

**Note:** The old methods still work but are marked `@deprecated`. They will be removed in a future major version.

## Step-by-Step Migration Example

### Before: Map-Based API

```dart
import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create user with map
    final userData = {
      'name': 'Alice Smith',
      'email': 'alice@example.com',
      'age': 30,
    };
    final user = await db.createQL('users', userData);
    
    // Manual type casting
    print('Created: ${user['name']} (${user['age']} years old)');
    
    // Query with raw SQL
    final response = await db.queryQL('SELECT * FROM users WHERE age > 25');
    final results = response.getResults();
    
    for (final result in results) {
      print('${result['name']}: ${result['email']}');
    }
  } finally {
    await db.close();
  }
}
```

### After: ORM Foundation (Current Available Features)

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Step 1: Define entity class with annotations
@SurrealTable('users')
class User {
  @SurrealId()
  @SurrealField(type: StringType())
  final String id;
  
  @SurrealField(type: StringType())
  final String name;
  
  @SurrealField(type: StringType())
  final String email;
  
  @SurrealField(type: NumberType(format: NumberFormat.integer))
  final int age;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
  });
}

void main() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Step 2: Create user object (type-safe!)
    final user = User(
      id: 'users:alice',
      name: 'Alice Smith',
      email: 'alice@example.com',
      age: 30,
    );
    
    // Step 3: Use generated serialization with existing QL API
    final created = await db.createQL('users', user.toSurrealMap());
    
    // Step 4: Deserialize result (type-safe!)
    final userFromDb = UserORM.fromSurrealMap(created);
    
    print('Created: ${userFromDb.name} (${userFromDb.age} years old)');
    
    // Still use raw SQL for queries (query builder coming in Phase 3)
    final response = await db.queryQL('SELECT * FROM users WHERE age > 25');
    final results = response.getResults();
    
    // Deserialize all results
    final users = results.map((r) => UserORM.fromSurrealMap(r)).toList();
    
    for (final u in users) {
      print('${u.name}: ${u.email}'); // Type-safe access!
    }
  } finally {
    await db.close();
  }
}
```

### After: Full ORM (When Phases 3-7 Are Complete)

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Same entity definition as above

void main() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Type-safe create
    final user = await db.create(User(
      id: 'users:alice',
      name: 'Alice Smith',
      email: 'alice@example.com',
      age: 30,
    ));
    
    print('Created: ${user.name} (${user.age} years old)');
    
    // Type-safe query with fluent API
    final adults = await db.query<User>()
      .where((t) => t.age.greaterThan(25))
      .execute();
    
    for (final user in adults) {
      print('${user.name}: ${user.email}');
    }
    
    // Type-safe update
    final updated = await db.update(user.copyWith(age: 31));
    
    // Type-safe delete
    await db.delete(user);
  } finally {
    await db.close();
  }
}
```

## Common Migration Patterns

### Pattern 1: Simple CRUD

**Before:**
```dart
// Create
final data = {'name': 'Product', 'price': 99.99};
final product = await db.createQL('products', data);

// Read
final products = await db.selectQL('products');

// Update
await db.updateQL('products:123', {'price': 89.99});

// Delete
await db.deleteQL('products:123');
```

**After (Current - Foundation):**
```dart
// Define entity
@SurrealTable('products')
class Product {
  final String id;
  final String name;
  final double price;
  
  Product({required this.id, required this.name, required this.price});
}

// Create with serialization
final product = Product(id: 'products:1', name: 'Product', price: 99.99);
final created = await db.createQL('products', product.toSurrealMap());
final productFromDb = ProductORM.fromSurrealMap(created);

// Read and deserialize
final products = await db.selectQL('products');
final typedProducts = products.map((p) => ProductORM.fromSurrealMap(p)).toList();

// Update with serialization
final updated = product.copyWith(price: 89.99);
await db.updateQL(product.id, updated.toSurrealMap());

// Delete (no change needed)
await db.deleteQL(product.id);
```

**After (Future - Full ORM):**
```dart
// Type-safe CRUD
final product = await db.create(Product(
  id: 'products:1',
  name: 'Product',
  price: 99.99,
));

final products = await db.query<Product>().execute();

await db.update(product.copyWith(price: 89.99));

await db.delete(product);
```

### Pattern 2: Querying with Filters

**Before:**
```dart
final response = await db.queryQL(
  'SELECT * FROM products WHERE price < 100 AND category = "electronics"',
);
final results = response.getResults();
```

**After (Current - Foundation):**
```dart
// Still use raw SQL (query builder coming soon)
final response = await db.queryQL(
  'SELECT * FROM products WHERE price < 100 AND category = "electronics"',
);

// But deserialize results with type safety
final products = response.getResults()
  .map((r) => ProductORM.fromSurrealMap(r))
  .toList();
```

**After (Future - Full ORM):**
```dart
// Type-safe query builder
final products = await db.query<Product>()
  .where((t) => 
    t.price.lessThan(100) & 
    t.category.equals('electronics')
  )
  .execute();
```

## Validation

### Current: Manual Validation with Schema

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
});

try {
  await db.createQL('users', userData, schema: schema);
} on ValidationException catch (e) {
  print('Validation failed: ${e.fieldName} - ${e.constraint}');
}
```

### With ORM: Automatic Validation

```dart
// Validation happens automatically when using generated code
final user = User(id: 'users:1', name: 'Alice', age: 30);

try {
  user.validate(); // Validates against table schema
  await db.createQL('users', user.toSurrealMap());
} on OrmValidationException catch (e) {
  print('Validation failed: ${e.field} - ${e.constraint}');
}
```

## Best Practices

### 1. Start with Annotations

Add annotations to your entity classes first, even if you're still using the QL API:

```dart
@SurrealTable('users')
class User {
  @SurrealField(type: StringType())
  final String name;
  
  // ... rest of fields
}
```

### 2. Generate Code Regularly

Run code generation after any schema changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Use Generated Serialization

Even before the full ORM is ready, use generated serialization:

```dart
final map = user.toSurrealMap();  // Type-safe serialization
final user = UserORM.fromSurrealMap(map);  // Type-safe deserialization
```

### 4. Keep QL Methods for Complex Queries

For complex queries that aren't yet supported by the query builder, continue using `queryQL`:

```dart
// Complex aggregation query
final response = await db.queryQL('''
  SELECT 
    category,
    count() as total,
    avg(price) as avg_price
  FROM products
  GROUP BY category
''');
```

### 5. Test Both APIs During Migration

During migration, test with both APIs to ensure consistency:

```dart
// Test with QL API
final qlResult = await db.createQL('users', userData);

// Test with ORM
final user = User(...);
final ormResult = await db.createQL('users', user.toSurrealMap());

// Verify results match
expect(ormResult, equals(qlResult));
```

## Troubleshooting

### Issue: "Method 'create' isn't defined"

**Problem:** Using the new ORM API before it's fully implemented.

**Solution:** Use the QL suffix methods for now:

```dart
// Don't use yet (coming in Phase 2)
// await db.create(user);

// Use this instead
await db.createQL('users', user.toSurrealMap());
```

### Issue: Generated code not found

**Problem:** Forgot to run build_runner.

**Solution:**

```bash
dart run build_runner build
```

### Issue: OrmSerializationException during fromSurrealMap

**Problem:** Missing required fields in the Map.

**Solution:** Ensure all required fields are present:

```dart
try {
  final user = UserORM.fromSurrealMap(map);
} on OrmSerializationException catch (e) {
  print('Missing field: ${e.field}');
  // Handle missing field
}
```

### Issue: Type mismatch during deserialization

**Problem:** Database field type doesn't match Dart type.

**Solution:** Check field types in annotations:

```dart
@SurrealField(type: NumberType(format: NumberFormat.integer))
final int age; // Make sure database has integer, not string
```

## Timeline

The ORM layer is being rolled out in phases:

- **✅ Phase 1 (Complete):** Foundation & method renaming
- **✅ Phase 2 (Complete):** Serialization & basic infrastructure
- **⏳ Phase 3 (Upcoming):** Query builder foundation
- **⏳ Phase 4 (Upcoming):** Advanced where clause DSL
- **⏳ Phase 5 (Upcoming):** Relationship system
- **⏳ Phase 6 (Upcoming):** Advanced include filtering
- **⏳ Phase 7 (Upcoming):** Integration & final documentation

## See Also

- [ORM API Documentation](./api_documentation.md) - Complete API reference
- [Relationship Patterns](./relationships.md) - Working with relationships (when implemented)
- [Query Patterns](./query_patterns.md) - Building complex queries (when implemented)
