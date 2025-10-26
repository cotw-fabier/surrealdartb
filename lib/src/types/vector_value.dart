/// VectorValue type for SurrealDB vector embeddings.
///
/// This library provides the VectorValue class which represents vector
/// embeddings with support for multiple data types (F32, F64, I8, I16, I32, I64)
/// and efficient serialization strategies.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Vector data format enumeration.
///
/// Represents the different numeric types supported by SurrealDB for vector data.
enum VectorFormat {
  /// 32-bit floating-point (primary type for embeddings)
  f32,

  /// 64-bit floating-point (high-precision)
  f64,

  /// 8-bit signed integer (quantized embeddings)
  i8,

  /// 16-bit signed integer (quantized embeddings)
  i16,

  /// 32-bit signed integer (quantized embeddings)
  i32,

  /// 64-bit signed integer (quantized embeddings)
  i64,
}

/// Represents a SurrealDB vector value with multi-format support.
///
/// VectorValue provides a type-safe wrapper around vector data with support
/// for all SurrealDB vector types. Vectors can be created from common Dart
/// types and serialized efficiently for FFI transport.
///
/// ## Supported Formats
///
/// - **F32** (Float32): Primary type for embedding models (OpenAI, etc.)
/// - **F64** (Float64): High-precision floating-point vectors
/// - **I8, I16, I32, I64**: Integer vectors for quantized embeddings
///
/// ## Factory Constructors
///
/// ```dart
/// // Named constructors for specific formats
/// final f32Vec = VectorValue.f32([0.1, 0.2, 0.3]);
/// final f64Vec = VectorValue.f64([0.1, 0.2, 0.3]);
/// final i16Vec = VectorValue.i16([100, 200, 300]);
///
/// // Generic constructors with format parameter
/// final vec1 = VectorValue.fromList([0.1, 0.2, 0.3]); // defaults to F32
/// final vec2 = VectorValue.fromList([1, 2, 3], format: VectorFormat.i32);
/// final vec3 = VectorValue.fromString('[0.1, 0.2, 0.3]');
/// ```
///
/// ## Math Operations
///
/// ```dart
/// final vec1 = VectorValue.f32([3.0, 4.0, 0.0]);
/// final vec2 = VectorValue.f32([1.0, 0.0, 0.0]);
///
/// // Basic operations
/// print(vec1.magnitude());        // 5.0
/// final normalized = vec1.normalize();  // Unit vector
/// final dot = vec1.dotProduct(vec2);    // 3.0
///
/// // Distance calculations
/// final euclidean = vec1.euclidean(vec2);
/// final manhattan = vec1.manhattan(vec2);
/// final cosine = vec1.cosine(vec2);
/// ```
///
/// ## Serialization
///
/// VectorValue supports hybrid serialization that automatically selects
/// the optimal format based on vector dimensions:
///
/// ```dart
/// final smallVec = VectorValue.fromList(List.filled(50, 1.0));
/// smallVec.toBinaryOrJson(); // Returns JSON List for small vectors
///
/// final largeVec = VectorValue.fromList(List.filled(768, 1.0));
/// largeVec.toBinaryOrJson(); // Returns binary Uint8List for large vectors
/// ```
///
/// The threshold defaults to 100 dimensions but can be configured:
/// ```dart
/// VectorValue.serializationThreshold = 150; // Use binary for >150 dimensions
/// ```
class VectorValue {
  /// Serialization threshold for automatic binary/JSON selection.
  ///
  /// Vectors with dimensions <= this value use JSON serialization.
  /// Vectors with dimensions > this value use binary serialization.
  /// Default: 100 dimensions.
  static int serializationThreshold = 100;

  /// Internal storage for vector data (typed list).
  final dynamic _data;

  /// Vector format specification.
  final VectorFormat format;

  /// Private constructor.
  VectorValue._(this._data, this.format);

