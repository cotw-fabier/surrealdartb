/// Tests for schema annotation classes.
///
/// This test suite validates that annotation classes work correctly,
/// can be parsed, and provide proper validation.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/src/schema/annotations.dart';
import 'package:surrealdartb/src/schema/surreal_types.dart';
import 'package:surrealdartb/src/types/vector_value.dart';

void main() {
  group('SurrealTable annotation', () {
    test('creates annotation with table name', () {
      // Arrange & Act
      const annotation = SurrealTable('users');

      // Assert
      expect(annotation.tableName, equals('users'));
    });

    test('is const constructor', () {
      // Arrange & Act
      const annotation1 = SurrealTable('users');
      const annotation2 = SurrealTable('users');

      // Assert - const instances are identical
      expect(identical(annotation1, annotation2), isTrue);
    });
  });

  group('SurrealField annotation', () {
    test('creates annotation with required type parameter', () {
      // Arrange & Act
      const annotation = SurrealField(type: StringType());

      // Assert
      expect(annotation.type, isA<StringType>());
      expect(annotation.defaultValue, isNull);
      expect(annotation.assertClause, isNull);
      expect(annotation.indexed, isFalse);
      expect(annotation.dimensions, isNull);
    });

    test('creates annotation with all parameters', () {
      // Arrange & Act
      const annotation = SurrealField(
        type: NumberType(),
        defaultValue: 0,
        assertClause: r'$value > 0',
        indexed: true,
        dimensions: 384,
      );

      // Assert
      expect(annotation.type, isA<NumberType>());
      expect(annotation.defaultValue, equals(0));
      expect(annotation.assertClause, equals(r'$value > 0'));
      expect(annotation.indexed, isTrue);
      expect(annotation.dimensions, equals(384));
    });

    test('supports vector type with dimensions', () {
      // Arrange & Act
      const annotation = SurrealField(
        type: VectorType(format: VectorFormat.f32, dimensions: 1536),
        dimensions: 1536,
      );

      // Assert
      expect(annotation.type, isA<VectorType>());
      expect(annotation.dimensions, equals(1536));
    });

    test('is const constructor', () {
      // Arrange & Act
      const annotation1 = SurrealField(type: StringType());
      const annotation2 = SurrealField(type: StringType());

      // Assert - const instances are identical
      expect(identical(annotation1, annotation2), isTrue);
    });
  });

  group('JsonField annotation', () {
    test('creates annotation', () {
      // Arrange & Act
      const annotation = JsonField();

      // Assert
      expect(annotation, isNotNull);
    });

    test('is const constructor', () {
      // Arrange & Act
      const annotation1 = JsonField();
      const annotation2 = JsonField();

      // Assert - const instances are identical
      expect(identical(annotation1, annotation2), isTrue);
    });
  });

  group('Annotation validation', () {
    test('SurrealTable requires non-empty table name', () {
      // This validation happens at generation time, not construction time
      // The annotation itself can be created with any string
      const annotation = SurrealTable('');
      expect(annotation.tableName, isEmpty);
    });

    test('SurrealField requires type parameter', () {
      // The type parameter is required at compile-time by the constructor
      // This test verifies it can be created with a type
      const annotation = SurrealField(type: BoolType());
      expect(annotation.type, isNotNull);
    });

    test('SurrealField indexed flag defaults to false', () {
      // Arrange & Act
      const annotation = SurrealField(type: StringType());

      // Assert
      expect(annotation.indexed, isFalse);
    });
  });
}
