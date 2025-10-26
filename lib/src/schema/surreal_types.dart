/// SurrealDB type system for schema definitions.
///
/// This library provides a comprehensive type hierarchy representing all
/// SurrealDB data types, enabling type-safe schema definitions and validation.
///
/// The type system uses Dart 3's sealed classes for exhaustive pattern matching,
/// ensuring all type variants are handled in validation and processing logic.
///
/// ## Type Categories
///
/// ### Scalar Types
/// - [StringType] - Text data
/// - [NumberType] - Numeric data (integer, floating, decimal)
/// - [BoolType] - Boolean values
/// - [DatetimeType] - Temporal data
/// - [DurationType] - Time spans
///
/// ### Collection Types
/// - [ArrayType] - Ordered collections with element type constraints
/// - [ObjectType] - Key-value structures with optional schema
///
/// ### Special Types
/// - [RecordType] - References to database records
/// - [GeometryType] - Geospatial data
/// - [VectorType] - Vector embeddings for AI/ML workloads
/// - [AnyType] - Dynamic fields without type constraints
///
/// ## Example Usage
///
/// ```dart
/// // Define a schema for a documents table with vector embeddings
/// final documentSchema = {
///   'title': FieldDefinition(StringType()),
///   'content': FieldDefinition(StringType()),
///   'embedding': FieldDefinition(
///     VectorType.f32(1536, normalized: true),
///     optional: false,
///   ),
///   'metadata': FieldDefinition(
///     ObjectType(),
///     optional: true,
///   ),
///   'tags': FieldDefinition(
///     ArrayType(StringType()),
///     optional: true,
///   ),
/// };
///
/// // Use NumberType with format constraints
/// final userSchema = {
///   'age': FieldDefinition(
///     NumberType(format: NumberFormat.integer),
///   ),
///   'balance': FieldDefinition(
///     NumberType(format: NumberFormat.decimal),
///   ),
/// };
/// ```
library;

import '../types/vector_value.dart' show VectorFormat;

/// Base sealed class for all SurrealDB types.
///
/// This sealed class enables exhaustive pattern matching in Dart 3,
/// ensuring all type variants are handled in validation and processing logic.
///
/// Use pattern matching to handle different type variants:
/// ```dart
/// String getTypeName(SurrealType type) {
///   return switch (type) {
///     StringType() => 'string',
///     NumberType() => 'number',
///     BoolType() => 'bool',
///     DatetimeType() => 'datetime',
///     DurationType() => 'duration',
///     ArrayType() => 'array',
///     ObjectType() => 'object',
///     RecordType() => 'record',
///     GeometryType() => 'geometry',
///     VectorType() => 'vector',
///     AnyType() => 'any',
///   };
/// }
/// ```
sealed class SurrealType {
  /// Creates a SurrealType.
  const SurrealType();
}

// ============================================================================
// Scalar Types
// ============================================================================

/// Represents SurrealDB string type for text data.
///
/// Maps to SurrealDB's `string` type, which stores UTF-8 text data
/// of arbitrary length.
///
/// Example:
/// ```dart
/// final nameField = FieldDefinition(StringType());
/// ```
class StringType extends SurrealType {
  /// Creates a StringType.
  const StringType();
}

/// Represents SurrealDB number type for numeric data.
///
/// SurrealDB numbers can be integers, floating-point values, or decimals.
/// Use the optional [format] parameter to constrain the numeric format.
///
/// Maps to SurrealDB's `number`, `int`, `float`, or `decimal` types.
///
/// Example:
/// ```dart
/// // Any numeric format
/// final anyNumber = NumberType();
///
/// // Integer only
/// final age = NumberType(format: NumberFormat.integer);
///
/// // Floating-point only
/// final temperature = NumberType(format: NumberFormat.floating);
///
/// // Decimal only (precise decimal arithmetic)
/// final price = NumberType(format: NumberFormat.decimal);
/// ```
class NumberType extends SurrealType {
  /// Creates a NumberType with optional format constraint.
  ///
  /// [format] - Optional constraint on the numeric format (integer, floating, decimal)
  const NumberType({this.format});

  /// Optional constraint on the numeric format.
  ///
  /// When null, any numeric format is accepted. When specified, validates
  /// that values match the expected format.
  final NumberFormat? format;
}