  /// Creates a 32-bit floating-point (F32) vector.
  ///
  /// This is the primary vector type optimized for embedding model outputs
  /// from services like OpenAI, Mistral, etc.
  ///
  /// Throws [ArgumentError] if:
  /// - [values] is empty
  /// - [values] contains NaN
  /// - [values] contains Infinity
  ///
  /// Example:
  /// ```dart
  /// final embedding = VectorValue.f32([0.1, 0.2, 0.3, 0.4]);
  /// print(embedding.dimensions); // 4
  /// print(embedding.format); // VectorFormat.f32
  /// ```
  factory VectorValue.f32(List<double> values) {
    _validateValues(values, 'f32');
    return VectorValue._(Float32List.fromList(values), VectorFormat.f32);
  }

  /// Creates a 64-bit floating-point (F64) vector.
  ///
  /// Use for high-precision floating-point vectors when F32 precision
  /// is insufficient.
  ///
  /// Throws [ArgumentError] if:
  /// - [values] is empty
  /// - [values] contains NaN
  /// - [values] contains Infinity
  ///
  /// Example:
  /// ```dart
  /// final precision = VectorValue.f64([0.123456789, 0.987654321]);
  /// ```
  factory VectorValue.f64(List<double> values) {
    _validateValues(values, 'f64');
    return VectorValue._(Float64List.fromList(values), VectorFormat.f64);
  }

  /// Creates an 8-bit signed integer (I8) vector.
  ///
  /// Use for quantized embeddings where values fit in [-128, 127].
  ///
  /// Throws [ArgumentError] if [values] is empty.
  ///
  /// Example:
  /// ```dart
  /// final quantized = VectorValue.i8([1, 2, 3, 4, 5]);
  /// ```
  factory VectorValue.i8(List<int> values) {
    if (values.isEmpty) {
      throw ArgumentError('Vector values cannot be empty (i8)');
    }
    return VectorValue._(Int8List.fromList(values), VectorFormat.i8);
  }

  /// Creates a 16-bit signed integer (I16) vector.
  ///
  /// Use for quantized embeddings where values fit in [-32768, 32767].
  ///
  /// Throws [ArgumentError] if [values] is empty.
  ///
  /// Example:
  /// ```dart
  /// final quantized = VectorValue.i16([100, 200, 300, 400]);
  /// ```
  factory VectorValue.i16(List<int> values) {
    if (values.isEmpty) {
      throw ArgumentError('Vector values cannot be empty (i16)');
    }
    return VectorValue._(Int16List.fromList(values), VectorFormat.i16);
  }

  /// Creates a 32-bit signed integer (I32) vector.
  ///
  /// Use for quantized embeddings with larger integer ranges.
  ///
  /// Throws [ArgumentError] if [values] is empty.
  ///
  /// Example:
  /// ```dart
  /// final quantized = VectorValue.i32([1000, 2000, 3000]);
  /// ```
  factory VectorValue.i32(List<int> values) {
    if (values.isEmpty) {
      throw ArgumentError('Vector values cannot be empty (i32)');
    }
    return VectorValue._(Int32List.fromList(values), VectorFormat.i32);
  }

  /// Creates a 64-bit signed integer (I64) vector.
  ///
  /// Use for quantized embeddings with very large integer ranges.
  ///
  /// Throws [ArgumentError] if [values] is empty.
  ///
  /// Example:
  /// ```dart
  /// final quantized = VectorValue.i64([100000, 200000, 300000]);
  /// ```
  factory VectorValue.i64(List<int> values) {
    if (values.isEmpty) {
      throw ArgumentError('Vector values cannot be empty (i64)');
    }
    return VectorValue._(Int64List.fromList(values), VectorFormat.i64);
  }

  /// Creates a vector from a Dart list with format specification.
  ///
  /// The [format] parameter defaults to [VectorFormat.f32] if not specified.
  ///
  /// Throws [ArgumentError] if:
  /// - [values] is empty
  /// - [values] contains NaN or Infinity (for float formats)
  ///
  /// Example:
  /// ```dart
  /// // Default F32 format
  /// final vec1 = VectorValue.fromList([0.1, 0.2, 0.3]);
  ///
  /// // Explicit format
  /// final vec2 = VectorValue.fromList([1, 2, 3], format: VectorFormat.i16);
  /// final vec3 = VectorValue.fromList([0.5, 1.5], format: VectorFormat.f64);
  /// ```
  factory VectorValue.fromList(
    List<num> values, {
    VectorFormat format = VectorFormat.f32,
  }) {
    return switch (format) {
      VectorFormat.f32 => VectorValue.f32(values.map((v) => v.toDouble()).toList()),
      VectorFormat.f64 => VectorValue.f64(values.map((v) => v.toDouble()).toList()),
      VectorFormat.i8 => VectorValue.i8(values.map((v) => v.toInt()).toList()),
      VectorFormat.i16 => VectorValue.i16(values.map((v) => v.toInt()).toList()),
      VectorFormat.i32 => VectorValue.i32(values.map((v) => v.toInt()).toList()),
      VectorFormat.i64 => VectorValue.i64(values.map((v) => v.toInt()).toList()),
    };
  }

