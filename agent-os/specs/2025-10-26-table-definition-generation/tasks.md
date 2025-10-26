# Task Breakdown: Table Definition Generation & Migration System

## Overview

This feature enables automatic SurrealDB table definition generation from annotated Dart classes using build_runner, plus an intelligent migration system with schema detection, safe execution, and rollback support.

**Total Tasks:** 6 Phase Groups (47 sub-tasks)
**Assigned Implementers:** database-engineer, api-engineer, testing-engineer
**Estimated Duration:** 6 weeks (1 week per phase)

## Task List

### Phase 1: Code Generation Foundation

#### Task Group 1.1: Annotation System & Basic Generator
**Assigned implementer:** database-engineer
**Dependencies:** None
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 1.1.0 Complete annotation system and basic generator
  - [ ] 1.1.1 Write 2-8 focused tests for annotation classes
    - Test SurrealTable annotation parsing
    - Test SurrealField annotation with all parameters
    - Test JsonField annotation
    - Verify annotation validation and error messages
  - [ ] 1.1.2 Create annotation classes in `lib/src/schema/annotations.dart`
    - Implement `@SurrealTable(tableName)` decorator
    - Implement `@SurrealField()` decorator with parameters: type, defaultValue, assert, indexed
    - Implement `@JsonField()` decorator for JSON serialization
    - Add validation for required parameters
    - Follow const constructor pattern for annotations
  - [ ] 1.1.3 Set up build_runner infrastructure
    - Create `lib/generator/` directory structure
    - Configure `build.yaml` with generator settings
    - Create generator class extending `GeneratorForAnnotation<SurrealTable>`
    - Set up part file generation pattern (`.surreal.dart`)
  - [ ] 1.1.4 Implement annotation parser using analyzer package
    - Parse `@SurrealTable` to extract table name
    - Parse `@SurrealField` to extract field metadata
    - Validate mandatory field annotations
    - Extract class and field information from AST
  - [ ] 1.1.5 Ensure annotation and parser tests pass
    - Run ONLY the 2-8 tests written in 1.1.1
    - Verify annotation parsing works correctly
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1.1 pass
- Annotations compile and can be applied to classes
- Generator can parse annotated classes
- Part files are generated with correct naming

---

#### Task Group 1.2: Basic Type Mapping & TableDefinition Generation
**Assigned implementer:** database-engineer
**Dependencies:** Task Group 1.1
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 1.2.0 Complete basic type mapping system
  - [ ] 1.2.1 Write 2-8 focused tests for type mapper
    - Test String → string mapping
    - Test int → int mapping
    - Test double → float mapping
    - Test bool → bool mapping
    - Test DateTime → datetime mapping
    - Test Duration → duration mapping
    - Test unknown type error handling
  - [ ] 1.2.2 Create type mapper in `lib/generator/type_mapper.dart`
    - Implement Dart primitive → SurrealDB type mapping
    - Map String → string
    - Map int → int
    - Map double → float
    - Map bool → bool
    - Map DateTime → datetime
    - Map Duration → duration
    - Add error handling for unsupported types
  - [ ] 1.2.3 Implement TableDefinition code generation
    - Generate immutable TableDefinition classes with const constructors
    - Generate FieldDefinition for each annotated field
    - Include type, defaultValue, and constraints in generated code
    - Follow existing TableStructure pattern in `lib/src/schema/` (reuse existing: TableStructure, FieldDefinition)
    - Ensure generated code is properly formatted
  - [ ] 1.2.4 Generate sample output for validation
    - Create test class with basic types
    - Run build_runner to generate `.surreal.dart` file
    - Verify generated code compiles
    - Verify generated code follows coding standards
  - [ ] 1.2.5 Ensure type mapper tests pass
    - Run ONLY the 2-8 tests written in 1.2.1
    - Verify all basic type mappings work
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.2.1 pass
- Basic Dart types map correctly to SurrealDB types
- Generated TableDefinition classes compile
- Generated code follows naming conventions
- Generated code is immutable with const constructors

---

### Phase 2: Advanced Type Support

