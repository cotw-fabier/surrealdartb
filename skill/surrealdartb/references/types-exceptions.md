# Types & Exceptions

**File:** `lib/src/types/types.dart`, `lib/src/exceptions.dart`

## Core Types

### RecordId

Represents a SurrealDB record identifier.

```dart
class RecordId {
  final String table;
  final String id;

  RecordId(this.table, this.id);

  String toString() => '$table:$id';
}
```

**Examples:**
```dart
final userId = RecordId('users', 'alice');
print(userId);  // users:alice

final postId = RecordId('posts', '123');
print(postId);  // posts:123
```

**Usage:**
```dart
// Create record with specific ID
await db.queryQL('CREATE \$rid SET name = \$name', {
  'rid': RecordId('users', 'alice'),
  'name': 'Alice',
});

// Reference in relationships
final post = {
  'title': 'Hello',
  'author': RecordId('users', 'alice'),
};
await db.createQL('posts', post);
```

### Datetime

Wrapper for DateTime with SurrealDB serialization.

```dart
class Datetime {
  final DateTime value;

  Datetime(this.value);

  String toSurrealQL() => value.toIso8601String();
}
```

**Examples:**
```dart
final now = Datetime(DateTime.now());
final specific = Datetime(DateTime(2024, 1, 15, 10, 30));

await db.createQL('events', {
  'name': 'Meeting',
  'scheduled_at': specific,
});
```

**Automatic conversion:**
```dart
// DateTime automatically converted in queries
await db.queryQL('CREATE events SET time = \$time', {
  'time': DateTime.now(),  // Auto-converted
});
```

### SurrealDuration

Wrapper for Duration with SurrealDB parsing.

```dart
class SurrealDuration {
  final Duration value;

  SurrealDuration(this.value);

  String toSurrealQL();  // e.g., "1h30m"
  static SurrealDuration parse(String s);  // Parse SurrealDB duration
}
```

**Examples:**
```dart
final duration = SurrealDuration(Duration(hours: 1, minutes: 30));
print(duration.toSurrealQL());  // 1h30m

// Parse from SurrealDB
final parsed = SurrealDuration.parse('2h45m15s');
print(parsed.value.inMinutes);  // 165
```

**SurrealDB duration formats:**
- `1ns` - nanoseconds
- `1µs` - microseconds
- `1ms` - milliseconds
- `1s` - seconds
- `1m` - minutes
- `1h` - hours
- `1d` - days
- `1w` - weeks
- `1y` - years

**Combined:**
```dart
'2h30m15s'  // 2 hours, 30 minutes, 15 seconds
'1d12h'     // 1 day, 12 hours
```

### PatchOp

JSON Patch operation for partial updates.

```dart
class PatchOp {
  final String op;
  final String path;
  final dynamic value;

  PatchOp(this.op, this.path, {this.value});
}
```

**Operations:**
```dart
PatchOp('add', '/field', value: 'new_value')
PatchOp('remove', '/field')
PatchOp('replace', '/field', value: 'updated_value')
PatchOp('test', '/field', value: 'expected_value')
```

**Example:**
```dart
await db.queryQL('UPDATE users:alice PATCH \$patches', {
  'patches': [
    PatchOp('replace', '/email', value: 'new@example.com'),
    PatchOp('add', '/tags', value: 'premium'),
  ],
});
```

### Jwt

JWT authentication token.

```dart
class Jwt {
  final String token;

  Jwt(this.token);
}
```

**Usage:**
```dart
final jwt = await db.signin(credentials);
await storage.save('token', jwt.token);

// Later
final token = await storage.load('token');
await db.authenticate(Jwt(token));
```

### Notification

Live query notification (for real-time features).

```dart
class Notification {
  final String action;  // CREATE, UPDATE, DELETE
  final dynamic result;
  final String? id;
}
```

**Note:** Live queries not fully functional yet.

## Exception Hierarchy

**Base:** `lib/src/exceptions.dart`

```dart
abstract class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
}
```

### ConnectionException

Database connection failures.

```dart
class ConnectionException extends DatabaseException {
  ConnectionException(String message);
}
```

**Causes:**
- Invalid connection parameters
- Database file inaccessible
- Backend initialization failure

**Example:**
```dart
try {
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: '/invalid/path',
    namespace: 'test',
    database: 'test',
  );
} on ConnectionException catch (e) {
  print('Connection failed: ${e.message}');
}
```

### QueryException

Query execution errors.

```dart
class QueryException extends DatabaseException {
  QueryException(String message);
}
```

**Causes:**
- Invalid SurrealQL syntax
- Table/field not found
- Type mismatch
- Constraint violation

**Example:**
```dart
try {
  await db.queryQL('INVALID SYNTAX');
} on QueryException catch (e) {
  print('Query error: ${e.message}');
}
```

### AuthenticationException

Authentication failures.

```dart
class AuthenticationException extends DatabaseException {
  AuthenticationException(String message);
}
```

**Causes:**
- Invalid credentials
- Insufficient permissions
- Expired token

**Example:**
```dart
try {
  await db.signin(credentials);
} on AuthenticationException catch (e) {
  print('Auth failed: ${e.message}');
}
```

