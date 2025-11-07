[← Back to Documentation Index](README.md)

# Table Structures & Schema Definition

## Table Structures & Schema Definition

Table structures provide a powerful way to define and validate your database schema in Dart, bringing type safety and compile-time checking to your SurrealDB applications. By defining schemas, you can ensure data integrity, leverage database-level validation, and automate schema migrations.

### Why Use Schemas?

While SurrealDB allows schemaless tables, defining explicit schemas offers several benefits:

- **Data Validation**: Catch invalid data before it reaches the database
- **Type Safety**: Leverage Dart's type system for schema definitions
- **Documentation**: Your schema serves as living documentation of your data model
- **Migration Control**: Automatically detect and apply schema changes
- **Database Constraints**: Use ASSERT clauses for database-level validation
- **Performance**: Indexed fields improve query performance

### Creating a Basic Schema

A table structure consists of a table name and a map of field definitions. Each field has a type and optional constraints.

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Define a simple user table
final userSchema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType()),
});

// Connect with the schema
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'app',
  database: 'app',
  tableDefinitions: [userSchema],
  autoMigrate: true,  // Automatically create/update tables
);

// Create a user (validated against schema)
final user = await db.createQL('users', {
  'name': 'Alice Smith',
  'age': 30,
  'email': 'alice@example.com',
});

await db.close();
```

### Field Types

SurrealDartBsupports all SurrealDB data types through a comprehensive type system:

#### Scalar Types

```dart
// String type
final nameField = FieldDefinition(StringType());

// Number types
final anyNumber = FieldDefinition(NumberType());  // Any numeric type
final age = FieldDefinition(NumberType(format: NumberFormat.integer));  // int only
final temperature = FieldDefinition(NumberType(format: NumberFormat.floating));  // float only
final price = FieldDefinition(NumberType(format: NumberFormat.decimal));  // precise decimal

// Boolean type
final isActive = FieldDefinition(BoolType());

// Datetime type
final createdAt = FieldDefinition(DatetimeType());

// Duration type
final sessionDuration = FieldDefinition(DurationType());
```

#### Collection Types

```dart
// Array type with element constraint
final tags = FieldDefinition(ArrayType(StringType()));

// Fixed-length array
final rgb = FieldDefinition(
  ArrayType(NumberType(format: NumberFormat.integer), length: 3),
);

// Nested arrays
final matrix = FieldDefinition(ArrayType(ArrayType(NumberType())));

// Object type (schemaless)
final metadata = FieldDefinition(ObjectType());

// Object with nested schema
final address = FieldDefinition(
  ObjectType(schema: {
    'street': FieldDefinition(StringType()),
    'city': FieldDefinition(StringType()),
    'zipCode': FieldDefinition(StringType()),
    'country': FieldDefinition(StringType(), optional: true),
  }),
);
```

#### Special Types

```dart
// Record type (reference to another table)
final authorId = FieldDefinition(RecordType(table: 'users'));  // Must be from 'users'
final anyRecord = FieldDefinition(RecordType());  // Any table

// Geometry type (GeoJSON)
final location = FieldDefinition(GeometryType(kind: GeometryKind.point));
final boundary = FieldDefinition(GeometryType(kind: GeometryKind.polygon));

// Vector type (for AI embeddings)
final embedding = FieldDefinition(VectorType.f32(1536, normalized: true));

// Any type (accepts any value - use sparingly)
final dynamicData = FieldDefinition(AnyType());
```

### Vector Field Types

Vector fields are specialized for AI/ML embeddings and similarity search:

```dart
// Common embedding formats
final openaiEmbedding = FieldDefinition(
  VectorType.f32(1536, normalized: true),  // OpenAI text-embedding-3-small
);

final bertEmbedding = FieldDefinition(
  VectorType.f32(768),  // BERT-base
);

// Different vector formats
final f32Vector = FieldDefinition(VectorType.f32(384));  // Float32 (most common)
final f64Vector = FieldDefinition(VectorType.f64(768));  // Float64 (high precision)
final i16Vector = FieldDefinition(VectorType.i16(384));  // Int16 (quantized)
final i8Vector = FieldDefinition(VectorType.i8(256));    // Int8 (highly compressed)

