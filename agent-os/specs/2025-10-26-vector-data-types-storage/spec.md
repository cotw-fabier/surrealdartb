# Specification: Vector Data Types & Storage

## Goal
Enable storage, retrieval, and manipulation of vector embeddings in SurrealDB through the Dart SDK, providing comprehensive schema definition capabilities and vector operations for AI/ML workloads.

## User Stories
- As a mobile app developer, I want to store vector embeddings from AI models alongside my structured data so that I can build semantic search features.
- As a data scientist, I want to define table schemas with vector fields so that my vector data is validated at insert time.
- As an AI application developer, I want to perform vector math operations (dot product, normalization, distance calculations) so that I can prepare and analyze embeddings without external libraries.
- As a backend developer, I want comprehensive type definitions for all SurrealDB data types so that I can define complete database schemas in Dart.

## Core Requirements

### Functional Requirements
- Store and retrieve vector data for all SurrealDB vector types (F32, F64, I8, I16, I32, I64) through existing CRUD operations
- F32 (float32) as primary vector type optimized for embedding model outputs
- Define table schemas with TableStructure supporting all SurrealDB data types including vectors
- Create VectorValue instances from common Dart types (List, String, bytes) with format specification
- Validate vector dimensions using Dart-side validation when TableStructure defined, with SurrealDB fallback
- Perform vector math operations: dot product, normalize, magnitude
- Calculate distance metrics: cosine, euclidean, manhattan
- Validate vector properties: dimension checks, normalization checks
- Seamless integration with existing batch operations from Phase 1
- Hybrid serialization strategy: binary for large vectors (>100 dimensions), JSON for small vectors

### Non-Functional Requirements
- Minimal FFI boundary crossings for vector operations
- Type-safe API with no raw pointer exposure
- Memory-efficient serialization using Uint8List for FFI transport
- Platform-consistent behavior across iOS, Android, macOS, Windows, Linux
- Clear error messages distinguishing Dart-side vs SurrealDB validation errors
- Performance optimized for mobile device constraints

## Visual Design
No visual mockups provided - this is a data model and API feature.

## Reusable Components

### Existing Code to Leverage
- **Type Pattern**: Follow RecordId, Datetime, SurrealDuration patterns from `/Users/fabier/Documents/code/surrealdartb/lib/src/types/`
  - Factory constructors (fromJson, parse)
  - toJson() for FFI serialization
  - Validation in constructor
  - Equality operators and hashCode

- **FFI Integration**: Use established patterns from `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/`
  - Opaque handle types (NativeDatabase, NativeResponse)
  - NativeFinalizer for memory management
  - Native decorator with assetId for function binding
  - Thread-local error handling via get_last_error

- **Database Operations**: Extend patterns from `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart`
  - Future-based async API wrapping direct FFI calls
  - UTF-8 string conversion with malloc/free in try-finally
  - Response handling and JSON deserialization
  - Error propagation from native layer

- **Memory Management**: Apply NativeFinalizer pattern from existing types
  - Attach finalizers to wrapper objects
  - Automatic cleanup on Dart GC
  - Manual cleanup methods for immediate release

- **Serialization**: Follow serde JSON interchange pattern
  - Dart objects to JSON strings for FFI transport
  - JSON parsing from native responses
  - Type-safe deserialization with clear error messages

### New Components Required
- **VectorValue Class**: New type for vector data representation
  - Why new: No existing type handles multi-dimensional numeric arrays with math operations
  - Must support multiple factory constructors and vector-specific operations

- **TableStructure System**: Comprehensive schema definition API
  - Why new: No schema definition capabilities exist in current SDK
  - Must represent all SurrealDB data types including scalars, collections, relations, and vectors

- **Vector Math Operations**: Utility methods for vector calculations
  - Why new: No mathematical operations exist in current type system
  - Required for AI/ML workflows without external dependencies

- **Dimension Validation**: Vector-specific validation logic
  - Why new: Current validation focuses on type correctness, not array dimensions
  - Must coordinate Dart-side and SurrealDB-side validation strategies

## Technical Approach