  /// Parses a vector from string format "[0.1, 0.2, 0.3]".
  ///
  /// The [format] parameter defaults to [VectorFormat.f32] if not specified.
  ///
  /// Throws [FormatException] if the string cannot be parsed.
  /// Throws [ArgumentError] if the parsed values are invalid.
  ///
  /// Example:
  /// ```dart
  /// final vec1 = VectorValue.fromString('[0.1, 0.2, 0.3]');
  /// final vec2 = VectorValue.fromString('[1, 2, 3]', format: VectorFormat.i32);
  /// ```
  factory VectorValue.fromString(
    String vectorStr, {
    VectorFormat format = VectorFormat.f32,
  }) {
    try {
      // Remove brackets and whitespace, then split by comma
      final cleaned = vectorStr.trim();
      if (!cleaned.startsWith('[') || !cleaned.endsWith(']')) {
        throw FormatException('Vector string must be enclosed in brackets');
      }

      final content = cleaned.substring(1, cleaned.length - 1).trim();
      if (content.isEmpty) {
        throw FormatException('Vector string cannot be empty');
      }

      final parts = content.split(',').map((s) => s.trim()).toList();
      final values = parts.map((s) {
        final parsed = num.tryParse(s);
        if (parsed == null) {
          throw FormatException('Invalid number: $s');
        }
        return parsed;
      }).toList();

      return VectorValue.fromList(values, format: format);
    } catch (e) {
      throw FormatException('Failed to parse vector string: $vectorStr', vectorStr);
    }
  }

  /// Deserializes a vector from binary format.
  ///
  /// Binary format specification:
  /// - Byte 0: Format enum (0=F32, 1=F64, 2=I8, 3=I16, 4=I32, 5=I64)
  /// - Bytes 1-4: Dimension count (little-endian uint32)
  /// - Remaining bytes: Data payload (format-specific)
  ///
  /// Throws [ArgumentError] if:
  /// - [bytes] is too short
  /// - Format mismatch between header and parameter
  ///
  /// Example:
  /// ```dart
  /// final bytes = someVectorValue.toBytes();
  /// final restored = VectorValue.fromBytes(bytes, VectorFormat.f32);
  /// ```
  factory VectorValue.fromBytes(Uint8List bytes, VectorFormat format) {
    if (bytes.length < 5) {
      throw ArgumentError('Binary data too short: minimum 5 bytes required');
    }

    final byteData = ByteData.view(bytes.buffer, bytes.offsetInBytes);

    // Read format header
    final formatByte = byteData.getUint8(0);
    final headerFormat = _formatFromByte(formatByte);
    if (headerFormat != format) {
      throw ArgumentError(
        'Format mismatch: header=$headerFormat, expected=$format',
      );
    }

    // Read dimensions
    final dimensions = byteData.getUint32(1, Endian.little);

    // Read data payload
    final dataOffset = 5;
    return switch (format) {
      VectorFormat.f32 => _readFloat32Data(byteData, dataOffset, dimensions),
      VectorFormat.f64 => _readFloat64Data(byteData, dataOffset, dimensions),
      VectorFormat.i8 => _readInt8Data(byteData, dataOffset, dimensions),
      VectorFormat.i16 => _readInt16Data(byteData, dataOffset, dimensions),
      VectorFormat.i32 => _readInt32Data(byteData, dataOffset, dimensions),
      VectorFormat.i64 => _readInt64Data(byteData, dataOffset, dimensions),
    };
  }

