# Task 2: ORM Annotations Definition

## Overview
**Task Reference:** Task #2 from `agent-os/specs/2025-10-26-type-safe-orm-layer/tasks.md`
**Implemented By:** database-engineer
**Date:** 2025-10-26
**Status:** Complete

### Task Description
Implement ORM annotations for defining relationships in the type-safe ORM layer. This includes annotations for record links, graph relations, edge tables, and ID field marking.

## Implementation Summary
This task successfully implements all four ORM annotation types required for relationship management in the type-safe ORM layer. The annotations follow Dart's standard annotation patterns and are fully const-constructable for use as decorators. Each annotation is comprehensively documented with detailed dartdoc comments including usage examples, parameter descriptions, and integration patterns with SurrealDB's graph database features.

The implementation provides a clean, declarative API for developers to define relationships between entities. The annotations enable compile-time type safety while maintaining flexibility through optional parameters and support for both simple and complex relationship patterns including nested relationships and edge metadata.

All eight acceptance criteria tests pass, validating that annotations can be correctly instantiated, parameters are properly handled, and the RelationDirection enum provides all three required direction values (out, inbound, both).

## Files Changed/Created

### New Files
- `lib/src/schema/orm_annotations.dart` - ORM annotations for relationship definitions
- `test/unit/orm_annotations_test.dart` - Unit tests validating annotation behavior

### Modified Files
- `lib/surrealdartb.dart` - Added exports for SurrealRecord, SurrealRelation, RelationDirection, SurrealEdge, and SurrealId annotations to public API
- `agent-os/specs/2025-10-26-type-safe-orm-layer/tasks.md` - Marked all Task Group 2 sub-tasks as completed

## Key Implementation Details

### SurrealRecord Annotation
**Location:** `lib/src/schema/orm_annotations.dart`

Marks a field as a record link relationship for direct references to other records. This annotation generates FETCH clauses in SurrealQL queries to load related records.

**Key Features:**
- Optional `tableName` parameter for explicit target table specification
- Supports both single references and lists of references
- Non-nullable fields are auto-included in queries
- Generates appropriate FETCH syntax based on field type

**Rationale:** Record links are the simplest and most common relationship type in SurrealDB. This annotation provides a clean syntax for defining them while allowing developers to override default table name inference when needed.

### SurrealRelation Annotation
**Location:** `lib/src/schema/orm_annotations.dart`

Marks a field as a graph traversal relationship using SurrealDB's directional graph syntax (->/<-/<->).

**Key Features:**
- Required `name` parameter for the relation edge name
- Required `direction` parameter using RelationDirection enum
- Optional `targetTable` parameter to constrain traversal targets
- Supports all three directional patterns: outgoing, incoming, and bidirectional

**Rationale:** Graph relations enable powerful bidirectional traversal patterns that are core to SurrealDB's graph database capabilities. This annotation exposes these features in a type-safe manner while maintaining clarity about traversal direction.

### RelationDirection Enum
**Location:** `lib/src/schema/orm_annotations.dart`

Defines the three types of graph traversal directions supported by SurrealDB.

**Values:**
- `out`: Outgoing edges (->)
- `inbound`: Incoming edges (<-)
- `both`: Bidirectional edges (<->)

**Rationale:** Using an enum instead of strings provides compile-time type safety and enables IDE autocomplete. The value names directly correspond to SurrealDB's graph syntax semantics. Note: Used `inbound` instead of `in` to avoid Dart keyword conflicts.

### SurrealEdge Annotation
**Location:** `lib/src/schema/orm_annotations.dart`

Marks a class as an edge table definition for many-to-many relationships with metadata.

**Key Features:**
- Required `edgeTableName` parameter for the edge table name
- Classes must have exactly two @SurrealRecord fields (source and target)
- Additional fields represent edge metadata
- Generates RELATE statement support

**Rationale:** Edge tables are special in SurrealDB as they allow storing metadata on relationships themselves. This annotation makes edge table definitions explicit and enables the generator to create appropriate RELATE statement helpers.

### SurrealId Annotation
**Location:** `lib/src/schema/orm_annotations.dart`

Marker annotation to explicitly identify a field as the record ID field.

**Key Features:**
- No parameters (pure marker annotation)
- Overrides default 'id' field detection
- Only one field per class should have this annotation

**Rationale:** By convention, fields named 'id' are automatically detected as ID fields. However, some schemas may use different field names (e.g., 'userId', 'recordId'). This annotation provides an explicit override mechanism when needed.

## Database Changes
No database changes required. This task only defines annotation types for use in code generation.

## Dependencies
No new dependencies added. All annotations use only standard Dart language features.

## Testing

### Test Files Created
- `test/unit/orm_annotations_test.dart` - 8 comprehensive unit tests

### Test Coverage
- Unit tests: Complete (8/8 tests passing)
- Integration tests: Not applicable for this task
- Edge cases covered:
  - Default parameter values (null tableName, null targetTable)
  - Explicit parameter values
  - All three RelationDirection enum values
  - Const constructability of all annotations
  - Annotation instances are non-null