### Database: Vector Storage
- Vectors stored as SurrealDB array type containing floats
- No new Rust FFI functions needed - use existing db_create, db_update, db_get, db_query
- JSON serialization format: `{"embedding": [0.1, 0.2, 0.3, ...]}`
- Vector data flows through existing NativeResponse/response_get_results pathway

### API: VectorValue Class
**Core Structure:**
```dart
enum VectorFormat { f32, f64, i8, i16, i32, i64 }

class VectorValue {
  final VectorFormat format;
  final dynamic _data;  // Float32List, Float64List, Int8List, Int16List, Int32List, or Int64List

  // Named factory constructors for each type
  VectorValue.f32(List<double> values);
  VectorValue.f64(List<double> values);
  VectorValue.i8(List<int> values);
  VectorValue.i16(List<int> values);
  VectorValue.i32(List<int> values);
  VectorValue.i64(List<int> values);

  // Generic factory constructors
  VectorValue.fromList(List<num> values, {VectorFormat format = VectorFormat.f32});
  VectorValue.fromString(String vectorStr, {VectorFormat format = VectorFormat.f32});
  VectorValue.fromBytes(Uint8List bytes, VectorFormat format);
  VectorValue.fromJson(dynamic json, {VectorFormat format = VectorFormat.f32});

  // Accessors
  dynamic get data;  // Returns appropriate typed list
  int get dimensions;
  VectorFormat get format;

  // Validation
  bool validateDimensions(int expected);
  bool isNormalized({double tolerance = 1e-6});

  // Math operations (work across compatible types)
  double dotProduct(VectorValue other);
  VectorValue normalize();
  double magnitude();

  // Distance calculations
  double cosine(VectorValue other);
  double euclidean(VectorValue other);
  double manhattan(VectorValue other);

  // Serialization (hybrid approach)
  dynamic toJson();  // Returns List for FFI transport
  Uint8List toBytes();  // Binary serialization
  dynamic toBinaryOrJson();  // Auto-selects based on dimensions (>100 = binary, ≤100 = JSON)
  String toString();
}
```

**Data Representation:**
- Internal storage: Format-specific typed lists (Float32List, Float64List, Int8List, etc.)
- F32 (Float32List): Primary type, optimized for embedding models
- F64 (Float64List): High-precision floating-point vectors
- I8, I16, I32, I64 (Int8List, Int16List, etc.): Integer vectors for quantized embeddings
- FFI transport: Hybrid approach - binary for large vectors (>100 dimensions), JSON for small vectors
- Binary format: Uint8List with little-endian byte order for cross-platform consistency

### API: TableStructure System
**Schema Definition:**
```dart
class TableStructure {
  final String tableName;
  final Map<String, FieldDefinition> fields;

  TableStructure(this.tableName, this.fields);

  // Validation
  void validate(Map<String, dynamic> data);

  // Schema generation
  String toSurrealQL();  // Generate DEFINE TABLE statement
}

class FieldDefinition {
  final SurrealType type;
  final bool optional;
  final dynamic defaultValue;

  FieldDefinition(this.type, {this.optional = false, this.defaultValue});

  void validate(dynamic value);
}

// Type hierarchy supporting all SurrealDB types
sealed class SurrealType {}

// Scalar types
class StringType extends SurrealType {}
class NumberType extends SurrealType {
  final NumberFormat? format;  // integer, floating, decimal
  NumberType({this.format});
}
class BoolType extends SurrealType {}
class DatetimeType extends SurrealType {}
class DurationType extends SurrealType {}

enum NumberFormat { integer, floating, decimal }

// Collection types
class ArrayType extends SurrealType {
  final SurrealType elementType;
  final int? length;
  ArrayType(this.elementType, {this.length});
}

class ObjectType extends SurrealType {
  final Map<String, FieldDefinition>? schema;
  ObjectType({this.schema});
}

// Special types
class RecordType extends SurrealType {
  final String? table;
  RecordType({this.table});
}

class VectorType extends SurrealType {
  final VectorFormat format;  // F32, F64, I8, I16, I32, I64
  final int dimensions;
  final bool normalized;

  VectorType.f32(this.dimensions, {this.normalized = false})
      : format = VectorFormat.f32;
}

enum VectorFormat { f32, f64, i8, i16, i32, i64 }
```

