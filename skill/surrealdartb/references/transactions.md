# Transactions

**CRITICAL BUG:** Transaction rollback is broken in current version. `CANCEL TRANSACTION` executes but changes persist. This affects both memory and RocksDB backends.

**Status:** 7/8 transaction tests pass, rollback test fails
**Impact:** Cannot rely on ACID rollback semantics
**Workaround:** Avoid transactions requiring rollback until fixed

## Transaction Syntax

Execute transaction via raw SurrealQL.

```dart
await db.queryQL('BEGIN TRANSACTION;');

try {
  // Execute operations
  await db.queryQL('CREATE users SET name = "Alice";');
  await db.queryQL('CREATE posts SET title = "First post";');

  // Commit
  await db.queryQL('COMMIT TRANSACTION;');
} catch (e) {
  // Rollback (BROKEN - changes will persist!)
  await db.queryQL('CANCEL TRANSACTION;');
  rethrow;
}
```

## Transaction Statements

```sql
BEGIN TRANSACTION;    -- Start transaction
COMMIT TRANSACTION;   -- Commit changes
CANCEL TRANSACTION;   -- Rollback (BROKEN)
```

## Working Functionality

### Commit Works Correctly

```dart
await db.queryQL('BEGIN TRANSACTION;');

await db.queryQL('CREATE users:alice SET name = "Alice";');
await db.queryQL('CREATE users:bob SET name = "Bob";');

await db.queryQL('COMMIT TRANSACTION;');

// Both users created ✅
final users = await db.selectQL('users');
assert(users.length == 2);
```

### Error Handling Works

```dart
await db.queryQL('BEGIN TRANSACTION;');

try {
  await db.queryQL('CREATE users:alice SET name = "Alice";');
  await db.queryQL('INVALID SYNTAX;');  // Throws error
  await db.queryQL('COMMIT TRANSACTION;');
} on QueryException catch (e) {
  print('Transaction failed: ${e.message}');
  // Transaction automatically aborted on error ✅
}
```

## Broken Functionality

### Rollback Does Not Work

```dart
await db.queryQL('BEGIN TRANSACTION;');

await db.queryQL('CREATE users:alice SET name = "Alice";');
await db.queryQL('CREATE users:bob SET name = "Bob";');

await db.queryQL('CANCEL TRANSACTION;');

// ❌ BUG: Users still exist after CANCEL!
final users = await db.selectQL('users');
assert(users.length == 0);  // FAILS - users were created
```

## Migration Usage

Migrations use transactions for atomicity:

```dart
// From migration_engine.dart
await db.queryQL('BEGIN TRANSACTION;');

try {
  for (final ddl in ddlStatements) {
    await db.queryQL(ddl);
  }

  await db.queryQL('COMMIT TRANSACTION;');
} catch (e) {
  await db.queryQL('CANCEL TRANSACTION;');  // BROKEN
  throw MigrationException('Rollback failed: $e');
}
```

**Impact:** Failed migrations may be partially applied.

**Workaround:** Dry-run migrations to verify before applying.

```dart
// Always preview first
final preview = await db.migrate(dryRun: true);
print('DDL: ${preview.generatedDDL}');

// Then apply
if (confirmed) {
  await db.migrate(dryRun: false);
}
```

## Current Recommendations

### DO: Use Transactions for Commits

```dart
// Atomic multi-operation inserts
await db.queryQL('''
  BEGIN TRANSACTION;

  CREATE products:widget SET name = "Widget", price = 9.99;
  CREATE inventory:widget SET product = products:widget, quantity = 100;

  COMMIT TRANSACTION;
''');
```

### DO: Rely on Error Aborts

```dart
// Transaction aborted on error
await db.queryQL('''
  BEGIN TRANSACTION;

  CREATE users:alice SET name = "Alice";
  -- Syntax error automatically aborts
  INVALID_STATEMENT;

  COMMIT TRANSACTION;
''');
// alice NOT created ✅
```

### DON'T: Rely on Manual Rollback