#### Task Group 2.1: Collection & Nested Object Types
**Assigned implementer:** database-engineer
**Dependencies:** Task Group 1.2
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 2.1.0 Complete collection and nested object support
  - [ ] 2.1.1 Write 2-8 focused tests for advanced types
    - Test List<T> → array<T> mapping
    - Test Set<T> → array<T> mapping
    - Test Map<String, dynamic> → object mapping
    - Test custom class → nested object mapping
    - Test recursive nested object generation
  - [ ] 2.1.2 Implement collection type mapping
    - Add List<T> → array<T> support
    - Add Set<T> → array<T> support
    - Handle generic type parameters correctly
    - Map Map<String, dynamic> to object type
  - [ ] 2.1.3 Implement recursive nested object generation
    - Detect custom class types in fields
    - Recursively traverse nested classes
    - Generate nested FieldDefinition structures
    - Handle circular references gracefully (throw error)
  - [ ] 2.1.4 Add custom converter support
    - Support `@JsonConverter` pattern from json_serializable
    - Implement toString() fallback for unknown types
    - Generate conversion code in TableDefinition
  - [ ] 2.1.5 Ensure advanced type tests pass
    - Run ONLY the 2-8 tests written in 2.1.1
    - Verify collection and nested object generation works
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1.1 pass
- Collections map to array types correctly
- Nested objects generate complete schemas
- Custom converters integrate properly
- Circular references are detected and handled

---

#### Task Group 2.2: Vector Types & Schema Constraints
**Assigned implementer:** database-engineer
**Dependencies:** Task Group 2.1
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 2.2.0 Complete vector types and schema constraints
  - [ ] 2.2.1 Write 2-8 focused tests for vectors and constraints
    - Test vector field with dimensions → array<float, X>
    - Test ASSERT clause generation
    - Test INDEX definition generation
    - Test default value handling
    - Test vector dimension validation
  - [ ] 2.2.2 Implement vector type support
    - Reference existing VectorValue from `lib/src/types/vector_value.dart` (reuse existing: VectorValue, VectorFormat)
    - Add dimensions parameter to @SurrealField
    - Generate `array<float, X>` type with dimension
    - Validate dimension is specified for vector types
  - [ ] 2.2.3 Implement ASSERT clause generation
    - Parse assert parameter from @SurrealField
    - Generate ASSERT syntax in TableDefinition
    - Support SurrealQL validation expressions
  - [ ] 2.2.4 Implement INDEX definition generation
    - Parse indexed parameter from @SurrealField
    - Generate INDEX definitions in TableDefinition
    - Support basic field indexes
  - [ ] 2.2.5 Implement default value handling
    - Parse defaultValue parameter from @SurrealField
    - Generate DEFAULT clauses in TableDefinition
    - Handle different value types (primitives, expressions)
  - [ ] 2.2.6 Ensure vector and constraint tests pass
    - Run ONLY the 2-8 tests written in 2.2.1
    - Verify vector generation with dimensions works
    - Verify ASSERT and INDEX generation works
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.2.1 pass
- Vector fields generate correct array<float, X> types
- ASSERT clauses are properly formatted
- INDEX definitions are generated correctly
- Default values work for all supported types

---

### Phase 3: Migration Detection System

#### Task Group 3.1: Schema Introspection
**Assigned implementer:** api-engineer
**Dependencies:** Phase 2 complete
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 3.1.0 Complete schema introspection system
  - [ ] 3.1.1 Write 2-8 focused tests for introspection
    - Test INFO FOR DB query execution
    - Test schema response parsing
    - Test table metadata extraction
    - Test field metadata extraction
    - Test index metadata extraction
  - [ ] 3.1.2 Create introspection module in `lib/src/schema/introspection.dart`
    - Implement INFO FOR DB query wrapper
    - Implement INFO FOR TABLE query wrapper
    - Parse JSON response from SurrealDB
    - Extract table definitions
    - Extract field definitions with types and constraints
    - Extract index definitions
  - [ ] 3.1.3 Build schema snapshot data structure
    - Create DatabaseSchema class to hold current state
    - Create TableSchema class for table metadata
    - Create FieldSchema class for field metadata
    - Support serialization for snapshot storage
  - [ ] 3.1.4 Integrate with Database class
    - Add introspection call to Database initialization (reuse existing: Database.query() method)
    - Cache schema snapshot in Database instance
    - Handle introspection errors gracefully
    - Add SchemaIntrospectionException to `lib/src/exceptions.dart` (reuse existing: DatabaseException hierarchy)
  - [ ] 3.1.5 Ensure introspection tests pass
    - Run ONLY the 2-8 tests written in 3.1.1
    - Verify INFO queries execute correctly
    - Verify parsing handles all schema elements
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1.1 pass
- INFO FOR DB returns complete schema data
- Parser handles all SurrealDB schema elements
- Schema snapshot accurately represents database state
- Errors provide clear diagnostic information

