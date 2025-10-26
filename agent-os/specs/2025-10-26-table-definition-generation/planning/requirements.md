# Spec Requirements: Table Definition Generation

## Initial Description

The user wants to expand the TableDefinition setup to automatically establish tables from serializable Dart objects. The feature should support:

- `TableDefinition.fromClass(ClassName)` - Create table definition from a Dart class
- `TableDefinition.fromObject(instancedObject)` - Create table definition from an object instance

The goal is to eliminate the need for custom implementations by building the spec dynamically from the serialized object, providing type safety by mapping common Dart types to SurrealDB types automatically.

This is a schema generation/reflection feature that will improve developer experience by reducing boilerplate code for table definitions.

## Requirements Discussion

### First Round Questions

**Q1:** I assume we'll use a build_runner-based code generation approach (similar to json_serializable) rather than runtime reflection, since Dart's reflection is limited and code generation is a standard pattern. Is that correct, or would you prefer a different approach?

**Answer:** YES - build_runner + code generation is the right approach for this library.

---

**Q2:** For the type mapping, I'm thinking we should support:
- Basic types: String → string, int → int, double → float, bool → bool, DateTime → datetime
- Collections: List<T> → array<T>, Set<T> → array<T>
- Nested objects: Custom classes → object type with nested schema
- Special types: Duration → duration, Geometry types → geometry

Should we support all of these, or is there a subset you want to start with?

**Answer:** Support all of them. Also need to handle vector types (array<float, X> where X is dimension count). Reference the vector implementation work that's already been done in the codebase.

---

**Q3:** I assume developers will need to annotate their Dart classes with decorators (like @SurrealTable, @SurrealField) to provide metadata like table name, field constraints, indexes, etc. Should we make these decorators:
- Mandatory for all fields (explicit is better)?
- Optional with smart defaults (fields without decorators get inferred)?

**Answer:** Mandatory decorators for all fields. Explicit is better - we want developers to be intentional about what goes into the database schema.

---

**Q4:** For nested objects (like a User class with an Address field), should we:
- Automatically generate nested object definitions recursively?
- Require developers to explicitly define nested structures?
- Support both approaches?

**Answer:** Automatically generate nested object definitions recursively. If a field is a custom class type, the generator should traverse into it and build the nested schema.

---