```dart
// DON'T: Manual rollback doesn't work
await db.queryQL('BEGIN TRANSACTION;');

if (shouldCancel) {
  await db.queryQL('CANCEL TRANSACTION;');  // BROKEN
}
```

### DON'T: Use for Critical ACID Requirements

```dart
// DON'T: Can't guarantee rollback
async function transferMoney(from, to, amount) {
  await db.queryQL('BEGIN TRANSACTION;');

  await db.queryQL(`UPDATE accounts:${from} SET balance -= ${amount};`);

  if (await checkFraud()) {
    await db.queryQL('CANCEL TRANSACTION;');  // BROKEN - money deducted!
    return;
  }

  await db.queryQL(`UPDATE accounts:${to} SET balance += ${amount};`);
  await db.queryQL('COMMIT TRANSACTION;');
}
```

## Workarounds

### Manual Compensation

Implement manual rollback logic:

```dart
final rollbackOps = <String>[];

await db.queryQL('CREATE users:alice SET name = "Alice";');
rollbackOps.add('DELETE users:alice;');

await db.queryQL('CREATE posts:1 SET title = "Post";');
rollbackOps.add('DELETE posts:1;');

if (shouldRollback) {
  // Manual compensation
  for (final op in rollbackOps.reversed) {
    await db.queryQL(op);
  }
}
```

### Dry-Run Pattern

Preview operations before executing:

```dart
// 1. Validate in memory
final memDb = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);

try {
  await executeOperations(memDb);
  // Validation successful
} catch (e) {
  print('Operations would fail: $e');
  return;
}

// 2. Execute on real DB
await executeOperations(realDb);
```

### Snapshot Pattern

Create backup before risky operations:

```dart
// Not implemented in package - custom solution needed
await backupDatabase(db);

try {
  await riskyOperations(db);
} catch (e) {
  await restoreDatabase(db);
  rethrow;
}
```

## Exception Handling

**Exception:** `TransactionException`

```dart
try {
  await db.queryQL('BEGIN TRANSACTION;');
  await db.queryQL('CREATE users SET name = "Alice";');
  await db.queryQL('COMMIT TRANSACTION;');
} on TransactionException catch (e) {
  print('Transaction failed: ${e.message}');
}
```

## Testing Recommendations

### Test for Commit

```dart
test('transaction commit works', () async {
  await db.queryQL('BEGIN TRANSACTION;');
  await db.createQL('users', {'name': 'Alice'});
  await db.queryQL('COMMIT TRANSACTION;');

  final users = await db.selectQL('users');
  expect(users.length, 1);
});
```

### Avoid Testing Rollback

```dart
// This test will FAIL due to bug
test('transaction rollback', () async {
  await db.queryQL('BEGIN TRANSACTION;');
  await db.createQL('users', {'name': 'Alice'});
  await db.queryQL('CANCEL TRANSACTION;');

  final users = await db.selectQL('users');
  expect(users.length, 0);  // FAILS - user still exists
});
```

## Future Expectations

Once bug is fixed, standard ACID semantics will apply:

```dart
// Future: This will work correctly
await db.queryQL('BEGIN TRANSACTION;');

await db.createQL('users', {'name': 'Alice'});

if (condition) {
  await db.queryQL('CANCEL TRANSACTION;');  // Will actually rollback
} else {
  await db.queryQL('COMMIT TRANSACTION;');
}
```

## Gotchas

1. **ROLLBACK BROKEN:** Primary issue - changes persist after CANCEL
2. **Migration Risk:** Failed migrations may be partially applied
3. **Both Backends:** Affects memory AND RocksDB
4. **No Savepoints:** Cannot rollback to specific point in transaction
5. **Nested Transactions:** Not supported
6. **Implicit Begin:** Some operations auto-start transaction
7. **Connection Scope:** Transactions tied to single database connection

## References

- **Issue Tracking:** `agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md`
- **Test File:** `test/transaction_test.dart`
- **Test Status:** 7/8 passing (rollback test fails)
