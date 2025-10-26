# Task 3: TableStructure Type System

## Overview
**Task Reference:** Task #3 from `agent-os/specs/2025-10-26-vector-data-types-storage/tasks.md`
**Implemented By:** database-engineer
**Date:** 2025-10-26
**Status:** Complete

### Task Description
Create a comprehensive SurrealDB type system for schema definitions using Dart 3 sealed classes. This includes all SurrealDB data types (scalar, collection, and special types) with support for vector embeddings across all formats (F32, F64, I8, I16, I32, I64).

## Implementation Summary
Implemented a complete type hierarchy using Dart 3's sealed class pattern to enable exhaustive pattern matching and type-safe schema definitions. The system provides a comprehensive representation of all SurrealDB data types including scalars (string, number, bool, datetime, duration), collections (array, object), and special types (record, geometry, vector, any).

The VectorType implementation supports all six vector formats (F32, F64, I8, I16, I32, I64) with dimensional constraints and normalization requirements, making it suitable for AI/ML workloads. The VectorFormat enum is imported from the existing vector_value.dart to maintain consistency across the codebase.

All types include comprehensive dartdoc documentation with usage examples and SurrealDB mappings. The system is designed for extensibility through sealed classes, ensuring that any future type additions will be caught by the compiler through exhaustive pattern matching.

## Files Changed/Created

### New Files
- `lib/src/schema/surreal_types.dart` - Complete SurrealDB type hierarchy with sealed classes for exhaustive pattern matching
- `lib/src/schema/schema.dart` - Barrel export file for schema-related types
- `test/schema/surreal_types_test.dart` - Comprehensive test suite with 35 tests covering all type variants

### Modified Files
- `lib/surrealdartb.dart` - Added exports for all schema types to public API (SurrealType, all type classes, FieldDefinition, enums)

### Deleted Files
None

## Key Implementation Details

### Sealed Class Hierarchy
**Location:** `lib/src/schema/surreal_types.dart`

Implemented a sealed base class `SurrealType` that all type classes extend. This enables Dart 3's exhaustive pattern matching, ensuring all type variants are handled in validation logic:

```dart
sealed class SurrealType {
  const SurrealType();
}
```

The sealed pattern provides compile-time safety by forcing switch expressions to handle all cases:

```dart
final typeName = switch (type) {
  StringType() => 'string',
  NumberType() => 'number',
  BoolType() => 'bool',
  DatetimeType() => 'datetime',
  DurationType() => 'duration',
  ArrayType() => 'array',
  ObjectType() => 'object',
  RecordType() => 'record',
  GeometryType() => 'geometry',
  VectorType() => 'vector',
  AnyType() => 'any',
};
```

**Rationale:** Sealed classes provide exhaustive checking at compile-time, preventing runtime errors from missing type handlers. This is critical for validation logic where all types must be handled.

### Scalar Types
**Location:** `lib/src/schema/surreal_types.dart` (lines 95-206)

Implemented five scalar type classes:
- `StringType` - UTF-8 text data
- `NumberType` - Numeric data with optional format constraint (integer, floating, decimal)
- `BoolType` - Boolean values
- `DatetimeType` - Temporal data with nanosecond precision
- `DurationType` - Time spans

The `NumberType` includes an optional `NumberFormat` enum parameter to constrain the numeric representation, allowing schemas to specify whether values must be integers, floating-point, or decimals.

**Rationale:** Scalar types follow the principle of least surprise, mapping directly to SurrealDB's scalar types. The NumberFormat constraint enables more precise schema definitions for financial and scientific applications.

### Collection Types
**Location:** `lib/src/schema/surreal_types.dart` (lines 212-282)

Implemented two collection type classes:

1. `ArrayType` - Ordered collections with element type constraints and optional fixed-length validation
   ```dart
   class ArrayType extends SurrealType {
     const ArrayType(this.elementType, {this.length});
     final SurrealType elementType;
     final int? length;
   }
   ```

2. `ObjectType` - Key-value structures with optional schema definitions
   ```dart
   class ObjectType extends SurrealType {
     const ObjectType({this.schema});
     final Map<String, FieldDefinition>? schema;
   }
   ```

**Rationale:** Collection types support both schemaless and schema-defined use cases. Arrays can specify element types and optionally enforce fixed lengths (useful for coordinates, RGB values). Objects can be completely schemaless or have strict field definitions through recursive schema composition.

### Special Types
**Location:** `lib/src/schema/surreal_types.dart` (lines 288-527)

Implemented four special type classes:

1. `RecordType` - References to database records with optional table constraints
2. `GeometryType` - Geospatial data with optional geometry kind (point, line, polygon, etc.)
3. `VectorType` - AI/ML embeddings with comprehensive format support (detailed below)
4. `AnyType` - Dynamic fields without type constraints

The GeometryType supports all seven GeoJSON geometry kinds through the `GeometryKind` enum (point, line, polygon, multipoint, multiline, multipolygon, collection).

**Rationale:** Special types handle domain-specific use cases. RecordType enables foreign key relationships, GeometryType supports GIS applications, VectorType enables AI/ML workloads, and AnyType provides an escape hatch for truly dynamic data.

### VectorType Implementation
**Location:** `lib/src/schema/surreal_types.dart` (lines 385-511)

Implemented comprehensive vector type support with:
- All six vector formats via imported `VectorFormat` enum (f32, f64, i8, i16, i32, i64)
- Named constructors for each format (`VectorType.f32`, `VectorType.f64`, etc.)
- Dimensional constraints (must be positive integer)
- Normalization requirements (boolean flag)

```dart
class VectorType extends SurrealType {
  const VectorType({
    required this.format,
    required this.dimensions,
    this.normalized = false,
  }) : assert(dimensions > 0, 'Vector dimensions must be positive');

  // Named constructors for convenience
  const VectorType.f32(this.dimensions, {this.normalized = false})
      : format = VectorFormat.f32,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  final VectorFormat format;
  final int dimensions;
  final bool normalized;
}
```

**Rationale:** Supporting all vector formats enables use cases from high-precision scientific computing (F64) to memory-efficient quantized embeddings (I8, I16). The normalization flag allows schemas to require unit vectors for cosine similarity optimizations. Named constructors provide ergonomic API while maintaining type safety.

### FieldDefinition
**Location:** `lib/src/schema/surreal_types.dart` (lines 533-586)

Implemented field definition class that combines type constraints with field metadata:

```dart
class FieldDefinition {
  const FieldDefinition(
    this.type, {
    this.optional = false,
    this.defaultValue,
  });

  final SurrealType type;
  final bool optional;
  final dynamic defaultValue;
}
```

**Rationale:** FieldDefinition separates type constraints from field requirements. This enables schemas to specify whether fields are required/optional and provide default values, matching SurrealDB's schema definition capabilities.

### Enums
**Location:** `lib/src/schema/surreal_types.dart` (lines 146-165, 348-383)

Created two enum types:

1. `NumberFormat` - Numeric format constraints (integer, floating, decimal)
2. `GeometryKind` - Geometry type constraints (7 GeoJSON variants)

The VectorFormat enum is imported from `vector_value.dart` to maintain consistency with the VectorValue implementation.

**Rationale:** Enums provide type-safe constraints with clear documentation. Using the existing VectorFormat enum prevents duplication and ensures consistency between type definitions and value implementations.

## Database Changes
No database migrations required - this is a pure Dart implementation for client-side schema definitions and validation.

## Dependencies

### New Dependencies Added
None - implementation uses only Dart standard library

### Configuration Changes
None

## Testing

### Test Files Created/Updated
- `test/schema/surreal_types_test.dart` - Created comprehensive test suite with 35 tests

### Test Coverage
- Unit tests: Complete (35 tests covering all type variants)
- Integration tests: Not applicable (pure type system)
- Edge cases covered:
  - All scalar types instantiation
  - Number type with all format variations
  - Array types with element types and fixed-length constraints
  - Nested array types (arrays of arrays)
  - Object types with and without schemas
  - Record types with and without table constraints
  - Geometry types with all geometry kinds
  - Vector types with all six formats
  - Vector types with normalization requirements
  - Field definitions with required/optional flags and default values
  - Complex nested schemas (documents table example)
  - Exhaustive pattern matching using switch expressions

### Manual Testing Performed
Verified exhaustive pattern matching compiles correctly by implementing a switch expression that handles all 11 type variants. The compiler successfully enforces that all cases are handled, demonstrating the sealed class pattern works as intended.

## User Standards & Preferences Compliance

### coding-style.md
**File Reference:** `agent-os/standards/global/coding-style.md`

**How Implementation Complies:**
All code follows Effective Dart guidelines with PascalCase for classes/enums, sealed class pattern for type hierarchy, const constructors for immutable types, comprehensive dartdoc with examples, and exhaustive switch expressions. Line length kept under 80 characters, arrow syntax used for simple getters, and all types marked final by default.

**Deviations:** None

### conventions.md
**File Reference:** `agent-os/standards/global/conventions.md`