// Complete document schema with embeddings
final documentsSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'content': FieldDefinition(StringType()),
  'embedding': FieldDefinition(
    VectorType.f32(1536, normalized: true),
    optional: false,
  ),
  'category': FieldDefinition(StringType(), optional: true),
});
```

### Optional Fields and Default Values

Control which fields are required and provide defaults for optional fields:

```dart
final productsSchema = TableStructure('products', {
  // Required fields (default)
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),

  // Optional fields
  'description': FieldDefinition(StringType(), optional: true),
  'category': FieldDefinition(StringType(), optional: true),

  // Optional with default value
  'in_stock': FieldDefinition(
    BoolType(),
    optional: true,
    defaultValue: true,
  ),
  'views': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,
  ),
  'created_at': FieldDefinition(
    DatetimeType(),
    optional: true,
    defaultValue: 'time::now()',  // SurrealDB function
  ),
});

// Create product without optional fields
final product = await db.createQL('products', {
  'name': 'Widget',
  'price': 19.99,
});
// Result will have in_stock=true, views=0, created_at=(current timestamp)
```

### Indexed Fields

Mark fields as indexed to improve query performance:

```dart
final usersSchema = TableStructure('users', {
  'username': FieldDefinition(
    StringType(),
    indexed: true,  // Fast lookups by username
  ),
  'email': FieldDefinition(
    StringType(),
    indexed: true,  // Fast lookups by email
  ),
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
});

// Queries on indexed fields will be faster
final results = await db.queryQL('SELECT * FROM users WHERE email = "alice@example.com"');
```

### Validation with ASSERT Clauses

ASSERT clauses provide database-level validation using SurrealQL expressions:

```dart
final usersSchema = TableStructure('users', {
  'name': FieldDefinition(StringType()),

  // Age must be between 0 and 150
  'age': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 0 AND $value <= 150',
  ),

  // Email must be valid format
  'email': FieldDefinition(
    StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  ),

  // Username must be alphanumeric and 3-20 characters
  'username': FieldDefinition(
    StringType(),
    assertClause: r'string::len($value) >= 3 AND string::len($value) <= 20',
  ),

  // Password must be at least 8 characters
  'password': FieldDefinition(
    StringType(),
    assertClause: r'string::len($value) >= 8',
  ),
});

// Valid data passes through
final user = await db.createQL('users', {
  'name': 'Alice',
  'age': 30,
  'email': 'alice@example.com',
  'username': 'alice123',
  'password': 'secure_password',
});

