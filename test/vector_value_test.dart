/// Tests for VectorValue class core functionality.
library;

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:surrealdartb/src/types/vector_value.dart';
import 'package:test/test.dart';

void main() {
  group('VectorValue Factory Constructors', () {
    test('fromList creates F32 vector by default', () {
      final vector = VectorValue.fromList([0.1, 0.2, 0.3]);
      expect(vector.dimensions, equals(3));
      expect(vector.format, equals(VectorFormat.f32));
      expect(vector.data, isA<Float32List>());
    });

    test('fromList with explicit format creates correct type', () {
      final vectorF64 = VectorValue.fromList([1.0, 2.0], format: VectorFormat.f64);
      expect(vectorF64.format, equals(VectorFormat.f64));
      expect(vectorF64.data, isA<Float64List>());

      final vectorI16 = VectorValue.fromList([1, 2, 3], format: VectorFormat.i16);
      expect(vectorI16.format, equals(VectorFormat.i16));
      expect(vectorI16.data, isA<Int16List>());
    });

    test('fromString parses vector from string format', () {
      final vector = VectorValue.fromString('[0.1, 0.2, 0.3]');
      expect(vector.dimensions, equals(3));
      expect(vector.data[0], closeTo(0.1, 0.0001));
      expect(vector.data[1], closeTo(0.2, 0.0001));
      expect(vector.data[2], closeTo(0.3, 0.0001));
    });

    test('fromJson creates vector from list', () {
      final vector = VectorValue.fromJson([1.0, 2.0, 3.0]);
      expect(vector.dimensions, equals(3));
      expect(vector.format, equals(VectorFormat.f32));
    });

    test('fromBytes deserializes binary format correctly', () {
      // Create a simple F32 vector: [1.0, 2.0, 3.0]
      final bytes = ByteData(1 + 4 + 12); // format + dimensions + 3 floats
      bytes.setUint8(0, 0); // F32 format
      bytes.setUint32(1, 3, Endian.little); // 3 dimensions
      bytes.setFloat32(5, 1.0, Endian.little);
      bytes.setFloat32(9, 2.0, Endian.little);
      bytes.setFloat32(13, 3.0, Endian.little);

      final vector = VectorValue.fromBytes(bytes.buffer.asUint8List(), VectorFormat.f32);
      expect(vector.dimensions, equals(3));
      expect(vector.format, equals(VectorFormat.f32));
      expect(vector.data[0], closeTo(1.0, 0.0001));
      expect(vector.data[1], closeTo(2.0, 0.0001));
      expect(vector.data[2], closeTo(3.0, 0.0001));
    });
  });

  group('VectorValue Named Constructors', () {
    test('f32 constructor creates Float32 vector', () {
      final vector = VectorValue.f32([0.1, 0.2, 0.3]);
      expect(vector.format, equals(VectorFormat.f32));
      expect(vector.data, isA<Float32List>());
      expect(vector.dimensions, equals(3));
    });

    test('f64 constructor creates Float64 vector', () {
      final vector = VectorValue.f64([0.1, 0.2, 0.3]);
      expect(vector.format, equals(VectorFormat.f64));
      expect(vector.data, isA<Float64List>());
      expect(vector.dimensions, equals(3));
    });

    test('i8 constructor creates Int8 vector', () {
      final vector = VectorValue.i8([1, 2, 3]);
      expect(vector.format, equals(VectorFormat.i8));
      expect(vector.data, isA<Int8List>());
      expect(vector.dimensions, equals(3));
    });

    test('i16 constructor creates Int16 vector', () {
      final vector = VectorValue.i16([100, 200, 300]);
      expect(vector.format, equals(VectorFormat.i16));
      expect(vector.data, isA<Int16List>());
      expect(vector.dimensions, equals(3));
    });

    test('i32 constructor creates Int32 vector', () {
      final vector = VectorValue.i32([1000, 2000, 3000]);
      expect(vector.format, equals(VectorFormat.i32));
      expect(vector.data, isA<Int32List>());
      expect(vector.dimensions, equals(3));
    });

    test('i64 constructor creates Int64 vector', () {
      final vector = VectorValue.i64([100000, 200000, 300000]);
      expect(vector.format, equals(VectorFormat.i64));
      expect(vector.data, isA<Int64List>());
      expect(vector.dimensions, equals(3));
    });

    test('constructors throw ArgumentError for empty lists', () {
      expect(() => VectorValue.f32([]), throwsArgumentError);
      expect(() => VectorValue.i16([]), throwsArgumentError);
    });

    test('constructors throw ArgumentError for NaN values', () {
      expect(() => VectorValue.f32([1.0, double.nan, 3.0]), throwsArgumentError);
      expect(() => VectorValue.f64([double.nan]), throwsArgumentError);
    });

    test('constructors throw ArgumentError for Infinity values', () {
      expect(() => VectorValue.f32([1.0, double.infinity, 3.0]), throwsArgumentError);
      expect(() => VectorValue.f64([double.negativeInfinity]), throwsArgumentError);
    });
  });

  group('VectorValue Accessors', () {
    test('data returns internal typed list', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      final data = vector.data;
      expect(data, isA<Float32List>());
      expect(data.length, equals(3));
    });

    test('dimensions returns correct length', () {
      final vector3 = VectorValue.f32([1.0, 2.0, 3.0]);
      expect(vector3.dimensions, equals(3));

      final vector100 = VectorValue.fromList(List.filled(100, 1.0));
      expect(vector100.dimensions, equals(100));
    });

    test('format returns correct vector format', () {
      expect(VectorValue.f32([1.0]).format, equals(VectorFormat.f32));
      expect(VectorValue.f64([1.0]).format, equals(VectorFormat.f64));
      expect(VectorValue.i8([1]).format, equals(VectorFormat.i8));
      expect(VectorValue.i16([1]).format, equals(VectorFormat.i16));
      expect(VectorValue.i32([1]).format, equals(VectorFormat.i32));
      expect(VectorValue.i64([1]).format, equals(VectorFormat.i64));
    });

    test('toString returns human-readable format', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      final str = vector.toString();
      expect(str, contains('VectorValue'));
      expect(str, contains('f32'));
      expect(str, contains('3'));
    });
  });

  group('VectorValue Serialization', () {
    test('toJson returns List for FFI transport', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      final json = vector.toJson();
      expect(json, isA<List>());
      expect(json.length, equals(3));
      expect(json[0], closeTo(1.0, 0.0001));
      expect(json[1], closeTo(2.0, 0.0001));
      expect(json[2], closeTo(3.0, 0.0001));
    });

    test('toBytes returns binary with format header', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      final bytes = vector.toBytes();
      expect(bytes, isA<Uint8List>());

      // Check format header
      expect(bytes[0], equals(0)); // F32 format

      // Check dimensions (little-endian)
      final dimensions = ByteData.view(bytes.buffer).getUint32(1, Endian.little);
      expect(dimensions, equals(3));
    });

    test('toBinaryOrJson returns JSON for small vectors', () {
      final smallVector = VectorValue.fromList(List.filled(50, 1.0));
      final result = smallVector.toBinaryOrJson();
      expect(result, isA<List>());
    });

    test('toBinaryOrJson returns binary for large vectors', () {
      final largeVector = VectorValue.fromList(List.filled(200, 1.0));
      final result = largeVector.toBinaryOrJson();
      expect(result, isA<Uint8List>());
    });

    test('serialization round-trip works for all formats', () {
      final original = VectorValue.f32([1.0, 2.0, 3.0]);
      final json = original.toJson();
      final restored = VectorValue.fromJson(json, format: VectorFormat.f32);
      expect(restored.dimensions, equals(original.dimensions));
      expect(restored.format, equals(original.format));

      // Binary round-trip
      final bytes = original.toBytes();
      final fromBytes = VectorValue.fromBytes(bytes, VectorFormat.f32);
      expect(fromBytes.dimensions, equals(original.dimensions));
    });
  });

  group('VectorValue Equality', () {
    test('operator == compares element-wise', () {
      final vector1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vector2 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vector3 = VectorValue.f32([1.0, 2.0, 4.0]);

      expect(vector1, equals(vector2));
      expect(vector1, isNot(equals(vector3)));
    });

    test('hashCode is consistent with equality', () {
      final vector1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vector2 = VectorValue.f32([1.0, 2.0, 3.0]);

      expect(vector1.hashCode, equals(vector2.hashCode));
    });

    test('different formats are not equal', () {
      final vectorF32 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vectorF64 = VectorValue.f64([1.0, 2.0, 3.0]);

      expect(vectorF32, isNot(equals(vectorF64)));
    });
  });

  group('VectorValue Validation', () {
    test('validateDimensions returns true for matching dimensions', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      expect(vector.validateDimensions(3), isTrue);
    });

    test('validateDimensions returns false for mismatching dimensions', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      expect(vector.validateDimensions(4), isFalse);
      expect(vector.validateDimensions(2), isFalse);
    });

    test('isNormalized returns true for unit vectors', () {
      // Unit vector in x direction
      final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
      expect(unitVec.isNormalized(), isTrue);

      // Normalized 3D vector
      final norm = 1.0 / math.sqrt(3);
      final normalized = VectorValue.f32([norm, norm, norm]);
      expect(normalized.isNormalized(), isTrue);
    });

    test('isNormalized returns false for non-normalized vectors', () {
      final vector = VectorValue.f32([1.0, 2.0, 3.0]);
      expect(vector.isNormalized(), isFalse);

      final largeVector = VectorValue.f32([10.0, 0.0, 0.0]);
      expect(largeVector.isNormalized(), isFalse);
    });

    test('isNormalized respects tolerance parameter', () {
      // Vector very close to normalized but not exact
      final almostNormalized = VectorValue.f32([0.9999, 0.0, 0.0]);

      // Should fail with default tolerance
      expect(almostNormalized.isNormalized(), isFalse);

      // Should pass with larger tolerance
      expect(almostNormalized.isNormalized(tolerance: 0.01), isTrue);
    });

    test('isNormalized handles zero vectors', () {
      final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
      expect(zeroVec.isNormalized(), isFalse);
    });
  });

  group('VectorValue Math Operations', () {
    test('magnitude returns correct length', () {
      // 3-4-5 triangle
      final vector1 = VectorValue.f32([3.0, 4.0, 0.0]);
      expect(vector1.magnitude(), closeTo(5.0, 0.0001));

      // Unit vector
      final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
      expect(unitVec.magnitude(), closeTo(1.0, 0.0001));

      // All same values
      final vector2 = VectorValue.f32([1.0, 1.0, 1.0]);
      expect(vector2.magnitude(), closeTo(math.sqrt(3), 0.0001));
    });

    test('magnitude returns zero for zero vector', () {
      final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
      expect(zeroVec.magnitude(), equals(0.0));
    });

    test('dotProduct computes correctly with known values', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([4.0, 5.0, 6.0]);

      // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
      expect(vec1.dotProduct(vec2), closeTo(32.0, 0.0001));
    });

    test('dotProduct with orthogonal vectors returns zero', () {
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.0, 1.0, 0.0]);

      expect(vec1.dotProduct(vec2), closeTo(0.0, 0.0001));
    });

    test('dotProduct throws ArgumentError for dimension mismatch', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0]);

      expect(() => vec1.dotProduct(vec2), throwsArgumentError);
    });

    test('normalize returns unit vector', () {
      final vector = VectorValue.f32([3.0, 4.0, 0.0]);
      final normalized = vector.normalize();

      expect(normalized.magnitude(), closeTo(1.0, 0.0001));
      expect(normalized.data[0], closeTo(0.6, 0.0001));
      expect(normalized.data[1], closeTo(0.8, 0.0001));
    });

    test('normalize preserves direction', () {
      final vector = VectorValue.f32([2.0, 2.0, 2.0]);
      final normalized = vector.normalize();

      // All components should be equal (proportional to original)
      final expected = 1.0 / math.sqrt(3);
      expect(normalized.data[0], closeTo(expected, 0.0001));
      expect(normalized.data[1], closeTo(expected, 0.0001));
      expect(normalized.data[2], closeTo(expected, 0.0001));
    });

    test('normalize of unit vector returns unit vector', () {
      final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
      final normalized = unitVec.normalize();

      expect(normalized.magnitude(), closeTo(1.0, 0.0001));
      expect(normalized.data[0], closeTo(1.0, 0.0001));
    });

    test('normalize throws StateError for zero vector', () {
      final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);

      expect(() => zeroVec.normalize(), throwsStateError);
    });

    test('normalize works across different vector formats', () {
      // F64 vector
      final f64Vec = VectorValue.f64([3.0, 4.0, 0.0]);
      final f64Norm = f64Vec.normalize();
      expect(f64Norm.magnitude(), closeTo(1.0, 0.0001));
      expect(f64Norm.format, equals(VectorFormat.f64));

      // Integer vectors should also normalize (converted to double)
      final i16Vec = VectorValue.i16([3, 4, 0]);
      final i16Norm = i16Vec.normalize();
      expect(i16Norm.magnitude(), closeTo(1.0, 0.0001));
    });
  });

  group('VectorValue Distance Calculations', () {
    test('euclidean distance calculates correctly', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

      // sqrt((4-1)^2 + (6-2)^2 + (8-3)^2) = sqrt(9 + 16 + 25) = sqrt(50)
      expect(vec1.euclidean(vec2), closeTo(math.sqrt(50), 0.0001));
    });

    test('euclidean distance is zero for identical vectors', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0, 3.0]);

      expect(vec1.euclidean(vec2), closeTo(0.0, 0.0001));
    });

    test('euclidean throws ArgumentError for dimension mismatch', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0]);

      expect(() => vec1.euclidean(vec2), throwsArgumentError);
    });

    test('manhattan distance calculates correctly', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

      // |4-1| + |6-2| + |8-3| = 3 + 4 + 5 = 12
      expect(vec1.manhattan(vec2), closeTo(12.0, 0.0001));
    });

    test('manhattan distance is zero for identical vectors', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0, 3.0]);

      expect(vec1.manhattan(vec2), closeTo(0.0, 0.0001));
    });

    test('manhattan throws ArgumentError for dimension mismatch', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0]);

      expect(() => vec1.manhattan(vec2), throwsArgumentError);
    });

    test('cosine similarity calculates correctly', () {
      // Parallel vectors should have similarity 1.0
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([2.0, 4.0, 6.0]);

      expect(vec1.cosine(vec2), closeTo(1.0, 0.0001));
    });

    test('cosine similarity for orthogonal vectors is zero', () {
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.0, 1.0, 0.0]);

      expect(vec1.cosine(vec2), closeTo(0.0, 0.0001));
    });

    test('cosine similarity for opposite vectors is -1', () {
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([-1.0, 0.0, 0.0]);

      expect(vec1.cosine(vec2), closeTo(-1.0, 0.0001));
    });

    test('cosine throws ArgumentError for dimension mismatch', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final vec2 = VectorValue.f32([1.0, 2.0]);

      expect(() => vec1.cosine(vec2), throwsArgumentError);
    });

    test('cosine throws StateError for zero vectors', () {
      final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
      final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);

      expect(() => vec1.cosine(zeroVec), throwsStateError);
      expect(() => zeroVec.cosine(vec1), throwsStateError);
    });

    test('distance calculations work across different formats', () {
      final f32Vec = VectorValue.f32([1.0, 2.0, 3.0]);
      final f64Vec = VectorValue.f64([4.0, 6.0, 8.0]);

      // Should work despite different formats
      expect(() => f32Vec.euclidean(f64Vec), returnsNormally);
      expect(() => f32Vec.manhattan(f64Vec), returnsNormally);
      expect(() => f32Vec.cosine(f64Vec), returnsNormally);
    });
  });
}
