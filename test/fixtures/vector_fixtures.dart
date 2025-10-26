/// Test fixtures and factories for vector testing.
///
/// Provides reusable test data for common vector dimensions, edge cases,
/// and sample schemas to improve test code reusability and maintainability.
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Common dimension sizes used by popular embedding models.
class CommonDimensions {
  /// Small vector for testing (MiniLM-L6)
  static const int dim128 = 128;

  /// Moderate vector (all-MiniLM-L12-v2)
  static const int dim384 = 384;

  /// Large vector (OpenAI ada-002, many models)
  static const int dim768 = 768;

  /// Very large vector (OpenAI text-embedding-3-large)
  static const int dim1536 = 1536;

  /// Extra large vector (some multimodal models)
  static const int dim3072 = 3072;
}

/// Factory for creating test vectors with common dimensions.
class VectorFixtures {
  /// Creates a normalized F32 vector of specified dimensions.
  ///
  /// All elements are set to 1/sqrt(dimensions) to ensure normalization.
  static VectorValue normalizedF32(int dimensions) {
    final value = 1.0 / dimensions;
    return VectorValue.f32(List.filled(dimensions, value)).normalize();
  }

  /// Creates a non-normalized F32 vector with sequential values.
  ///
  /// Elements are set to [0.1, 0.2, 0.3, ...].
  static VectorValue sequentialF32(int dimensions) {
    return VectorValue.f32(
      List.generate(dimensions, (i) => (i + 1) * 0.1),
    );
  }

  /// Creates a zero vector (all elements are 0.0).
  static VectorValue zeroVector(int dimensions, {VectorFormat format = VectorFormat.f32}) {
    switch (format) {
      case VectorFormat.f32:
        return VectorValue.f32(List.filled(dimensions, 0.0));
      case VectorFormat.f64:
        return VectorValue.f64(List.filled(dimensions, 0.0));
      case VectorFormat.i8:
        return VectorValue.i8(List.filled(dimensions, 0));
      case VectorFormat.i16:
        return VectorValue.i16(List.filled(dimensions, 0));
      case VectorFormat.i32:
        return VectorValue.i32(List.filled(dimensions, 0));
      case VectorFormat.i64:
        return VectorValue.i64(List.filled(dimensions, 0));
    }
  }

  /// Creates a unit vector along specified axis (all zeros except one 1.0).
  static VectorValue unitVector(int dimensions, int axis) {
    if (axis < 0 || axis >= dimensions) {
      throw ArgumentError('Axis $axis out of range for $dimensions dimensions');
    }
    final values = List<double>.filled(dimensions, 0.0);
    values[axis] = 1.0;
    return VectorValue.f32(values);
  }

  /// Creates vector with all elements set to the same value.
  static VectorValue constant(int dimensions, double value) {
    return VectorValue.f32(List.filled(dimensions, value));
  }

  /// Creates a vector with random-like values (deterministic for testing).
  ///
  /// Uses a simple pattern to generate pseudo-random values for testing.
  static VectorValue pseudoRandom(int dimensions, {int seed = 42}) {
    return VectorValue.f32(
      List.generate(dimensions, (i) {
        final val = ((i + seed) * 1234567) % 1000;
        return val / 1000.0;
      }),
    );
  }

  /// Creates a very small vector (near-zero values) for precision testing.
  static VectorValue nearZero(int dimensions) {
    return VectorValue.f32(
      List.filled(dimensions, 1e-10),
    );
  }

  /// Creates a vector with very large values for overflow testing.
  static VectorValue largeValues(int dimensions) {
    return VectorValue.f64(
      List.filled(dimensions, 1e100),
    );
  }

  /// Creates a vector at the threshold between JSON and binary serialization.
  static VectorValue atSerializationThreshold() {
    return sequentialF32(VectorValue.serializationThreshold);
  }

  /// Creates a vector just below the serialization threshold.
  static VectorValue belowSerializationThreshold() {
    return sequentialF32(VectorValue.serializationThreshold - 1);
  }