### TransactionException

Transaction operation errors.

```dart
class TransactionException extends DatabaseException {
  TransactionException(String message);
}
```

**Causes:**
- Transaction commit failure
- Rollback error (note: rollback is broken)
- Nested transaction attempt

### LiveQueryException

Live query errors.

```dart
class LiveQueryException extends DatabaseException {
  LiveQueryException(String message);
}
```

**Note:** Live queries not fully functional.

### ParameterException

Parameter management errors.

```dart
class ParameterException extends DatabaseException {
  ParameterException(String message);
}
```

**Causes:**
- Invalid parameter name
- Type conversion error

### ExportException

Export operation failures.

```dart
class ExportException extends DatabaseException {
  ExportException(String message);
}
```

### ImportException

Import operation failures.

```dart
class ImportException extends DatabaseException {
  ImportException(String message);
}
```

### ValidationException

Schema validation errors.

```dart
class ValidationException extends DatabaseException {
  final Map<String, String> fieldErrors;

  ValidationException(String message, this.fieldErrors);
}
```

**Example:**
```dart
try {
  tableStructure.validate({'name': 'Alice', 'age': 'invalid'});
} on ValidationException catch (e) {
  print('Validation failed: ${e.message}');
  for (final entry in e.fieldErrors.entries) {
    print('  ${entry.key}: ${entry.value}');
  }
  // age: Expected number, got String
}
```

### SchemaIntrospectionException

Schema reading errors.

```dart
class SchemaIntrospectionException extends DatabaseException {
  SchemaIntrospectionException(String message);
}
```

### MigrationException

Migration execution errors.

```dart
class MigrationException extends DatabaseException {
  MigrationException(String message);
}
```

**Causes:**
- DDL execution failure
- Conflicting schema changes
- Destructive migration blocked

## ORM Exceptions

**Base:** `OrmException extends DatabaseException`

### OrmValidationException

ORM data validation errors.

```dart
class OrmValidationException extends OrmException {
  OrmValidationException(String message);
}
```

### OrmSerializationException

Serialization/deserialization errors.

```dart
class OrmSerializationException extends OrmException {
  OrmSerializationException(String message);
}
```

### OrmRelationshipException

Relationship operation errors.

```dart
class OrmRelationshipException extends OrmException {
  OrmRelationshipException(String message);
}
```

### OrmQueryException

ORM query building errors.

```dart
class OrmQueryException extends OrmException {
  OrmQueryException(String message);
}
```

## Error Handling Patterns

### Specific Exception Handling

```dart
try {
  await db.connect(/*...*/);
} on ConnectionException catch (e) {
  print('Connection error: ${e.message}');
  // Retry or show error to user
} on AuthenticationException catch (e) {
  print('Auth error: ${e.message}');
  // Redirect to login
} on DatabaseException catch (e) {
  print('Database error: ${e.message}');
  // General error handling
} catch (e) {
  print('Unexpected error: $e');
}
```

### Validation with Field Errors

```dart
try {
  user.validate();
  await db.createQL('users', user.toSurrealMap());
} on ValidationException catch (e) {
  for (final entry in e.fieldErrors.entries) {
    showFieldError(entry.key, entry.value);
  }
}
```

### Query Error Recovery

```dart
try {
  return await db.queryQL(query).then((r) => r.getResults());
} on QueryException catch (e) {
  if (e.message.contains('not found')) {
    return [];  // Empty result for not found
  } else if (e.message.contains('syntax')) {
    throw ArgumentError('Invalid query syntax');
  }
  rethrow;
}
```

### Migration Error Handling

```dart
try {
  final result = await db.migrate(dryRun: false);
  print('Migration successful: ${result.migrationId}');
} on MigrationException catch (e) {
  print('Migration failed: ${e.message}');
  // Check logs, restore backup
} on ValidationException catch (e) {
  print('Schema validation failed');
  // Fix schema definitions
}
```

## Common Error Messages

### Connection Errors
- "Failed to connect to database"
- "Invalid storage backend"
- "Database path does not exist"

### Query Errors
- "Parse error: invalid syntax"
- "Table 'X' does not exist"
- "Field 'X' does not exist on table 'Y'"
- "Type mismatch"

### Validation Errors
- "Expected X, got Y"
- "Field 'X' is required"
- "Assert clause failed"

### Authentication Errors
- "Invalid credentials"
- "Insufficient permissions"
- "Token expired"

## Gotchas

1. **RecordId Format:** Always `table:id`, colon required
2. **DateTime Precision:** Microseconds, not nanoseconds
3. **Duration Parsing:** SurrealDB format differs from ISO 8601
4. **Null vs Missing:** Null value differs from missing field
5. **Exception Inheritance:** Catch specific exceptions before general ones
6. **Field Errors:** ValidationException provides detailed field-level errors
7. **Async Exceptions:** Always use try-catch with async database operations
8. **Type Safety:** RecordId, Datetime, etc. provide compile-time safety
9. **Error Messages:** May vary by SurrealDB version
10. **Stack Traces:** Enable for debugging, disable in production
