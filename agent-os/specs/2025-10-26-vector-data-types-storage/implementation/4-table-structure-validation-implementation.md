# Task 4: TableStructure Validation & Schema Definition

## Overview
**Task Reference:** Task #4 from `agent-os/specs/2025-10-26-vector-data-types-storage/tasks.md`
**Implemented By:** database-engineer
**Date:** 2025-10-26
**Status:** ✅ Complete

### Task Description
This task implements TableStructure validation and schema definition capabilities, providing a Dart-side validation layer that works alongside SurrealDB's schema validation. The implementation enables developers to define table schemas with field definitions, validate data before sending to the database, and generate SurrealQL DDL statements.

## Implementation Summary

The TableStructure implementation provides a comprehensive validation framework that:
- Validates required and optional fields before database operations
- Performs vector-specific validation (dimensions, normalization, format matching)
- Supports nested object schema validation with recursive field checking
- Provides clear, actionable error messages through ValidationException
- Generates experimental SurrealQL schema definitions
- Offers helper methods for introspecting schema structure

The implementation follows the dual validation strategy (Option C from the spec): Dart-side validation occurs when a TableStructure is provided, while SurrealDB validation remains as a fallback. This approach provides faster feedback to developers and reduces unnecessary database roundtrips for invalid data.

## Files Changed/Created

### New Files
- `lib/src/schema/table_structure.dart` - TableStructure class with validation logic for all SurrealDB types
- `test/schema/table_structure_test.dart` - Comprehensive test suite covering 30 test cases for validation scenarios

### Modified Files
- `lib/src/exceptions.dart` - Added ValidationException class extending DatabaseException with field-level error details
- `lib/src/schema/schema.dart` - Updated barrel export to include TableStructure
- `lib/surrealdartb.dart` - Added TableStructure and ValidationException to public API exports

## Key Implementation Details

### ValidationException Class
**Location:** `lib/src/exceptions.dart`

Created a new ValidationException that extends DatabaseException to provide field-level validation error details. The exception includes:
- `fieldName`: Identifies which field failed validation
- `constraint`: Describes what constraint was violated (e.g., 'required', 'dimension_mismatch', 'not_normalized')
- Clear toString() implementation for debugging

**Rationale:** Distinguishing Dart-side validation errors from SurrealDB errors helps developers quickly identify where to fix issues. The field-level details make it easy to pinpoint exactly what needs to be corrected.

### TableStructure Class
**Location:** `lib/src/schema/table_structure.dart`

Implemented a comprehensive TableStructure class that:
- Validates table names as valid identifiers (alphanumeric and underscore)
- Stores field definitions in a Map for efficient lookups
- Provides a main validate() method that checks all fields
- Uses pattern matching on sealed SurrealType classes for type-specific validation

**Rationale:** The pattern matching approach leverages Dart 3's sealed classes for compile-time exhaustiveness checking, ensuring all type variants are handled. This makes the validation logic maintainable and extensible.

### Vector-Specific Validation
**Location:** `lib/src/schema/table_structure.dart` (_validateVectorField method)

Vector validation performs multiple checks:
1. Converts the value to VectorValue (supports both List and VectorValue inputs)
2. Validates dimensions match the schema definition
3. Checks normalization requirement if specified
4. Verifies format matches (F32, F64, I8, I16, I32, I64)

Each validation failure throws a ValidationException with specific details about what was expected vs. what was provided.

**Rationale:** Vector fields have unique constraints (dimensions, normalization, format) that aren't applicable to other types. Dedicated validation ensures these constraints are enforced early, before expensive database operations.

### Type-Specific Validation Helpers
**Location:** `lib/src/schema/table_structure.dart` (_validateField and related methods)

Implemented private validation methods for each SurrealType variant:
- `_validateStringField` - Checks value is a String
- `_validateNumberField` - Checks value is num, validates format if specified
- `_validateBoolField` - Checks value is bool
- `_validateDatetimeField` - Checks value is DateTime or valid ISO 8601 string
- `_validateDurationField` - Checks value is Duration or duration string
- `_validateArrayField` - Validates element types and optional length constraint
- `_validateObjectField` - Recursively validates nested schemas
- `_validateRecordField` - Validates record ID format and table constraint
- `_validateGeometryField` - Basic GeoJSON structure validation

**Rationale:** Separating validation logic by type keeps the code organized and maintainable. Each method focuses on a single responsibility and throws clear exceptions on failure.

### Nested Object Schema Validation
**Location:** `lib/src/schema/table_structure.dart` (_validateObjectField method)

Object validation supports both schemaless and schema-defined objects:
- When schema is null, accepts any Map
- When schema is defined, recursively validates nested fields
- Uses dot notation for field names in nested errors (e.g., 'address.city')

**Rationale:** Nested validation enables complex schema definitions while maintaining clear error paths. The dot notation in field names makes it immediately obvious which nested field failed validation.

### SurrealQL Schema Generation
**Location:** `lib/src/schema/table_structure.dart` (toSurrealQL method)

Implemented experimental SurrealQL DDL generation that:
- Creates DEFINE TABLE statement with SCHEMAFULL
- Generates DEFINE FIELD for each field with type mapping
- Adds ASSERT constraints for required fields
- Handles vector types with dimension specifications

**Rationale:** This feature bridges Dart schema definitions to SurrealDB DDL, enabling schema migration and documentation. Marked as experimental since SurrealQL syntax may have edge cases not yet covered.

### Helper Methods
**Location:** `lib/src/schema/table_structure.dart`

Implemented utility methods for schema introspection:
- `hasField(String fieldName)` - Check if field exists
- `getField(String fieldName)` - Retrieve field definition
- `getRequiredFields()` - List all required fields
- `getOptionalFields()` - List all optional fields

