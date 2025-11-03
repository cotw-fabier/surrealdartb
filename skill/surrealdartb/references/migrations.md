# Schema Migrations

**Primary File:** `lib/src/schema/migration_engine.dart`

## Auto-Migration

Automatically apply schema changes on database connection.

```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: './db',
  namespace: 'app',
  database: 'main',
  tableDefinitions: [UserTableDef(), PostTableDef()],
  autoMigrate: true,
  allowDestructiveMigrations: false,  // Require confirmation for dangerous changes
);
```

## Manual Migration

### migrate()

Execute schema migration with optional dry-run.

```dart
Future<MigrationReport> migrate({
  bool dryRun = false,
  bool allowDestructiveMigrations = false,
})
```

**Example:**
```dart
// Preview changes
final preview = await db.migrate(dryRun: true);
print('Tables to add: ${preview.tablesAdded}');
print('Tables to remove: ${preview.tablesRemoved}');
print('Has destructive changes: ${preview.hasDestructiveChanges}');

// Apply if safe
if (!preview.hasDestructiveChanges) {
  final result = await db.migrate(dryRun: false);
  print('Migration ID: ${result.migrationId}');
}
```

### rollbackMigration()

Rollback last migration (if supported).

```dart
Future<void> rollbackMigration()
```

## MigrationReport

Detailed report of migration execution.

```dart
class MigrationReport {
  final bool success;
  final bool dryRun;
  final String? migrationId;

  // Changes
  final List<String> tablesAdded;
  final List<String> tablesRemoved;
  final Map<String, List<String>> fieldsAdded;
  final Map<String, List<String>> fieldsRemoved;
  final Map<String, List<String>> fieldsModified;
  final Map<String, List<String>> indexesAdded;
  final Map<String, List<String>> indexesRemoved;

  // DDL
  final List<String> generatedDDL;

  // Safety
  final bool hasDestructiveChanges;
  final String? errorMessage;
}
```

**Example:**
```dart
final report = await db.migrate(dryRun: true);

if (report.success) {
  print('DDL to execute:');
  report.generatedDDL.forEach(print);

  if (report.hasDestructiveChanges) {
    print('WARNING: Destructive changes detected!');
    print('Tables removed: ${report.tablesRemoved}');
    print('Fields removed: ${report.fieldsRemoved}');
  }
}
```

## Schema Introspection

**File:** `lib/src/schema/introspection.dart`

Read current database schema.

### DatabaseSchema.introspect()

```dart
static Future<DatabaseSchema> introspect(Database db)
```

**Returns:**
```dart
class DatabaseSchema {
  final Map<String, TableSchema> tables;
}

class TableSchema {
  final String name;
  final Map<String, FieldSchema> fields;
  final List<IndexSchema> indexes;
}

class FieldSchema {
  final String name;
  final String type;
  final bool optional;
}

class IndexSchema {
  final String name;
  final List<String> fields;
  final bool unique;
}
```

**Example:**
```dart
final schema = await DatabaseSchema.introspect(db);

for (final tableName in schema.tables.keys) {
  final table = schema.tables[tableName]!;
  print('Table: $tableName');

  for (final field in table.fields.values) {
    print('  ${field.name}: ${field.type} ${field.optional ? '(optional)' : ''}');
  }

  for (final index in table.indexes) {
    print('  Index: ${index.name} on ${index.fields}');
  }
}
```

## Schema Diff Engine

**File:** `lib/src/schema/diff_engine.dart`

Calculate differences between schemas.

### SchemaDiff.calculate()

```dart
static SchemaDiff calculate(
  DatabaseSchema current,
  DatabaseSchema desired,
)
```

**Returns:**
```dart
class SchemaDiff {
  final List<TableDiff> tableDiffs;
  final List<String> tablesAdded;
  final List<String> tablesRemoved;
}

class TableDiff {
  final String tableName;
  final List<String> fieldsAdded;
  final List<String> fieldsRemoved;
  final List<FieldModification> fieldsModified;
  final List<String> indexesAdded;
  final List<String> indexesRemoved;
}

class FieldModification {
  final String fieldName;
  final String oldType;
  final String newType;
  final bool typeChanged;
  final bool optionalityChanged;
}
```

**Example:**
```dart
final current = await DatabaseSchema.introspect(db);
final desired = DatabaseSchema.fromTableDefinitions([UserTableDef()]);
final diff = SchemaDiff.calculate(current, desired);

for (final tableDiff in diff.tableDiffs) {
  print('Table ${tableDiff.tableName} changes:');
  print('  Fields added: ${tableDiff.fieldsAdded}');
  print('  Fields removed: ${tableDiff.fieldsRemoved}');
}
```

## DDL Generation

**File:** `lib/src/schema/ddl_generator.dart`

Generate SurrealQL DDL statements from schema diff.

### generateDDL()

```dart
List<String> generateDDL(SchemaDiff diff)
```

**Generated statements:**
- `DEFINE TABLE`
- `DEFINE FIELD`
- `DEFINE INDEX`
- `REMOVE TABLE`
- `REMOVE FIELD`
- `REMOVE INDEX`

**Example:**
```dart
final diff = SchemaDiff.calculate(current, desired);
final ddl = generateDDL(diff);

for (final statement in ddl) {
  print(statement);
}
// DEFINE TABLE users SCHEMAFULL;
// DEFINE FIELD name ON users TYPE string;
// DEFINE FIELD age ON users TYPE number;
```

## Migration History