---

#### Task Group 3.2: Schema Diff Calculation
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 3.1
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 3.2.0 Complete schema diff calculation
  - [ ] 3.2.1 Write 2-8 focused tests for diff engine
    - Test detection of new tables
    - Test detection of removed tables
    - Test detection of new fields
    - Test detection of removed fields
    - Test detection of modified field types
    - Test detection of constraint changes
    - Test identical schema (no changes)
  - [ ] 3.2.2 Create diff engine in `lib/src/schema/diff_engine.dart`
    - Implement table-level diff (added, removed, unchanged)
    - Implement field-level diff (added, removed, modified)
    - Implement type change detection
    - Implement constraint change detection (ASSERT, DEFAULT)
    - Implement index change detection
  - [ ] 3.2.3 Implement change classification system
    - Classify additions (safe)
    - Classify deletions (destructive)
    - Classify modifications (destructive if type change)
    - Classify constraint additions (safe)
    - Classify index changes (safe additions, destructive removals)
  - [ ] 3.2.4 Create SchemaDiff result structure
    - List of tables added
    - List of tables removed
    - Map of fields added per table
    - Map of fields removed per table
    - Map of fields modified per table
    - List of indexes added/removed
    - Boolean flag: hasDestructiveChanges
  - [ ] 3.2.5 Generate migration hash for tracking
    - Create deterministic hash from schema changes
    - Use for migration identification in _migrations table
    - Ensure same changes produce same hash
  - [ ] 3.2.6 Ensure diff engine tests pass
    - Run ONLY the 2-8 tests written in 3.2.1
    - Verify all change types detected correctly
    - Verify classification is accurate
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.2.1 pass
- All schema change types are detected accurately
- Safe vs destructive classification is correct
- SchemaDiff provides complete change information
- Migration hash is deterministic and unique

---

### Phase 4: Migration Execution Engine

#### Task Group 4.1: DDL Generation
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 3.2
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 4.1.0 Complete DDL generation system
  - [ ] 4.1.1 Write 2-8 focused tests for DDL generator
    - Test DEFINE TABLE statement generation
    - Test DEFINE FIELD statement generation
    - Test DEFINE INDEX statement generation
    - Test REMOVE TABLE statement generation
    - Test REMOVE FIELD statement generation
    - Test complex schema with all elements
  - [ ] 4.1.2 Create DDL generator in `lib/src/schema/ddl_generator.dart`
    - Implement DEFINE TABLE generation
    - Implement DEFINE FIELD generation with type, constraints
    - Implement DEFINE INDEX generation
    - Implement REMOVE TABLE generation
    - Implement REMOVE FIELD generation
    - Implement REMOVE INDEX generation
  - [ ] 4.1.3 Generate DDL from SchemaDiff
    - Convert table additions to DEFINE TABLE
    - Convert field additions to DEFINE FIELD
    - Convert index additions to DEFINE INDEX
    - Convert removals to REMOVE statements
    - Generate in correct dependency order
  - [ ] 4.1.4 Handle vector field DDL
    - Generate proper array<float, X> syntax
    - Include dimension in type definition
    - Validate dimension value
  - [ ] 4.1.5 Handle ASSERT and DEFAULT clauses
    - Format ASSERT expressions correctly
    - Format DEFAULT values based on type
    - Escape string values properly
  - [ ] 4.1.6 Ensure DDL generator tests pass
    - Run ONLY the 2-8 tests written in 4.1.1
    - Verify all DDL statements are syntactically correct
    - Verify complex schemas generate complete DDL
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.1.1 pass
- Generated DDL is valid SurrealQL syntax
- All schema elements translate to correct DDL
- Statement order respects dependencies
- Special types (vectors, assertions) handled correctly

---