**Q5:** I'm thinking we should allow developers to specify custom serialization logic for complex types (like a custom Color class → string). Should we support:
- Custom converter classes (similar to json_serializable's @JsonConverter)?
- Inline serialization functions in the decorator?
- Both options?

**Answer:** Support custom converter classes similar to json_serializable. Also provide a sensible fallback - if a type doesn't have an explicit converter and isn't a recognized primitive, call its toString() method and store as string. This gives developers flexibility while preventing runtime crashes.

---

**Q6:** For field constraints and validation, should the generated TableDefinition include:
- ASSERT clauses for validation rules?
- PERMISSIONS definitions?
- INDEX definitions?
- Or should these be manually added after generation?

**Answer:** The decorators should support specifying ASSERT clauses and INDEX definitions. PERMISSIONS can be handled separately (out of scope for this spec) since they're usually defined at the table level and involve more complex logic.

---

**Q7:** I assume we want to support default values for fields. Should these:
- Come from the Dart class's default values in the constructor?
- Be specified in the @SurrealField decorator?
- Support both with decorator taking precedence?

**Answer:** Default values should be specified in the field decorators (e.g., @SurrealField(defaultValue: 'active')). This keeps the schema definition explicit and separate from the Dart class's own initialization logic.

---

**Q8:** For the generated TableDefinition, should we:
- Generate a separate .surreal.dart file for each annotated class?
- Generate a single file with all table definitions?
- Let developers configure this via build.yaml?

**Answer:** Generate a separate .surreal.dart file for each annotated class (e.g., user.dart → user.surreal.dart). This follows the json_serializable pattern and makes it easier to find and maintain generated code.

---

**Q9:** Should the generated TableDefinition classes be immutable (const constructors where possible), or should they allow runtime modification?

**Answer:** Generated TableDefinition classes should be immutable with const constructors where possible. Schema definitions shouldn't change at runtime - they represent the database structure.

---

**Q10:** For handling schema evolution/migrations, should this feature:
- Just generate the current schema based on the Dart classes?
- Also support schema migration/versioning (detecting changes and generating ALTER TABLE queries)?
- Leave migration handling for a future feature?

**Answer:** YES to migrations! This is a critical feature. We want the system to:
- Detect schema changes automatically when the app starts
- Generate and apply migrations to keep the database in sync with code
- Support both automatic migrations (dev mode) and manual review (production)

This is complex enough that we should explore it as a follow-up set of questions.

---

**Q11:** I'm thinking the API usage would look like:

```dart
@SurrealTable('users')
class User {
  @SurrealField(type: SurrealType.recordId)
  final String? id;

  @SurrealField(type: SurrealType.string, assert: 'string::len($value) > 0')
  final String name;

  @SurrealField(type: SurrealType.int, defaultValue: 0)
  final int age;

  User({this.id, required this.name, this.age = 0});
}

// Generated code creates:
// - UserTableDefinition class
// - Automatic registration with Database.init()
```

Does this match your vision, or would you prefer a different API style?

**Answer:** This looks great! One addition: support a @JsonField() decorator for fields that should be serialized to JSON before storing. For example, a Map<String, dynamic> metadata field should be stored as a JSON object in SurrealDB.

---

**Q12:** Finally, are there specific features you DON'T want in the initial version? For example:
- Support for SurrealDB's graph relations (RELATE statements)?
- Support for computed fields (VALUE clauses)?
- Support for event definitions (EVENTS)?

**Answer:** Exclude for initial version:
- Graph relations (RELATE) - this is complex and deserves its own spec
- Event definitions - rarely used, can add later
- Computed fields - nice to have but not critical

DO include: vector field support with explicit dimension specification since we already have vector functionality in the codebase.

---

### Migration System Follow-up Questions

**Q1:** For migration detection, should we:
- Store a hash/checksum of the schema and detect changes?
- Compare the actual database schema (via INFO FOR DB queries) with the defined schema?
- Use a version number in the code that developers manually increment?

**Answer:** Use `INFO FOR DB` query to fetch the current schema from the database and diff it against the TableDefinition objects defined in code. This is stateless (no version tracking needed) and always reflects reality. The comparison should happen when the database connection is opened in Dart.

---

**Q2:** When should migrations run:
- Automatically on every Database.init()?
- Only when explicitly triggered by calling Database.migrate()?
- Configurable with a flag (autoMigrate: true/false)?

**Answer:** Both automatic and manual, controlled by a flag. Default should be autoMigrate: true for development convenience, but developers can set it to false for production and call migrate() manually after review.

---

**Q3:** For destructive operations (dropping columns, changing types), should we:
- Always allow them (developer responsibility)?
- Require explicit confirmation (throwOnDestructive: false flag)?
- Generate separate "up" and "down" migrations that developers review?

**Answer:** Require explicit confirmation via a flag: `allowDestructiveMigrations: true/false`. Default to false (safe mode). When false and a destructive change is detected, throw an error with details about what would be destroyed.

Destructive operations include:
- Dropping tables that exist in DB but not in definitions
- Removing fields that exist in DB table but not in definition
- Changing field types (potential data loss)

---

**Q4:** If a migration would be destructive and we're in "safe mode", should we:
- Throw an exception and halt?
- Log a warning and continue with non-destructive changes only?
- Create the migration script but not execute it?

**Answer:** Throw an exception and halt. Don't do partial migrations - it's too risky. Force the developer to either:
- Set allowDestructiveMigrations: true (accepting data loss)
- Manually fix the schema mismatch
- Update their code to match the database

---

**Q5:** Should we track migration history in:
- A file (like migrations/0001_initial.sql)?
- The database itself (e.g., _migrations table)?
- Both?

**Answer:** Store migrations in the database itself (e.g., `_migrations` table) to track what migrations have been applied, when they ran, whether they succeeded, etc. This is similar to Rails/Django approach and ensures the database is self-documenting.

The table should track:
- Migration identifier (hash of schema changes)
- Timestamp applied
- Success/failure status
- Schema snapshot (for rollback)

---

**Q6:** For rollback support, should we:
- Not support rollback (forward-only migrations)?
- Generate automatic rollback logic where possible?
- Require manual rollback procedures?

**Answer:** Two-tier approach:
- On migration failure: Throw error, don't commit changes (use SurrealDB transactions)
- For manual rollback: Support a rollback API that can revert to previous schema using the snapshot stored in _migrations table

Don't try to auto-generate rollback for every scenario - data migrations are too complex. But do support the mechanism for developers to trigger it.

---

**Q7:** Should migrations be aware of different environments (dev/staging/production):
- Yes, with environment-specific migration strategies?
- No, migrations are migrations regardless of environment?

**Answer:** The library should NOT be explicitly aware of environments. It just works with SurrealDB. Developers can build their own environment abstraction in their application code (e.g., different autoMigrate settings for dev vs prod).

Keep the library focused on schema management, not environment management.

---

**Q8:** For validation before applying migrations, should we support a "dry run" mode that:
- Shows what would change without applying it?
- Validates the migration would succeed?
- Both?

**Answer:** YES! This would be super helpful. Add a `dryRun: true` flag to the init() or migrate() call. When enabled:
- Detect schema differences
- Generate migration SQL
- Validate it would work (maybe in a transaction that gets rolled back?)
- Return a report of changes WITHOUT applying them

This lets developers preview migrations in production before committing.

**Technical Implementation Note**: SurrealDB supports:
- `INFO FOR DB` and `INFO FOR TABLE` for schema introspection
- Transaction support with `BEGIN/COMMIT/CANCEL`
- Dry run can be implemented by: BEGIN TRANSACTION → Execute schema changes → Verify → CANCEL TRANSACTION

---

**Q9:** For the migration API, would you prefer:

**Option A - Direct parameters:**
```dart
await Database.init(
  path: 'db.surreal',
  tableDefinitions: [UserTable(), PostTable()],
  allowDestructiveMigrations: false,
  autoMigrate: true,
  dryRun: false,
);
```

**Option B - Configuration object:**
```dart
await Database.init(
  path: 'db.surreal',
  tableDefinitions: [UserTable(), PostTable()],
  migrationConfig: MigrationConfig(
    autoMigrate: true,
    allowDestructive: false,
    dryRun: false,
  ),
);
```

**Answer:** Option A - Direct parameter style. It's more concise and these are core enough parameters that they don't need to be wrapped in a config object. Keep the API simple and flat.

---

### Existing Code Reuse

**Similar Features Identified:**

The user referenced existing vector implementation work in the codebase that should be consulted for vector type handling:

- Vector value types and storage patterns: `lib/src/types/vector_value.dart`
- Vector database integration tests: `test/vector_database_integration_test.dart`
- Vector strategic gaps tests: `test/vector_strategic_gaps_test.dart`
- Vector example scenarios: `example/scenarios/vector_embeddings.dart`
- Schema definitions (if any): `lib/src/schema/` directory

These should inform how vector types are annotated and generated in TableDefinitions (e.g., `array<float, 384>` for 384-dimensional embeddings).

**Build System Patterns:**

The project likely follows standard Dart patterns for code generation:
- build_runner configuration in `build.yaml`
- Generator implementation extending `Generator` or `GeneratorForAnnotation`
- Part files using `part 'filename.g.dart'` pattern

**Database Initialization:**

Current database initialization pattern should be examined:
- `lib/src/database.dart` - existing Database.init() implementation
- Connection management and configuration patterns
- Existing exception handling patterns: `lib/src/exceptions.dart`

---

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
N/A - This is a code generation and API feature without visual UI components.

---

## Requirements Summary

### Functional Requirements

#### 1. Schema Generation System (build_runner + decorators)

**Code Generation Infrastructure:**
- Use build_runner-based code generation approach
- Generate separate `.surreal.dart` file for each annotated class
- Follow json_serializable patterns for consistency
- Generated classes should be immutable with const constructors

**Decorator System:**
- `@SurrealTable('table_name')` - Marks a class as a database table
- `@SurrealField()` - Mandatory for all fields with parameters:
  - `type`: Explicit SurrealType specification
  - `defaultValue`: Optional default value
  - `assert`: Optional ASSERT clause for validation
  - `indexed`: Optional flag for INDEX generation
- `@JsonField()` - Marks fields for JSON serialization before storage

**Type Mapping:**
- Primitives: String → string, int → int, double → float, bool → bool
- Temporal: DateTime → datetime, Duration → duration
- Collections: List<T> → array<T>, Set<T> → array<T>
- Nested objects: Custom classes → object type with recursive schema generation
- Special types: Geometry types → geometry
- Vector types: Explicit dimension specification (e.g., array<float, 384>)
- Custom types: Support custom converter classes OR fallback to toString() for storage as string

**Nested Object Support:**
- Automatically traverse and generate nested object definitions recursively
- When a field type is a custom class, introspect it and build nested schema
- Support arbitrary depth of nesting

**Schema Features:**
- Support ASSERT clauses for validation rules (specified in decorator)
- Support INDEX definitions (specified in decorator)
- Support default values (specified in decorator, not from Dart constructor)
- Exclude: PERMISSIONS (separate concern), computed fields (VALUE clauses), event definitions

**Vector Field Support:**
- Explicit annotations for vector dimensions
- Reference existing vector implementation: `lib/src/types/vector_value.dart`
- Generate proper `array<float, X>` type definitions

#### 2. Migration System

**Migration Detection:**
- Use `INFO FOR DB` query to fetch current database schema
- Diff current schema against TableDefinition objects in code
- Stateless comparison (no version tracking)
- Detection happens when database connection opens

**Migration Execution:**
- Configurable via `autoMigrate: true/false` flag
- Default to `true` for development convenience
- When `false`, require manual `migrate()` call

**Destructive Operation Handling:**
- Controlled by `allowDestructiveMigrations: true/false` flag
- Default to `false` (safe mode)
- Destructive operations include:
  - Dropping tables not in definitions
  - Removing fields not in definitions
  - Changing field types (data loss risk)
- When destructive changes detected in safe mode: throw exception with details

**Migration History Tracking:**
- Store migrations in `_migrations` database table
- Track for each migration:
  - Migration identifier (hash of schema changes)
  - Timestamp when applied
  - Success/failure status
  - Schema snapshot for rollback support

**Transaction Safety:**
- Use SurrealDB transactions for migration execution
- On failure: rollback transaction and throw error
- Ensure atomic migration application (all-or-nothing)

**Rollback Support:**
- On migration failure: automatic rollback via transaction
- Manual rollback API: revert to previous schema using snapshot from `_migrations`
- Don't auto-generate rollback for all scenarios (data complexity)
- Provide mechanism for developer-triggered rollback

**Dry Run Mode:**
- Support `dryRun: true` flag
- When enabled:
  - Detect schema differences
  - Generate migration SQL
  - Validate via transaction (BEGIN → Execute → Verify → CANCEL)
  - Return report WITHOUT applying changes
- Allows preview of migrations before production deployment

**Technical Implementation:**
- Leverage SurrealDB's `INFO FOR DB` and `INFO FOR TABLE` for introspection
- Use `BEGIN/COMMIT/CANCEL` transaction support
- No environment awareness (library agnostic to dev/staging/prod)

---

### API Design

**Annotation Example:**
```dart
@SurrealTable('users')
class User {
  @SurrealField(type: SurrealType.recordId)
  final String? id;

  @SurrealField(type: SurrealType.string, assert: 'string::len($value) > 0')
  final String name;

  @SurrealField(type: SurrealType.int, defaultValue: 0)
  final int age;

  @SurrealField(type: SurrealType.datetime)
  final DateTime createdAt;

  @JsonField()
  @SurrealField(type: SurrealType.object)
  final Map<String, dynamic> metadata;

  @SurrealField(type: SurrealType.vector, dimensions: 384)
  final List<double> embedding;

  User({
    this.id,
    required this.name,
    this.age = 0,
    required this.createdAt,
    this.metadata = const {},
    required this.embedding,
  });
}
```

**Database Initialization with Migration Control:**
```dart
await Database.init(
  path: 'db.surreal',
  tableDefinitions: [UserTable(), PostTable(), CommentTable()],
  autoMigrate: true,              // Auto-apply migrations on init
  allowDestructiveMigrations: false,  // Throw error on data loss risk
  dryRun: false,                  // Actually apply (not just preview)
);
```

**Manual Migration:**
```dart
// For production: review before applying
await Database.init(
  path: 'db.surreal',
  tableDefinitions: [UserTable(), PostTable()],
  autoMigrate: false,  // Don't auto-migrate
);

// Preview changes
final report = await db.migrate(dryRun: true);
print(report);  // Shows what would change

// Apply after review
await db.migrate(allowDestructiveMigrations: true);
```

**Manual Rollback:**
```dart
// Rollback to previous schema state
await db.rollbackMigration();
```

---

### Scope Boundaries

**In Scope:**

1. **Code Generation:**
   - build_runner integration
   - Decorator-based schema definition
   - Type mapping for all common Dart types
   - Recursive nested object generation
   - Custom converter support
   - Vector type support with dimensions
   - Generated immutable TableDefinition classes

2. **Migration System:**
   - Automatic schema detection via INFO FOR DB
   - Schema diffing and change detection
   - Migration generation and execution
   - Destructive operation safeguards
   - Migration history tracking in database
   - Transaction-based safety
   - Dry run validation mode
   - Manual rollback API

3. **Validation & Constraints:**
   - ASSERT clause generation
   - INDEX definition generation
   - Default value support

**Out of Scope:**

1. **Advanced Features (Future Specs):**
   - Graph relations (RELATE statements) - complex, deserves own spec
   - Event definitions (EVENTS) - rarely used, can add later
   - Computed fields (VALUE clauses) - nice to have, not critical
   - PERMISSIONS definitions - separate concern, table-level complexity

2. **Environment Management:**
   - Environment-specific migration strategies
   - Environment detection/awareness
   - (Developers handle this in application code)

3. **Data Migration:**
   - Automatic data transformation on schema changes
   - (Too complex/risky - manual developer responsibility)

4. **Schema Versioning:**
   - External migration file generation (.sql files)
   - Migration version numbers in code
   - (Using stateless diff approach instead)

---

### Technical Considerations

**SurrealDB Capabilities to Leverage:**
- `INFO FOR DB` - Database-level schema introspection
- `INFO FOR TABLE <name>` - Table-level schema details
- `BEGIN TRANSACTION` / `COMMIT` / `CANCEL` - Transaction support for safe migrations
- Full DDL support: `DEFINE TABLE`, `DEFINE FIELD`, `DEFINE INDEX`, `REMOVE TABLE`, etc.

**Integration Points:**
- Existing database initialization: `lib/src/database.dart`
- Exception handling patterns: `lib/src/exceptions.dart`
- FFI bindings: `lib/src/ffi/bindings.dart`
- Native types: `lib/src/ffi/native_types.dart`
- Type system: `lib/src/types/types.dart`
- Vector types: `lib/src/types/vector_value.dart`

**Build System Integration:**
- Follow standard Dart code generation patterns
- Part file approach: `part 'filename.surreal.dart'`
- build.yaml configuration for generator
- Generator extends `GeneratorForAnnotation<SurrealTable>`

**Error Handling:**
- Throw descriptive exceptions for destructive operations in safe mode
- Detailed migration failure messages with schema diff
- Validation errors for malformed decorators
- Transaction rollback on any migration failure

**Performance:**
- Schema introspection happens once on init (not per query)
- Generated code is compile-time (no runtime overhead)
- Migration detection is stateless (no version file I/O)

**Compatibility:**
- Align with existing vector implementation patterns
- Match current Database.init() parameter style
- Follow project's coding standards and conventions
- Use project's established FFI patterns for Rust integration

---

### Reusability Opportunities

**Existing Components to Reference:**

1. **Vector Types Implementation:**
   - `lib/src/types/vector_value.dart` - Vector value representation
   - `test/vector_value_test.dart` - Vector validation patterns
   - `example/scenarios/vector_embeddings.dart` - Usage examples

2. **Type System:**
   - `lib/src/types/types.dart` - Existing type definitions
   - Pattern for mapping Dart types to SurrealDB types

3. **Database Layer:**
   - `lib/src/database.dart` - Initialization patterns
   - Connection management approach
   - Configuration parameter patterns

4. **Exception Handling:**
   - `lib/src/exceptions.dart` - Error types and patterns
   - Consistent error messaging approach

5. **FFI Integration:**
   - `lib/src/ffi/bindings.dart` - Native interop patterns
   - `lib/src/ffi/native_types.dart` - Type conversion patterns

6. **Testing Patterns:**
   - `test/vector_database_integration_test.dart` - Integration test approach
   - `test/transaction_test.dart` - Transaction testing patterns

**Code Generation Patterns:**
- Follow Dart ecosystem standards (json_serializable, freezed, etc.)
- Part file generation approach
- Annotation processing patterns

---

## Technical Implementation Notes

### SurrealDB Schema Introspection

SurrealDB provides comprehensive schema introspection via INFO commands:

```sql
-- Get all database schema
INFO FOR DB;

-- Get specific table schema
INFO FOR TABLE users;
```

These return structured data about:
- Table definitions
- Field types and constraints
- Indexes
- Assertions
- Default values

### Transaction Support for Safe Migrations

SurrealDB transactions enable safe, atomic migrations:

```sql
BEGIN TRANSACTION;

-- Schema changes
DEFINE TABLE users SCHEMAFULL;
DEFINE FIELD name ON users TYPE string;

-- Verify changes
INFO FOR TABLE users;

-- Commit or rollback
COMMIT;  -- or CANCEL to rollback
```

This enables:
- Dry run mode (BEGIN → changes → verify → CANCEL)
- Atomic migrations (all-or-nothing)
- Safe rollback on failure

### Vector Type Specification

Based on existing vector implementation, vector fields require dimension specification:

```dart
@SurrealField(type: SurrealType.vector, dimensions: 384)
final List<double> embedding;
```

Generates:
```sql
DEFINE FIELD embedding ON table TYPE array<float, 384>;
```

### Migration History Schema

The `_migrations` table structure:

```sql
DEFINE TABLE _migrations SCHEMAFULL;
DEFINE FIELD migration_id ON _migrations TYPE string;
DEFINE FIELD applied_at ON _migrations TYPE datetime;
DEFINE FIELD status ON _migrations TYPE string;  -- 'success' | 'failed'
DEFINE FIELD schema_snapshot ON _migrations TYPE object;
DEFINE FIELD changes_applied ON _migrations TYPE array;
```

---

## Summary

This specification covers two major feature areas:

1. **Schema Generation System**: A build_runner-based code generation tool that converts annotated Dart classes into SurrealDB TableDefinition objects, with full support for type mapping, nested objects, custom converters, vector types, and validation constraints.

2. **Migration System**: An intelligent schema migration system that detects differences between code and database, safely applies changes with destructive operation safeguards, tracks migration history, supports dry-run validation, and provides rollback capabilities.

Together, these features will significantly improve developer experience by:
- Eliminating boilerplate table definition code
- Ensuring schema stays in sync with code
- Preventing accidental data loss
- Providing safe migration workflows for development and production
- Supporting the full range of SurrealDB types including vectors

The implementation leverages SurrealDB's introspection and transaction capabilities while following Dart ecosystem best practices for code generation and API design.