// Invalid data throws QueryException
try {
  await db.createQL('users', {
    'name': 'Bob',
    'age': 15,  // Valid age
    'email': 'invalid-email',  // Invalid email format!
    'username': 'bo',  // Too short!
    'password': 'short',  // Too short!
  });
} on QueryException catch (e) {
  print('Validation failed: ${e.message}');
  // The ASSERT clause blocks invalid data at the database level
}
```

### Common Validation Patterns

Here are some useful ASSERT clause patterns:

```dart
final validationExamples = TableStructure('examples', {
  // String validations
  'email': FieldDefinition(
    StringType(),
    assertClause: r'string::is::email($value)',
  ),
  'url': FieldDefinition(
    StringType(),
    assertClause: r'string::is::url($value)',
  ),
  'uuid': FieldDefinition(
    StringType(),
    assertClause: r'string::is::uuid($value)',
  ),

  // Number range validations
  'percentage': FieldDefinition(
    NumberType(format: NumberFormat.floating),
    assertClause: r'$value >= 0 AND $value <= 100',
  ),
  'positive': FieldDefinition(
    NumberType(),
    assertClause: r'$value > 0',
  ),

  // Enum-like validations
  'status': FieldDefinition(
    StringType(),
    assertClause: r"$value IN ['pending', 'active', 'inactive', 'archived']",
  ),
  'role': FieldDefinition(
    StringType(),
    assertClause: r"$value IN ['admin', 'user', 'guest']",
  ),

  // Array validations
  'tags': FieldDefinition(
    ArrayType(StringType()),
    assertClause: r'array::len($value) <= 10',  // Max 10 tags
  ),

  // Vector validations
  'embedding': FieldDefinition(
    VectorType.f32(384, normalized: true),
    assertClause: r'vector::magnitude($value) == 1.0',
  ),

  // Date validations
  'birth_date': FieldDefinition(
    DatetimeType(),
    assertClause: r'$value < time::now()',  // Must be in the past
  ),
  'expiry_date': FieldDefinition(
    DatetimeType(),
    assertClause: r'$value > time::now()',  // Must be in the future
  ),
});
```

### Schema Validation Methods

Before sending data to the database, you can validate it against your schema in Dart:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
});

// Validate data for CREATE operation (all required fields needed)
final userData = {
  'name': 'Alice',
  'age': 30,
};

try {
  schema.validate(userData, partial: false);  // Full validation
  print('Valid data for creation');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
  print('Field: ${e.fieldName}');
  print('Constraint: ${e.constraint}');
}

// Validate data for UPDATE operation (partial validation)
final updateData = {
  'age': 31,  // Only updating age
};

try {
  schema.validate(updateData, partial: true);  // Partial validation
  print('Valid data for update');
} on ValidationException catch (e) {
  print('Validation error: ${e.message}');
}

// Validation catches type mismatches
final invalidData = {
  'name': 'Bob',
  'age': 'thirty',  // Should be a number!
  'email': 'bob@example.com',
};

try {
  schema.validate(invalidData, partial: false);
} on ValidationException catch (e) {
  print(e.message);  // "Field 'age' must be a number, got String"
  print(e.fieldName);  // "age"
  print(e.constraint);  // "type_mismatch"
}
```

### Schema Introspection

Query and inspect your schema definitions at runtime:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
  'phone': FieldDefinition(StringType(), optional: true),
});

// Check if field exists
print(schema.hasField('name'));   // true
print(schema.hasField('salary')); // false

// Get field definition
final emailDef = schema.getField('email');
if (emailDef != null) {
  print('Email type: ${emailDef.type}');
  print('Is optional: ${emailDef.optional}');
  print('Is indexed: ${emailDef.indexed}');
}

// Get lists of required and optional fields
final required = schema.getRequiredFields();
print('Required fields: $required');  // ['name', 'age']

final optional = schema.getOptionalFields();
print('Optional fields: $optional');  // ['email', 'phone']

// Access table name
print('Table name: ${schema.tableName}');  // 'users'

// Access all fields
print('Total fields: ${schema.fields.length}');
for (final entry in schema.fields.entries) {
  print('Field ${entry.key}: ${entry.value.type}');
}
```

### Generating DDL with toSurrealQL

Convert your Dart schema definitions to SurrealDB DDL statements:

```dart
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'email': FieldDefinition(StringType(), optional: true),
  'created_at': FieldDefinition(DatetimeType()),
});

// Generate SurrealQL DDL
final ddl = schema.toSurrealQL();
print(ddl);

/* Output:
DEFINE TABLE users SCHEMAFULL;
DEFINE FIELD name ON TABLE users TYPE string ASSERT $value != NONE;
DEFINE FIELD age ON TABLE users TYPE int ASSERT $value != NONE;
DEFINE FIELD email ON TABLE users TYPE string;
DEFINE FIELD created_at ON TABLE users TYPE datetime ASSERT $value != NONE;
*/

// Works with complex types too
final complexSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'tags': FieldDefinition(ArrayType(StringType())),
  'embedding': FieldDefinition(VectorType.f32(1536)),
  'metadata': FieldDefinition(ObjectType()),
});

print(complexSchema.toSurrealQL());

