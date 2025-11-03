# Schema & Table Structures

## TableStructure

**File:** `lib/src/schema/table_structure.dart`

Define table schemas for validation and migrations.

```dart
TableStructure(
  String tableName,
  Map<String, FieldDefinition> fields,
  {List<IndexDefinition>? vectorIndexes}
)
```

**Example:**
```dart
final userTable = TableStructure(
  'users',
  {
    'name': FieldDefinition(StringType()),
    'age': FieldDefinition(NumberType()),
    'email': FieldDefinition(StringType(), optional: true),
  },
);
```

### Methods

```dart
void validate(Map<String, dynamic> data)  // Throws ValidationException on failure
```

## FieldDefinition

```dart
FieldDefinition(
  SurrealType type,
  {bool optional = false,
   dynamic defaultValue,
   String? assertClause,
   bool indexed = false}
)
```

**Properties:**
- `type` - SurrealDB type (required)
- `optional` - Allow null values (default: false)
- `defaultValue` - Default when not provided
- `assertClause` - SurrealQL validation (e.g., `'\$value > 0'`)
- `indexed` - Create index on field

**Example:**
```dart
'price': FieldDefinition(
  NumberType(),
  assertClause: '\$value > 0',
  indexed: true,
)
```

## SurrealDB Type System

**File:** `lib/src/schema/surreal_types.dart`

### Primitive Types

```dart
StringType()
BoolType()
DatetimeType()
DurationType()
NumberType({NumberFormat format = NumberFormat.decimal})
```

**NumberFormat:**
- `NumberFormat.integer` - Integer values
- `NumberFormat.decimal` - Decimal/float values
- `NumberFormat.float` - Explicit float

### Collection Types

```dart
ArrayType(SurrealType elementType)
ObjectType({Map<String, FieldDefinition>? schema})
```

**Example:**
```dart
// Simple array
'tags': FieldDefinition(ArrayType(StringType()))

// Typed object
'address': FieldDefinition(ObjectType(schema: {
  'street': FieldDefinition(StringType()),
  'city': FieldDefinition(StringType()),
}))

// Array of objects
'items': FieldDefinition(ArrayType(ObjectType()))
```

### Special Types

```dart
RecordType({String? table})          // Record link (e.g., users:alice)
GeometryType({GeometryKind? kind})   // GeoJSON
AnyType()                            // Any type allowed
VectorType(VectorFormat format, int dimensions)  // AI embeddings
```

**RecordType Example:**
```dart
'author': FieldDefinition(RecordType(table: 'users'))
'reference': FieldDefinition(RecordType())  // Any table
```

**VectorType Example:**
```dart
'embedding': FieldDefinition(
  VectorType(VectorFormat.f32, 384),
)
```

## IndexDefinition

**File:** `lib/src/schema/table_structure.dart`

```dart
IndexDefinition(
  String name,
  List<String> fields,
  {bool unique = false}
)
```

**Example:**
```dart
final table = TableStructure(
  'users',
  fields,
  vectorIndexes: [
    IndexDefinition('email_idx', ['email'], unique: true),
  ],
);
```

## Validation

### Validation Methods

```dart
TableStructure.validate(data)  // Throws ValidationException
```

**Exception:** `lib/src/exceptions.dart`
```dart
class ValidationException extends DatabaseException {
  final Map<String, String> fieldErrors;
}
```

**Example:**
```dart
try {
  userTable.validate({'name': 'Alice', 'age': 'invalid'});
} on ValidationException catch (e) {
  print('Field errors: ${e.fieldErrors}');
  // {age: Expected number, got String}
}
```

### Built-in Validation

- Type checking (String, number, bool, etc.)
- Optional/required field enforcement
- Array element type validation
- Nested object validation
- Assert clause evaluation (SurrealDB side)

## Common Patterns

### Complete Table Definition

```dart
final productTable = TableStructure(
  'products',
  {
    'name': FieldDefinition(
      StringType(),
      indexed: true,
    ),
    'price': FieldDefinition(
      NumberType(format: NumberFormat.decimal),
      assertClause: '\$value >= 0',
    ),
    'category': FieldDefinition(
      RecordType(table: 'categories'),
    ),
    'tags': FieldDefinition(
      ArrayType(StringType()),
      optional: true,
    ),
    'metadata': FieldDefinition(
      ObjectType(),
      optional: true,
    ),
  },
);
```

### Using with CRUD

```dart
// Validation on create
await db.createQL('products', data, schema: productTable);

// Validation on update
await db.updateQL('products:123', data, schema: productTable);
```

### Vector Fields in Schema

```dart
final docTable = TableStructure(
  'documents',
  {
    'title': FieldDefinition(StringType()),
    'embedding': FieldDefinition(
      VectorType(VectorFormat.f32, 384),
    ),
  },
);
```

## Type Conversion

### Dart to SurrealDB Mapping

| Dart Type | SurrealType |
|-----------|-------------|
| String | StringType() |
| int, double, num | NumberType() |
| bool | BoolType() |
| DateTime | DatetimeType() |
| Duration | DurationType() |
| List | ArrayType() |
| Map | ObjectType() |
| RecordId | RecordType() |
| VectorValue | VectorType() |

## Gotchas

1. **SCHEMAFULL Tables:** For vector fields in SCHEMAFULL tables, define as `array<float>` in DDL, not `vector<F32,384>`
2. **Assert Clauses:** Evaluated by SurrealDB, not Dart - use SurrealQL syntax
3. **Nested Validation:** Objects validate recursively if schema provided
4. **Type Coercion:** No automatic coercion - strict type checking
5. **Default Values:** Applied during migration, not CRUD operations
6. **Optional Fields:** Can be omitted but cannot be explicitly null in Dart Map