**How Implementation Complies:**
Package structure follows standard Dart layout with implementation in `lib/src/schema/` and barrel export through `schema.dart`. All code is soundly null-safe with explicit type annotations. Comprehensive dartdoc provided before considering implementation complete. Sealed class pattern enables compile-time exhaustiveness checking.

**Deviations:** None

### error-handling.md
**File Reference:** `agent-os/standards/global/error-handling.md`

**How Implementation Complies:**
VectorType constructors include assertion checks for positive dimensions with clear error messages. No exceptions thrown in this pure type system implementation - validation logic will be added in Task Group 4.

**Deviations:** None

### validation.md
**File Reference:** `agent-os/standards/global/validation.md`

**How Implementation Complies:**
Type system provides foundation for validation at FFI boundary. VectorType validates dimension constraints through assertions. FieldDefinition structure prepared for validation logic that will check non-null requirements, range validation, and type validation in Task Group 4.

**Deviations:** None

### test-writing.md
**File Reference:** `agent-os/standards/testing/test-writing.md`

**How Implementation Complies:**
Tests follow Arrange-Act-Assert pattern with descriptive names. Test independence maintained (no shared state). Tests organized into logical groups (Scalar Types, Collection Types, Special Types, VectorType, FieldDefinition, Type System Integration). Each test has clear scenario and expected outcome in test name.

**Deviations:** None

## Integration Points

### APIs/Endpoints
Not applicable - this is a pure Dart type system with no API integration

### External Services
None

### Internal Dependencies
- Imports `VectorFormat` from `lib/src/types/vector_value.dart` to maintain consistency between type definitions and value implementations
- Exported through `lib/surrealdartb.dart` public API for application usage
- Will be used by Task Group 4 (TableStructure validation logic) and Task Group 5 (Database integration)

## Known Issues & Limitations

### Issues
None identified

### Limitations
1. **No Runtime Validation**
   - Description: Type system provides structure but not validation logic
   - Reason: Validation logic is intentionally deferred to Task Group 4
   - Future Consideration: Task Group 4 will implement validation methods that use this type system

2. **Default Value Type Checking**
   - Description: FieldDefinition accepts dynamic defaultValue without compile-time type checking
   - Reason: Dart's type system cannot enforce that defaultValue matches SurrealType at compile time
   - Future Consideration: Task Group 4 validation logic will check defaultValue types at runtime

## Performance Considerations
All types use const constructors and are immutable, enabling compile-time const evaluation and eliminating runtime allocation overhead. Sealed class pattern has zero runtime cost - exhaustiveness checking is purely compile-time. Type hierarchy is shallow (max 2 levels) preventing performance issues from deep inheritance chains.

## Security Considerations
No security implications - this is a pure type system for schema definitions. Validation logic in Task Group 4 will use this type system to prevent invalid data from reaching the FFI boundary.

## Dependencies for Other Tasks
- **Task Group 4:** TableStructure validation logic will use this type system to validate data against schema definitions
- **Task Group 5:** Database integration will expose TableStructure with this type system in CRUD method signatures
- **Task Group 6:** Testing engineer will write additional tests for edge cases and integration scenarios

## Notes

### Design Decisions
1. **Sealed Classes:** Chosen for compile-time exhaustiveness checking, preventing runtime errors from missing type handlers in validation logic
2. **Imported VectorFormat:** Reused existing enum from vector_value.dart to maintain consistency and avoid duplication
3. **Const Constructors:** All types are immutable with const constructors, enabling compile-time const evaluation
4. **Optional Constraints:** Many types include optional constraint parameters (NumberFormat, GeometryKind, array length) to support both loose and strict schema definitions
5. **Comprehensive Dartdoc:** Every type includes detailed documentation with SurrealDB mappings and usage examples to serve as both API documentation and developer guide

### Future Enhancements
- SurrealQL schema generation (`toSurrealQL()` method) will be added in Task Group 4
- Runtime validation logic will be implemented in Task Group 4 using this type system
- TableStructure class will compose these types into complete table schemas in Task Group 4

### Observations
The sealed class pattern proved highly effective for this use case. The compiler catches missing cases in switch expressions, providing strong guarantees that validation logic will handle all types. The type system strikes a good balance between flexibility (optional constraints) and strictness (compile-time exhaustiveness checking).

The decision to import VectorFormat from vector_value.dart rather than duplicating it prevents inconsistencies and follows DRY principles. This also ensures that VectorType definitions and VectorValue implementations always use the same format enumeration.

Test coverage is comprehensive with 35 tests covering all type variants, nested compositions, and integration scenarios. The exhaustive pattern matching test demonstrates that the sealed class implementation works correctly.
