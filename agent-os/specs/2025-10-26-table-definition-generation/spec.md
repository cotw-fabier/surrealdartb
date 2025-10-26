# Specification: Table Definition Generation & Migration System

## Goal

Enable developers to automatically generate SurrealDB table definitions from annotated Dart classes using build_runner code generation, and provide an intelligent migration system that detects schema changes and safely applies them to the database with transaction safety and rollback support.

## User Stories

- As a developer, I want to define my table schemas using Dart classes with decorators so that I have type-safe schema definitions in my codebase
- As a developer, I want the system to automatically generate TableDefinition objects from my annotated classes so that I don't have to write boilerplate schema code
- As a developer, I want schema changes to be automatically detected when my app starts so that my database stays in sync with my code
- As a developer, I want destructive schema changes to be blocked by default so that I don't accidentally lose data
- As a developer, I want to preview migrations in dry-run mode so that I can review changes before applying them in production
- As a developer, I want migrations to run in transactions so that failed migrations are automatically rolled back
- As a developer, I want to manually roll back migrations when needed so that I can recover from schema issues

## Implementation Status

**Last Updated:** 2025-10-26

### Completed Phases

**✅ Phase 1: Code Generation Foundation (Week 1)** - COMPLETED & VERIFIED
- Task Group 1.1: Annotation System & Basic Generator - ✅ Complete
- Task Group 1.2: Basic Type Mapping & TableDefinition Generation - ✅ Complete
- Verification Status: ✅ PASS (backend-verifier)
- Implementation Reports:
  - `implementation/1.1-annotation-system-basic-generator.md`
  - `implementation/1.2-basic-type-mapping-tabledefinition-generation-implementation.md`
- Verification Report: `verification/phase-1-verification.md`

**Deliverables Achieved:**
- ✅ Annotation classes (@SurrealTable, @SurrealField, @JsonField)
- ✅ build_runner generator infrastructure
- ✅ Basic type mapping (String, int, double, bool, DateTime, Duration)
- ✅ TableDefinition code generation with nullable type support
- ✅ 19 passing tests (11 annotation + 8 type mapper tests)
- ✅ Generated code compiles and follows all standards

### Pending Phases

**⏳ Phase 2: Advanced Type Support (Week 2)** - NOT STARTED
- Task Group 2.1: Collection & Nested Object Types
- Task Group 2.2: Vector Types & Schema Constraints

**⏳ Phase 3: Migration Detection System (Week 3)** - NOT STARTED
- Task Group 3.1: Schema Introspection
- Task Group 3.2: Schema Diff Calculation

**⏳ Phase 4: Migration Execution Engine (Week 4)** - NOT STARTED
- Task Group 4.1: DDL Generation
- Task Group 4.2: Transaction-Based Migration Execution

**⏳ Phase 5: Safety Features & Rollback (Week 5)** - NOT STARTED
- Task Group 5.1: Destructive Operation Protection
- Task Group 5.2: Manual Rollback Support

**⏳ Phase 6: Integration & API Completion (Week 6)** - NOT STARTED
- Task Group 6.1: Database Class Integration
- Task Group 6.2: End-to-End Integration Testing
- Task Group 6.3: Documentation & Examples

### Current Capabilities

With Phase 1 complete, the following functionality is now available:
- Developers can annotate Dart classes with `@SurrealTable` and `@SurrealField`
- Running `dart run build_runner build` generates `.surreal.dart` part files
- Generated files contain TableStructure definitions for basic types
- Type system supports: String, int, double, bool, DateTime, Duration
- Nullable types automatically map to optional fields
- Foundation ready for Phase 2 (advanced types, vectors, nested objects)

### Next Steps

To continue implementation:
1. Implement Phase 2 (Advanced Type Support) - Adds collections, nested objects, vectors
2. After Phase 2 completion, the code generation system will be feature-complete
3. Phases 3-6 implement the migration system (detection, execution, safety, integration)

## Core Requirements

### Functional Requirements