/// Numeric format constraints for NumberType.
///
/// Defines the specific numeric representation for a number field.
enum NumberFormat {
  /// Integer values only (no decimal point).
  ///
  /// Maps to SurrealDB's `int` type.
  /// Examples: 0, 1, -42, 1000000
  integer,

  /// Floating-point values (IEEE 754 double-precision).
  ///
  /// Maps to SurrealDB's `float` type.
  /// Examples: 0.0, 3.14159, -2.5, 1e10
  floating,

  /// Decimal values with precise decimal arithmetic.
  ///
  /// Maps to SurrealDB's `decimal` type for financial calculations
  /// requiring exact decimal representation.
  /// Examples: 19.99, 0.01, -1234.5678
  decimal,
}

/// Represents SurrealDB bool type for boolean values.
///
/// Maps to SurrealDB's `bool` type, which stores true/false values.
///
/// Example:
/// ```dart
/// final isActiveField = FieldDefinition(BoolType());
/// ```
class BoolType extends SurrealType {
  /// Creates a BoolType.
  const BoolType();
}

/// Represents SurrealDB datetime type for temporal data.
///
/// Maps to SurrealDB's `datetime` type, which stores timestamps
/// with nanosecond precision.
///
/// Example:
/// ```dart
/// final createdAtField = FieldDefinition(DatetimeType());
/// ```
class DatetimeType extends SurrealType {
  /// Creates a DatetimeType.
  const DatetimeType();
}

/// Represents SurrealDB duration type for time spans.
///
/// Maps to SurrealDB's `duration` type, which represents time intervals
/// (e.g., "5d", "2h30m", "1w").
///
/// Example:
/// ```dart
/// final sessionDurationField = FieldDefinition(DurationType());
/// ```
class DurationType extends SurrealType {
  /// Creates a DurationType.
  const DurationType();
}

// ============================================================================
// Collection Types
// ============================================================================

/// Represents SurrealDB array type for ordered collections.
///
/// Maps to SurrealDB's `array` type, which stores ordered lists of values.
/// Use [elementType] to constrain what types of elements the array can contain.
///
/// Optionally specify [length] for fixed-length array validation.
///
/// Example:
/// ```dart
/// // Array of strings
/// final tags = ArrayType(StringType());
///
/// // Array of numbers
/// final coordinates = ArrayType(NumberType(format: NumberFormat.floating));
///
/// // Fixed-length array (3 elements)
/// final rgb = ArrayType(
///   NumberType(format: NumberFormat.integer),
///   length: 3,
/// );
///
/// // Nested array (array of arrays)
/// final matrix = ArrayType(ArrayType(NumberType()));
/// ```
class ArrayType extends SurrealType {
  /// Creates an ArrayType with element type constraint.
  ///
  /// [elementType] - The type of elements this array can contain
  /// [length] - Optional fixed length constraint
  const ArrayType(this.elementType, {this.length});

  /// The type of elements this array contains.
  final SurrealType elementType;

  /// Optional fixed length constraint.
  ///
  /// When null, array can have any length. When specified, validates
  /// that arrays have exactly this many elements.
  final int? length;
}

/// Represents SurrealDB object type for key-value structures.
///
/// Maps to SurrealDB's `object` type, which stores key-value pairs.
/// Optionally specify [schema] to enforce a specific structure.
///
/// Example:
/// ```dart
/// // Schemaless object (any keys/values)
/// final metadata = ObjectType();
///
/// // Object with defined schema
/// final address = ObjectType(schema: {
///   'street': FieldDefinition(StringType()),
///   'city': FieldDefinition(StringType()),
///   'zipCode': FieldDefinition(StringType()),
///   'country': FieldDefinition(StringType(), optional: true),
/// });
/// ```
class ObjectType extends SurrealType {
  /// Creates an ObjectType with optional schema.
  ///
  /// [schema] - Optional map defining the expected fields and their types
  const ObjectType({this.schema});

  /// Optional schema defining expected fields.
  ///
  /// When null, object can contain any fields. When specified, validates
  /// that objects conform to the defined field structure.
  final Map<String, FieldDefinition>? schema;
}

// ============================================================================
// Special Types
// ============================================================================

