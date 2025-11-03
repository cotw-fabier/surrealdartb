# Troubleshooting & Known Issues

## Critical Issues

### 1. Transaction Rollback Broken

**Issue:** `CANCEL TRANSACTION` executes but changes persist.

**Status:** ⚠️ BLOCKING - Affects both memory and RocksDB backends

**Impact:**
- Cannot rely on ACID rollback semantics
- Failed migrations may be partially applied
- 7/8 transaction tests pass, rollback test fails

**Workaround:**
```dart
// Use dry-run migrations
final preview = await db.migrate(dryRun: true);
if (preview.success && !preview.hasDestructiveChanges) {
  await db.migrate(dryRun: false);
}

// Implement manual compensation
final rollbackOps = <String>[];
// Track operations and manually reverse if needed
```

**Reference:** `agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md`

### 2. Vector DDL Syntax Not Supported

**Issue:** `vector<F32,384>` syntax doesn't work in SCHEMAFULL tables.

**Status:** ⚠️ WORKAROUND AVAILABLE

**Problem:**
```dart
// ❌ DOESN'T WORK
await db.queryQL('''
  DEFINE TABLE documents SCHEMAFULL;
  DEFINE FIELD embedding ON documents TYPE vector<F32,384>;
''');
// Stores empty arrays instead of vectors
```

**Solution:**
```dart
// ✅ USE THIS
await db.queryQL('''
  DEFINE TABLE documents SCHEMAFULL;
  DEFINE FIELD embedding ON documents TYPE array<float>;
''');
```

**Why:** Embedded SurrealDB 2.3.10 doesn't support vector DDL syntax yet.

**TableStructure:** Still use VectorType for validation, just not in DDL:
```dart
'embedding': FieldDefinition(
  VectorType(VectorFormat.f32, 384),  // Validation only
)
```

### 3. Live Queries Not Functional

**Issue:** Infrastructure exists but not exposed to FFI.

**Status:** 🚧 IN PROGRESS (20% complete)

**Impact:** No real-time data subscriptions available

**Workaround:** Poll for updates or implement custom change detection

## Common Issues

### Vector Search Returns Empty Results

**Symptoms:**
- Similarity search returns no results
- Vectors stored but not indexed

**Causes:**
1. Vector field defined as `vector<F32,384>` instead of `array<float>`
2. Index created before data inserted
3. Wrong distance metric for use case

**Solutions:**
```dart
// 1. Fix field type
await db.queryQL('DEFINE FIELD embedding ON docs TYPE array<float>;');

// 2. Recreate index after inserting data
await db.dropVectorIndex('docs', 'embedding');
// Insert data first
await db.createVectorIndex(/*...*/);

// 3. Use cosine for text embeddings
await db.searchSimilar(
  metric: DistanceMetric.cosine,  // Best for semantic search
  // ...
);
```

### Schema Validation Fails

**Symptoms:**
- `ValidationException` thrown
- Field type mismatches

**Common Causes:**

**1. Type Coercion Expected**
```dart
// ❌ Fails - no auto coercion
await db.createQL('users', {'age': '25'}, schema: userTable);

// ✅ Correct type
await db.createQL('users', {'age': 25}, schema: userTable);
```

**2. Optional Field Confusion**
```dart
// ❌ Can't explicitly set null
await db.createQL('users', {'email': null});

// ✅ Omit optional fields
await db.createQL('users', {'name': 'Alice'});
```

**3. Nested Object Validation**
```dart
// Ensure nested objects match schema
'address': FieldDefinition(ObjectType(schema: {
  'street': FieldDefinition(StringType()),
  'city': FieldDefinition(StringType()),
}))
```

### Build Runner Issues

**Symptoms:**
- Generated files not updating
- Conflicting outputs
- Build errors

**Solutions:**

**1. Clean and rebuild**
```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

**2. Check build.yaml**
```yaml
targets:
  $default:
    builders:
      surrealdartb|surreal_table_generator:
        enabled: true
        options:
          generate_for:
            - lib/models/**/*.dart  # Check path
