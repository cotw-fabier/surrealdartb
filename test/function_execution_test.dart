/// Tests for function execution functionality (Task Group 4.2).
///
/// This test file covers the run() and version() methods for executing
/// SurrealQL functions with optional arguments.
library;

import 'dart:io';

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Task Group 4.2: Function Execution Tests', () {
    late Database db;

    setUp(() async {
      // Use in-memory database for faster tests
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
      // Small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('4.2.1 - Execute rand::float function with no arguments', () async {
      final result = await db.run<double>('rand::float');

      expect(result, isA<double>());
      expect(result, greaterThanOrEqualTo(0.0));
      expect(result, lessThan(1.0));
    });

    test('4.2.2 - Execute rand::int function with arguments', () async {
      final result = await db.run<int>('rand::int', [1, 10]);

      expect(result, isA<int>());
      expect(result, greaterThanOrEqualTo(1));
      expect(result, lessThanOrEqualTo(10));
    });

    test('4.2.3 - Execute string::uppercase function', () async {
      final result = await db.run<String>('string::uppercase', ['hello world']);

      expect(result, equals('HELLO WORLD'));
    });

    test('4.2.4 - Execute string::lowercase function', () async {
      final result = await db.run<String>('string::lowercase', ['HELLO WORLD']);

      expect(result, equals('hello world'));
    });

    test('4.2.5 - Execute math::abs function', () async {
      final result = await db.run<int>('math::abs', [-42]);

      expect(result, equals(42));
    });

    test('4.2.6 - Execute array::len function', () async {
      final result = await db.run<int>('array::len', [
        [1, 2, 3, 4, 5]
      ]);

      expect(result, equals(5));
    });

    test('4.2.7 - Get database version', () async {
      final version = await db.version();

      expect(version, isA<String>());
      expect(version, isNotEmpty);
      // Version should match pattern like "1.5.0" or "2.0.0"
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });

    test('4.2.8 - Execute function that returns null', () async {
      // Using type::string to convert null to "null" string
      final result = await db.run<dynamic>('type::thing', ['person', null]);

      // The result should be a Thing (record ID) or null
      expect(result, anyOf(isNull, isA<String>()));
    });
  });
}
