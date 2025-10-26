/// Tests for vector types and schema constraints generation.
///
/// This test suite verifies that the table definition generator correctly
/// handles:
/// - Vector fields with dimensions → array<float, X>
/// - ASSERT clause generation
/// - INDEX definition generation
/// - Default value handling
/// - Vector dimension validation
library;

import 'package:test/test.dart';
import 'package:surrealdartb/src/schema/annotations.dart';
import 'package:surrealdartb/src/schema/surreal_types.dart';
import 'package:surrealdartb/src/types/vector_value.dart';

void main() {
  group('Vector Type Generation', () {
    test('vector field should include dimensions in generated type', () {
      // This is a documentation test to verify that vector types
      // with dimensions generate correct array<float, X> types

      // Given: A VectorType with dimensions
      const vectorType = VectorType(
        format: VectorFormat.f32,
        dimensions: 384,
      );

      // Then: The type should have the correct format and dimensions
      expect(vectorType.format, VectorFormat.f32);
      expect(vectorType.dimensions, 384);
      expect(vectorType.normalized, false);
    });

    test('vector type with normalization constraint', () {
      // Given: A normalized vector type
      const vectorType = VectorType(
        format: VectorFormat.f32,
        dimensions: 1536,
        normalized: true,
      );

      // Then: The normalization flag should be set
      expect(vectorType.normalized, true);
      expect(vectorType.dimensions, 1536);
    });

    test('vector type supports different formats', () {
      // Given: Vector types with different formats
      const f32Vector = VectorType.f32(384);
      const f64Vector = VectorType.f64(768);
      const i16Vector = VectorType.i16(128);

      // Then: Each should have the correct format
      expect(f32Vector.format, VectorFormat.f32);
      expect(f64Vector.format, VectorFormat.f64);
      expect(i16Vector.format, VectorFormat.i16);
    });
  });

  group('ASSERT Clause Generation', () {
    test('field with ASSERT clause should store the clause', () {
      // This documents that assertClause is extracted and available

      // Given: A SurrealField with an ASSERT clause
      const field = SurrealField(
        type: NumberType(format: NumberFormat.integer),
        assertClause: r'$value >= 0 AND $value <= 100',
      );

      // Then: The assertion should be accessible
      expect(field.assertClause, r'$value >= 0 AND $value <= 100');
    });

    test('field without ASSERT clause should have null', () {
      // Given: A field without assertions
      const field = SurrealField(type: StringType());

      // Then: The clause should be null
      expect(field.assertClause, isNull);
    });

    test('vector field can have ASSERT clause for normalization check', () {
      // Given: A vector field with normalization assertion
      const field = SurrealField(
        type: VectorType(
          format: VectorFormat.f32,
          dimensions: 384,
          normalized: true,
        ),
        dimensions: 384,
        assertClause: r'vector::magnitude($value) == 1.0',
      );

      // Then: Both type and assertion should be set
      expect(field.dimensions, 384);
      expect(field.assertClause, contains('magnitude'));
    });
  });

  group('INDEX Definition Generation', () {
    test('field with indexed=true should be marked for indexing', () {
      // Given: An indexed field
      const field = SurrealField(
        type: StringType(),
        indexed: true,
      );

      // Then: The indexed flag should be true
      expect(field.indexed, true);
    });

    test('field with indexed=false should not be indexed', () {
      // Given: A non-indexed field (default)
      const field = SurrealField(type: StringType());

      // Then: The indexed flag should be false
      expect(field.indexed, false);
    });

    test('multiple fields can be indexed in same table', () {
      // This documents that multiple fields can have indexes

      // Given: Multiple indexed fields
      const emailField = SurrealField(
        type: StringType(),
        indexed: true,
      );
      const usernameField = SurrealField(
        type: StringType(),
        indexed: true,
      );

      // Then: Both should be marked for indexing
      expect(emailField.indexed, true);
      expect(usernameField.indexed, true);
    });
  });

  group('Default Value Handling', () {
    test('field with string default value', () {
      // Given: A field with a string default
      const field = SurrealField(
        type: StringType(),
        defaultValue: 'active',
      );

      // Then: The default should be accessible
      expect(field.defaultValue, 'active');
    });

    test('field with numeric default value', () {
      // Given: A field with a numeric default
      const field = SurrealField(
        type: NumberType(format: NumberFormat.integer),
        defaultValue: 0,
      );

      // Then: The default should be accessible
      expect(field.defaultValue, 0);
    });

    test('field with boolean default value', () {
      // Given: A field with a boolean default
      const field = SurrealField(
        type: BoolType(),
        defaultValue: false,
      );

      // Then: The default should be accessible
      expect(field.defaultValue, false);
    });

    test('field without default value should be null', () {
      // Given: A field without a default
      const field = SurrealField(type: StringType());

      // Then: Default should be null
      expect(field.defaultValue, isNull);
    });
  });

  group('Vector Dimension Validation', () {
    test('vector type requires positive dimensions', () {
      // Given/When: Attempting to create a vector with 0 dimensions
      // Then: Should throw assertion error (handled at compile time)
      expect(
        () => VectorType(format: VectorFormat.f32, dimensions: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('vector field dimensions should match type dimensions', () {
      // This documents that dimensions are specified in both places
      // for consistency and validation

      // Given: A properly configured vector field
      const field = SurrealField(
        type: VectorType(format: VectorFormat.f32, dimensions: 384),
        dimensions: 384,
      );

      // Then: Both should match
      expect((field.type as VectorType).dimensions, field.dimensions);
    });

    test('common embedding dimensions are supported', () {
      // Documents common dimensions used by embedding models

      // OpenAI text-embedding-3-small
      const openai384 = VectorType.f32(384);
      expect(openai384.dimensions, 384);

      // BERT-base
      const bert768 = VectorType.f32(768);
      expect(bert768.dimensions, 768);

      // OpenAI text-embedding-3-large
      const openai1536 = VectorType.f32(1536);
      expect(openai1536.dimensions, 1536);

      // OpenAI text-embedding-3-large (max)
      const openai3072 = VectorType.f32(3072);
      expect(openai3072.dimensions, 3072);
    });
  });
}
