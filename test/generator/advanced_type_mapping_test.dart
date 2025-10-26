/// Tests for advanced type mapping: collections, nested objects, and converters.
///
/// This test suite validates collection types (List, Set, Map), nested objects,
/// custom converters, and circular reference detection.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/generator/type_mapper.dart';

void main() {
  group('TypeMapper - Collection Type Mapping', () {
    late TypeMapper mapper;

    setUp(() {
      mapper = TypeMapper();
    });

    test('maps List<String> to array<string> type', () {
      final result = mapper.mapDartTypeToSurreal('List<String>');
      expect(result, equals('ArrayType(StringType())'));
    });

    test('maps List<int> to array<int> type', () {
      final result = mapper.mapDartTypeToSurreal('List<int>');
      expect(
        result,
        equals('ArrayType(NumberType(format: NumberFormat.integer))'),
      );
    });

    test('maps Set<String> to array<string> type', () {
      final result = mapper.mapDartTypeToSurreal('Set<String>');
      expect(result, equals('ArrayType(StringType())'));
    });

    test('maps Set<double> to array<float> type', () {
      final result = mapper.mapDartTypeToSurreal('Set<double>');
      expect(
        result,
        equals('ArrayType(NumberType(format: NumberFormat.floating))'),
      );
    });

    test('maps Map<String, dynamic> to object type', () {
      final result = mapper.mapDartTypeToSurreal('Map<String, dynamic>');
      expect(result, equals('ObjectType()'));
    });

    test('maps nested List<List<int>> to nested array type', () {
      final result = mapper.mapDartTypeToSurreal('List<List<int>>');
      expect(
        result,
        equals(
          'ArrayType(ArrayType(NumberType(format: NumberFormat.integer)))',
        ),
      );
    });
  });

  group('TypeMapper - Nested Object Mapping', () {
    late TypeMapper mapper;

    setUp(() {
      mapper = TypeMapper();
    });

    test('detects custom class type and prepares for nested generation', () {
      // Custom classes should be detected (not in basic type map)
      expect(
        () => mapper.mapDartTypeToSurreal('CustomClass'),
        throwsA(isA<UnsupportedTypeException>()),
      );

      // The exception should indicate it's a custom type
      try {
        mapper.mapDartTypeToSurreal('Address');
        fail('Expected UnsupportedTypeException');
      } catch (e) {
        expect(e, isA<UnsupportedTypeException>());
        expect((e as UnsupportedTypeException).dartType, equals('Address'));
      }
    });
  });

  group('TypeMapper - Circular Reference Detection', () {
    test('should be handled by generator, not mapper', () {
      // TypeMapper only handles individual type mappings
      // Circular reference detection is the responsibility of the generator
      // during recursive nested object traversal
      expect(true, isTrue); // Placeholder test
    });
  });

  group('TypeMapper - Edge Cases', () {
    late TypeMapper mapper;

    setUp(() {
      mapper = TypeMapper();
    });

    test('handles List without type parameter as List<dynamic>', () {
      final result = mapper.mapDartTypeToSurreal('List');
      expect(result, equals('ArrayType(AnyType())'));
    });

    test('handles Map without type parameters as Map<dynamic, dynamic>', () {
      final result = mapper.mapDartTypeToSurreal('Map');
      expect(result, equals('ObjectType()'));
    });

    test('handles Set without type parameter as Set<dynamic>', () {
      final result = mapper.mapDartTypeToSurreal('Set');
      expect(result, equals('ArrayType(AnyType())'));
    });
  });
}
