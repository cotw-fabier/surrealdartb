## Production Migration Guide

# Table Definition Generation & Migration System

Complete guide for using the annotation-based schema generation and migration system in production environments.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Development Workflow](#development-workflow)
4. [Production Workflow](#production-workflow)
5. [Migration Safety](#migration-safety)
6. [Preview Migrations](#preview-migrations)
7. [Handling Destructive Changes](#handling-destructive-changes)
8. [Rollback Procedures](#rollback-procedures)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)
11. [Migration History](#migration-history)

---

## Overview

The Table Definition Generation & Migration System provides:

- **Annotation-Based Schema Definition** - Define your database schema using Dart decorators
- **Automatic Code Generation** - Generate type-safe TableDefinition classes with build_runner
- **Intelligent Migration Detection** - Automatically detect schema changes
- **Safe Migration Execution** - Transaction-based migrations with automatic rollback
- **Production Controls** - Preview, validate, and manually control migrations

### Key Features

✅ **Transaction Safety** - All migrations execute in transactions (atomic all-or-nothing)
✅ **Automatic Rollback** - Failed migrations never leave partial changes
✅ **Destructive Protection** - Destructive operations blocked by default
✅ **Dry-Run Mode** - Preview migrations before applying
✅ **Migration History** - Complete audit trail of all schema changes
✅ **Zero Downtime** - Safe schema evolution without data loss

---

## Quick Start

### Step 1: Define Your Schema

```dart
import 'package:surrealdartb/surrealdartb.dart';

@SurrealTable('users')
class User {
  @SurrealField(type: StringType())
  final String name;

  @SurrealField(
    type: NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 18',
  )
  final int age;

  @SurrealField(
    type: StringType(),
    indexed: true,
  )
  final String email;
}
```

### Step 2: Generate Code

```bash
dart run build_runner build
```

This generates `user.surreal.dart` containing `UserTableDef`.

### Step 3: Use with Database

```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/path/to/db',
  namespace: 'prod',
  database: 'main',
  tableDefinitions: [UserTableDef()],
  autoMigrate: true,  // or false for manual control
);
```

---

## Development Workflow

For rapid iteration during development, use automatic migrations:

### Configuration

```dart
final db = await Database.connect(
  backend: StorageBackend.memory,  // Fast in-memory DB for dev
  namespace: 'dev',
  database: 'dev',
  tableDefinitions: [...],
  autoMigrate: true,  // Automatic schema sync!
);
```

### Workflow

1. **Define/Update Annotations** - Add or modify `@SurrealTable` and `@SurrealField` annotations
2. **Regenerate Code** - Run `dart run build_runner build`
3. **Restart App** - Schema changes auto-detected and applied on connect
4. **Iterate** - Continue developing without manual migration management

### Development Benefits

- ✅ Instant schema updates
- ✅ Fast iteration cycle
- ✅ No manual migration files
- ✅ Safe for additive changes (new fields, new tables)

### Development Limitations

- ⚠️ Auto-migration applies immediately (no preview)
- ⚠️ Destructive changes still require explicit permission
- ⚠️ Not suitable for production deployments

---

## Production Workflow

For production deployments, use manual migration control with safety checks:

### Step 1: Connect with Auto-Migration Disabled

```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/production.db',
  namespace: 'prod',
  database: 'main',
  tableDefinitions: [UserTableDef(), ProductTableDef()],
  autoMigrate: false,  // Manual control!
);
```

The database connects successfully, but schema changes are **not applied yet**.

### Step 2: Preview Migration (Dry-Run)

```dart
final previewReport = await db.migrate(dryRun: true);

if (previewReport.success) {
  print('Migration is safe to apply:');
  print('  Tables to add: ${previewReport.tablesAdded}');
  print('  Fields to add: ${previewReport.fieldsAdded}');
  print('  Indexes to add: ${previewReport.indexesAdded}');
  print('  Destructive: ${previewReport.hasDestructiveChanges}');

  print('\nGenerated DDL:');
  for (final ddl in previewReport.generatedDDL) {
    print('  $ddl');
  }
} else {
  print('Migration would fail: ${previewReport.errorMessage}');
}
```

**Dry-run mode:**
- ✅ Executes migration in a transaction
- ✅ Validates all DDL statements
- ✅ Returns complete report
- ✅ Cancels transaction (no changes applied)
- ✅ Safe to run multiple times

### Step 3: Review and Decide

Based on the preview report:

1. **Safe Changes** (non-destructive):
   - Adding new tables
   - Adding new optional fields
   - Adding indexes
   - Adding assertions

   → Safe to apply immediately

2. **Destructive Changes**:
   - Removing tables
   - Removing fields
   - Changing field types

   → Requires explicit permission and careful review

### Step 4: Apply Migration

```dart
// For safe changes:
final report = await db.migrate(
  allowDestructiveMigrations: false,
  dryRun: false,
);

if (report.success) {
  print('Migration applied successfully');
  print('Migration ID: ${report.migrationId}');
} else {
  print('Migration failed: ${report.errorMessage}');
  // Transaction automatically rolled back
}
```

### Step 5: Verify Migration

```dart
// Check migration history
final history = await db.query(
  'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 5'
);

// Verify schema changes
final users = await db.select('users');
print('User count: ${users.length}');
```

---

## Migration Safety

### Transaction-Based Execution

All migrations execute within SurrealDB transactions:

```sql
BEGIN TRANSACTION;
  DEFINE TABLE users SCHEMAFULL;
  DEFINE FIELD name ON users TYPE string;
  DEFINE FIELD email ON users TYPE string;
  DEFINE INDEX idx_email ON users FIELDS email;
COMMIT TRANSACTION;  -- or CANCEL on failure
```

**Safety Guarantees:**

1. **Atomic Operations** - All DDL applies or none applies
2. **Automatic Rollback** - Failures trigger CANCEL TRANSACTION
3. **Data Integrity** - Existing data is never corrupted
4. **Consistent State** - Database always in valid state

### Safe vs Destructive Changes

#### Safe Changes (Auto-Approved)

These changes are safe and can be applied automatically:

- ✅ **Adding new tables** - No existing data affected
- ✅ **Adding new fields (optional)** - Existing records get null/default
- ✅ **Adding indexes** - Performance optimization only
- ✅ **Adding assertions** - Validation for new data
- ✅ **Adding default values** - Only affects new inserts
- ✅ **Making required fields optional** - Less restrictive

#### Destructive Changes (Require Permission)

These changes can cause data loss and require explicit opt-in:

- ⚠️ **Removing tables** - All table data would be deleted
- ⚠️ **Removing fields** - Field data would be lost
- ⚠️ **Changing field types** - Data conversion may fail
- ⚠️ **Making optional fields required** - Existing nulls may violate constraint
- ⚠️ **Tightening assertions** - Existing data may fail validation
- ⚠️ **Removing indexes** - Performance impact (debatable if destructive)

---

## Preview Migrations

### Using Dry-Run Mode

Dry-run mode allows you to safely preview migrations without applying them:

```dart
final report = await db.migrate(dryRun: true);

// Inspect what would happen:
print('Would this migration succeed? ${report.success}');
print('Is this destructive? ${report.hasDestructiveChanges}');
print('Tables to add: ${report.tablesAdded}');
print('Fields to add: ${report.fieldsAdded}');
print('Generated DDL: ${report.generatedDDL}');
```

### Understanding MigrationReport

```dart
class MigrationReport {
  bool success;                           // Would migration succeed?
  bool dryRun;                           // Was this a dry-run?
  String migrationId;                    // Unique migration identifier

  List<String> tablesAdded;              // New tables
  List<String> tablesRemoved;            // Deleted tables (destructive)
  Map<String, List<String>> fieldsAdded; // New fields per table
  Map<String, List<String>> fieldsRemoved; // Deleted fields (destructive)
  Map<String, List<String>> fieldsModified; // Changed fields (destructive)
  Map<String, List<String>> indexesAdded; // New indexes
  Map<String, List<String>> indexesRemoved; // Deleted indexes

  List<String> generatedDDL;             // All SQL statements
  bool hasDestructiveChanges;            // Requires permission?
  String? errorMessage;                  // Error if success = false
}
```

### Preview Workflow

```dart
// 1. Preview migration
final preview = await db.migrate(dryRun: true);

// 2. Check if safe
if (!preview.hasDestructiveChanges && preview.success) {
  // Safe to apply
  print('✓ Migration is safe, applying...');
  await db.migrate(dryRun: false);
} else if (preview.hasDestructiveChanges) {
  // Needs review
  print('⚠️ Destructive changes detected:');
  print('Tables removed: ${preview.tablesRemoved}');
  print('Fields removed: ${preview.fieldsRemoved}');

  // Wait for approval...
  final approved = await getUserApproval();

  if (approved) {
    await db.migrate(
      allowDestructiveMigrations: true,
      dryRun: false,
    );
  }
} else {
  // Would fail
  print('✗ Migration validation failed:');
  print(preview.errorMessage);
}
```

---

## Handling Destructive Changes

### Detecting Destructive Changes

When a migration includes destructive changes, you'll receive a `MigrationException`:

```dart
try {
  await db.migrate(allowDestructiveMigrations: false);
} on MigrationException catch (e) {
  if (e.isDestructive) {
    print('Destructive changes detected:');
    print(e.message);

    // Example error message:
    // Destructive schema changes detected and allowDestructiveMigrations=false
    //
    // Destructive changes:
    // - Table 'legacy_table' will be removed (120 records may be lost)
    // - Field 'users.old_field' will be removed
    // - Field 'products.price' type changing from string to float
    //
    // To apply these changes:
    // 1. Set allowDestructiveMigrations: true
    // 2. OR fix schema to match database
    // 3. OR manually migrate data before applying changes
  }
}
```

### Applying Destructive Changes Safely

#### Option 1: Explicit Permission (Use with Caution)

```dart
// DANGER: This will remove fields/tables and delete data!
final report = await db.migrate(
  allowDestructiveMigrations: true,  // Explicit opt-in
  dryRun: false,
);
```

**Only use this when:**
- ✅ You've backed up the database
- ✅ You've verified the changes in staging
- ✅ You understand the data loss implications
- ✅ You've migrated any data you need to keep

#### Option 2: Manual Data Migration (Recommended)

For complex destructive changes, manually migrate data first:

```dart
// Step 1: Connect without auto-migration
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/production.db',
  namespace: 'prod',
  database: 'main',
  tableDefinitions: [NewSchema()],
  autoMigrate: false,
);

// Step 2: Manually migrate data
print('Migrating data from old_field to new_field...');
await db.query('''
  UPDATE users SET new_field = old_field WHERE old_field != NONE;
''');

// Step 3: Verify migration
final updated = await db.query('SELECT * FROM users WHERE new_field = NONE');
assert(updated.getResults().isEmpty, 'All records should have new_field');

// Step 4: Apply destructive schema change
print('Applying schema changes...');
await db.migrate(allowDestructiveMigrations: true);

// Step 5: Verify final state
final users = await db.select('users');
print('Migration complete: ${users.length} users migrated');
```

#### Option 3: Fix the Schema (Non-Destructive)

If the destructive change was unintentional, fix your annotations:

```dart
// Before (destructive - removes field):
@SurrealTable('users')
class User {
  @SurrealField(type: StringType())
  final String name;
  // email field removed!
}

// After (fixed - keeps field):
@SurrealTable('users')
class User {
  @SurrealField(type: StringType())
  final String name;

  @SurrealField(type: StringType())
  final String? email;  // Keep existing field
}
```

### Destructive Change Checklist

Before applying destructive migrations:

- [ ] Database is backed up
- [ ] Changes tested in staging environment
- [ ] Data migration script prepared (if needed)
- [ ] Rollback procedure documented
- [ ] Stakeholders notified
- [ ] Dry-run executed successfully
- [ ] Off-peak time scheduled (if downtime expected)

---

## Rollback Procedures

### Automatic Rollback (On Failure)

Failed migrations automatically rollback thanks to transaction safety:

```dart
try {
  await db.migrate(dryRun: false);
} on MigrationException catch (e) {
  // Migration failed and was automatically rolled back
  print('Migration failed: ${e.message}');
  print('Database state unchanged (automatic rollback)');

  // Safe to retry after fixing the issue
}
```

**What happens automatically:**
1. Migration executes in BEGIN TRANSACTION
2. Error detected during execution
3. CANCEL TRANSACTION called automatically
4. Database returns to pre-migration state
5. No manual cleanup needed

### Manual Rollback (Intentional Revert)

To manually rollback a previously applied migration:

```dart
// View migration history
final history = await db.query(
  'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 10'
);

print('Recent migrations:');
for (final migration in history.getResults()) {
  print('${migration['migration_id']}: ${migration['status']}');
}

// Rollback to previous state
final rollbackReport = await db.rollbackMigration();

if (rollbackReport.success) {
  print('Rollback successful');
  print('Reverted to previous schema state');
} else {
  print('Rollback failed: ${rollbackReport.errorMessage}');
}
```

### Manual Rollback Procedure

For complex rollbacks or when automatic rollback isn't available:

#### Step 1: Identify Target State

```dart
// Find the migration to rollback to
final migrations = await db.query('''
  SELECT migration_id, applied_at, schema_snapshot
  FROM _migrations
  WHERE status = 'success'
  ORDER BY applied_at DESC
''');

print('Available migration points:');
for (var i = 0; i < migrations.getResults().length; i++) {
  final m = migrations.getResults()[i];
  print('$i. ${m['applied_at']}: ${m['migration_id']}');
}
```

#### Step 2: Create Reverse Migration

```dart
// Option A: Use stored schema snapshot
final targetMigration = migrations.getResults()[1]; // Previous migration
final snapshotSchema = targetMigration['schema_snapshot'];

// Generate reverse DDL from snapshot...
```

#### Step 3: Apply Reverse Migration

```dart
// Execute reverse DDL in transaction
await db.query('BEGIN TRANSACTION');

try {
  // Apply reverse changes
  await db.query('REMOVE FIELD new_field ON users');
  await db.query('REMOVE INDEX idx_new ON users');

  // Record rollback
  await db.create('_migrations', {
    'migration_id': 'rollback_${DateTime.now().millisecondsSinceEpoch}',
    'applied_at': DateTime.now().toIso8601String(),
    'status': 'rollback',
    'description': 'Manual rollback to previous state',
  });

  await db.query('COMMIT TRANSACTION');
  print('✓ Rollback successful');
} catch (e) {
  await db.query('CANCEL TRANSACTION');
  print('✗ Rollback failed: $e');
  rethrow;
}
```

#### Step 4: Verify State

```dart
// Verify schema after rollback
final tables = await db.query('INFO FOR DB');
print('Current tables: ${tables.getResults()}');

// Verify data integrity
final users = await db.select('users');
print('User count after rollback: ${users.length}');
```

---

## Best Practices

### Development Best Practices

1. **Use In-Memory DB for Tests**
   ```dart
   final testDb = await Database.connect(
     backend: StorageBackend.memory,
     namespace: 'test',
     database: 'test',
     autoMigrate: true,
   );
   ```

2. **Enable Auto-Migration in Dev**
   - Fast iteration
   - Immediate feedback
   - No manual migration management

3. **Commit Generated Files**
   - Check `.surreal.dart` files into version control
   - Ensures consistent builds
   - Documents schema evolution

### Production Best Practices

1. **Disable Auto-Migration**
   ```dart
   autoMigrate: false,  // Always false in production
   ```

2. **Always Use Dry-Run First**
   ```dart
   // Preview before applying
   final preview = await db.migrate(dryRun: true);
   // Review, then apply
   await db.migrate(dryRun: false);
   ```

3. **Backup Before Destructive Changes**
   ```bash
   # Create backup before migration
   surreal export --ns prod --db main backup.surql
   ```

4. **Test in Staging First**
   - Apply migrations to staging environment
   - Verify application compatibility
   - Monitor for issues
   - Then apply to production

5. **Monitor Migration History**
   ```dart
   // Regular audit of migrations
   final history = await db.query(
     'SELECT * FROM _migrations WHERE status = "failed"'
   );
   ```

6. **Use Version Control for Schema**
   - Tag releases with schema versions
   - Document migration procedures
   - Track schema evolution over time

### Schema Design Best Practices

1. **Make New Fields Optional**
   ```dart
   // Good: Won't break existing data
   @SurrealField(type: StringType())
   final String? newField;

   // Bad: Requires default or migration
   @SurrealField(type: StringType())
   final String newField;
   ```

2. **Use Default Values**
   ```dart
   @SurrealField(
     type: StringType(),
     defaultValue: 'pending',
   )
   final String status;
   ```

3. **Add Assertions Incrementally**
   ```dart
   // Phase 1: Add field without assertion
   @SurrealField(type: NumberType())
   final int age;

   // Phase 2: After data cleaned, add assertion
   @SurrealField(
     type: NumberType(),
     assertClause: r'$value >= 0',
   )
   final int age;
   ```

4. **Index Strategically**
   ```dart
   // Index frequently queried fields
   @SurrealField(type: StringType(), indexed: true)
   final String email;

   // Don't over-index (slows writes)
   ```

---

## Troubleshooting

### Migration Fails to Apply

**Symptom:** Migration throws `MigrationException`

**Possible Causes:**
1. Destructive changes without permission
2. Invalid DDL syntax
3. Constraint violation with existing data
4. Database connection issue

**Solutions:**

```dart
try {
  await db.migrate();
} on MigrationException catch (e) {
  print('Migration error: ${e.message}');

  if (e.isDestructive) {
    // Destructive changes detected
    print('Review changes and use allowDestructiveMigrations: true');
  } else {
    // Other error - check DDL
    print('Review generated DDL for errors');
    final preview = await db.migrate(dryRun: true);
    print(preview.generatedDDL);
  }
}
```

### Schema Not Detected

**Symptom:** Changes to annotations not reflected in migration

**Possible Causes:**
1. Forgot to run build_runner
2. Generated files not imported
3. Old TableDefinition passed to Database.connect()

**Solutions:**

```bash
# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Clean build
dart run build_runner clean
dart run build_runner build
```

### Data Loss After Migration

**Symptom:** Data missing after applying migration

**This should not happen due to transaction safety!**

**If it does:**
1. Check migration history for clues
2. Look for destructive changes that were applied
3. Restore from backup
4. Report as a bug (transaction safety failed)

**Prevention:**
- Always use dry-run mode first
- Backup before destructive changes
- Test in staging environment

### Migration History Corrupted

**Symptom:** `_migrations` table has invalid entries

**Recovery:**

```dart
// Query migration history
final history = await db.query('SELECT * FROM _migrations');
print('Current history: ${history.getResults()}');

// If corrupted, can manually fix:
await db.query('''
  UPDATE _migrations SET status = 'invalid'
  WHERE migration_id = '<problematic-id>'
''');

// Or clear and restart (DANGER: loses history):
await db.query('DELETE FROM _migrations');
```

### Cannot Rollback

**Symptom:** Rollback fails with error

**Possible Causes:**
1. No previous migration to rollback to
2. Schema snapshot missing
3. Current state incompatible with previous state

**Solutions:**

```dart
// Check if rollback is possible
final history = await db.query(
  'SELECT COUNT() as count FROM _migrations WHERE status = "success"'
);

if (history.getResults()[0]['count'] < 2) {
  print('No previous migration to rollback to');
  // Must manually revert schema
}
```

---

## Migration History

### Understanding _migrations Table

The system automatically creates a `_migrations` table to track all schema changes:

```sql
DEFINE TABLE _migrations SCHEMAFULL;
DEFINE FIELD migration_id ON _migrations TYPE string;
DEFINE FIELD applied_at ON _migrations TYPE datetime;
DEFINE FIELD status ON _migrations TYPE string;
DEFINE FIELD schema_snapshot ON _migrations TYPE object;
DEFINE FIELD changes_applied ON _migrations TYPE array;
```

### Querying Migration History

```dart
// Recent migrations
final recent = await db.query('''
  SELECT migration_id, applied_at, status
  FROM _migrations
  ORDER BY applied_at DESC
  LIMIT 10
''');

// Failed migrations
final failed = await db.query('''
  SELECT * FROM _migrations WHERE status = 'failed'
''');

// Migrations in last 7 days
final recent_week = await db.query('''
  SELECT * FROM _migrations
  WHERE applied_at > time::now() - 7d
  ORDER BY applied_at DESC
''');
```

### Migration History Fields

- **migration_id**: Unique hash of schema changes (deterministic)
- **applied_at**: Timestamp when migration was executed
- **status**: `success`, `failed`, or `rollback`
- **schema_snapshot**: Complete schema state after migration (for rollback)
- **changes_applied**: List of DDL statements executed

### Using History for Auditing

```dart
// Generate migration audit report
Future<void> auditMigrations(Database db) async {
  final history = await db.query('''
    SELECT
      migration_id,
      applied_at,
      status,
      changes_applied
    FROM _migrations
    ORDER BY applied_at ASC
  ''');

  print('Migration Audit Report');
  print('=' * 60);

  for (final migration in history.getResults()) {
    print('\nMigration: ${migration['migration_id']}');
    print('Applied: ${migration['applied_at']}');
    print('Status: ${migration['status']}');
    print('Changes:');
    for (final change in migration['changes_applied']) {
      print('  - $change');
    }
  }
}
```

---

## Summary

The Table Definition Generation & Migration System provides:

✅ **Annotation-Based Schema** - Define once, generate everywhere
✅ **Automatic Detection** - Schema changes detected automatically
✅ **Transaction Safety** - Atomic migrations with automatic rollback
✅ **Production Controls** - Preview, validate, and manually control
✅ **Zero Downtime** - Safe schema evolution without data loss
✅ **Complete History** - Full audit trail of all changes

### Recommended Workflow

**Development:**
```dart
autoMigrate: true  // Fast iteration
```

**Production:**
```dart
1. autoMigrate: false
2. Preview with migrate(dryRun: true)
3. Review and approve
4. Apply with migrate(dryRun: false)
5. Verify and monitor
```

### Key Principles

1. **Safety First** - Always use dry-run in production
2. **Backup Always** - Before destructive changes
3. **Test Thoroughly** - Staging before production
4. **Monitor Actively** - Track migration history
5. **Document Everything** - Schema evolution and procedures

For more examples, see `/example/scenarios/` directory.