**Schema Generation (build_runner + Decorators)**
- Support `@SurrealTable(tableName)` decorator to mark classes as database tables
- Support `@SurrealField()` decorator for all fields with parameters: type, defaultValue, assert, indexed
- Support `@JsonField()` decorator for Map/complex types that need JSON serialization
- Generate separate `.surreal.dart` file for each annotated class following json_serializable pattern
- Generate immutable TableDefinition classes with const constructors
- Support mandatory field annotations (developers must be explicit about schema)
- Support recursive nested object schema generation for custom class types
- Support custom converter classes similar to json_serializable for complex types
- Fallback to toString() for types without explicit converters
- Support vector types with explicit dimension specification using existing VectorValue infrastructure

**Type Mapping**
- Map Dart primitives to SurrealDB types: String→string, int→int, double→float, bool→bool
- Map temporal types: DateTime→datetime, Duration→duration
- Map collections: List&lt;T&gt;→array&lt;T&gt;, Set&lt;T&gt;→array&lt;T&gt;
- Map custom classes to nested object definitions with recursive traversal
- Support vector types: array&lt;float, X&gt; where X is dimension count
- Support geometry types for GeoJSON data
- Automatic custom type handling via converters or toString() fallback
- **Nullable type handling**: Nullable Dart types (e.g., `String?`, `int?`) automatically map to `optional: true` in FieldDefinition, while non-nullable types map to `optional: false`

**Schema Features**
- Generate ASSERT clauses from decorator parameters for validation
- Generate INDEX definitions from decorator parameters
- Support default values specified in decorators (not from Dart constructors)
- Exclude: PERMISSIONS (separate feature), computed fields, event definitions, graph relations

**Migration Detection**
- Use INFO FOR DB query to fetch current database schema
- Stateless diffing between database schema and code-defined TableDefinition objects
- Detection runs on Database.init() when database connection opens
- Identify additions: new tables, new fields, new indexes
- Identify modifications: field type changes, constraint changes
- Identify deletions: removed tables, removed fields

**Migration Execution**
- Support autoMigrate flag (default: true for development convenience)
- When autoMigrate=false, require manual migrate() call
- Execute migrations within SurrealDB transactions (BEGIN/COMMIT/CANCEL)
- Generate and execute DDL statements: DEFINE TABLE, DEFINE FIELD, DEFINE INDEX, REMOVE TABLE, etc.
- Support dryRun mode to preview changes without applying them

**Destructive Operation Handling**
- Control via allowDestructiveMigrations flag (default: false for safety)
- Destructive operations: dropping tables, removing fields, changing field types
- When destructive changes detected in safe mode: throw detailed exception listing changes
- Force developer to explicitly enable destructive migrations or fix the mismatch

**Migration History**
- Store migration records in `_migrations` database table
- Track: migration identifier (hash of changes), timestamp, success/failure status, schema snapshot
- Use schema snapshot for rollback support
- Migrations are self-documenting within the database

**Rollback Support**
- Automatic rollback on migration failure via transaction cancellation
- Manual rollback API to revert to previous schema using stored snapshot
- Rollback restores both schema structure and validates compatibility

**Dry Run Validation**
- Support dryRun parameter on init() or migrate()
- Execute schema changes in transaction, validate, then cancel transaction
- Return detailed report of changes without applying them
- Enable production migration previews

### Non-Functional Requirements

**Performance**
- Schema introspection happens once on init (not per query)
- Generated code has zero runtime overhead (compile-time generation)
- Migration detection is stateless (no version file I/O overhead)
- Use efficient transaction handling for migration execution

**Safety**
- All migrations run in transactions (atomic all-or-nothing)
- Destructive operations blocked by default
- Failed migrations automatically rolled back
- Clear error messages with field-level details

**Maintainability**
- Follow Dart ecosystem patterns (json_serializable style)
- Generated code is readable and debuggable
- Separate generated files for easy location and maintenance
- Clear separation between schema definition and application logic

## Technical Approach

### Code Generation Architecture

**Package Structure**
- `lib/src/schema/annotations.dart` - Decorator definitions (@SurrealTable, @SurrealField, @JsonField)
- `lib/src/schema/table_definition.dart` - TableDefinition class (extend existing TableStructure)
- `lib/src/schema/migration_engine.dart` - Migration detection and execution logic
- `lib/generator/` - build_runner generator implementation
- `build.yaml` - Generator configuration