  /// Creates a vector from JSON (for FFI deserialization).
  ///
  /// The JSON can be:
  /// - A List of numbers
  ///
  /// The [format] parameter defaults to [VectorFormat.f32] if not specified.
  ///
  /// Throws [ArgumentError] if JSON is not a valid list of numbers.
  ///
  /// Example:
  /// ```dart
  /// final vec1 = VectorValue.fromJson([0.1, 0.2, 0.3]);
  /// final vec2 = VectorValue.fromJson([1, 2, 3], format: VectorFormat.i32);
  /// ```
  factory VectorValue.fromJson(
    dynamic json, {
    VectorFormat format = VectorFormat.f32,
  }) {
    if (json is! List) {
      throw ArgumentError(
        'VectorValue JSON must be a List, got ${json.runtimeType}',
      );
    }

    final values = json.map((v) {
      if (v is! num) {
        throw ArgumentError(
          'VectorValue elements must be numbers, got ${v.runtimeType}',
        );
      }
      return v;
    }).toList();

    return VectorValue.fromList(values, format: format);
  }

  /// Read-only access to internal typed list.
  ///
  /// Returns the appropriate typed list based on the vector format:
  /// - F32: [Float32List]
  /// - F64: [Float64List]
  /// - I8: [Int8List]
  /// - I16: [Int16List]
  /// - I32: [Int32List]
  /// - I64: [Int64List]
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final data = vec.data; // Float32List
  /// print(data[0]); // 1.0
  /// ```
  dynamic get data => _data;

  /// Returns the number of dimensions in the vector.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// print(vec.dimensions); // 3
  /// ```
  int get dimensions => (_data as List).length;

  /// Returns the string representation with format information.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// print(vec); // VectorValue(format=f32, dimensions=3)
  /// ```
  @override
  String toString() => 'VectorValue(format=$format, dimensions=$dimensions)';

  /// Converts to JSON for FFI transport.
  ///
  /// Returns a [List] representation suitable for JSON encoding.
  /// Works with all vector formats.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final json = vec.toJson(); // [1.0, 2.0, 3.0]
  /// ```
  List<num> toJson() => (_data as List).cast<num>();

