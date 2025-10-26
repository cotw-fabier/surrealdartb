# Spec Requirements: Vector Data Types and Storage + Schema Decorators & Code Generation

## Initial Description
This feature is from Phase 2, Milestone 5 of the roadmap and focuses on implementing vector data types and storage capabilities for SurrealDB embedded Dart SDK. Additionally, this spec now includes implementing a comprehensive decorator-based schema system with code generation for type-safe table definitions, and a table migration system for managing schema evolution.

## Requirements Discussion

### First Round Questions

**Q1:** For schema generation implementation, I'm assuming we should use build_runner with annotations/decorators for maximum portability across platforms (avoiding dart:mirrors due to Flutter web/mobile limitations). Is that correct?

**Answer:** Yes, use build_runner for max portability (not dart:mirrors).

**Q2:** Should all fields in a class require explicit annotations/decorators, or should we try to auto-detect field types and only use decorators for special cases (like vectors, constraints, custom serialization)?

**Answer:** Yes, decorators are mandatory for all fields.

**Q3:** For the generated code API, I'm thinking we could support both `TableStructure.fromClass<MyModel>()` for class-based schemas and `TableStructure.fromObject(myInstance)` for instance-based inference. Which approach aligns better with your vision, or should we support both?

**Answer:** Drop both `fromClass()` and `fromObject()` concepts - use decorators + code generation instead.

**Q4:** For type mappings between Dart types and SurrealDB types, I assume:
- `String` → `StringType()`
- `int` → `NumberType(format: NumberFormat.integer)`
- `double` → `NumberType(format: NumberFormat.floating)`
- `bool` → `BoolType()`
- `DateTime` → `DatetimeType()`
- `Duration` → `DurationType()`
- `List<T>` → `ArrayType(T)`
- `Map<String, dynamic>` → `ObjectType()`

Should we also map `VectorValue` automatically to `VectorType()`?

**Answer:** Approved. Also need vector type support.

**Q5:** For nullable types in Dart, should `String?` automatically map to `FieldDefinition(StringType(), optional: true)`, or should nullability be configured via decorator parameters?

**Answer:** Yes, nullable types → `optional: true`.

**Q6:** For nested objects, should we recursively generate TableStructure schemas, or require explicit decoration? Also, should we support a `@JsonField` decorator option that serializes complex objects to JSON strings instead of nested ObjectType?

**Answer:** Recursively generate. Also wants `@JsonField` decorator option for serializing objects to JSON string.

**Q7:** For collections like `List<CustomClass>` or `Set<MyType>`, should we require explicit annotations to clarify intent (e.g., `@SurrealArray(MyType)` vs `@JsonSerialize`), or try to auto-detect and generate nested schemas?

**Answer:** Use explicit annotations to keep things clear.

**Q8:** For vector fields, should we require explicit `@VectorField(dimensions: 1536, format: VectorFormat.f32)` annotation, or try to infer from `VectorValue` type?

**Answer:** Yes, require explicit annotation.

**Q9:** Should we support default value declarations in decorators (e.g., `@Field(defaultValue: 'unknown')`) that get applied during schema validation or object creation?

**Answer:** Support as optional parameter in field decorators.

**Q10:** For custom types that don't map directly to SurrealDB types, should we provide a `@CustomConverter` decorator for user-defined serialization, or rely on toString() as a fallback?

**Answer:** Support custom converters, with toString() as fallback.

**Q11:** For ID fields, should we auto-detect fields named `id` or `recordId` and treat them as RecordType, or require explicit `@RecordId` decoration?

**Answer:** Decorators mandatory (no auto-detection).

**Q12:** Are there any specific edge cases or complex type scenarios we should explicitly exclude from the initial implementation to keep scope manageable?

**Answer:** Exclude complex nested generics like `Map<String, List<CustomClass>>`.

### MAJOR SCOPE ADDITION - Migration System

**User Request:** Add a table migration system to this spec. When initializing the database connection, should be able to pass table definitions and optionally enable destructive operations during migrations. System should handle when table structure changes.

### Existing Code to Reference

**Similar Features Identified:**
Based on documentation review and codebase analysis, the following existing patterns should be referenced:

- **Database Connection Pattern:** `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart` - Shows established pattern for `Database.connect()` factory method with parameters
- **Type System Pattern:** `/Users/fabier/Documents/code/surrealdartb/lib/src/types/` - Shows established pattern for SurrealDB types (RecordId, Datetime, Duration, etc.)
- **TableStructure Existing Implementation:** `/Users/fabier/Documents/code/surrealdartb/lib/src/schema/table_structure.dart` - Already has comprehensive schema definition and validation, includes `toSurrealQL()` method for generating DEFINE TABLE statements
- **FFI Type Definitions:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart` - Demonstrates opaque handle pattern and FFI type definitions
- **Serialization Pattern:** Existing types show serde integration for Rust-Dart data interchange
- **Resource/Value Pattern:** `/Users/fabier/Documents/code/surrealdartb/docs/doc-sdk-rust/concepts/flexible-typing.mdx` - Documents the `Resource` and `Value` types for dynamic data handling
- **Vector Concepts:** `/Users/fabier/Documents/code/surrealdartb/docs/doc-sdk-rust/concepts/vector-embeddings.mdx` - References vector embedding usage patterns with SurrealDB Rust SDK
- **Example Usage Pattern:** `/Users/fabier/Documents/code/surrealdartb/example/scenarios/crud_operations.dart` - Shows current connection initialization and schema usage patterns

### Follow-up Questions

Based on the user's answers and the major scope addition (migration system), I need clarification on migration behavior and implementation details:

**Migration Behavior & Detection:**

1. For migration detection strategy, should the system:
   - **Option A:** Auto-detect changes by comparing provided TableStructure definitions against existing database schema (query SHOW TABLE and DESCRIBE TABLE)?
   - **Option B:** Use explicit version numbers/migration files (like Rails/Django migrations)?
   - **Option C:** Hybrid approach - auto-detect in development, explicit migrations in production?

2. When should migrations run:
   - **Option A:** Automatically on `Database.connect()` if table definitions are provided?
   - **Option B:** Manual trigger via separate method like `db.runMigrations()` after connection?
   - **Option C:** Both - with an optional `autoMigrate: true/false` parameter in `Database.connect()`?

**Destructive Operations Scope:**

3. What should the "destructive operations" flag enable/disable?
   - Drop columns that are no longer in the schema?
   - Drop tables that are no longer defined?
   - Recreate tables (drop + create) when incompatible changes detected?
   - All of the above?
   - Something else?

4. For non-destructive mode, what should happen when schema changes require destructive operations (e.g., removing a field)?
   - Throw an error with details about required changes?
   - Log a warning and skip the change?
   - Create a "migration plan" file that user must manually review and execute?

**Migration Storage & History:**

5. Should the system track applied migrations in the database itself (like a `_migrations` table)?
   - If yes, what information should be stored (timestamp, schema hash, user-provided version number, etc.)?
   - If no, how do we avoid re-running migrations on every connection?

6. Should we support rollback functionality?
   - If yes, should we generate rollback logic automatically or require user-provided rollback scripts?
   - If no, is this explicitly out of scope for MVP?

**Development vs Production:**

7. Should migration behavior differ between development and production environments?
   - For example, auto-migrate with destructive ops in dev, but require explicit approval in prod?
   - How would the system detect environment (explicit flag, environment variables, heuristics)?

**Schema Validation Without Migration:**

8. Should there be a "validate only" mode that checks schema compatibility without applying changes?
   - Useful for CI/CD pipelines to catch schema drift
   - Could return a report of differences between defined schema and actual database

**API Design Question:**

9. For the initialization API, which approach do you prefer:

**Option A: Connection Parameters**
```dart
await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
  tables: [userSchema, productSchema],
  autoMigrate: true,
  allowDestructive: false,
);
```

**Option B: Post-Connection Method**
```dart
final db = await Database.connect(...);
await db.applySchemas(
  [userSchema, productSchema],
  destructive: false,
);
```

**Option C: Schema Manager Class**
```dart
final db = await Database.connect(...);
final migrator = SchemaManager(db);
await migrator.sync([userSchema, productSchema],
  destructive: false,
);
```

Please provide your preferences for these migration design questions.

## Visual Assets

### Files Provided:
No visual assets found (bash check confirmed).

### Visual Insights:
Not applicable - this is a data model and API feature without UI components.

## Requirements Summary

### Functional Requirements

#### Vector Data Type Support (Completed in Previous Work)
1. **Primary Vector Type:** F32 (float32) vector type as the primary use case
2. **Additional Vector Types:** F64, I8, I16, I32, I64 supported
3. **VectorValue Class:** Comprehensive Dart class with factory constructors, validation, math operations, and distance calculations
4. **Serialization:** Hybrid strategy (JSON ≤100 dims, binary >100 dims)
5. **Integration:** Seamless integration with existing CRUD operations

#### TableStructure Implementation (Completed in Previous Work)
1. **Comprehensive Schema Support:** Full TableStructure with complete type definitions
2. **Type System Coverage:** All SurrealDB data types supported
3. **Schema Definition API:** Dart API for defining table structures programmatically
4. **Vector Field Types:** Full support for vector fields with dimensions and constraints
5. **Validation Strategy:** Dual validation (Dart-side + SurrealDB fallback)

#### NEW: Decorator-Based Schema System with Code Generation
1. **Decorator Annotations:**
   - All fields must have explicit decorators
   - `@Table(name: 'table_name')` for class-level table definition
   - `@Field()` for basic field decoration with Dart type → SurrealType mapping
   - `@VectorField(dimensions: N, format: VectorFormat.f32)` for vector fields
   - `@RecordId()` for ID fields (no auto-detection)
   - `@JsonField()` for serializing complex objects to JSON strings
   - `@CustomConverter(converter: MyConverter)` for custom type serialization
   - Support for `defaultValue` parameter in field decorators

2. **Null Safety Integration:**
   - Nullable types (`String?`) automatically map to `optional: true` in FieldDefinition
   - Non-nullable types are treated as required fields

3. **Collection Handling:**
   - Explicit annotations required for collections (`@SurrealArray()`, etc.)
   - No auto-detection of collection element types to keep intent clear

4. **Nested Object Support:**
   - Recursive generation of nested TableStructure schemas
   - Option to use `@JsonField()` to serialize to JSON string instead of ObjectType

5. **Type Mapping:**
   - `String` → `StringType()`
   - `int` → `NumberType(format: NumberFormat.integer)`
   - `double` → `NumberType(format: NumberFormat.floating)`
   - `bool` → `BoolType()`
   - `DateTime` → `DatetimeType()`
   - `Duration` → `DurationType()`
   - `List<T>` → `ArrayType(T)` (with explicit annotation)
   - `Map<String, dynamic>` → `ObjectType()`
   - `VectorValue` → `VectorType()` (with explicit `@VectorField` annotation)

6. **Code Generation Output:**
   - Generate `TableStructure` instances for each decorated class
   - Generate factory constructors for creating instances from database records
   - Generate `toJson()` methods for serialization
   - Generate validation helpers

7. **Build Integration:**
   - Use build_runner for code generation
   - No dependency on dart:mirrors (Flutter web/mobile compatible)

8. **Custom Converter Support:**
   - `@CustomConverter` decorator for user-defined serialization logic
   - Fallback to `toString()` for types without explicit converters

#### NEW: Table Migration System
1. **Connection-Time Schema Definitions:**
   - Ability to pass table definitions (TableStructure instances) during `Database.connect()`
   - Optional parameter for enabling/disabling destructive operations
   - Support for automatic migration detection and execution

2. **Schema Change Detection:**
   - [TO BE DETERMINED] Auto-detect vs explicit versioning strategy
   - [TO BE DETERMINED] Comparison mechanism for schema differences

3. **Migration Execution:**
   - [TO BE DETERMINED] Automatic on connect vs manual trigger
   - [TO BE DETERMINED] Handling of non-destructive vs destructive changes
   - Generate and execute SurrealQL DDL statements (DEFINE TABLE, DEFINE FIELD, etc.)

4. **Destructive Operations Control:**
   - [TO BE DETERMINED] Scope of destructive operations flag
   - [TO BE DETERMINED] Behavior when destructive changes are required but disabled

5. **Migration History & Tracking:**
   - [TO BE DETERMINED] Storage mechanism for applied migrations
   - [TO BE DETERMINED] Rollback support requirements

6. **Environment-Aware Behavior:**
   - [TO BE DETERMINED] Development vs production differences
   - [TO BE DETERMINED] Validation-only mode for CI/CD

7. **Error Handling:**
   - Clear error messages when migrations fail
   - Rollback or partial application strategy for failed migrations
   - Detailed reporting of schema differences and required changes

### Reusability Opportunities

**Existing Patterns to Follow:**
1. **Database Connection Pattern:** Model after existing `Database.connect()` in `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart`
2. **TableStructure Foundation:** Build on existing TableStructure implementation in `/Users/fabier/Documents/code/surrealdartb/lib/src/schema/table_structure.dart`
3. **SurrealQL Generation:** Leverage existing `toSurrealQL()` method in TableStructure for DDL generation
4. **Type Definition Pattern:** Follow patterns in `/Users/fabier/Documents/code/surrealdartb/lib/src/types/` for any new type definitions
5. **FFI Integration:** Follow NativeDatabase/NativeResponse opaque handle pattern if Rust-side support needed
6. **Memory Management:** Use NativeFinalizer pattern established in Phase 1 for automatic cleanup
7. **Testing Pattern:** Model tests after existing 18 test files with similar structure and coverage

**Code References:**
- Database connection: `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart`
- Schema definitions: `/Users/fabier/Documents/code/surrealdartb/lib/src/schema/table_structure.dart`
- Type system: `/Users/fabier/Documents/code/surrealdartb/lib/src/schema/surreal_types.dart`
- Type exports: `/Users/fabier/Documents/code/surrealdartb/lib/src/types/types.dart`
- Example usage: `/Users/fabier/Documents/code/surrealdartb/example/scenarios/crud_operations.dart`

### Scope Boundaries

**In Scope:**
- Decorator-based schema annotations for all field types
- Code generation using build_runner (no dart:mirrors)
- Automatic Dart type → SurrealType mapping with explicit decorators
- Null safety integration (`String?` → `optional: true`)
- Nested object recursive generation with `@JsonField` option
- Custom converter support with toString() fallback
- Default value support in field decorators
- Explicit collection annotations
- Vector field explicit annotation requirement
- Table migration system foundation (detailed scope pending follow-up answers)
- Schema change detection mechanism (strategy TBD)
- Migration execution (timing and destructive operation handling TBD)
- Migration history tracking (mechanism TBD)

**Out of Scope (For Initial Implementation):**
- Complex nested generics like `Map<String, List<CustomClass>>`
- Auto-detection of ID fields (decorators mandatory)
- dart:mirrors-based reflection
- Migration rollback functionality (pending follow-up answers)
- Advanced migration features like data transformations during schema changes
- Migration version conflict resolution for multi-developer scenarios

**Future Enhancements (Post-Initial Implementation):**
- Support for complex nested generic types
- Advanced migration features (data transformations, seeding)
- Migration rollback with automatic reverse logic generation
- Schema diffing tools and migration plan generation
- Integration with version control for migration history
- Advanced custom converter patterns
- Schema inheritance and composition patterns

### Technical Considerations

#### Code Generation Architecture
- Use build_runner with source_gen for code generation
- Generate `.g.dart` files alongside decorated class files
- Ensure generated code is human-readable and debuggable
- Handle edge cases in type mapping gracefully
- Provide clear error messages during generation phase

#### Migration System Architecture (Pending Follow-up Answers)
- [TBD] Detection strategy: auto-detect vs explicit versioning
- [TBD] Execution timing: on connect vs manual
- [TBD] Migration storage: in-database vs external files
- Integration with existing TableStructure and toSurrealQL() method
- Use existing Database.query() for executing DDL statements
- Consider transaction support for atomic migration application (note: rollback currently broken per roadmap)

#### FFI Integration
- Likely pure Dart implementation for migration system (no new FFI required)
- Leverage existing SurrealQL query execution through FFI
- Follow established error handling pattern for migration failures

#### Memory Management
- No special memory management needed for code generation (compile-time)
- Migration system should properly clean up any temporary resources

#### Performance
- Code generation happens at build time (no runtime performance impact)
- Migration system should minimize database queries during schema comparison
- Consider caching schema information to avoid repeated SHOW TABLE queries

#### Type Safety
- Maintain type-safe decorator APIs
- Ensure generated code maintains type safety
- Migration system should validate schema changes before execution

#### Platform Compatibility
- Code generation must work across all platforms
- Avoid platform-specific migration logic
- Ensure migration system works with both memory and rocksdb backends

#### Documentation Requirements
- Document all decorator annotations with examples
- Provide migration system usage guide
- Include example decorated classes
- Document generated code structure
- Create migration best practices guide
- Include troubleshooting section for common generation errors

#### Standards Compliance
All implementation must align with:
- Global coding standards in `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/global/`
- Frontend standards in `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/frontend/`
- Backend standards in `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/backend/`
- Testing standards in `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/testing/`

Key standards to follow:
- Rust integration patterns from `backend/rust-integration.md`
- FFI type definitions from `backend/ffi-types.md`
- Async patterns from `backend/async-patterns.md`
- Error handling from `global/error-handling.md`
- Validation patterns from `global/validation.md`
- Test writing from `testing/test-writing.md`
- Coding style from `global/coding-style.md`
- Commenting from `global/commenting.md`

## Success Criteria

### Exit Criteria (Extended from Phase 2 Milestone 5)
- Vector data storage and retrieval continues to work reliably (already complete)
- Decorator-based schema system generates valid TableStructure instances
- Code generation produces correct and type-safe output
- Null safety properly maps to optional fields
- Nested objects are recursively generated
- Custom converters work as expected
- Migration system successfully applies schema changes (behavior pending follow-up answers)
- Migration system handles destructive operations according to configuration
- Test coverage meets project standards (~92% or higher)
- Documentation includes usage examples for decorators and migrations
- Feature works consistently across all supported platforms

### Testing Requirements
- Unit tests for all decorator annotations
- Unit tests for code generation logic
- Unit tests for type mapping
- Unit tests for nested object generation
- Unit tests for custom converter functionality
- Integration tests for migration detection and execution
- Integration tests for destructive vs non-destructive migrations
- Integration tests for migration error handling and rollback
- Cross-platform validation tests for generated code
- Performance tests for migration on large schemas
- Memory leak tests for migration system

### Documentation Deliverables
- Decorator annotation reference guide
- Code generation setup and configuration guide
- Migration system usage guide
- Examples of decorated classes for common use cases
- Migration best practices and patterns
- Troubleshooting guide for common issues
- API documentation for all new classes and methods
- Migration guide for adding schema management to existing projects