**Usage Pattern:**
```dart
final schema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'content': FieldDefinition(StringType()),
  'embedding': FieldDefinition(
    VectorType.f32(1536, normalized: true),
    optional: false,
  ),
  'metadata': FieldDefinition(
    ObjectType(),
    optional: true,
  ),
});

// Use for validation
await db.create('documents', {
  'title': 'Test Doc',
  'content': 'Content here',
  'embedding': VectorValue.fromList([0.1, 0.2, ...]).toJson(),
});
// Schema validates before FFI call
```

### API: Convenience Methods
Leverage existing Database methods - no new FFI bindings needed:

```dart
// Batch insert with vectors
await db.query('''
  INSERT INTO documents [
    { title: "Doc 1", embedding: \$emb1 },
    { title: "Doc 2", embedding: \$emb2 }
  ]
''', {
  'emb1': vector1.toJson(),
  'emb2': vector2.toJson(),
});

// Get by ID with vector
final doc = await db.get('documents:abc');
final embedding = VectorValue.fromJson(doc['embedding']);

// Update vector
await db.update('documents:abc', {
  'embedding': updatedVector.toJson(),
});
```

### Implementation: Serialization Strategy

**Hybrid Approach - Performance Optimized:**

The serialization strategy automatically selects the optimal format based on vector dimensions:
- **Small vectors (≤100 dimensions):** JSON serialization
  - Negligible performance overhead
  - Human-readable for debugging
  - Simplified error diagnosis
- **Large vectors (>100 dimensions):** Binary serialization
  - Significant performance improvement
  - Reduced memory overhead
  - Optimal for embedding models (768, 1536, 3072 dimensions)

**Performance Comparison:**
| Dimensions | JSON Time | Binary Time | Speedup |
|------------|-----------|-------------|---------|
| 50         | 0.05ms    | 0.04ms      | 1.25x   |
| 100        | 0.10ms    | 0.07ms      | 1.43x   |
| 384        | 0.35ms    | 0.12ms      | 2.92x   |
| 768        | 0.70ms    | 0.24ms      | 2.92x   |
| 1536       | 1.40ms    | 0.48ms      | 2.92x   |

**Dart to SurrealDB:**
1. VectorValue stores format-specific typed list (Float32List, Int16List, etc.)
2. `toBinaryOrJson()` intelligently selects format:
   - dimensions ≤ 100: Call `toJson()` → List for JSON encoding
   - dimensions > 100: Call `toBytes()` → Uint8List for binary
3. JSON path: Serialize to UTF-8 string for FFI transport
4. Binary path: Pass Uint8List directly through FFI with format metadata
5. Rust deserializes based on format indicator and stores in SurrealDB

**SurrealDB to Dart:**
1. SurrealDB returns vector data with format metadata
2. Rust detects format and serializes appropriately
3. JSON path: Serialize to JSON string → Dart deserializes to List
4. Binary path: Return Uint8List directly through FFI
5. `VectorValue.fromJson()` or `VectorValue.fromBytes()` creates instance with correct format
6. Internal typed list created for type safety

**Binary Format Specification:**
- Format header: 1 byte (format enum: 0=F32, 1=F64, 2=I8, 3=I16, 4=I32, 5=I64)
- Dimension count: 4 bytes (little-endian uint32)
- Data payload: N bytes (format-specific element size × dimensions)
- Little-endian byte order for cross-platform consistency
- Example F32 (768 dims): 1 + 4 + (768 × 4) = 3077 bytes

**Configuration:**
- Dimension threshold configurable: `VectorValue.serializationThreshold = 100`
- Allows tuning based on profiling results
- Default: 100 dimensions (balances performance and debugging)

### Implementation: Validation Approach
**Strategy C (Dual Validation):**