#### Task Group 4.2: Transaction-Based Migration Execution
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 4.1
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 4.2.0 Complete migration execution engine
  - [ ] 4.2.1 Write 2-8 focused tests for migration execution
    - Test successful migration with transaction commit
    - Test failed migration with automatic rollback
    - Test dry run mode (transaction cancel)
    - Test migration history recording
    - Test destructive operation blocking
  - [ ] 4.2.2 Create migration engine in `lib/src/schema/migration_engine.dart`
    - Implement migration orchestration
    - Integrate introspection, diff, and DDL generation
    - Add migration validation logic
    - Add destructive change detection
    - Add dry run support
  - [ ] 4.2.3 Implement transaction-based execution
    - Execute BEGIN TRANSACTION before DDL (reuse existing: Database.transaction() method)
    - Execute DDL statements sequentially
    - Validate results after each statement
    - Execute COMMIT on success
    - Execute CANCEL on failure
  - [ ] 4.2.4 Create migration history tracking
    - Create `lib/src/schema/migration_history.dart`
    - Implement _migrations table creation
    - Define schema: migration_id, applied_at, status, schema_snapshot, changes_applied
    - Record successful migrations
    - Record failed migrations with error details
    - Store schema snapshot for rollback
  - [ ] 4.2.5 Implement dry run mode
    - Execute migration in transaction
    - Validate DDL execution
    - Query schema to verify changes
    - CANCEL transaction instead of COMMIT
    - Return MigrationReport with preview
  - [ ] 4.2.6 Add migration exceptions
    - Extend DatabaseException in `lib/src/exceptions.dart` (reuse existing: DatabaseException, error message patterns)
    - Create MigrationException with report and isDestructive flag
    - Create descriptive error messages
    - Include actionable guidance in messages
  - [ ] 4.2.7 Ensure migration execution tests pass
    - Run ONLY the 2-8 tests written in 4.2.1
    - Verify transactions commit/rollback correctly
    - Verify migration history is recorded
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 4.2.1 pass
- Migrations execute atomically (all-or-nothing)
- Failed migrations automatically roll back
- Migration history is complete and accurate
- Dry run mode accurately previews changes
- Exceptions provide clear, actionable messages

---

### Phase 5: Safety Features & Rollback

#### Task Group 5.1: Destructive Operation Protection
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 4.2
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 5.1.0 Complete destructive operation protection
  - [ ] 5.1.1 Write 2-8 focused tests for safety features
    - Test safe mode blocks destructive changes
    - Test allow mode permits destructive changes
    - Test error message includes all destructive operations
    - Test mixed safe/destructive changes handling
  - [ ] 5.1.2 Implement destructive change validation
    - Check for table removals
    - Check for field removals
    - Check for type changes
    - Check for index removals (optional: treat as non-destructive)
    - Check for constraint tightening
  - [ ] 5.1.3 Implement allowDestructiveMigrations flag handling
    - Default to false (safe mode)
    - When false and destructive changes detected: throw MigrationException
    - When true: allow all changes
    - Include detailed change list in exception
  - [ ] 5.1.4 Create MigrationReport class
    - Lists of tables added/removed
    - Maps of fields added/removed/modified per table
    - List of indexes added/removed
    - Boolean hasDestructiveChanges flag
    - String generatedDDL with full SQL
    - Summary statistics
  - [ ] 5.1.5 Generate detailed error messages
    - List each destructive operation with context
    - Estimate potential data loss (e.g., "12 records may be lost")
    - Provide 3 resolution options: enable flag, fix schema, manual migration
    - Format for readability
  - [ ] 5.1.6 Ensure safety feature tests pass
    - Run ONLY the 2-8 tests written in 5.1.1
    - Verify destructive operations blocked in safe mode
    - Verify error messages are clear and actionable
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 5.1.1 pass
- Destructive operations blocked by default
- Error messages list all destructive changes
- Guidance helps developers resolve issues
- MigrationReport provides complete information

---