  /// Creates a vector just above the serialization threshold.
  static VectorValue aboveSerializationThreshold() {
    return sequentialF32(VectorValue.serializationThreshold + 1);
  }
}

/// Sample table schemas for testing.
class SchemaFixtures {
  /// Simple document schema with title and F32 embedding.
  static TableStructure documentSchema({int dimensions = 384}) {
    return TableStructure('documents', {
      'title': FieldDefinition(StringType()),
      'content': FieldDefinition(StringType()),
      'embedding': FieldDefinition(VectorType.f32(dimensions)),
    });
  }

  /// Schema with normalized vector requirement.
  static TableStructure normalizedEmbeddingSchema({int dimensions = 768}) {
    return TableStructure('normalized_vectors', {
      'id': FieldDefinition(StringType()),
      'embedding': FieldDefinition(VectorType.f32(dimensions, normalized: true)),
    });
  }

  /// Schema with multiple vector fields of different dimensions.
  static TableStructure multiVectorSchema() {
    return TableStructure('multi_vectors', {
      'name': FieldDefinition(StringType()),
      'small_embedding': FieldDefinition(VectorType.f32(128)),
      'medium_embedding': FieldDefinition(VectorType.f32(384)),
      'large_embedding': FieldDefinition(VectorType.f32(1536)),
    });
  }

  /// Schema with optional vector field.
  static TableStructure optionalVectorSchema() {
    return TableStructure('optional_vectors', {
      'title': FieldDefinition(StringType()),
      'embedding': FieldDefinition(VectorType.f32(768), optional: true),
    });
  }

  /// Schema with nested object containing vector.
  static TableStructure nestedVectorSchema() {
    return TableStructure('nested_vectors', {
      'name': FieldDefinition(StringType()),
      'metadata': FieldDefinition(
        ObjectType(schema: {
          'model': FieldDefinition(StringType()),
          'version': FieldDefinition(NumberType(format: NumberFormat.integer)),
          'embedding': FieldDefinition(VectorType.f32(384)),
        }),
      ),
    });
  }

  /// Schema with all vector formats.
  static TableStructure allFormatsSchema() {
    return TableStructure('all_formats', {
      'f32_vec': FieldDefinition(VectorType.f32(10)),
      'f64_vec': FieldDefinition(VectorType.f64(10)),
      'i8_vec': FieldDefinition(VectorType.i8(10)),
      'i16_vec': FieldDefinition(VectorType.i16(10)),
      'i32_vec': FieldDefinition(VectorType.i32(10)),
      'i64_vec': FieldDefinition(VectorType.i64(10)),
    });
  }
}

/// Edge case vectors for comprehensive testing.
class EdgeCaseVectors {
  /// Single-dimension vector.
  static VectorValue singleDimension() => VectorValue.f32([1.0]);

  /// Two-dimension vector (minimal for distance calculations).
  static VectorValue twoDimensions() => VectorValue.f32([1.0, 2.0]);

  /// Maximum practical dimension for mobile devices.
  static VectorValue largeMobileDimension() => VectorFixtures.sequentialF32(4096);

  /// Alternating positive/negative values.
  static VectorValue alternating(int dimensions) {
    return VectorValue.f32(
      List.generate(dimensions, (i) => i.isEven ? 1.0 : -1.0),
    );
  }

  /// Vector with mix of very small and very large values.
  static VectorValue mixedScale(int dimensions) {
    return VectorValue.f64(
      List.generate(dimensions, (i) => i.isEven ? 1e-10 : 1e10),
    );
  }

  /// Integer vector at format boundaries.
  static VectorValue i8Boundary() {
    return VectorValue.i8([
      -128, // min
      -1,
      0,
      1,
      127, // max
    ]);
  }

  /// Integer vector at I16 boundaries.
  static VectorValue i16Boundary() {
    return VectorValue.i16([
      -32768, // min
      -1,
      0,
      1,
      32767, // max
    ]);
  }
}