/// Represents SurrealDB record type for references to database records.
///
/// Maps to SurrealDB's `record` type, which stores references to records
/// in the format "table:id".
///
/// Optionally specify [table] to constrain which table the record must be from.
///
/// Example:
/// ```dart
/// // Any record from any table
/// final anyRecord = RecordType();
///
/// // Record from specific table
/// final personRecord = RecordType(table: 'person');
/// ```
class RecordType extends SurrealType {
  /// Creates a RecordType with optional table constraint.
  ///
  /// [table] - Optional table name constraint
  const RecordType({this.table});

  /// Optional table name constraint.
  ///
  /// When null, record can be from any table. When specified, validates
  /// that records are from the specified table.
  final String? table;
}

/// Represents SurrealDB geometry type for geospatial data.
///
/// Maps to SurrealDB's geometry types, which store GeoJSON-compatible
/// spatial data structures.
///
/// Optionally specify [kind] to constrain the geometry type.
///
/// Example:
/// ```dart
/// // Any geometry type
/// final location = GeometryType();
///
/// // Specific geometry type
/// final pointLocation = GeometryType(kind: GeometryKind.point);
/// final boundary = GeometryType(kind: GeometryKind.polygon);
/// ```
class GeometryType extends SurrealType {
  /// Creates a GeometryType with optional kind constraint.
  ///
  /// [kind] - Optional geometry kind constraint
  const GeometryType({this.kind});

  /// Optional geometry kind constraint.
  ///
  /// When null, any geometry kind is accepted. When specified, validates
  /// that geometries are of the specified kind.
  final GeometryKind? kind;
}

/// Geometry kind constraints for GeometryType.
///
/// Defines the specific geospatial structure type.
enum GeometryKind {
  /// A single point in space (longitude, latitude).
  ///
  /// Example: {"type": "Point", "coordinates": [-122.4, 37.8]}
  point,

  /// A line connecting two or more points.
  ///
  /// Example: {"type": "LineString", "coordinates": [[0,0], [1,1], [2,0]]}
  line,

  /// A closed shape with one or more rings.
  ///
  /// Example: {"type": "Polygon", "coordinates": [[[0,0], [1,0], [1,1], [0,1], [0,0]]]}
  polygon,

  /// Multiple points.
  ///
  /// Example: {"type": "MultiPoint", "coordinates": [[0,0], [1,1]]}
  multipoint,

  /// Multiple lines.
  ///
  /// Example: {"type": "MultiLineString", "coordinates": [[[0,0], [1,1]], [[2,2], [3,3]]]}
  multiline,

  /// Multiple polygons.
  ///
  /// Example: {"type": "MultiPolygon", "coordinates": [[[[0,0], [1,0], [1,1], [0,0]]]]}
  multipolygon,

  /// Collection of different geometry types.
  ///
  /// Example: {"type": "GeometryCollection", "geometries": [...]}
  collection,
}

/// Represents SurrealDB vector type for AI/ML embeddings.
///
/// Maps to SurrealDB's vector types (F32, F64, I8, I16, I32, I64), which
/// store multi-dimensional numeric arrays optimized for AI/ML workloads.
///
/// Vectors must specify:
/// - [format] - The numeric format (F32, F64, I8, I16, I32, I64)
/// - [dimensions] - The number of dimensions (must be > 0)
/// - [normalized] - Whether vectors must have magnitude 1.0
///
/// Use named constructors for convenient creation:
/// ```dart
/// // F32 vector (most common for embeddings)
/// final embedding = VectorType.f32(1536, normalized: true);
///
/// // F64 vector (high precision)
/// final preciseVector = VectorType.f64(768);
///
/// // I16 vector (quantized embeddings)
/// final quantized = VectorType.i16(384);
/// ```
class VectorType extends SurrealType {
  /// Creates a VectorType with explicit format and dimensions.
  ///
  /// [format] - The vector format (F32, F64, I8, I16, I32, I64)
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  ///
  /// Throws [ArgumentError] if dimensions is not positive.
  const VectorType({
    required this.format,
    required this.dimensions,
    this.normalized = false,
  }) : assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an F32 (float32) vector type.
  ///
  /// F32 is the most common format for embedding models (OpenAI, Mistral, etc.).
  /// Uses 4 bytes per dimension.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  ///
  /// Example:
  /// ```dart
  /// // OpenAI text-embedding-3-small (1536 dimensions)
  /// final openaiEmbedding = VectorType.f32(1536, normalized: true);
  /// ```
  const VectorType.f32(this.dimensions, {this.normalized = false})
      : format = VectorFormat.f32,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an F64 (float64) vector type.
  ///
  /// F64 provides high precision for scientific computing.
  /// Uses 8 bytes per dimension.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  const VectorType.f64(this.dimensions, {this.normalized = false})
      : format = VectorFormat.f64,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an I8 (int8) vector type.
  ///
  /// I8 is used for highly quantized embeddings.
  /// Uses 1 byte per dimension, values range from -128 to 127.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  const VectorType.i8(this.dimensions, {this.normalized = false})
      : format = VectorFormat.i8,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an I16 (int16) vector type.
  ///
  /// I16 is used for quantized embeddings with moderate precision.
  /// Uses 2 bytes per dimension, values range from -32768 to 32767.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  const VectorType.i16(this.dimensions, {this.normalized = false})
      : format = VectorFormat.i16,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an I32 (int32) vector type.
  ///
  /// I32 is used for integer vectors with high precision.
  /// Uses 4 bytes per dimension.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  const VectorType.i32(this.dimensions, {this.normalized = false})
      : format = VectorFormat.i32,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// Creates an I64 (int64) vector type.
  ///
  /// I64 is used for integer vectors with maximum precision.
  /// Uses 8 bytes per dimension.
  ///
  /// [dimensions] - The number of dimensions (must be > 0)
  /// [normalized] - Whether vectors must have magnitude 1.0
  const VectorType.i64(this.dimensions, {this.normalized = false})
      : format = VectorFormat.i64,
        assert(dimensions > 0, 'Vector dimensions must be positive');

