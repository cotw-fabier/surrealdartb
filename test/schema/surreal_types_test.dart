/// Tests for SurrealDB type system.
///
/// These tests verify that:
/// - All type classes can be instantiated correctly
/// - VectorType supports all formats with proper constraints
/// - FieldDefinition works with type constraints
/// - Type system provides comprehensive coverage of SurrealDB types
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Scalar Types', () {
    test('StringType can be instantiated', () {
      // Arrange & Act
      const stringType = StringType();

      // Assert
      expect(stringType, isA<StringType>());
      expect(stringType, isA<SurrealType>());
    });

    test('NumberType without format accepts any numeric format', () {
      // Arrange & Act
      const numberType = NumberType();

      // Assert
      expect(numberType, isA<NumberType>());
      expect(numberType.format, isNull);
    });

    test('NumberType with integer format', () {
      // Arrange & Act
      const numberType = NumberType(format: NumberFormat.integer);

      // Assert
      expect(numberType, isA<NumberType>());
      expect(numberType.format, NumberFormat.integer);
    });

    test('NumberType with floating format', () {
      // Arrange & Act
      const numberType = NumberType(format: NumberFormat.floating);

      // Assert
      expect(numberType, isA<NumberType>());
      expect(numberType.format, NumberFormat.floating);
    });

    test('NumberType with decimal format', () {
      // Arrange & Act
      const numberType = NumberType(format: NumberFormat.decimal);

      // Assert
      expect(numberType, isA<NumberType>());
      expect(numberType.format, NumberFormat.decimal);
    });

    test('BoolType can be instantiated', () {
      // Arrange & Act
      const boolType = BoolType();

      // Assert
      expect(boolType, isA<BoolType>());
      expect(boolType, isA<SurrealType>());
    });

    test('DatetimeType can be instantiated', () {
      // Arrange & Act
      const datetimeType = DatetimeType();

      // Assert
      expect(datetimeType, isA<DatetimeType>());
      expect(datetimeType, isA<SurrealType>());
    });

    test('DurationType can be instantiated', () {
      // Arrange & Act
      const durationType = DurationType();

      // Assert
      expect(durationType, isA<DurationType>());
      expect(durationType, isA<SurrealType>());
    });
  });

  group('Collection Types', () {
    test('ArrayType with element type', () {
      // Arrange & Act
      const arrayType = ArrayType(StringType());

      // Assert
      expect(arrayType, isA<ArrayType>());
      expect(arrayType.elementType, isA<StringType>());
      expect(arrayType.length, isNull);
    });

    test('ArrayType with fixed length', () {
      // Arrange & Act
      const arrayType = ArrayType(
        NumberType(format: NumberFormat.integer),
        length: 3,
      );

      // Assert
      expect(arrayType, isA<ArrayType>());
      expect(arrayType.elementType, isA<NumberType>());
      expect(arrayType.length, 3);
    });

    test('ArrayType can be nested', () {
      // Arrange & Act
      const arrayType = ArrayType(ArrayType(NumberType()));

      // Assert
      expect(arrayType, isA<ArrayType>());
      expect(arrayType.elementType, isA<ArrayType>());
      final innerArray = arrayType.elementType as ArrayType;
      expect(innerArray.elementType, isA<NumberType>());
    });

    test('ObjectType without schema is schemaless', () {
      // Arrange & Act
      const objectType = ObjectType();

      // Assert
      expect(objectType, isA<ObjectType>());
      expect(objectType.schema, isNull);
    });

    test('ObjectType with schema', () {
      // Arrange & Act
      const objectType = ObjectType(schema: {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      // Assert
      expect(objectType, isA<ObjectType>());
      expect(objectType.schema, isNotNull);
      expect(objectType.schema!.length, 2);
      expect(objectType.schema!['name'], isA<FieldDefinition>());
      expect(objectType.schema!['age'], isA<FieldDefinition>());
    });
  });

  group('Special Types', () {
    test('RecordType without table constraint', () {
      // Arrange & Act
      const recordType = RecordType();

      // Assert
      expect(recordType, isA<RecordType>());
      expect(recordType.table, isNull);
    });

    test('RecordType with table constraint', () {
      // Arrange & Act
      const recordType = RecordType(table: 'person');

      // Assert
      expect(recordType, isA<RecordType>());
      expect(recordType.table, 'person');
    });

    test('GeometryType without kind constraint', () {
      // Arrange & Act
      const geometryType = GeometryType();

      // Assert
      expect(geometryType, isA<GeometryType>());
      expect(geometryType.kind, isNull);
    });

    test('GeometryType with point kind', () {
      // Arrange & Act
      const geometryType = GeometryType(kind: GeometryKind.point);

      // Assert
      expect(geometryType, isA<GeometryType>());
      expect(geometryType.kind, GeometryKind.point);
    });

    test('GeometryType supports all geometry kinds', () {
      // Test all enum values
      expect(GeometryKind.point, isA<GeometryKind>());
      expect(GeometryKind.line, isA<GeometryKind>());
      expect(GeometryKind.polygon, isA<GeometryKind>());
      expect(GeometryKind.multipoint, isA<GeometryKind>());
      expect(GeometryKind.multiline, isA<GeometryKind>());
      expect(GeometryKind.multipolygon, isA<GeometryKind>());
      expect(GeometryKind.collection, isA<GeometryKind>());
    });

    test('AnyType can be instantiated', () {
      // Arrange & Act
      const anyType = AnyType();

      // Assert
      expect(anyType, isA<AnyType>());
      expect(anyType, isA<SurrealType>());
    });
  });

  group('VectorType', () {
    test('VectorType.f32 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.f32(1536);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.f32);
      expect(vectorType.dimensions, 1536);
      expect(vectorType.normalized, false);
    });

    test('VectorType.f32 with normalization', () {
      // Arrange & Act
      const vectorType = VectorType.f32(768, normalized: true);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.f32);
      expect(vectorType.dimensions, 768);
      expect(vectorType.normalized, true);
    });

    test('VectorType.f64 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.f64(384);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.f64);
      expect(vectorType.dimensions, 384);
      expect(vectorType.normalized, false);
    });

    test('VectorType.i8 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.i8(128);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.i8);
      expect(vectorType.dimensions, 128);
      expect(vectorType.normalized, false);
    });

    test('VectorType.i16 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.i16(256);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.i16);
      expect(vectorType.dimensions, 256);
      expect(vectorType.normalized, false);
    });

    test('VectorType.i32 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.i32(512);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.i32);
      expect(vectorType.dimensions, 512);
      expect(vectorType.normalized, false);
    });

    test('VectorType.i64 constructor', () {
      // Arrange & Act
      const vectorType = VectorType.i64(1024);

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.i64);
      expect(vectorType.dimensions, 1024);
      expect(vectorType.normalized, false);
    });

    test('VectorType with explicit format', () {
      // Arrange & Act
      const vectorType = VectorType(
        format: VectorFormat.f32,
        dimensions: 1536,
        normalized: true,
      );

      // Assert
      expect(vectorType, isA<VectorType>());
      expect(vectorType.format, VectorFormat.f32);
      expect(vectorType.dimensions, 1536);
      expect(vectorType.normalized, true);
    });

    test('VectorFormat enum has all expected values', () {
      // Test all vector formats are available
      expect(VectorFormat.f32, isA<VectorFormat>());
      expect(VectorFormat.f64, isA<VectorFormat>());
      expect(VectorFormat.i8, isA<VectorFormat>());
      expect(VectorFormat.i16, isA<VectorFormat>());
      expect(VectorFormat.i32, isA<VectorFormat>());
      expect(VectorFormat.i64, isA<VectorFormat>());
    });
  });

  group('FieldDefinition', () {
    test('creates required field with type', () {
      // Arrange & Act
      const field = FieldDefinition(StringType());

      // Assert
      expect(field, isA<FieldDefinition>());
      expect(field.type, isA<StringType>());
      expect(field.optional, false);
      expect(field.defaultValue, isNull);
    });

    test('creates optional field', () {
      // Arrange & Act
      const field = FieldDefinition(
        NumberType(format: NumberFormat.integer),
        optional: true,
      );

      // Assert
      expect(field, isA<FieldDefinition>());
      expect(field.type, isA<NumberType>());
      expect(field.optional, true);
      expect(field.defaultValue, isNull);
    });

    test('creates field with default value', () {
      // Arrange & Act
      const field = FieldDefinition(
        NumberType(format: NumberFormat.integer),
        optional: true,
        defaultValue: 0,
      );

      // Assert
      expect(field, isA<FieldDefinition>());
      expect(field.type, isA<NumberType>());
      expect(field.optional, true);
      expect(field.defaultValue, 0);
    });

    test('works with complex types', () {
      // Arrange & Act
      const field = FieldDefinition(
        VectorType.f32(1536, normalized: true),
        optional: false,
      );

      // Assert
      expect(field, isA<FieldDefinition>());
      expect(field.type, isA<VectorType>());
      final vectorType = field.type as VectorType;
      expect(vectorType.format, VectorFormat.f32);
      expect(vectorType.dimensions, 1536);
      expect(vectorType.normalized, true);
    });

    test('works with nested collection types', () {
      // Arrange & Act
      const field = FieldDefinition(
        ArrayType(ObjectType(schema: {
          'x': FieldDefinition(NumberType()),
          'y': FieldDefinition(NumberType()),
        })),
        optional: true,
      );

      // Assert
      expect(field, isA<FieldDefinition>());
      expect(field.type, isA<ArrayType>());
      final arrayType = field.type as ArrayType;
      expect(arrayType.elementType, isA<ObjectType>());
      final objectType = arrayType.elementType as ObjectType;
      expect(objectType.schema, isNotNull);
      expect(objectType.schema!.length, 2);
    });
  });

  group('Type System Integration', () {
    test('can define complete table schema', () {
      // Arrange & Act - Define a documents table schema
      final schema = {
        'id': FieldDefinition(RecordType(table: 'documents')),
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'embedding': FieldDefinition(
          VectorType.f32(1536, normalized: true),
          optional: false,
        ),
        'metadata': FieldDefinition(
          ObjectType(schema: {
            'author': FieldDefinition(StringType()),
            'created_at': FieldDefinition(DatetimeType()),
            'tags': FieldDefinition(
              ArrayType(StringType()),
              optional: true,
            ),
          }),
          optional: true,
        ),
        'published': FieldDefinition(BoolType(), defaultValue: false),
      };

      // Assert
      expect(schema, isNotNull);
      expect(schema.length, 6);
      expect(schema['title']!.type, isA<StringType>());
      expect(schema['embedding']!.type, isA<VectorType>());
      expect(schema['metadata']!.type, isA<ObjectType>());
      expect(schema['published']!.defaultValue, false);
    });

    test('sealed class enables exhaustive pattern matching', () {
      // Arrange
      const types = <SurrealType>[
        StringType(),
        NumberType(),
        BoolType(),
        DatetimeType(),
        DurationType(),
        ArrayType(StringType()),
        ObjectType(),
        RecordType(),
        GeometryType(),
        VectorType.f32(128),
        AnyType(),
      ];

      // Act - Use switch expression for exhaustive matching
      for (final type in types) {
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

        // Assert
        expect(typeName, isNotEmpty);
      }
    });
  });
}