/* Output:
DEFINE TABLE documents SCHEMAFULL;
DEFINE FIELD title ON TABLE documents TYPE string ASSERT $value != NONE;
DEFINE FIELD tags ON TABLE documents TYPE array<string> ASSERT $value != NONE;
DEFINE FIELD embedding ON TABLE documents TYPE vector<F32, 1536> ASSERT $value != NONE;
DEFINE FIELD metadata ON TABLE documents TYPE object ASSERT $value != NONE;
*/
```

### Migration Strategies

SurrealDartBprovides two approaches for applying schema changes:

#### Auto-Migration (Development)

Best for rapid development iteration. Schema changes are automatically detected and applied on connection:

```dart
// Define initial schema
final initialSchema = TableStructure('products', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
});

// Connect with auto-migration
var db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'dev',
  database: 'dev',
  tableDefinitions: [initialSchema],
  autoMigrate: true,  // Automatically apply schema changes
);

// Add some data
await db.createQL('products', {
  'name': 'Widget',
  'price': 19.99,
});

await db.close();

// Later: Evolve the schema (add new fields)
final evolvedSchema = TableStructure('products', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  'description': FieldDefinition(StringType(), optional: true),  // New field!
  'stock': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,
  ),  // New field with default!
});

// Reconnect with evolved schema
db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'dev',
  database: 'dev',
  tableDefinitions: [evolvedSchema],
  autoMigrate: true,  // New fields are automatically added
);

// Old data is preserved, new fields available
final products = await db.selectQL('products');
print('Existing product: ${products[0]}');  // Has name and price

// Create new product with all fields
await db.createQL('products', {
  'name': 'Gadget',
  'price': 29.99,
  'description': 'A useful gadget',
  'stock': 50,
});

await db.close();
```

#### Manual Migration (Production)

Best for production environments where you want explicit control over when and how schema changes are applied:

```dart
// Connect WITHOUT auto-migration
final schema = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'email': FieldDefinition(StringType(), indexed: true),  // Adding index
  'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  'created_at': FieldDefinition(
    DatetimeType(),
    optional: true,
    defaultValue: 'time::now()',
  ),  // New field with default
});

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'prod',
  database: 'prod',
  tableDefinitions: [schema],
  autoMigrate: false,  // Manual control
);

// Step 1: Preview migration with dry-run
print('Previewing migration changes...');
final previewReport = await db.migrate(dryRun: true);

if (previewReport.success) {
  print('Migration preview:');
  print('  Tables added: ${previewReport.tablesAdded.length}');
  print('  Fields added: ${previewReport.fieldsAdded.length}');
  print('  Fields modified: ${previewReport.fieldsModified.length}');
  print('  Indexes added: ${previewReport.indexesAdded.length}');
  print('  Has destructive changes: ${previewReport.hasDestructiveChanges}');
  print('');
  print('Generated DDL:');
  for (final ddl in previewReport.generatedDDL) {
    print('  $ddl');
  }
  print('');
} else {
  print('Migration would fail: ${previewReport.errorMessage}');
}

// Step 2: Apply migration (if preview looks good)
print('Applying migration...');
final applyReport = await db.migrate(
  dryRun: false,
  allowDestructiveMigrations: false,  // Block destructive changes
);

if (applyReport.success) {
  print('Migration applied successfully!');
  print('Migration ID: ${applyReport.migrationId}');
  print('Applied at: ${DateTime.now()}');
} else {
  print('Migration failed: ${applyReport.errorMessage}');
}

// Step 3: View migration history
final historyResponse = await db.queryQL(
  'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 5',
);
final history = historyResponse.getResults();
print('\nMigration history:');
for (final migration in history) {
  print('  ${migration['migration_id']}: ${migration['status']}');
  print('    Applied: ${migration['applied_at']}');
}

await db.close();
```

### Understanding Migration Reports

Migration operations return a `MigrationReport` with detailed information:

```dart
final report = await db.migrate(dryRun: true);