**Rationale:** These helpers enable dynamic schema inspection and validation of partial data updates, common patterns in database applications.

## Database Changes (if applicable)

No database migrations required. This is purely Dart-side validation logic that works with existing database infrastructure.

## Dependencies (if applicable)

### Internal Dependencies
- `lib/src/schema/surreal_types.dart` - Uses the SurrealType sealed class hierarchy
- `lib/src/types/vector_value.dart` - Uses VectorValue for vector validation
- `lib/src/exceptions.dart` - Extends DatabaseException for ValidationException

## Testing

### Test Files Created/Updated
- `test/schema/table_structure_test.dart` - Comprehensive validation test suite

### Test Coverage
- Unit tests: ✅ Complete (30 tests covering all major scenarios)
- Integration tests: N/A (Integration with Database class in Task Group 5)
- Edge cases covered:
  - Required field validation
  - Optional field handling
  - Vector dimension validation
  - Vector normalization validation
  - Nested object schema validation
  - Type mismatch error messages
  - Helper method functionality
  - SurrealQL generation
  - Table name validation

### Manual Testing Performed
Ran all TableStructure tests to verify:
- All 30 tests pass successfully
- ValidationException provides clear, actionable error messages
- Vector validation catches dimension mismatches with expected vs. actual values
- Nested object validation properly validates required fields at all levels
- Helper methods return correct field lists

## User Standards & Preferences Compliance

### global/coding-style.md
**File Reference:** `agent-os/standards/global/coding-style.md`

**How Implementation Complies:**
The TableStructure class follows Dart coding conventions with clear method names, proper dartdoc comments with examples, and consistent formatting. Pattern matching on sealed classes provides type-safe validation logic. Private methods use underscore prefixes (_validateField, _validateVectorField, etc.) following Dart conventions.

**Deviations:** None

### global/error-handling.md
**File Reference:** `agent-os/standards/global/error-handling.md`

**How Implementation Complies:**
Created ValidationException extending DatabaseException to provide specific validation error context. Error messages include field names, constraints, and expected vs. actual values. Each validation failure throws immediately with actionable error information, following the fail-fast principle.

**Deviations:** None

### global/validation.md
**File Reference:** `agent-os/standards/global/validation.md`

**How Implementation Complies:**
Implemented comprehensive Dart-side validation that validates type correctness, required fields, vector dimensions, normalization, and nested schemas. Validation occurs before database operations to provide fast feedback. Clear error messages distinguish validation failures from database errors.

**Deviations:** None

### global/commenting.md
**File Reference:** `agent-os/standards/global/commenting.md`

**How Implementation Complies:**
Every public method has complete dartdoc with description, parameter documentation, usage examples, and exception documentation. Complex validation logic includes inline comments explaining the validation strategy. Examples in dartdoc demonstrate real-world usage patterns.

**Deviations:** None

### testing/test-writing.md
**File Reference:** `agent-os/standards/testing/test-writing.md`

**How Implementation Complies:**
Tests follow AAA (Arrange-Act-Assert) pattern with clear test names describing what is being tested. Each test focuses on a single validation scenario. Test groups organize related tests (Construction, Required Fields, Optional Fields, etc.). All tests use proper matchers with specific assertions.

**Deviations:** None

## Integration Points (if applicable)

### APIs/Endpoints
- None - This is a validation library used by Database class (Task Group 5)

### Internal Dependencies
- Used by Database class (Task Group 5) for optional Dart-side validation
- Validates data before FFI calls to provide fast feedback
- Works alongside SurrealDB's schema validation as fallback

## Known Issues & Limitations

### Limitations
1. **SurrealQL Generation Experimental**
   - Description: toSurrealQL() may not cover all SurrealDB DDL syntax edge cases
   - Reason: Marked as experimental due to potential SurrealDB syntax complexity
   - Future Consideration: Expand based on community feedback and real-world usage

2. **NumberType Format Validation**
   - Description: Decimal format validation accepts any num type (not a true Decimal type)
   - Reason: Dart doesn't have a built-in Decimal type
   - Future Consideration: Could integrate with a decimal library for precise validation

3. **Geometry Validation Basic**
   - Description: GeometryType validation only checks for 'type' and 'coordinates' keys
   - Reason: Full GeoJSON validation would require substantial additional complexity
   - Future Consideration: Add comprehensive GeoJSON schema validation if needed

## Performance Considerations

Validation is performed in-memory with minimal overhead:
- Field lookups use Map for O(1) access
- Pattern matching compiles to efficient switch statements
- Vector validation uses existing VectorValue methods
- Recursive object validation depth is bounded by schema complexity

For most use cases, validation overhead is negligible compared to network I/O and database operations. The benefit of catching errors early outweighs the minimal CPU cost.

## Security Considerations

- Table name validation prevents injection attacks by enforcing alphanumeric+underscore identifiers
- No dynamic code execution or eval() usage
- All validation logic is deterministic and side-effect free
- Error messages don't leak sensitive data, only schema structure

## Dependencies for Other Tasks

- Task Group 5 depends on this implementation for Database class integration
- ValidationException is used by Task Group 5 to distinguish validation errors
- Future tasks can extend validation logic for custom types

## Notes

The TableStructure implementation successfully provides the foundation for Dart-side validation as specified in the dual validation strategy (Option C). The comprehensive test coverage (30 tests) verifies all major validation scenarios work correctly.

Key achievements:
- Type-safe validation using sealed classes and pattern matching
- Clear error messages with field-level details for fast debugging
- Support for complex nested schemas with recursive validation
- Vector-specific validation for dimensions, normalization, and format
- Experimental SurrealQL generation for schema migration support
- Intuitive API with helper methods for common operations

The implementation is ready for integration with the Database class in Task Group 5, where it will provide optional validation before database operations.