#### Task Group 5.2: Manual Rollback Support
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 5.1
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 5.2.0 Complete manual rollback system
  - [ ] 5.2.1 Write 2-8 focused tests for rollback
    - Test rollback to previous schema snapshot
    - Test rollback generates correct reverse DDL
    - Test rollback records history entry
    - Test rollback when no previous snapshot exists
  - [ ] 5.2.2 Implement schema snapshot storage
    - Store complete schema in _migrations.schema_snapshot
    - Include all tables, fields, indexes, constraints
    - Serialize as JSON for storage
    - Deserialize for rollback
  - [ ] 5.2.3 Implement rollback DDL generation
    - Generate reverse DDL from schema diff
    - Convert current schema → snapshot schema
    - Generate appropriate DEFINE/REMOVE statements
    - Handle edge cases (table didn't exist before)
  - [ ] 5.2.4 Add rollbackMigration() method to Database class
    - Query _migrations table for last successful migration
    - Extract schema snapshot
    - Generate rollback DDL
    - Execute in transaction
    - Record rollback in migration history
  - [ ] 5.2.5 Handle rollback edge cases
    - No previous migration exists → throw error
    - Current schema matches snapshot → no-op
    - Rollback would be destructive → require flag
  - [ ] 5.2.6 Ensure rollback tests pass
    - Run ONLY the 2-8 tests written in 5.2.1
    - Verify rollback restores previous schema
    - Verify rollback is recorded in history
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 5.2.1 pass
- Rollback accurately restores previous schema
- Rollback handles edge cases gracefully
- Rollback operations are recorded in history
- Errors provide clear guidance when rollback not possible

---

### Phase 6: Integration & API Completion

#### Task Group 6.1: Database Class Integration
**Assigned implementer:** database-engineer
**Dependencies:** Phase 5 complete
**Complexity:** Medium
**Estimated Duration:** 2-3 days

- [ ] 6.1.0 Complete Database class integration
  - [ ] 6.1.1 Write 2-8 focused tests for Database integration
    - Test Database.connect() with autoMigrate=true
    - Test Database.connect() with autoMigrate=false
    - Test Database.migrate() manual call
    - Test migration parameters (dryRun, allowDestructive)
  - [ ] 6.1.2 Add migration parameters to Database.connect()
    - Add tableDefinitions parameter (List<TableDefinition>)
    - Add autoMigrate parameter (bool, default: true)
    - Add allowDestructiveMigrations parameter (bool, default: false)
    - Add dryRun parameter (bool, default: false)
    - Follow flat parameter style (not nested config) (reuse existing: Database.connect() parameter conventions)
  - [ ] 6.1.3 Implement auto-migration on connect
    - When autoMigrate=true: call migration engine after connection
    - Pass tableDefinitions to migration engine
    - Handle migration errors and rethrow with context
    - Log migration results
  - [ ] 6.1.4 Add Database.migrate() method for manual migrations
    - Accept dryRun parameter
    - Accept allowDestructiveMigrations parameter
    - Return MigrationReport
    - Execute migration via migration engine
  - [ ] 6.1.5 Add Database.rollbackMigration() method
    - Call rollback logic from migration engine
    - Return rollback report
    - Handle errors gracefully
  - [ ] 6.1.6 Ensure Database integration tests pass
    - Run ONLY the 2-8 tests written in 6.1.1
    - Verify auto-migration works on connect
    - Verify manual migration API works
    - Do NOT run entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 6.1.1 pass
- Database.connect() supports all migration parameters
- Auto-migration executes correctly
- Manual migration methods work as expected
- No breaking changes to existing Database API

---

#### Task Group 6.2: End-to-End Integration Testing
**Assigned implementer:** testing-engineer
**Dependencies:** Task Group 6.1
**Complexity:** High
**Estimated Duration:** 3-4 days

- [ ] 6.2.0 Review and fill critical integration test gaps
  - [ ] 6.2.1 Review existing tests from all previous task groups
    - Review tests from Task Groups 1.1-6.1
    - Approximately 36-48 tests exist from previous phases
    - Identify gaps in end-to-end workflows
    - Focus on integration points between components
  - [ ] 6.2.2 Analyze test coverage gaps for THIS feature only
    - Identify critical workflows lacking coverage:
      - Full annotation → generation → migration workflow
      - Schema change detection across app restarts
      - Complex nested object migrations
      - Vector field migrations with dimension changes
      - Migration failure and recovery scenarios
      - Dry run preview accuracy
    - Do NOT assess entire application coverage
    - Prioritize integration tests over unit test gaps
  - [ ] 6.2.3 Write up to 10 strategic integration tests maximum
    - Test complete workflow: annotate class → generate → connect → auto-migrate
    - Test schema evolution: modify annotation → regenerate → detect changes → migrate
    - Test vector field generation and migration
    - Test nested object schema changes
    - Test destructive operation blocking and override
    - Test dry run accuracy (preview matches actual)
    - Test migration failure with automatic rollback
    - Test manual rollback to previous schema
    - Test migration history persistence across restarts
    - Test complex real-world scenario (multiple tables, nested objects, vectors)
  - [ ] 6.2.4 Run feature-specific tests only
    - Run ONLY tests for this spec's feature (tests from 1.1.1-6.2.3)
    - Expected total: approximately 46-58 tests maximum
    - Do NOT run entire application test suite
    - Verify all critical workflows pass

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 46-58 tests total)
- Critical end-to-end workflows are covered
- No more than 10 additional tests added by testing-engineer
- Integration tests verify component interactions
- Complex real-world scenarios work correctly