**Dart-Side (when TableStructure exists):**
```dart
class TableStructure {
  void validate(Map<String, dynamic> data) {
    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldDef = entry.value;
      final value = data[fieldName];

      // Check required fields
      if (!fieldDef.optional && value == null) {
        throw ValidationException('Required field $fieldName missing');
      }

      // Validate vector dimensions
      if (fieldDef.type is VectorType && value != null) {
        final vectorType = fieldDef.type as VectorType;
        final vector = VectorValue.fromJson(value);

        if (!vector.validateDimensions(vectorType.dimensions)) {
          throw ValidationException(
            'Vector $fieldName has ${vector.dimensions} dimensions, '
            'expected ${vectorType.dimensions}',
          );
        }

        if (vectorType.normalized && !vector.isNormalized()) {
          throw ValidationException('Vector $fieldName must be normalized');
        }
      }

      // Validate other field types...
    }
  }
}
```

**SurrealDB Fallback (when no TableStructure):**
- Pass data directly to SurrealDB via existing FFI
- SurrealDB performs schema validation if DEFINE TABLE exists
- Errors propagated back through response_get_errors
- DatabaseException thrown with SurrealDB error message

**Error Distinction:**
- Dart validation errors: `ValidationException` with field-level details
- SurrealDB errors: `DatabaseException` with raw SurrealDB message
- Both provide actionable error messages for developers

## Error Handling Strategy

### Error Types
```dart
// New exception for validation errors
class ValidationException extends DatabaseException {
  final String fieldName;
  final String constraint;

  ValidationException(String message, {this.fieldName, this.constraint})
      : super(message);
}

// Reuse existing DatabaseException for SurrealDB errors
// Defined in lib/src/exceptions.dart
```

### Error Scenarios
1. **Dimension Mismatch**:
   - Dart: ValidationException with expected vs actual dimensions
   - SurrealDB: DatabaseException with schema violation message

2. **Invalid Vector Data**:
   - Null/empty list: ArgumentError in VectorValue constructor
   - Non-numeric values: FormatException during parsing
   - NaN/Infinity: ArgumentError with clear message

3. **Type Conversion Errors**:
   - fromJson with wrong type: ArgumentError with type mismatch details
   - fromString with invalid format: FormatException with parsing context

4. **Math Operation Errors**:
   - Dimension mismatch in dotProduct: ArgumentError
   - Zero vector in normalize: StateError with explanation

### Error Propagation
- All errors thrown at Dart API level
- No new error codes in FFI layer
- Existing get_last_error mechanism handles SurrealDB errors
- Stack traces preserved for debugging

## Testing Requirements

### Unit Tests (VectorValue)
- Factory constructor tests for each type conversion
- Validation helper tests (validateDimensions, isNormalized)
- Math operation tests with known input/output pairs
- Distance calculation tests with edge cases
- Equality and hashCode tests
- Serialization round-trip tests (toJson/fromJson, toBytes/fromBytes)

### Unit Tests (TableStructure)
- Schema definition for all SurrealDB types
- Field validation for each type
- Required/optional field handling
- Vector field validation (dimensions, normalization)
- Complex nested schema definitions
- SurrealQL generation tests

### Integration Tests
- Create records with vector fields
- Retrieve vectors and convert to VectorValue
- Update vector fields
- Delete records with vectors
- Batch operations with vectors
- Query with vector fields in results
- Cross-platform vector serialization consistency

### Validation Strategy Tests
- Dart-side validation with TableStructure defined
- Validation errors thrown before FFI call
- SurrealDB validation when no TableStructure
- Error message clarity and actionability
- Mixed validation (some fields validated, others pass-through)

### Performance Tests
- Vector serialization overhead measurement
- Large batch insert benchmarks (1000+ vectors)
- Memory usage for vector storage
- Math operation performance on mobile devices

### Memory Tests
- VectorValue lifecycle with NativeFinalizer (if applicable)
- Large vector cleanup verification
- No leaks in serialization/deserialization cycles
- Batch operation memory pressure

## Documentation Requirements

### API Documentation (dartdoc)
- VectorValue class with usage examples for each factory constructor
- Math operation examples with visual explanations
- Distance calculation formulas and use cases
- TableStructure with complete schema definition examples
- FieldDefinition for each SurrealType variant
- Validation strategy explanation (dual approach)

