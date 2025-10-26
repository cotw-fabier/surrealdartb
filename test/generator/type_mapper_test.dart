/// Tests for the type mapper that converts Dart types to SurrealDB types.
///
/// This test suite validates that the type mapper correctly translates Dart
/// primitive types to their corresponding SurrealDB type expressions.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/generator/type_mapper.dart';

void main() {
  group('TypeMapper - Basic Type Mapping', () {
    late TypeMapper mapper;

    setUp(() {
      mapper = TypeMapper();
    });

    test('maps String to string type', () {
      final result = mapper.mapDartTypeToSurreal('String');
      expect(result, equals('StringType()'));
    });

    test('maps int to int type', () {
      final result = mapper.mapDartTypeToSurreal('int');
      expect(result, equals('NumberType(format: NumberFormat.integer)'));
    });

    test('maps double to float type', () {
      final result = mapper.mapDartTypeToSurreal('double');
      expect(result, equals('NumberType(format: NumberFormat.floating)'));
    });

    test('maps bool to bool type', () {
      final result = mapper.mapDartTypeToSurreal('bool');
      expect(result, equals('BoolType()'));
    });

    test('maps DateTime to datetime type', () {
      final result = mapper.mapDartTypeToSurreal('DateTime');
      expect(result, equals('DatetimeType()'));
    });

    test('maps Duration to duration type', () {
      final result = mapper.mapDartTypeToSurreal('Duration');
      expect(result, equals('DurationType()'));
    });

    test('throws error for unsupported type', () {
      expect(
        () => mapper.mapDartTypeToSurreal('UnsupportedType'),
        throwsA(isA<UnsupportedTypeException>()),
      );
    });

    test('error message includes type name for unsupported types', () {
      try {
        mapper.mapDartTypeToSurreal('CustomClass');
        fail('Expected UnsupportedTypeException');
      } catch (e) {
        expect(e, isA<UnsupportedTypeException>());
        expect(
          e.toString(),
          contains('CustomClass'),
        );
      }
    });
  });
}