```

**3. Import generated files**
```dart
import 'package:myapp/models/user.dart';
import 'package:myapp/models/user.surreal.dart';  // Don't forget!
```

**4. Rebuild after annotation changes**
```bash
# Watch mode for development
dart run build_runner watch
```

### Migration Fails to Apply

**Symptoms:**
- Migration reports success but changes not visible
- Partial migrations applied

**Causes:**

**1. Destructive changes blocked**
```dart
// Check for destructive changes
final preview = await db.migrate(dryRun: true);
if (preview.hasDestructiveChanges) {
  // Must allow explicitly
  await db.migrate(
    dryRun: false,
    allowDestructiveMigrations: true,
  );
}
```

**2. Transaction rollback issue**
```dart
// If migration fails, may be partially applied
// Always dry-run first
final preview = await db.migrate(dryRun: true);
print('DDL:\n${preview.generatedDDL.join('\n')}');
// Review before applying
```

**3. Schema definition mismatch**
```dart
// Ensure TableStructure matches desired schema
// Check field types, optional flags, etc.
```

### Connection Errors

**Symptoms:**
- `ConnectionException` on connect
- Database file locked

**Solutions:**

**1. Path issues**
```dart
// ❌ Relative path may fail
path: './db'

// ✅ Absolute path preferred
path: '/full/path/to/db'

// ✅ Or use path_provider
final dir = await getApplicationDocumentsDirectory();
path: '${dir.path}/myapp.db'
```

**2. Permissions**
```bash
# Check directory permissions
ls -la /path/to/db/

# Ensure write access
chmod 755 /path/to/db/
```

**3. Multiple connections**
```dart
// Only one connection per database file
await db1.close();  // Close before opening another
final db2 = await Database.connect(/*same path*/);
```

### Performance Issues

**Symptoms:**
- Slow queries
- High memory usage
- App lag

**Solutions:**

**1. Add indexes**
```dart
'email': FieldDefinition(
  StringType(),
  indexed: true,  // Index frequently queried fields
)
```

**2. Limit results**
```dart
await db.queryQL('SELECT * FROM users LIMIT 100');
```

**3. Use vector indexes**
```dart
// Don't search without index on large datasets
await db.createVectorIndex(
  table: 'documents',
  field: 'embedding',
  dimensions: 384,
  indexType: IndexType.hnsw,  // Fast for >100K vectors
  metric: DistanceMetric.cosine,
);
```

**4. Close connections**
```dart
try {
  // operations
} finally {
  await db.close();  // Always close
}
```

**5. Batch operations**
```dart
// ❌ Slow - multiple queries
for (final item in items) {
  await db.createQL('table', item);
}

// ✅ Fast - single batch query
await db.queryQL('''
  INSERT INTO table [
    ${items.map((i) => i.toJson()).join(', ')}
  ]
''');
```

## Platform-Specific Issues

### macOS

**Apple Silicon (M1/M2/M3):**
- Native ARM builds supported
- No Rosetta required

**Intel:**
- x86_64 builds available

**Permissions:**
```bash
# If database file access denied
chmod 755 ~/path/to/db/
```

### iOS

**Simulator:**
- Full support
- Same architecture as host Mac

**Device:**
- ARM64 builds required
- Enable "Embedded Content Contains Swift Code" in Xcode if using Swift bridge

**File Access:**
```dart
// Use app documents directory
final dir = await getApplicationDocumentsDirectory();
final dbPath = '${dir.path}/app.db';
```

### Android

**ABI Support:**
- arm64-v8a (64-bit ARM)
- armeabi-v7a (32-bit ARM)
- x86_64 (64-bit Intel emulator)

**Permissions:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
```

**File Path:**
```dart
// Internal storage
final dir = await getApplicationDocumentsDirectory();

// External storage (with permission)
final dir = await getExternalStorageDirectory();
```