  /// Serializes to binary format with format header.
  ///
  /// Binary format specification:
  /// - Byte 0: Format enum (0=F32, 1=F64, 2=I8, 3=I16, 4=I32, 5=I64)
  /// - Bytes 1-4: Dimension count (little-endian uint32)
  /// - Remaining bytes: Data payload (format-specific)
  ///
  /// Uses little-endian byte order for cross-platform consistency.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final bytes = vec.toBytes(); // Uint8List with binary data
  /// ```
  Uint8List toBytes() {
    final elementSize = _getElementSize(format);
    final totalSize = 1 + 4 + (dimensions * elementSize);
    final bytes = Uint8List(totalSize);
    final byteData = ByteData.view(bytes.buffer);

    // Write format header
    byteData.setUint8(0, _formatToByte(format));

    // Write dimensions
    byteData.setUint32(1, dimensions, Endian.little);

    // Write data payload
    final dataOffset = 5;
    switch (format) {
      case VectorFormat.f32:
        final data = _data as Float32List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setFloat32(dataOffset + i * 4, data[i], Endian.little);
        }
      case VectorFormat.f64:
        final data = _data as Float64List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setFloat64(dataOffset + i * 8, data[i], Endian.little);
        }
      case VectorFormat.i8:
        final data = _data as Int8List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setInt8(dataOffset + i, data[i]);
        }
      case VectorFormat.i16:
        final data = _data as Int16List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setInt16(dataOffset + i * 2, data[i], Endian.little);
        }
      case VectorFormat.i32:
        final data = _data as Int32List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setInt32(dataOffset + i * 4, data[i], Endian.little);
        }
      case VectorFormat.i64:
        final data = _data as Int64List;
        for (var i = 0; i < dimensions; i++) {
          byteData.setInt64(dataOffset + i * 8, data[i], Endian.little);
        }
    }

    return bytes;
  }

  /// Automatically selects JSON or binary serialization based on dimensions.
  ///
  /// - Dimensions <= [serializationThreshold]: Returns JSON List
  /// - Dimensions > [serializationThreshold]: Returns binary Uint8List
  ///
  /// Default threshold: 100 dimensions (configurable via [serializationThreshold]).
  ///
  /// Example:
  /// ```dart
  /// final smallVec = VectorValue.fromList(List.filled(50, 1.0));
  /// smallVec.toBinaryOrJson(); // Returns List
  ///
  /// final largeVec = VectorValue.fromList(List.filled(768, 1.0));
  /// largeVec.toBinaryOrJson(); // Returns Uint8List
  /// ```
  dynamic toBinaryOrJson() {
    if (dimensions <= serializationThreshold) {
      return toJson();
    } else {
      return toBytes();
    }
  }

  /// Validates that the vector has the expected number of dimensions.
  ///
  /// Returns `true` if the vector's dimension count matches [expected],
  /// `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([1.0, 2.0, 3.0]);
  /// print(vec.validateDimensions(3)); // true
  /// print(vec.validateDimensions(4)); // false
  /// ```
  bool validateDimensions(int expected) => dimensions == expected;

  /// Checks if the vector is normalized (has magnitude approximately 1.0).
  ///
  /// A normalized vector has a magnitude (length) of 1.0, meaning it's a
  /// unit vector. This is useful for embeddings that require normalization.
  ///
  /// The [tolerance] parameter allows for floating-point comparison with
  /// a specified precision. Default: 1e-6 (0.000001).
  ///
  /// Returns `true` if |magnitude - 1.0| <= tolerance, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
  /// print(unitVec.isNormalized()); // true
  ///
  /// final nonNormalized = VectorValue.f32([1.0, 2.0, 3.0]);
  /// print(nonNormalized.isNormalized()); // false
  ///
  /// // With custom tolerance
  /// final almostNormalized = VectorValue.f32([0.999, 0.0, 0.0]);
  /// print(almostNormalized.isNormalized(tolerance: 0.01)); // true
  /// ```
  bool isNormalized({double tolerance = 1e-6}) {
    final mag = magnitude();
    return (mag - 1.0).abs() <= tolerance;
  }

  /// Calculates the magnitude (length) of the vector.
  ///
  /// The magnitude is computed as: √(∑(a[i]²))
  ///
  /// This is also known as the Euclidean norm or L2 norm.
  ///
  /// Returns a [double] representing the vector's magnitude.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([3.0, 4.0, 0.0]);
  /// print(vec.magnitude()); // 5.0 (3-4-5 triangle)
  ///
  /// final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
  /// print(unitVec.magnitude()); // 1.0
  /// ```
  double magnitude() {
    double sumSquares = 0.0;
    final dataList = _data as List;

    for (var i = 0; i < dimensions; i++) {
      final value = (dataList[i] as num).toDouble();
      sumSquares += value * value;
    }

    return math.sqrt(sumSquares);
  }

  /// Computes the dot product (inner product) with another vector.
  ///
  /// The dot product is computed as: ∑(a[i] * b[i])
  ///
  /// Throws [ArgumentError] if vectors have different dimensions.
  ///
  /// Returns a [double] representing the dot product.
  ///
  /// Example:
  /// ```dart
  /// final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final vec2 = VectorValue.f32([4.0, 5.0, 6.0]);
  /// print(vec1.dotProduct(vec2)); // 32.0 (1*4 + 2*5 + 3*6)
  ///
  /// // Orthogonal vectors have dot product of 0
  /// final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
  /// final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
  /// print(vecX.dotProduct(vecY)); // 0.0
  /// ```
  double dotProduct(VectorValue other) {
    if (dimensions != other.dimensions) {
      throw ArgumentError(
        'Vector dimensions must match for dot product: '
        '$dimensions vs ${other.dimensions}',
      );
    }

    double sum = 0.0;
    final thisData = _data as List;
    final otherData = other._data as List;

    for (var i = 0; i < dimensions; i++) {
      final a = (thisData[i] as num).toDouble();
      final b = (otherData[i] as num).toDouble();
      sum += a * b;
    }

    return sum;
  }

  /// Returns a normalized version of this vector (unit vector).
  ///
  /// A normalized vector has the same direction but magnitude of 1.0.
  /// The result is computed as: a[i] / magnitude()
  ///
  /// Throws [StateError] if attempting to normalize a zero vector
  /// (magnitude = 0).
  ///
  /// Returns a new [VectorValue] with the same format as the original.
  ///
  /// Example:
  /// ```dart
  /// final vec = VectorValue.f32([3.0, 4.0, 0.0]);
  /// final normalized = vec.normalize();
  /// print(normalized.magnitude()); // 1.0
  /// print(normalized.data[0]); // 0.6
  /// print(normalized.data[1]); // 0.8
  ///
  /// // Direction preserved
  /// final vec2 = VectorValue.f32([2.0, 2.0, 2.0]);
  /// final norm2 = vec2.normalize();
  /// // All components equal: [0.577..., 0.577..., 0.577...]
  /// ```
  VectorValue normalize() {
    final mag = magnitude();

    if (mag == 0.0) {
      throw StateError(
        'Cannot normalize zero vector (magnitude = 0)',
      );
    }

    final dataList = _data as List;
    final normalizedValues = List<double>.generate(
      dimensions,
      (i) => (dataList[i] as num).toDouble() / mag,
    );

    // Return vector with same format
    return VectorValue.fromList(normalizedValues, format: format);
  }

  /// Calculates the cosine similarity with another vector.
  ///
  /// Cosine similarity is computed as: dot(a,b) / (magnitude(a) * magnitude(b))
  ///
  /// The result ranges from:
  /// - 1.0: vectors point in the same direction (parallel)
  /// - 0.0: vectors are orthogonal (perpendicular)
  /// - -1.0: vectors point in opposite directions
  ///
  /// Throws [ArgumentError] if vectors have different dimensions.
  /// Throws [StateError] if either vector is a zero vector.
  ///
  /// Returns a [double] representing the cosine similarity.
  ///
  /// Example:
  /// ```dart
  /// // Parallel vectors
  /// final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final vec2 = VectorValue.f32([2.0, 4.0, 6.0]);
  /// print(vec1.cosine(vec2)); // 1.0
  ///
  /// // Orthogonal vectors
  /// final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
  /// final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
  /// print(vecX.cosine(vecY)); // 0.0
  ///
  /// // Opposite vectors
  /// final vecA = VectorValue.f32([1.0, 0.0, 0.0]);
  /// final vecB = VectorValue.f32([-1.0, 0.0, 0.0]);
  /// print(vecA.cosine(vecB)); // -1.0
  /// ```
  double cosine(VectorValue other) {
    if (dimensions != other.dimensions) {
      throw ArgumentError(
        'Vector dimensions must match for cosine similarity: '
        '$dimensions vs ${other.dimensions}',
      );
    }

    final mag1 = magnitude();
    final mag2 = other.magnitude();

    if (mag1 == 0.0 || mag2 == 0.0) {
      throw StateError(
        'Cannot compute cosine similarity with zero vector',
      );
    }

    final dot = dotProduct(other);
    return dot / (mag1 * mag2);
  }

  /// Calculates the Euclidean distance to another vector.
  ///
  /// Euclidean distance is computed as: √(∑((a[i] - b[i])²))
  ///
  /// This is the straight-line distance between two points in vector space.
  ///
  /// Throws [ArgumentError] if vectors have different dimensions.
  ///
  /// Returns a [double] representing the Euclidean distance.
  ///
  /// Example:
  /// ```dart
  /// final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);
  /// print(vec1.euclidean(vec2)); // 7.071... (√50)
  ///
  /// // Distance to self is 0
  /// print(vec1.euclidean(vec1)); // 0.0
  /// ```
  double euclidean(VectorValue other) {
    if (dimensions != other.dimensions) {
      throw ArgumentError(
        'Vector dimensions must match for Euclidean distance: '
        '$dimensions vs ${other.dimensions}',
      );
    }

    double sumSquares = 0.0;
    final thisData = _data as List;
    final otherData = other._data as List;

    for (var i = 0; i < dimensions; i++) {
      final a = (thisData[i] as num).toDouble();
      final b = (otherData[i] as num).toDouble();
      final diff = a - b;
      sumSquares += diff * diff;
    }

    return math.sqrt(sumSquares);
  }

  /// Calculates the Manhattan distance to another vector.
  ///
  /// Manhattan distance is computed as: ∑(|a[i] - b[i]|)
  ///
  /// This is also known as L1 distance or taxicab distance. It measures
  /// the distance along axis-aligned paths.
  ///
  /// Throws [ArgumentError] if vectors have different dimensions.
  ///
  /// Returns a [double] representing the Manhattan distance.
  ///
  /// Example:
  /// ```dart
  /// final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
  /// final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);
  /// print(vec1.manhattan(vec2)); // 12.0 (3 + 4 + 5)
  ///
  /// // Distance to self is 0
  /// print(vec1.manhattan(vec1)); // 0.0
  /// ```
  double manhattan(VectorValue other) {
    if (dimensions != other.dimensions) {
      throw ArgumentError(
        'Vector dimensions must match for Manhattan distance: '
        '$dimensions vs ${other.dimensions}',
      );
    }

    double sum = 0.0;
    final thisData = _data as List;
    final otherData = other._data as List;

    for (var i = 0; i < dimensions; i++) {
      final a = (thisData[i] as num).toDouble();
      final b = (otherData[i] as num).toDouble();
      sum += (a - b).abs();
    }

    return sum;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VectorValue) return false;
    if (other.format != format) return false;
    if (other.dimensions != dimensions) return false;

    // Element-wise comparison
    final otherData = other._data as List;
    final thisData = _data as List;
    for (var i = 0; i < dimensions; i++) {
      if (thisData[i] != otherData[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([format, ...((_data as List).cast<num>())]);

  // Private validation helper
  static void _validateValues(List<double> values, String formatName) {
    if (values.isEmpty) {
      throw ArgumentError('Vector values cannot be empty ($formatName)');
    }

    for (var i = 0; i < values.length; i++) {
      if (values[i].isNaN) {
        throw ArgumentError(
          'Vector values cannot contain NaN at index $i ($formatName)',
        );
      }
      if (values[i].isInfinite) {
        throw ArgumentError(
          'Vector values cannot contain Infinity at index $i ($formatName)',
        );
      }
    }
  }

  // Format conversion helpers
  static int _formatToByte(VectorFormat format) {
    return switch (format) {
      VectorFormat.f32 => 0,
      VectorFormat.f64 => 1,
      VectorFormat.i8 => 2,
      VectorFormat.i16 => 3,
      VectorFormat.i32 => 4,
      VectorFormat.i64 => 5,
    };
  }

  static VectorFormat _formatFromByte(int byte) {
    return switch (byte) {
      0 => VectorFormat.f32,
      1 => VectorFormat.f64,
      2 => VectorFormat.i8,
      3 => VectorFormat.i16,
      4 => VectorFormat.i32,
      5 => VectorFormat.i64,
      _ => throw ArgumentError('Invalid format byte: $byte'),
    };
  }

  static int _getElementSize(VectorFormat format) {
    return switch (format) {
      VectorFormat.f32 => 4,
      VectorFormat.f64 => 8,
      VectorFormat.i8 => 1,
      VectorFormat.i16 => 2,
      VectorFormat.i32 => 4,
      VectorFormat.i64 => 8,
    };
  }

  // Binary deserialization helpers
  static VectorValue _readFloat32Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Float32List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getFloat32(offset + i * 4, Endian.little);
    }
    return VectorValue._(data, VectorFormat.f32);
  }

  static VectorValue _readFloat64Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Float64List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getFloat64(offset + i * 8, Endian.little);
    }
    return VectorValue._(data, VectorFormat.f64);
  }

  static VectorValue _readInt8Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Int8List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getInt8(offset + i);
    }
    return VectorValue._(data, VectorFormat.i8);
  }

  static VectorValue _readInt16Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Int16List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getInt16(offset + i * 2, Endian.little);
    }
    return VectorValue._(data, VectorFormat.i16);
  }

  static VectorValue _readInt32Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Int32List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getInt32(offset + i * 4, Endian.little);
    }
    return VectorValue._(data, VectorFormat.i32);
  }

  static VectorValue _readInt64Data(
    ByteData byteData,
    int offset,
    int dimensions,
  ) {
    final data = Int64List(dimensions);
    for (var i = 0; i < dimensions; i++) {
      data[i] = byteData.getInt64(offset + i * 8, Endian.little);
    }
    return VectorValue._(data, VectorFormat.i64);
  }
}