// Check if migration succeeded
if (report.success) {
  print('Migration would succeed');

  // Check what changed
  print('Tables added: ${report.tablesAdded}');
  print('Tables removed: ${report.tablesRemoved}');
  print('Fields added: ${report.fieldsAdded}');  // Map<table, List<field>>
  print('Fields removed: ${report.fieldsRemoved}');  // Map<table, List<field>>
  print('Fields modified: ${report.fieldsModified}');  // Map<table, List<modification>>
  print('Indexes added: ${report.indexesAdded}');  // Map<table, List<index>>
  print('Indexes removed: ${report.indexesRemoved}');  // Map<table, List<index>>

  // Check if changes are destructive
  if (report.hasDestructiveChanges) {
    print('WARNING: This migration contains destructive changes!');
    print('Destructive changes may result in data loss.');
  }

  // View generated DDL
  print('Generated DDL statements:');
  for (final ddl in report.generatedDDL) {
    print('  $ddl');
  }

  // Get migration hash (unique identifier for this set of changes)
  print('Migration hash: ${report.migrationHash}');

  // Get migration ID (if applied)
  if (report.migrationId != null) {
    print('Migration ID: ${report.migrationId}');
  }
} else {
  print('Migration would fail: ${report.errorMessage}');
  if (report.errorCode != null) {
    print('Error code: ${report.errorCode}');
  }
}
```

### Handling Destructive Changes

Destructive changes (like removing fields or tables) require explicit permission:

```dart
// Schema that removes a field (destructive!)
final oldSchema = TableStructure('items', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  'old_field': FieldDefinition(StringType(), optional: true),
});

final newSchema = TableStructure('items', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType(format: NumberFormat.floating)),
  // old_field removed - this is destructive!
});

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
  tableDefinitions: [newSchema],
  autoMigrate: false,
);

// This will fail (blocks destructive changes by default)
try {
  await db.migrate(allowDestructiveMigrations: false);
  print('Should not reach here');
} on MigrationException catch (e) {
  print('Blocked destructive migration: ${e.message}');
  print('Destructive changes detected:');
  print('  - Field removed: old_field');
  print('');
  print('To apply destructive changes:');
  print('  1. Review the changes carefully');
  print('  2. Backup your data');
  print('  3. Use allowDestructiveMigrations: true');
}

// Apply with explicit permission
print('\nApplying with explicit permission...');
final report = await db.migrate(allowDestructiveMigrations: true);
if (report.success) {
  print('Destructive migration applied');
  print('WARNING: Data in removed fields is lost');
}

await db.close();
```

### Complete Example: Multi-Table Schema

Here's a complete example with multiple related tables:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Define schemas for a blog application
  final userSchema = TableStructure('users', {
    'username': FieldDefinition(
      StringType(),
      indexed: true,
      assertClause: r'string::len($value) >= 3',
    ),
    'email': FieldDefinition(
      StringType(),
      indexed: true,
      assertClause: r'string::is::email($value)',
    ),
    'bio': FieldDefinition(StringType(), optional: true),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  final postSchema = TableStructure('posts', {
    'title': FieldDefinition(StringType()),
    'content': FieldDefinition(StringType()),
    'author_id': FieldDefinition(RecordType(table: 'users')),
    'published': FieldDefinition(BoolType(), defaultValue: false),
    'tags': FieldDefinition(ArrayType(StringType()), optional: true),
    'views': FieldDefinition(
      NumberType(format: NumberFormat.integer),
      defaultValue: 0,
      assertClause: r'$value >= 0',
    ),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  final commentSchema = TableStructure('comments', {
    'post_id': FieldDefinition(RecordType(table: 'posts')),
    'author_id': FieldDefinition(RecordType(table: 'users')),
    'content': FieldDefinition(StringType()),
    'created_at': FieldDefinition(
      DatetimeType(),
      defaultValue: 'time::now()',
    ),
  });

  // Connect with all schemas
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'blog',
    database: 'blog',
    tableDefinitions: [userSchema, postSchema, commentSchema],
    autoMigrate: true,
  );

  try {
    // Create user
    final user = await db.createQL('users', {
      'username': 'alice',
      'email': 'alice@example.com',
      'bio': 'Software developer and blogger',
    });
    print('Created user: ${user['username']}');

    // Create post
    final post = await db.createQL('posts', {
      'title': 'Getting Started with SurrealDB',
      'content': 'SurrealDB is a powerful database...',
      'author_id': user['id'],
      'tags': ['database', 'tutorial', 'surreal'],
    });
    print('Created post: ${post['title']}');

    // Create comment
    final comment = await db.createQL('comments', {
      'post_id': post['id'],
      'author_id': user['id'],
      'content': 'Great post!',
    });
    print('Created comment: ${comment['content']}');

    // Query posts with author info
    final postsResponse = await db.queryQL('''
      SELECT *,
        author_id.username AS author_name,
        author_id.email AS author_email
      FROM posts
      WHERE published = false
    ''');
    final posts = postsResponse.getResults();
    print('\nUnpublished posts: ${posts.length}');
    for (final p in posts) {
      print('  ${p['title']} by ${p['author_name']}');
    }

    // Demonstrate validation failure
    try {
      await db.createQL('users', {
        'username': 'ab',  // Too short! (minimum 3 characters)
        'email': 'invalid-email',  // Invalid format!
      });
    } on QueryException catch (e) {
      print('\nValidation error caught (as expected):');
      print('  ${e.message}');
    }
  } finally {
    await db.close();
  }
}
```