**File:** `lib/src/schema/migration_history.dart`

Track migration execution in `_migrations` table.

### MigrationRecord

```dart
class MigrationRecord {
  final String id;
  final DateTime appliedAt;
  final List<String> ddlStatements;
  final Map<String, dynamic> changes;
  final bool hasDestructiveChanges;
}
```

**Automatic tracking:**
```dart
// Migrations stored in _migrations table
final history = await db.selectQL<Map>('_migrations');

for (final migration in history) {
  print('Migration ${migration['id']} applied at ${migration['applied_at']}');
}
```

## Destructive Change Analysis

**File:** `lib/src/schema/destructive_change_analyzer.dart`

Classify changes as safe or destructive.

### Destructive Changes

Operations that may lose data:
- `DROP TABLE` / `REMOVE TABLE`
- `REMOVE FIELD`
- Field type changes (e.g., string → number)
- Adding non-optional field to existing table
- Changing field from optional to required

### Safe Changes

Operations that preserve data:
- `DEFINE TABLE` (new table)
- `DEFINE FIELD` (new optional field)
- `DEFINE INDEX`
- Changing field from required to optional
- Adding indexes

**Example:**
```dart
final report = await db.migrate(dryRun: true);

if (report.hasDestructiveChanges) {
  print('⚠️  WARNING: Destructive changes require confirmation');
  print('Tables to remove: ${report.tablesRemoved}');
  print('Fields to remove: ${report.fieldsRemoved}');

  // Require explicit permission
  final result = await db.migrate(
    dryRun: false,
    allowDestructiveMigrations: true,  // Must be true
  );
}
```

## Migration Workflows

### Safe Development Workflow

```dart
// 1. Update TableStructure definitions
final newUserTable = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'email': FieldDefinition(StringType()),  // New field
});

// 2. Preview migration
final preview = await db.migrate(dryRun: true);
print('Changes:');
print(preview.generatedDDL.join('\n'));

// 3. Check for destructive changes
if (preview.hasDestructiveChanges) {
  print('⚠️  Destructive changes detected!');
  print('Review and confirm before applying.');
  return;
}

// 4. Apply migration
final result = await db.migrate(dryRun: false);
print('✅ Migration ${result.migrationId} applied successfully');
```

### Production Deployment

```dart
// 1. Auto-migrate with safety checks
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/var/lib/myapp/db',
  namespace: 'production',
  database: 'main',
  tableDefinitions: tableDefinitions,
  autoMigrate: true,
  allowDestructiveMigrations: false,  // Block destructive in prod
);

// Migration fails if destructive changes detected
// Manual intervention required for destructive changes
```

### Manual Migration with Backup

```dart
// 1. Backup before migration (implement your own backup)
await backupDatabase(db);

// 2. Preview changes
final preview = await db.migrate(dryRun: true);

// 3. Log migration plan
logger.info('Migration plan: ${preview.generatedDDL}');

// 4. Apply with confirmation
if (await confirmWithUser(preview)) {
  final result = await db.migrate(
    dryRun: false,
    allowDestructiveMigrations: preview.hasDestructiveChanges,
  );
  logger.info('Migration complete: ${result.migrationId}');
}
```

## Common Patterns

### Adding New Table

```dart
// 1. Define new table
final productTable = TableStructure('products', {
  'name': FieldDefinition(StringType()),
  'price': FieldDefinition(NumberType()),
});

// 2. Add to tableDefinitions and migrate
await db.migrate(dryRun: false);
```

### Adding Field to Existing Table

```dart
// 1. Update TableStructure (add optional field to avoid destructive)
final updatedTable = TableStructure('users', {
  'name': FieldDefinition(StringType()),
  'age': FieldDefinition(NumberType()),
  'email': FieldDefinition(StringType(), optional: true),  // New optional field
});

// 2. Migrate
await db.migrate(dryRun: false);
```

### Renaming Field (Workaround)

SurrealDB doesn't support direct rename - requires data migration:

```dart
// 1. Add new field
await db.queryQL('DEFINE FIELD new_name ON users TYPE string');

// 2. Copy data
await db.queryQL('UPDATE users SET new_name = old_name');

// 3. Remove old field (destructive!)
await db.queryQL('REMOVE FIELD old_name ON users');
```

### Type Migration

```dart
// Type changes are destructive - backup and migrate data manually
// 1. Preview change
final preview = await db.migrate(dryRun: true);

// 2. If type change detected, manual migration needed
if (preview.fieldsModified.isNotEmpty) {
  // Add new field with new type
  await db.queryQL('DEFINE FIELD age_new ON users TYPE number');

  // Convert and migrate data
  await db.queryQL('UPDATE users SET age_new = <number>age');

  // Remove old field
  await db.queryQL('REMOVE FIELD age ON users');

  // Rename new field to old name (via data migration)
}
```

## Gotchas

1. **Transaction Support:** Migrations run in transactions but rollback is broken (see troubleshooting)
2. **Destructive Flag:** Must set `allowDestructiveMigrations: true` for destructive changes
3. **Auto-Migration Timing:** Runs immediately on connect - ensure schema up to date
4. **Field Renaming:** Not supported - requires manual data migration
5. **Type Changes:** Always destructive - plan data migration carefully
6. **Vector Fields:** Remember to use `array<float>` not `vector<F32,384>` in DDL
7. **Dry Run:** Always preview with `dryRun: true` first in production
8. **Migration History:** Stored in `_migrations` table - don't delete manually