---

#### Task Group 6.3: Documentation & Examples
**Assigned implementer:** database-engineer
**Dependencies:** Task Group 6.2
**Complexity:** Low
**Estimated Duration:** 2 days

- [ ] 6.3.0 Complete documentation and examples
  - [ ] 6.3.1 Create usage examples in `example/scenarios/`
    - Basic annotation and generation example
    - Migration workflow examples (dev vs production)
    - Vector field example with embeddings
    - Nested object example
    - Custom converter example
    - Dry run usage example
    - Rollback example
  - [ ] 6.3.2 Write API documentation
    - Document all annotation classes with examples
    - Document Database migration parameters
    - Document migration methods (migrate, rollback)
    - Document MigrationReport structure
    - Document exceptions and error handling
  - [ ] 6.3.3 Create migration guide for production
    - Recommended workflow for production deployments
    - How to preview migrations before applying
    - How to handle destructive changes safely
    - Rollback procedures
    - Best practices for schema evolution
  - [ ] 6.3.4 Update README with feature overview
    - Add table generation section
    - Add migration system section
    - Link to examples
    - Add quick start guide
  - [ ] 6.3.5 Add inline code documentation
    - Document all public API methods
    - Add examples in dartdoc comments
    - Document parameters and return types
    - Document exceptions thrown
  - [ ] 6.3.6 Update CHANGELOG.md with feature details
    - Add entry for table definition generation feature
    - Document new annotations (@SurrealTable, @SurrealField, @JsonField)
    - Document new Database migration parameters and methods
    - List breaking changes (if any)
    - Follow project's changelog conventions

**Acceptance Criteria:**
- All examples run successfully
- API documentation is complete and accurate
- Migration guide covers production scenarios
- README clearly explains feature usage
- Code documentation follows dartdoc standards
- CHANGELOG.md updated with complete feature details

---

## Execution Order

### Phase-by-Phase Implementation Sequence

**Phase 1: Code Generation Foundation (Week 1)**
1. Task Group 1.1: Annotation System & Basic Generator
2. Task Group 1.2: Basic Type Mapping & TableDefinition Generation

**Phase 2: Advanced Type Support (Week 2)**
3. Task Group 2.1: Collection & Nested Object Types
4. Task Group 2.2: Vector Types & Schema Constraints

**Phase 3: Migration Detection System (Week 3)**
5. Task Group 3.1: Schema Introspection
6. Task Group 3.2: Schema Diff Calculation

**Phase 4: Migration Execution Engine (Week 4)**
7. Task Group 4.1: DDL Generation
8. Task Group 4.2: Transaction-Based Migration Execution

**Phase 5: Safety Features & Rollback (Week 5)**
9. Task Group 5.1: Destructive Operation Protection
10. Task Group 5.2: Manual Rollback Support

**Phase 6: Integration & API Completion (Week 6)**
11. Task Group 6.1: Database Class Integration
12. Task Group 6.2: End-to-End Integration Testing
13. Task Group 6.3: Documentation & Examples

---

## Critical Dependencies

**External Dependencies:**
- build_runner package
- analyzer package for annotation parsing
- Existing VectorValue infrastructure (`lib/src/types/vector_value.dart`)
- SurrealDB INFO FOR DB/TABLE query support
- SurrealDB transaction support (BEGIN/COMMIT/CANCEL)