### Windows

**Architecture:**
- x64 support
- ARM64 support (Windows 11 on ARM)

**Path Format:**
```dart
// Use forward slashes or double backslashes
path: 'C:/Users/Name/db'  // ✅
path: r'C:\Users\Name\db'  // ✅
path: 'C:\Users\Name\db'   // ❌ Escape issues
```

### Linux

**Architectures:**
- x86_64
- ARM64 (Raspberry Pi, etc.)

**Permissions:**
```bash
# Ensure user has write access
chmod 755 /path/to/db/
```

## Debugging Tips

### Enable Verbose Logging

```dart
// Check query execution
final response = await db.queryQL('SELECT * FROM users');
print('Results: ${response.getResults()}');
print('Errors: ${response.getErrors()}');
```

### Inspect Generated Schema

```dart
// View current database schema
final schema = await DatabaseSchema.introspect(db);
for (final table in schema.tables.values) {
  print('Table: ${table.name}');
  for (final field in table.fields.values) {
    print('  ${field.name}: ${field.type}');
  }
}
```

### Test Vector Storage

```dart
// Verify vector is stored correctly
final vec = VectorValue.f32([1.0, 2.0, 3.0]);
await db.createQL('test', {'vec': vec.toJson()});

final result = await db.get<Map>('test:⟨...⟩');
print('Stored: ${result!['vec']}');
print('Type: ${result['vec'].runtimeType}');
```

### Check Index Creation

```dart
// Verify index exists
final hasIndex = await db.hasVectorIndex('documents', 'embedding');
print('Index exists: $hasIndex');

// Inspect with introspection
final schema = await DatabaseSchema.introspect(db);
final table = schema.tables['documents'];
print('Indexes: ${table?.indexes}');
```

### Migration Debugging

```dart
// Always dry-run first
final preview = await db.migrate(dryRun: true);
print('Success: ${preview.success}');
print('Destructive: ${preview.hasDestructiveChanges}');
print('DDL:');
preview.generatedDDL.forEach(print);
print('Errors: ${preview.errorMessage}');
```

## Error Messages & Solutions

### "Parse error: invalid syntax"
**Cause:** SurrealQL syntax error
**Solution:** Check query syntax, parameter binding, quotes

### "Table 'X' does not exist"
**Cause:** Table not created or wrong namespace/database
**Solution:** Create table or check `useNamespace()`/`useDatabase()`

### "Field 'X' does not exist"
**Cause:** Field not defined in schema
**Solution:** Run migration or define field manually

### "Expected X, got Y"
**Cause:** Type mismatch in validation
**Solution:** Fix data type or update schema

### "Vector dimensions mismatch"
**Cause:** Vector size doesn't match defined dimensions
**Solution:** Ensure embedding size matches FieldDefinition

### "Index already exists"
**Cause:** Attempting to create duplicate index
**Solution:** Check with `hasVectorIndex()` first or drop existing

### "Permission denied"
**Cause:** File system permissions
**Solution:** Check directory permissions, use app-specific directories

## Best Practices to Avoid Issues

1. **Always dry-run migrations** before applying in production
2. **Use `array<float>` for vector fields** in SCHEMAFULL tables
3. **Close database connections** in finally blocks
4. **Validate data** before CRUD operations
5. **Create indexes after** inserting initial data
6. **Use typed builders** for WhereConditions to avoid syntax errors
7. **Test on target platforms** before release
8. **Handle exceptions** for all database operations
9. **Check migration reports** for destructive changes
10. **Keep SurrealDB version** consistent across environments

## Getting Help

**Documentation:**
- Package README: `/README.md`
- Test examples: `/test/`
- Scenario examples: `/example/scenarios/`

**Issue Tracking:**
- Roadmap: `/agent-os/product/roadmap.md`
- Known issues: `/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md`

**Community:**
- GitHub Issues: [Create issue if bug found]
- SurrealDB Discord: For SurrealDB-specific questions