**Generator Implementation**
- Extend `GeneratorForAnnotation<SurrealTable>` from build_runner
- Use analyzer package to introspect annotated classes
- Generate part files: `part 'filename.surreal.dart'`
- Output immutable TableDefinition subclasses
- Generate type mappings recursively for nested objects
- Reference existing VectorValue for vector type handling
- Detect nullable types (via analyzer's `isNullable` property) and set `optional: true` in generated FieldDefinition

**Annotation Design**
```dart
class SurrealTable {
  final String tableName;
  const SurrealTable(this.tableName);
}

class SurrealField {
  final SurrealType type;
  final dynamic defaultValue;
  final String? assert;
  final bool indexed;
  final int? dimensions; // For vectors

  const SurrealField({
    required this.type,
    this.defaultValue,
    this.assert,
    this.indexed = false,
    this.dimensions,
  });
}

class JsonField {
  const JsonField();
}
```

### Migration System Architecture

**Database Layer Integration**
- Extend Database class with migration methods
- Add migration parameters to Database.connect():
  - autoMigrate (bool, default: true)
  - allowDestructiveMigrations (bool, default: false)
  - dryRun (bool, default: false)
- Add Database.migrate() method for manual migrations
- Add Database.rollbackMigration() method for manual rollback

**Schema Introspection**
- Execute `INFO FOR DB` to get current schema
- Parse response into structured format
- Build diff between current schema and TableDefinition objects
- Categorize changes: additions, modifications, deletions

**Migration Generation**
- Convert schema diffs into DDL statements
- Generate DEFINE TABLE statements for new tables
- Generate DEFINE FIELD statements for new/modified fields
- Generate DEFINE INDEX statements for new indexes
- Generate REMOVE statements for deletions (if allowed)

**Migration Execution**
- Validate migration safety (check for destructive operations)
- Start transaction: BEGIN TRANSACTION
- Execute DDL statements sequentially
- Record migration in `_migrations` table
- Commit transaction: COMMIT
- On error: cancel transaction (CANCEL) and throw exception

**Migration History Schema**
```sql
DEFINE TABLE _migrations SCHEMAFULL;
DEFINE FIELD migration_id ON _migrations TYPE string;
DEFINE FIELD applied_at ON _migrations TYPE datetime;
DEFINE FIELD status ON _migrations TYPE string; -- 'success' | 'failed'
DEFINE FIELD schema_snapshot ON _migrations TYPE object;
DEFINE FIELD changes_applied ON _migrations TYPE array;
```

### Database API

**Connection with Migration Support**
```dart
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: 'db.surreal',
  namespace: 'prod',
  database: 'main',
  tableDefinitions: [UserTableDef(), PostTableDef()],
  autoMigrate: true,
  allowDestructiveMigrations: false,
  dryRun: false,
);
```

**Manual Migration**
```dart
// Preview migrations
final report = await db.migrate(dryRun: true);
print('Pending changes: ${report.changes}');

// Apply migrations
await db.migrate(allowDestructiveMigrations: true);

// Rollback if needed
await db.rollbackMigration();
```

**Migration Report Structure**
```dart
class MigrationReport {
  final List<String> tablesAdded;
  final List<String> tablesRemoved;
  final Map<String, List<String>> fieldsAdded;
  final Map<String, List<String>> fieldsRemoved;
  final Map<String, List<String>> fieldsModified;
  final List<String> indexesAdded;
  final bool hasDestructiveChanges;
  final String generatedDDL;
}
```

## Migration Workflow

### Development Workflow

1. Developer annotates Dart classes with @SurrealTable and @SurrealField
2. Run `dart run build_runner build` to generate `.surreal.dart` files
3. Generated files contain TableDefinition classes
4. App startup calls Database.connect() with tableDefinitions and autoMigrate=true
5. Migration system detects schema differences
6. Migrations applied automatically (safe changes only)
7. Developer can review changes in logs

### Production Workflow

1. Developer reviews pending migrations using dryRun mode
2. Database.connect() called with autoMigrate=false
3. App starts without applying migrations
4. Developer calls db.migrate(dryRun: true) to preview changes
5. After review, developer calls db.migrate() to apply
6. Migration executes in transaction with full rollback support
7. If issues occur, developer can call db.rollbackMigration()

### Migration Safety Checks

**Safe Changes (applied automatically)**
- Adding new tables
- Adding new fields to existing tables
- Adding indexes
- Adding assertions to fields
- Changing default values

**Destructive Changes (require flag)**
- Dropping tables
- Removing fields
- Changing field types (potential data loss)
- Removing indexes

**Error Scenarios**
- Destructive change in safe mode: throw MigrationException with details
- Migration execution failure: rollback transaction, throw exception
- Schema introspection failure: throw DatabaseException
- Invalid DDL generation: throw MigrationException before execution

## Error Handling Strategy

### Exception Types

Extend existing exception hierarchy in `lib/src/exceptions.dart`:

```dart
class MigrationException extends DatabaseException {
  final MigrationReport? report;
  final bool isDestructive;

  MigrationException(
    super.message, {
    this.report,
    this.isDestructive = false,
    super.errorCode,
    super.nativeStackTrace,
  });
}

class SchemaIntrospectionException extends DatabaseException {
  SchemaIntrospectionException(super.message, {
    super.errorCode,
    super.nativeStackTrace,
  });
}
```

### Error Messages

**Destructive Migration Blocked**
```
MigrationException: Destructive schema changes detected and allowDestructiveMigrations=false

Destructive changes:
- Table 'posts' will be removed (12 records may be lost)
- Field 'users.legacy_field' will be removed
- Field 'products.price' type changing from string to int (data conversion required)

To apply these changes:
1. Set allowDestructiveMigrations: true in Database.connect()
2. OR fix schema to match database
3. OR manually migrate data before applying changes
```

**Migration Execution Failure**
```
MigrationException: Migration failed during execution

Error: Failed to execute DEFINE FIELD age ON users TYPE int
Reason: Existing data in 'age' field cannot be converted to int

Migration has been rolled back. Database state unchanged.
```

### Validation Errors

Build on existing ValidationException for Dart-side schema validation before generation.

## Testing Approach

### Unit Tests

**Generator Tests** (`test/generator/`)
- Test annotation parsing for all decorator types
- Test type mapping for all Dart → SurrealDB type conversions
- Test recursive nested object generation
- Test vector type generation with dimensions
- Test custom converter handling
- Test generated code output format

**Migration Detection Tests** (`test/migration/detection_test.dart`)
- Test schema diff calculation for all change types
- Test identification of safe vs. destructive changes
- Test edge cases: empty schema, identical schema, complex nested changes
- Test schema snapshot creation and comparison

**Migration Execution Tests** (`test/migration/execution_test.dart`)
- Test DDL generation for all schema change types
- Test transaction handling: begin, commit, cancel
- Test migration history recording
- Test rollback logic

### Integration Tests

**End-to-End Generation** (`test/integration/generation_test.dart`)
- Test complete workflow: annotation → generation → compilation
- Test generated code integrates with Database class
- Test TableDefinition objects work with existing validation

**End-to-End Migration** (`test/integration/migration_test.dart`)
- Test full migration workflow with real SurrealDB database
- Test autoMigrate flag behavior
- Test destructive migration blocking
- Test dry run mode accuracy
- Test migration history persistence
- Test rollback functionality
- Test migration failure and automatic rollback

**Vector Type Integration** (`test/integration/vector_migration_test.dart`)
- Test vector field generation and migration
- Test dimension validation in generated schemas
- Test integration with existing VectorValue infrastructure

### Test Database Setup

Use in-memory SurrealDB for fast test execution:
```dart
final testDb = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
  autoMigrate: false, // Control manually in tests
);
```

## Implementation Phases

### Phase 1: Code Generation Foundation (Week 1)
- Define annotation classes (@SurrealTable, @SurrealField, @JsonField)
- Implement build_runner generator skeleton
- Implement type mapper for basic types (String, int, double, bool, DateTime)
- Generate basic TableDefinition classes
- Write unit tests for generator and type mapping

**Deliverable**: Annotated classes generate valid TableDefinition objects for basic types

### Phase 2: Advanced Type Support (Week 2)
- Implement recursive nested object generation
- Implement vector type generation with VectorValue integration
- Implement custom converter support
- Implement collection type mapping (List, Set, Map)
- Implement ASSERT and INDEX generation
- Write unit tests for advanced features

**Deliverable**: Full type system support with vectors, nested objects, and constraints

### Phase 3: Migration Detection (Week 3)
- Implement schema introspection using INFO FOR DB
- Implement schema diff calculation
- Implement safe vs. destructive change classification
- Implement migration hash generation for tracking
- Write unit tests for detection logic

**Deliverable**: System can detect all schema changes and classify them correctly

### Phase 4: Migration Execution (Week 4)
- Implement DDL generation from schema diffs
- Implement transaction-based migration execution
- Implement migration history table creation and tracking
- Implement dry run mode
- Write unit tests for execution logic

**Deliverable**: Migrations can be generated, validated, and executed safely

### Phase 5: Rollback & Safety (Week 5)
- Implement rollback functionality
- Implement destructive operation blocking
- Implement detailed error messages and reporting
- Implement MigrationReport generation
- Write unit tests for rollback and safety features

**Deliverable**: Complete safety mechanisms and rollback support

### Phase 6: Integration & Documentation (Week 6)
- Integrate migration system with Database.connect()
- Add migration methods to Database class
- Write comprehensive integration tests
- Write user documentation and examples
- Write migration guide for production use

**Deliverable**: Fully integrated, tested, and documented feature

## Out of Scope

**Future Enhancements (Separate Specs)**
- Graph relations (RELATE statements) - complex feature deserving own specification
- Event definitions (EVENTS) - rarely used, lower priority
- Computed fields (VALUE clauses) - nice to have, not critical
- PERMISSIONS definitions - separate concern with table-level complexity
- Data migration support - transforming existing data on schema changes
- Schema version numbers in code - using stateless diff approach instead
- External migration file generation - using database-stored approach
- Environment-specific migration strategies - developers handle in app code

**Explicitly Excluded**
- Automatic data transformation on type changes (too risky/complex)
- Migration file versioning system (stateless diff preferred)
- Multi-database migration orchestration (single database focus)

## Success Criteria

**Developer Experience**
- Developers can define schemas in 50% less code compared to manual TableDefinition creation
- Schema changes are detected automatically with zero manual tracking
- Destructive changes are prevented by default, protecting production data
- Migration errors provide actionable guidance for resolution

**Safety & Reliability**
- 100% of migrations execute in transactions with rollback support
- Destructive operations require explicit opt-in flag
- Failed migrations leave database in original state (no partial changes)
- Migration history is complete and queryable

**Performance**
- Schema generation adds &lt;1s to build time for typical projects
- Schema introspection completes in &lt;100ms for databases with &lt;100 tables
- Migration detection completes in &lt;200ms
- Migration execution completes in &lt;1s for typical schema changes

**Code Quality**
- 90%+ test coverage for generator and migration logic
- Zero breaking changes to existing Database API
- Generated code passes all linters and analyzer checks
- Documentation covers all common use cases with examples

## Reusable Components

### Existing Code to Leverage

**Vector Types** (`lib/src/types/vector_value.dart`)
- VectorValue class for vector representation
- VectorFormat enum for type specification
- Vector validation methods (dimensions, normalization)
- Use as reference for vector field generation

**Type System** (`lib/src/types/types.dart`)
- Existing type definitions and patterns
- Type mapping conventions
- Export pattern for generated code

**Schema Infrastructure** (`lib/src/schema/`)
- TableStructure class as base for TableDefinition
- FieldDefinition class for field specifications
- SurrealType hierarchy for type definitions
- Validation logic patterns

**Database Layer** (`lib/src/database.dart`)
- Database.connect() initialization pattern
- Parameter passing conventions (flat style, not nested config)
- Transaction support (transaction() method)
- Query execution patterns (query(), Future-based API)

**Exception Hierarchy** (`lib/src/exceptions.dart`)
- DatabaseException base class
- Exception naming conventions
- Error message formatting
- Stack trace handling

**FFI Integration** (`lib/src/ffi/`)
- bindings.dart - Native function call patterns
- native_types.dart - Type conversion patterns
- Memory management with malloc/free
- String conversion helpers (toNativeUtf8, toDartString)

**Testing Patterns**
- `test/vector_database_integration_test.dart` - Integration test structure
- `test/transaction_test.dart` - Transaction testing approach
- Test fixtures and helper functions

### New Components Required

**Annotation Package** (`lib/src/schema/annotations.dart`)
- No existing annotation system in codebase
- Need: SurrealTable, SurrealField, JsonField classes
- Reason: Core to decorator-based schema definition

**Generator Package** (`lib/generator/`)
- No existing code generation infrastructure
- Need: build_runner generator implementation
- Reason: Required for annotation processing and code generation

**Migration Engine** (`lib/src/schema/migration_engine.dart`)
- No existing migration system
- Need: Schema diffing, DDL generation, execution orchestration
- Reason: Core migration functionality

**Migration History** (`lib/src/schema/migration_history.dart`)
- No existing migration tracking
- Need: _migrations table management, snapshot storage
- Reason: Required for tracking and rollback support

**Schema Introspection** (`lib/src/schema/introspection.dart`)
- No existing INFO FOR DB parsing
- Need: Query execution and response parsing for schema data
- Reason: Required for detecting current database state

---

## Additional Technical Notes

### SurrealDB Integration Points

**Schema Introspection API**
- `INFO FOR DB` returns all table definitions
- `INFO FOR TABLE <name>` returns specific table schema
- Response format: JSON with tables, fields, indexes, assertions

**DDL Syntax**
```sql
DEFINE TABLE users SCHEMAFULL;
DEFINE FIELD name ON users TYPE string ASSERT $value != NONE;
DEFINE FIELD age ON users TYPE int DEFAULT 0;
DEFINE INDEX idx_name ON users FIELDS name;
DEFINE FIELD embedding ON users TYPE array<float, 384>;
```

**Transaction Support**
```sql
BEGIN TRANSACTION;
-- DDL statements
COMMIT; -- or CANCEL to rollback
```

### Code Generation Best Practices

**Follow Dart Ecosystem Patterns**
- Mimic json_serializable part file approach
- Generate readable, formatted code
- Include source location comments
- Preserve developer annotations in generated code

**Type Safety**
- Generate strong typing for all TableDefinition objects
- Use const constructors where possible
- Leverage sealed classes for result types

**Error Handling**
- Validate annotations at generation time
- Provide clear error messages for invalid schemas
- Generate compile-time errors for type mismatches

### Migration Safety Guidelines

**What Qualifies as Destructive**
- Removing any column that exists in DB but not in code
- Changing field type (e.g., string → int) without explicit conversion
- Dropping any table that exists in DB
- Removing indexes (may impact performance but not data integrity - debatable)

**Non-Destructive Changes**
- Adding new tables (no existing data affected)
- Adding new fields with defaults (existing records get default value)
- Adding indexes (performance optimization, no data loss)
- Making required fields optional (less restrictive)
- Adding assertions (validation, doesn't remove data)

**Gray Area (Treat as Destructive)**
- Making optional fields required (existing NULL values may violate)
- Tightening assertions (existing data may fail validation)
- Changing default values (affects new records, not existing)

### Compatibility Notes

**Rust FFI Layer**
- No changes required to Rust layer (all operations use existing query() FFI)
- DDL statements pass through as SurrealQL queries
- Transaction support already implemented in Rust layer

**Existing Database API**
- No breaking changes to Database class public API
- New methods are additive (migrate, rollbackMigration)
- New parameters on connect() are optional with sensible defaults

**Vector Implementation**
- Builds on existing VectorValue infrastructure
- No changes needed to vector storage/retrieval
- Vector dimension validation handled by generated schemas

**Backward Compatibility**
- Developers can continue using manual TableStructure definitions
- Generated TableDefinition classes extend TableStructure
- Existing code continues working without migration

---

**Final Note**: This specification provides a complete blueprint for implementing table definition generation and migration system. Implementation should proceed in phases, with each phase fully tested before moving to the next. The feature integrates deeply with existing infrastructure while maintaining backward compatibility and following established patterns in the codebase.