**Internal Dependencies:**
- Existing Database class (`lib/src/database.dart`)
- Existing TableStructure pattern (`lib/src/schema/`)
- Existing exception hierarchy (`lib/src/exceptions.dart`)
- Existing FFI bindings (`lib/src/ffi/bindings.dart`)

**Inter-Phase Dependencies:**
- Phase 2 requires Phase 1 (type mapping builds on basic generator)
- Phase 3 requires Phase 2 (migration needs complete type support)
- Phase 4 requires Phase 3 (execution needs detection)
- Phase 5 requires Phase 4 (safety builds on execution)
- Phase 6 requires Phase 5 (integration needs all components)

---

## Risk Areas & Mitigation

**High-Risk Areas:**

1. **Schema Introspection Parsing (Task 3.1)**
   - Risk: INFO FOR DB response format may vary across SurrealDB versions
   - Mitigation: Test against multiple SurrealDB versions; handle missing fields gracefully

2. **DDL Generation Accuracy (Task 4.1)**
   - Risk: Generated DDL may have syntax errors or miss edge cases
   - Mitigation: Extensive test coverage; validate DDL in dry run before commit

3. **Transaction Rollback (Task 4.2)**
   - Risk: Partial execution if transaction support doesn't work as expected
   - Mitigation: Test transaction behavior thoroughly; fail fast on errors

4. **Recursive Nested Objects (Task 2.1)**
   - Risk: Circular references or infinite recursion
   - Mitigation: Track visited types; throw error on circular reference

**Medium-Risk Areas:**

5. **Build_runner Integration (Task 1.1)**
   - Risk: Generator configuration issues or part file conflicts
   - Mitigation: Follow json_serializable patterns closely; test with clean builds

6. **Vector Type Handling (Task 2.2)**
   - Risk: Dimension validation or integration with existing VectorValue
   - Mitigation: Reference existing implementation; test dimension validation

---

## Testing Strategy Summary

**Per-Phase Testing Approach:**
- Each task group writes 2-8 focused tests (except integration phase)
- Tests run ONLY for current task group (not entire suite)
- Testing-engineer adds up to 10 strategic integration tests
- Total expected tests: 46-58 for complete feature

**Test Coverage Focus:**
- Unit tests for each component (generator, mapper, diff, DDL)
- Integration tests for component interactions
- End-to-end tests for complete workflows
- Edge case tests for error handling

**Test Execution:**
- Use in-memory SurrealDB for fast test execution
- Test transaction behavior with real database
- Verify generated code compiles and passes linter
- Test across multiple schema change scenarios

---

## Success Metrics

**Code Quality:**
- All generated code passes linter and analyzer
- Zero breaking changes to existing Database API
- Generated code is readable and maintainable
- 90%+ test coverage for new code

**Functionality:**
- All basic and advanced types map correctly
- Schema detection is 100% accurate
- Migrations execute atomically
- Rollback restores exact previous state

**Developer Experience:**
- Annotation-based schema definition reduces boilerplate by 50%+
- Clear error messages guide developers to solutions
- Dry run accurately previews production migrations
- Documentation covers all common use cases

**Safety:**
- Destructive operations blocked by default
- Failed migrations automatically roll back
- No partial migrations (all-or-nothing)
- Migration history is complete and queryable

---

## Notes for Implementers

**For database-engineer:**
- Reference existing schema patterns in `lib/src/schema/`
- Follow TableStructure and FieldDefinition patterns
- Use const constructors for generated classes
- Follow Dart formatting and naming conventions
- Keep generated code readable

**For api-engineer:**
- Leverage existing Database.query() for introspection
- Use existing transaction() method for migration execution
- Follow exception patterns in `lib/src/exceptions.dart`
- Keep migration logic stateless where possible
- Validate all DDL before execution

**For testing-engineer:**
- Focus on integration points between components
- Test real SurrealDB transaction behavior
- Verify migration history persists correctly
- Test complex scenarios (nested objects, vectors, mixed changes)
- Ensure tests are deterministic and fast

**General Guidelines:**
- Run `dart format` on all code
- Follow TDD: write tests first, implement second
- Keep functions small and focused (< 20 lines)
- Use descriptive names for variables and methods
- Document public APIs with dartdoc comments
- Handle all error cases explicitly