### Manual Testing Performed
All tests executed via `dart test test/unit/orm_annotations_test.dart`. All 8 tests pass:
1. SurrealRecord annotation with default parameters
2. SurrealRecord annotation with explicit table name
3. SurrealRelation annotation with all parameters
4. SurrealRelation annotation with optional targetTable
5. RelationDirection enum has all three directions
6. SurrealEdge annotation with edge table name
7. SurrealId annotation as marker
8. Annotations are const and can be used as decorators

## User Standards & Preferences Compliance

### global/coding-style.md
**File Reference:** `agent-os/standards/global/coding-style.md`

**How Implementation Complies:**
- All classes follow PascalCase naming convention (SurrealRecord, SurrealRelation, RelationDirection, SurrealEdge, SurrealId)
- Enum values use camelCase naming (out, inbound, both)
- File name uses snake_case: `orm_annotations.dart`
- Comprehensive dartdoc comments on all public APIs with usage examples
- Final by default: All annotation fields are final
- Const constructors: All annotation classes use const constructors for zero runtime overhead
- Meaningful names: All annotation and parameter names are descriptive and reveal intent (e.g., `edgeTableName`, `direction`, `targetTable`)

**Deviations:** None

### global/conventions.md
**File Reference:** `agent-os/standards/global/conventions.md`

**How Implementation Complies:**
- Package structure follows standard Dart layout with annotations in `lib/src/schema/`
- Public API exports through main library file `lib/surrealdartb.dart`
- Documentation first approach: Extensive dartdoc with examples before implementation
- Null safety: All code is soundly null-safe with appropriate optional parameters
- All public APIs have comprehensive documentation with usage examples
- Clear license compatibility maintained (existing MIT license)

**Deviations:** None

### global/error-handling.md
**File Reference:** `agent-os/standards/global/error-handling.md`

**How Implementation Complies:**
This task defines annotation classes with no runtime error conditions. Error handling will be implemented in subsequent tasks when annotations are parsed by the code generator. The annotations themselves are simple const data classes with no validation logic, following the standard Dart annotation pattern.

**Deviations:** None (error handling not applicable for simple annotation definitions)

### global/tech-stack.md
**File Reference:** `agent-os/standards/global/tech-stack.md`

**How Implementation Complies:**
- Uses Dart 3.x features appropriately (const constructors, null safety)
- Enum definitions follow modern Dart enum patterns
- Zero runtime dependencies added
- Minimal code footprint with maximal expressiveness through annotations

**Deviations:** None

## Integration Points

### APIs/Endpoints
No API endpoints created. This task defines annotation types for use by the code generator.

### Internal Dependencies
- Annotations will be used by `lib/generator/surreal_table_generator.dart` in future tasks
- Exported through `lib/surrealdartb.dart` for public API access
- Will work in conjunction with existing `@SurrealTable` and `@SurrealField` annotations

## Known Issues & Limitations

### Issues
None identified

### Limitations
1. **Annotation Validation**
   - Description: Annotations themselves do not validate that they are used correctly (e.g., ensuring edge tables have exactly two @SurrealRecord fields)
   - Reason: Validation is handled by the code generator, not the annotations
   - Future Consideration: The generator will validate proper annotation usage during code generation (Task Groups 4, 11)

2. **Runtime Reflection Not Supported**
   - Description: Annotations cannot be introspected at runtime without mirrors
   - Reason: Dart's build_runner approach uses compile-time code generation instead of runtime reflection
   - Future Consideration: This is by design for performance reasons; no changes needed

## Performance Considerations
Zero runtime performance impact. All annotations are const classes that exist only at compile-time. The code generator reads them during build, but they have no runtime overhead.

## Security Considerations
No security implications. Annotations are purely metadata for code generation with no runtime behavior or data access.

## Dependencies for Other Tasks
The following task groups depend on these annotations:
- Task Group 4: Serialization Code Generation (needs @SurrealId)
- Task Group 11: Relationship Field Detection and Metadata (needs all relationship annotations)
- Task Group 12: Record Link Relationships (needs @SurrealRecord)
- Task Group 13: Graph Relation & Edge Table Relationships (needs @SurrealRelation, @SurrealEdge)

## Notes

### Design Decision: RelationDirection Naming
The enum value for incoming edges is named `inbound` rather than `in` to avoid conflicts with Dart's `in` keyword. This naming is consistent with common terminology in graph databases and networking (inbound/outbound).

### Design Decision: Const Constructors
All annotations use const constructors to enable their use as compile-time constants in decorator syntax. This is a requirement for Dart annotations and ensures zero runtime overhead.

### Design Decision: Optional Parameters
Most parameters are optional with null defaults, allowing the code generator to infer values when possible (e.g., inferring table names from type names). This reduces boilerplate while maintaining flexibility for explicit overrides when needed.

### Comprehensive Documentation
Each annotation includes extensive dartdoc comments with:
- Overview of the annotation's purpose
- Multiple usage examples for different scenarios
- Parameter descriptions with examples
- Integration notes with SurrealDB syntax
- When to use guidance
This documentation-first approach ensures developers can use the annotations effectively without referring to implementation details.

### Future Enhancements
In subsequent task groups, the code generator will:
- Parse these annotations during build_runner execution
- Generate appropriate SurrealQL syntax based on annotation parameters
- Validate annotation usage (e.g., ensuring edge tables have correct structure)
- Create relationship loading logic based on annotation metadata