### Best Practices

1. **Start with Schemas Early**: Define schemas from the beginning, even if simple. They serve as documentation and catch errors early.

2. **Use Optional Fields Wisely**: Make fields optional only when they truly can be absent. Required fields ensure data consistency.

3. **Leverage ASSERT Clauses**: Database-level validation is more robust than application-level validation alone.

4. **Index Frequently Queried Fields**: Add `indexed: true` to fields you'll query often (like email, username, foreign keys).

5. **Validate Before Inserting**: Use `schema.validate()` in your application to catch errors before database operations.

6. **Preview Migrations**: Always use `migrate(dryRun: true)` in production to preview changes before applying them.

7. **Version Your Schemas**: Keep your schema definitions in version control alongside your code.

8. **Test Schema Changes**: Test migrations thoroughly in development before deploying to production.

9. **Backup Before Destructive Migrations**: Always backup your data before applying migrations that remove fields or tables.

10. **Use Auto-Migration in Development**: Enable `autoMigrate: true` during development for fast iteration, but use manual migration in production.

### Common Pitfalls

**Pitfall 1: Forgetting to handle optional fields**
```dart
// Bad: No default, may cause null errors
final schema = TableStructure('users', {
  'credits': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
  ),
});

// Good: Provide default value
final schema = TableStructure('users', {
  'credits': FieldDefinition(
    NumberType(format: NumberFormat.integer),
    optional: true,
    defaultValue: 0,  // Clear default
  ),
});
```

**Pitfall 2: Over-validating with ASSERT clauses**
```dart
// Bad: Too restrictive, hard to change later
'username': FieldDefinition(
  StringType(),
  assertClause: r'string::len($value) == 8',  // Exactly 8 chars - too rigid!
),

// Good: Reasonable constraints
'username': FieldDefinition(
  StringType(),
  assertClause: r'string::len($value) >= 3 AND string::len($value) <= 20',
),
```

**Pitfall 3: Not using partial validation for updates**
```dart
// Bad: Full validation on updates fails for partial data
schema.validate({'age': 31}, partial: false);  // Fails! Missing 'name'

// Good: Use partial validation for updates
schema.validate({'age': 31}, partial: true);  // OK! Only validates present fields
```

### Next Steps

Now that you understand table structures and schema definition, you can move on to type-safe data access using the code generator. The next section covers:

- Using `@SurrealTable` and `@SurrealField` annotations
- Generating type-safe models with build_runner
- Type-safe query builders
- Working with relationships

Continue to [Section 4: Type-Safe Data with Code Generator](#) →

---

## Navigation

[← Previous: Basic Operations](02-basic-operations.md) | [Back to Index](README.md) | [Next: Code Generator →](04-code-generator.md)