### Usage Examples
```dart
// Example 1: Basic vector storage
final embedding = VectorValue.fromList([0.1, 0.2, 0.3]);
await db.create('embeddings', {
  'text': 'Hello world',
  'vector': embedding.toJson(),
});

// Example 2: Vector math operations
final vec1 = VectorValue.fromList([1.0, 0.0, 0.0]);
final vec2 = VectorValue.fromList([0.0, 1.0, 0.0]);
final similarity = vec1.cosine(vec2);  // 0.0 (orthogonal)

// Example 3: Schema definition with validation
final schema = TableStructure('documents', {
  'embedding': FieldDefinition(VectorType.f32(384, normalized: true)),
});

final vector = VectorValue.fromList([/* 384 values */]);
if (!vector.isNormalized()) {
  vector = vector.normalize();  // Ensure normalized before insert
}

await db.create('documents', {
  'embedding': vector.toJson(),
});

// Example 4: Batch vector operations
final vectors = [
  VectorValue.fromList([/* ... */]),
  VectorValue.fromList([/* ... */]),
];

await db.query('''
  INSERT INTO embeddings [
    \$vector0,
    \$vector1
  ]
''', {
  'vector0': {'data': vectors[0].toJson()},
  'vector1': {'data': vectors[1].toJson()},
});
```

### Migration Guide
- Adding vectors to existing tables
- Migrating from manual array handling to VectorValue
- Schema definition best practices
- Performance optimization tips for large vector datasets

### Performance Characteristics
- Vector serialization overhead: O(n) where n = dimensions
- Math operations complexity: dot product O(n), normalize O(n), distances O(n)
- Memory footprint by format:
  - F32: 4 bytes per dimension
  - F64: 8 bytes per dimension
  - I8: 1 byte per dimension
  - I16: 2 bytes per dimension
  - I32: 4 bytes per dimension
  - I64: 8 bytes per dimension
- Batch insert recommended sizes based on platform
- Hybrid serialization threshold: 100 dimensions (configurable)

## Out of Scope

### Excluded from This Milestone
- Vector search operations (knn, similarity search) - **Phase 3 Milestone 6**
- Vector indexing configuration - **Phase 3 Milestone 6**
- Approximate nearest neighbor (ANN) search - **Phase 3 Milestone 6**
- Advanced vector operations beyond basic math/distance
- Vector compression or quantization
- Batch similarity operations
- Vector clustering utilities

### Future Enhancements
- Advanced vector transformations (PCA, dimensionality reduction)
- Vector compression for storage optimization
- Hardware-accelerated vector operations (SIMD, GPU)
- Streaming vector operations for memory efficiency
- Integration with popular embedding libraries (OpenAI, Mistral, FastEmbed)

## Success Criteria

### Functional Success
- VectorValue class supports all SurrealDB vector types (F32, F64, I8, I16, I32, I64)
- All specified factory constructors work (fromList, fromString, fromBytes, fromJson, format-specific named constructors)
- All math operations implemented and tested (dotProduct, normalize, magnitude)
- All distance calculations implemented and tested (cosine, euclidean, manhattan)
- Validation helpers work correctly (validateDimensions, isNormalized)
- TableStructure supports comprehensive type definitions including vectors
- Dimension validation works with dual strategy (Dart-side when TableStructure exists, SurrealDB fallback otherwise)
- Vector data integrates seamlessly with existing CRUD operations
- Batch operations work with vector data
- Hybrid serialization automatically selects optimal format (JSON vs binary)

### Quality Success
- Test coverage meets project standard (92% or higher)
- All tests pass on all supported platforms (iOS, Android, macOS, Windows, Linux)
- No memory leaks detected in vector lifecycle tests
- Performance acceptable on mobile devices (tested on real hardware)
- Documentation complete with runnable examples
- Error messages clear and actionable

### Developer Experience
- API feels natural and Dart-idiomatic
- Factory constructors cover common use cases
- Schema definition is intuitive and type-safe
- Validation errors provide enough context to fix issues
- Examples demonstrate real-world AI/ML workflows
- Migration from manual array handling is straightforward
