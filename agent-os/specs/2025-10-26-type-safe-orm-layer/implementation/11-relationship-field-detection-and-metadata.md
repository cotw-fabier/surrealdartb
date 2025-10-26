# Task 11: Relationship Field Detection and Metadata

## Overview
**Task Reference:** Task #11 from `agent-os/specs/2025-10-26-type-safe-orm-layer/tasks.md`
**Implemented By:** database-engineer
**Date:** 2025-10-26
**Status:** ✅ Complete

### Task Description
Implement relationship field detection and metadata classes to support the ORM's relationship system. This includes detecting @SurrealRecord, @SurrealRelation, and @SurrealEdge annotations, creating metadata classes to store relationship information, and generating relationship registries in generated code.

## Implementation Summary
This task establishes the foundation for the ORM relationship system by creating metadata classes that represent different relationship types and implementing detection logic in the code generator to identify and extract relationship information from annotated fields. The implementation follows Dart 3.x patterns using sealed classes for exhaustive pattern matching and provides a clean separation of concerns by extracting relationship detection and code generation into separate utility classes.

The implementation creates a metadata hierarchy that can represent record links (direct references), graph relations (bidirectional traversal), and edge tables (many-to-many with metadata). These metadata classes are then used during code generation to create relationship registries and auto-include sets that will be used by the query builder in later phases.

## Files Changed/Created

### New Files
- `lib/src/orm/relationship_metadata.dart` - Core metadata classes representing relationship types using sealed class hierarchy
- `lib/generator/relationship_detector.dart` - Utility class for detecting and extracting relationship metadata from annotated fields
- `lib/generator/relationship_code_generator.dart` - Utility class for generating Dart code representing relationship registries
- `test/orm/relationship_metadata_test.dart` - Comprehensive tests for metadata classes with 10 test cases

### Modified Files
- `lib/generator/surreal_table_generator.dart` - Extended to detect relationships and generate relationship registries in entity extensions

## Key Implementation Details

### Relationship Metadata Classes
**Location:** `lib/src/orm/relationship_metadata.dart`

Created a sealed class hierarchy for type-safe relationship metadata:

```dart
sealed class RelationshipMetadata {
  final String fieldName;
  final String targetType;
  final bool isList;
  final bool isOptional;
}
```

Three concrete implementations:
1. **RecordLinkMetadata**: For @SurrealRecord annotations with optional explicit table names
2. **GraphRelationMetadata**: For @SurrealRelation annotations with relation name, direction, and optional target table
3. **EdgeTableMetadata**: For @SurrealEdge annotations with source/target fields and metadata fields

**Rationale:** Sealed classes enable exhaustive pattern matching in Dart 3.x, ensuring all relationship types are handled correctly during code generation and query building. The hierarchy provides a type-safe way to represent different relationship strategies.

### Relationship Detector
**Location:** `lib/generator/relationship_detector.dart`

Implemented `RelationshipDetector` class with static methods to extract relationship metadata from class elements:

- `extractRelationships()`: Scans all fields for relationship annotations
- `extractRecordLinkMetadata()`: Extracts @SurrealRecord annotation details
- `extractGraphRelationMetadata()`: Extracts @SurrealRelation annotation details
- `isListType()`: Determines if a field is a List relationship
- `extractTargetType()`: Extracts the target entity type from field types
- `getAutoIncludeFields()`: Identifies non-optional relationships for auto-inclusion

**Rationale:** Separating detection logic into a dedicated class improves maintainability and testability. The static methods can be easily tested in isolation and reused across different parts of the generator.

### Relationship Code Generator
**Location:** `lib/generator/relationship_code_generator.dart`

Implemented `RelationshipCodeGenerator` class for generating Dart code:

- `generateRelationshipRegistry()`: Generates static const Map with all relationship metadata
- `generateAutoIncludes()`: Generates static const Set with auto-include field names

Generated code example:
```dart
extension UserORM on User {
  static const relationshipMetadata = <String, Map<String, dynamic>>{
    'profile': {
      'type': 'RecordLink',
      'fieldName': 'profile',
      'targetType': 'Profile',
      'isList': false,
      'isOptional': true,
      'effectiveTableName': 'profile',
    },
  };

  static const autoIncludeRelations = <String>{
    'organization', // non-optional relationship
  };
}
```

**Rationale:** Keeping code generation logic separate from detection improves single responsibility principle. The generated metadata will be used at runtime by query builders to determine which relationships to load.

### Generator Integration
**Location:** `lib/generator/surreal_table_generator.dart`

Modified the generator to:
1. Import relationship utilities
2. Call `RelationshipDetector.extractRelationships()` after field extraction
3. Pass relationships to `_generateOrmExtension()`
4. Generate relationship registry and auto-includes in the entity extension

**Rationale:** Minimal changes to the existing generator maintain backward compatibility while adding new functionality. The relationship detection happens alongside field detection, keeping the generation flow consistent.

## Database Changes (if applicable)

No database schema changes were required for this task. This task focuses on metadata representation and code generation infrastructure.

## Dependencies (if applicable)

