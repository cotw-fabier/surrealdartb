/// Tests for TableStructure validation and schema definition.
///
/// These tests verify that:
/// - Required field validation works correctly
/// - Optional field handling works as expected
/// - Vector dimension validation catches mismatches
/// - Vector normalization validation works
/// - Nested object schema validation functions properly
/// - Type mismatch errors provide clear messages
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('TableStructure Construction', () {
    test('creates table structure with valid name and fields', () {
      // Arrange & Act
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      // Assert
      expect(schema.tableName, 'users');
      expect(schema.fields.length, 2);
      expect(schema.hasField('name'), true);
      expect(schema.hasField('age'), true);
    });

    test('throws ArgumentError for empty table name', () {
      // Arrange & Act & Assert
      expect(
        () => TableStructure('', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError for invalid table name with spaces', () {
      // Arrange & Act & Assert
      expect(
        () => TableStructure('invalid name', {}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts table name with underscores', () {
      // Arrange & Act
      final schema = TableStructure('user_profiles', {});

      // Assert
      expect(schema.tableName, 'user_profiles');
    });
  });

  group('Required Field Validation', () {
    test('validates successfully when all required fields are present', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final data = {'name': 'Alice', 'age': 30};

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('throws ValidationException when required field is missing', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final data = {'name': 'Bob'}; // Missing 'age'

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'age')
              .having((e) => e.constraint, 'constraint', 'required')
              .having((e) => e.message, 'message', contains("Required field 'age' is missing")),
        ),
      );
    });

    test('provides clear error message for missing required field', () {
      // Arrange
      final schema = TableStructure('products', {
        'title': FieldDefinition(StringType()),
        'price': FieldDefinition(NumberType()),
      });

      final data = {'title': 'Widget'}; // Missing 'price'

      // Act & Assert
      try {
        schema.validate(data);
        fail('Expected ValidationException');
      } catch (e) {
        expect(e, isA<ValidationException>());
        final exception = e as ValidationException;
        expect(exception.fieldName, 'price');
        expect(exception.constraint, 'required');
        expect(exception.message, contains('price'));
      }
    });
  });

  group('Optional Field Validation', () {
    test('validates successfully when optional field is omitted', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), optional: true),
      });

      final data = {'name': 'Charlie'}; // No 'email'

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('validates successfully when optional field is provided', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), optional: true),
      });

      final data = {'name': 'Dana', 'email': 'dana@example.com'};

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('validates type of optional field when provided', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(), optional: true),
      });

      final data = {'name': 'Eve', 'age': 'not a number'}; // Wrong type

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'age')
              .having((e) => e.constraint, 'constraint', 'type_mismatch'),
        ),
      );
    });
  });

  group('Vector Dimension Validation', () {
    test('validates vector with correct dimensions', () {
      // Arrange
      final schema = TableStructure('documents', {
        'title': FieldDefinition(StringType()),
        'embedding': FieldDefinition(VectorType.f32(384)),
      });

      final embedding = VectorValue.fromList(List.filled(384, 0.1));
      final data = {'title': 'Test Doc', 'embedding': embedding.toJson()};

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('throws ValidationException for dimension mismatch', () {
      // Arrange
      final schema = TableStructure('documents', {
        'embedding': FieldDefinition(VectorType.f32(1536)),
      });

      final embedding = VectorValue.fromList(List.filled(768, 0.1)); // Wrong dimensions
      final data = {'embedding': embedding.toJson()};

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'embedding')
              .having((e) => e.constraint, 'constraint', 'dimension_mismatch')
              .having((e) => e.message, 'message', contains('768'))
              .having((e) => e.message, 'message', contains('1536')),
        ),
      );
    });

    test('provides clear error message with expected vs actual dimensions', () {
      // Arrange
      final schema = TableStructure('embeddings', {
        'vector': FieldDefinition(VectorType.f32(512)),
      });

      final vector = VectorValue.fromList(List.filled(256, 0.5));
      final data = {'vector': vector.toJson()};

      // Act & Assert
      try {
        schema.validate(data);
        fail('Expected ValidationException');
      } catch (e) {
        expect(e, isA<ValidationException>());
        final exception = e as ValidationException;
        expect(exception.message, contains('256 dimensions'));
        expect(exception.message, contains('expected 512'));
      }
    });
  });

  group('Vector Normalization Validation', () {
    test('validates normalized vector when normalization required', () {
      // Arrange
      final schema = TableStructure('documents', {
        'embedding': FieldDefinition(VectorType.f32(3, normalized: true)),
      });

      // Create a normalized vector (magnitude 1.0)
      final embedding = VectorValue.fromList([1.0, 0.0, 0.0]); // Unit vector
      final data = {'embedding': embedding.toJson()};

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('throws ValidationException for non-normalized vector when normalization required', () {
      // Arrange
      final schema = TableStructure('documents', {
        'embedding': FieldDefinition(VectorType.f32(3, normalized: true)),
      });

      // Create a non-normalized vector
      final embedding = VectorValue.fromList([2.0, 3.0, 4.0]); // magnitude > 1
      final data = {'embedding': embedding.toJson()};

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'embedding')
              .having((e) => e.constraint, 'constraint', 'not_normalized')
              .having((e) => e.message, 'message', contains('normalized')),
        ),
      );
    });

    test('accepts non-normalized vector when normalization not required', () {
      // Arrange
      final schema = TableStructure('vectors', {
        'data': FieldDefinition(VectorType.f32(3, normalized: false)),
      });

      final vector = VectorValue.fromList([5.0, 10.0, 15.0]); // Not normalized
      final data = {'data': vector.toJson()};

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });
  });

  group('Nested Object Schema Validation', () {
    test('validates nested object with schema', () {
      // Arrange
      final schema = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'metadata': FieldDefinition(
          ObjectType(schema: {
            'category': FieldDefinition(StringType()),
            'tags': FieldDefinition(ArrayType(StringType()), optional: true),
          }),
        ),
      });

      final data = {
        'name': 'Widget',
        'metadata': {
          'category': 'Tools',
          'tags': ['hardware', 'tools'],
        },
      };

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('validates required fields in nested object', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'address': FieldDefinition(
          ObjectType(schema: {
            'street': FieldDefinition(StringType()),
            'city': FieldDefinition(StringType()),
          }),
        ),
      });

      final data = {
        'name': 'Frank',
        'address': {
          'street': '123 Main St',
          // Missing 'city'
        },
      };

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'address.city')
              .having((e) => e.constraint, 'constraint', 'required'),
        ),
      );
    });

    test('validates optional fields in nested object', () {
      // Arrange
      final schema = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'details': FieldDefinition(
          ObjectType(schema: {
            'description': FieldDefinition(StringType()),
            'notes': FieldDefinition(StringType(), optional: true),
          }),
          optional: true,
        ),
      });

      final data = {
        'name': 'Gadget',
        'details': {
          'description': 'A useful gadget',
          // 'notes' omitted (optional)
        },
      };

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });
  });

  group('Type Mismatch Error Messages', () {
    test('provides clear error for string field with wrong type', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
      });

      final data = {'name': 123}; // Number instead of string

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('must be a String'))
              .having((e) => e.message, 'message', contains('int')),
        ),
      );
    });

    test('provides clear error for number field with wrong type', () {
      // Arrange
      final schema = TableStructure('users', {
        'age': FieldDefinition(NumberType()),
      });

      final data = {'age': 'thirty'}; // String instead of number

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('must be a number'))
              .having((e) => e.message, 'message', contains('String')),
        ),
      );
    });

    test('provides clear error for array field with wrong type', () {
      // Arrange
      final schema = TableStructure('posts', {
        'tags': FieldDefinition(ArrayType(StringType())),
      });

      final data = {'tags': 'not an array'}; // String instead of List

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.message, 'message', contains('must be a List'))
              .having((e) => e.constraint, 'constraint', 'type_mismatch'),
        ),
      );
    });

    test('provides clear error for vector field with wrong type', () {
      // Arrange
      final schema = TableStructure('vectors', {
        'embedding': FieldDefinition(VectorType.f32(128)),
      });

      final data = {'embedding': 'not a vector'}; // String instead of vector

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'embedding')
              .having((e) => e.constraint, 'constraint', 'type_mismatch'),
        ),
      );
    });
  });

  group('Helper Methods', () {
    test('hasField returns true for existing field', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
      });

      // Act & Assert
      expect(schema.hasField('name'), true);
      expect(schema.hasField('nonexistent'), false);
    });

    test('getField returns field definition', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
      });

      // Act
      final field = schema.getField('name');

      // Assert
      expect(field, isNotNull);
      expect(field!.type, isA<StringType>());
    });

    test('getRequiredFields returns list of required fields', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType()),
        'email': FieldDefinition(StringType(), optional: true),
      });

      // Act
      final required = schema.getRequiredFields();

      // Assert
      expect(required, hasLength(2));
      expect(required, containsAll(['name', 'age']));
      expect(required, isNot(contains('email')));
    });

    test('getOptionalFields returns list of optional fields', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), optional: true),
        'phone': FieldDefinition(StringType(), optional: true),
      });

      // Act
      final optional = schema.getOptionalFields();

      // Assert
      expect(optional, hasLength(2));
      expect(optional, containsAll(['email', 'phone']));
      expect(optional, isNot(contains('name')));
    });
  });

  group('SurrealQL Generation', () {
    test('generates basic table definition', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      // Act
      final sql = schema.toSurrealQL();

      // Assert
      expect(sql, contains('DEFINE TABLE users SCHEMAFULL'));
      expect(sql, contains('DEFINE FIELD name ON TABLE users TYPE string'));
      expect(sql, contains('DEFINE FIELD age ON TABLE users TYPE int'));
    });

    test('includes vector type in SurrealQL', () {
      // Arrange
      final schema = TableStructure('documents', {
        'embedding': FieldDefinition(VectorType.f32(1536)),
      });

      // Act
      final sql = schema.toSurrealQL();

      // Assert
      expect(sql, contains('vector<F32, 1536>'));
    });

    test('marks required fields with ASSERT', () {
      // Arrange
      final schema = TableStructure('users', {
        'name': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), optional: true),
      });

      // Act
      final sql = schema.toSurrealQL();

      // Assert
      expect(sql, contains('DEFINE FIELD name ON TABLE users TYPE string ASSERT'));
      // Optional field should not have ASSERT
      final emailLine = sql.split('\n').firstWhere((line) => line.contains('email'));
      expect(emailLine, isNot(contains('ASSERT')));
    });
  });
}