  /// The vector format (F32, F64, I8, I16, I32, I64).
  final VectorFormat format;

  /// The number of dimensions in the vector.
  ///
  /// Must be a positive integer. Common dimensions:
  /// - 128: Small models
  /// - 384: MiniLM, all-MiniLM-L6-v2
  /// - 768: BERT-base, sentence-transformers
  /// - 1536: OpenAI text-embedding-3-small, text-embedding-ada-002
  /// - 3072: OpenAI text-embedding-3-large
  final int dimensions;

  /// Whether vectors must be normalized (magnitude 1.0).
  ///
  /// When true, validation checks that vector magnitude is approximately 1.0
  /// (within floating-point tolerance). Useful for cosine similarity where
  /// normalized vectors enable dot product optimization.
  final bool normalized;
}

/// Represents a dynamic field that can contain any type.
///
/// Maps to SurrealDB's `any` type, which accepts values of any type
/// without validation.
///
/// Use sparingly - prefer specific types for better validation.
///
/// Example:
/// ```dart
/// final dynamicData = FieldDefinition(AnyType());
/// ```
class AnyType extends SurrealType {
  /// Creates an AnyType.
  const AnyType();
}

// ============================================================================
// Field Definition
// ============================================================================

/// Defines a field in a table schema.
///
/// A field definition combines a [type] constraint with metadata about
/// whether the field is [optional] and what [defaultValue] to use if not provided.
///
/// Example:
/// ```dart
/// // Required string field
/// final nameField = FieldDefinition(StringType());
///
/// // Optional number field with default
/// final ageField = FieldDefinition(
///   NumberType(format: NumberFormat.integer),
///   optional: true,
///   defaultValue: 0,
/// );
///
/// // Required vector field with normalization
/// final embeddingField = FieldDefinition(
///   VectorType.f32(1536, normalized: true),
///   optional: false,
/// );
/// ```
class FieldDefinition {
  /// Creates a field definition.
  ///
  /// [type] - The SurrealDB type for this field
  /// [optional] - Whether this field can be omitted (defaults to false)
  /// [defaultValue] - Default value to use if field is not provided
  ///
  /// When [optional] is false, the field must be present in data.
  /// When [optional] is true, the field can be omitted, and [defaultValue]
  /// is used if specified.
  const FieldDefinition(
    this.type, {
    this.optional = false,
    this.defaultValue,
  });

  /// The SurrealDB type for this field.
  final SurrealType type;

  /// Whether this field is optional.
  ///
  /// When false (default), the field must be present in data.
  /// When true, the field can be omitted.
  final bool optional;

  /// Default value to use if field is not provided.
  ///
  /// Only used when [optional] is true and the field is not present.
  /// Should match the type specified in [type].
  final dynamic defaultValue;
}