### New Dependencies Added
No new external dependencies were added. The implementation uses only existing packages:
- `analyzer` (already used for source_gen)
- `source_gen` (already used for code generation)

### Configuration Changes
No configuration changes required.

## Testing

### Test Files Created/Updated
- `test/orm/relationship_metadata_test.dart` - Created with 10 focused tests

### Test Coverage
- Unit tests: ✅ Complete (10 tests)
  - RecordLinkMetadata construction and effective table name inference (4 tests)
  - GraphRelationMetadata construction and wildcard target handling (3 tests)
  - EdgeTableMetadata construction with and without metadata fields (2 tests)
  - Pattern matching across all relationship types (1 test)
- Integration tests: ⚠️ None (not required for this task)
- Edge cases covered:
  - PascalCase to snake_case conversion for table names
  - Null/wildcard handling for optional parameters
  - Empty metadata fields list

### Manual Testing Performed
Ran tests using:
```bash
dart test test/orm/relationship_metadata_test.dart
```

All 10 tests passed successfully, verifying:
- Metadata classes construct correctly with all parameters
- Effective table name inference works for RecordLinkMetadata
- Wildcard target table defaulting works for GraphRelationMetadata
- Pattern matching correctly distinguishes between relationship types

## User Standards & Preferences Compliance

### tech-stack.md
**File Reference:** `agent-os/standards/global/tech-stack.md`

**How Implementation Complies:**
- Uses modern Dart 3.0+ features including sealed classes for RelationshipMetadata
- Leverages pattern matching via switch expressions in documentation examples
- Uses records and null safety throughout
- Integrates with existing build_runner workflow via source_gen
- No reflection used - all code generation based

**Deviations:** None

### coding-style.md
**File Reference:** `agent-os/standards/global/coding-style.md`

**How Implementation Complies:**
- All classes use PascalCase (RelationshipMetadata, RecordLinkMetadata, etc.)
- All methods and variables use camelCase (extractRelationships, fieldName, etc.)
- File names use snake_case (relationship_metadata.dart, relationship_detector.dart)
- Functions kept focused and under 20 lines where possible
- Used arrow functions for simple getters (get effectiveTableName => ...)
- All variables marked final unless reassignment needed
- Comprehensive dartdoc comments on all public APIs
- Type annotations provided for all public APIs

**Deviations:** None

### conventions.md
**File Reference:** `agent-os/standards/global/conventions.md`

**How Implementation Complies:**
- Files organized in proper package structure (lib/src/orm/, lib/generator/)
- Null safety used throughout with proper ? annotations
- Documentation-first approach with comprehensive dartdoc comments
- Clear API design with sealed classes for type safety
- Minimized dependencies (no new packages added)

**Deviations:** None

### error-handling.md
**File Reference:** `agent-os/standards/global/error-handling.md`

**How Implementation Complies:**
- No errors are silently ignored
- Generator throws `InvalidGenerationSourceError` for invalid annotations (will be used in future tasks)
- Clear error messages planned for validation failures
- Uses existing exception hierarchy

**Deviations:** None

### test-writing.md
**File Reference:** `agent-os/standards/testing/test-writing.md`

**How Implementation Complies:**
- Followed Arrange-Act-Assert pattern in all tests
- Descriptive test names that explain scenario and expected outcome
- Tests are independent with no shared state
- Fast unit tests that run in milliseconds
- Focused tests (2-8 tests as specified in task requirements, implemented 10)

**Deviations:** None

## Integration Points (if applicable)

### Internal Dependencies
- Integrates with existing `SurrealTableGenerator` class
- Uses annotation classes from `lib/src/schema/orm_annotations.dart`
- Will be used by query builder (Task Groups 6-7) and relationship loader (Task Groups 12-13)

## Known Issues & Limitations

### Issues
None identified at this time.

### Limitations
1. **Edge Table Detection Not Fully Implemented**
   - Description: While EdgeTableMetadata class is defined, the detector doesn't yet scan for @SurrealEdge class annotations
   - Reason: Edge tables require class-level annotation detection which is deferred to Task Group 13
   - Future Consideration: Will be completed in Task Group 13

## Performance Considerations
- Relationship detection happens during code generation (compile-time), so no runtime performance impact
- Generated metadata uses const Maps and Sets for zero runtime allocation
- Sealed class pattern matching is optimized by Dart compiler

## Security Considerations
No security-sensitive operations in this task. All code generation happens at compile time with trusted input.

## Dependencies for Other Tasks
- Task Group 12 depends on this implementation for RecordLinkMetadata
- Task Group 13 depends on this implementation for GraphRelationMetadata and EdgeTableMetadata
- Future query builder tasks will use the generated relationship registries

## Notes
- The implementation uses a pragmatic approach of storing metadata as Maps in generated code rather than generating full class instances. This simplifies the generated code and makes it easier to inspect relationship metadata at runtime.
- The sealed class hierarchy provides excellent type safety during code generation while the generated Map format provides flexibility for runtime use.
- Auto-include detection is implemented but will be fully utilized when the query builder is implemented in later task groups.
- The snake_case conversion for table names follows common database naming conventions and matches the pattern used elsewhere in the codebase.
