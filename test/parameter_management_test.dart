/// Tests for parameter management functionality (Task Group 4.1).
///
/// This test file covers the set() and unset() methods for managing
/// query parameters that can be used in queries with $param_name syntax.
library;

import 'dart:io';

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Task Group 4.1: Parameter Management Tests', () {
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

    test('4.1.1 - Set string parameter and use in query', () async {
      // Set a parameter
      await db.set('name', 'Alice');

      // Create a record to query
      await db.createQL('person', {'name': 'Alice', 'age': 30});

      // Use the parameter in a query
      final response = await db.queryQL('SELECT * FROM person WHERE name = \$name');
      final results = response.getResults();

      expect(results, isNotEmpty);
      expect(results.first['name'], equals('Alice'));
    });

    test('4.1.2 - Set numeric parameter and use in query', () async {
      // Set numeric parameter
      await db.set('min_age', 25);

      // Create records
      await db.createQL('person', {'name': 'Alice', 'age': 30});
      await db.createQL('person', {'name': 'Bob', 'age': 20});

      // Use parameter in query
      final response = await db.queryQL('SELECT * FROM person WHERE age >= \$min_age');
      final results = response.getResults();

      expect(results.length, equals(1));
      expect(results.first['name'], equals('Alice'));
    });

    test('4.1.3 - Set complex object parameter', () async {
      // Set object parameter
      await db.set('filter', {'min_age': 25, 'max_age': 35});

      // Verify parameter was set (by using it in a query)
      final response = await db.queryQL('RETURN \$filter');
      final results = response.getResults();

      expect(results, isNotEmpty);
      final filter = results.first;
      expect(filter['min_age'], equals(25));
      expect(filter['max_age'], equals(35));
    });

    test('4.1.4 - Unset parameter', () async {
      // Set a parameter
      await db.set('temp_value', 42);

      // Verify it exists
      var response = await db.queryQL('RETURN \$temp_value');
      var results = response.getResults();
      expect(results.first, equals(42));

      // Unset the parameter
      await db.unset('temp_value');

      // Verify it's been removed (query should fail or return null)
      try {
        response = await db.queryQL('RETURN \$temp_value');
        results = response.getResults();
        // If query succeeds, parameter should be null
        expect(results.first, isNull);
      } catch (e) {
        // It's also acceptable for the query to fail when parameter doesn't exist
        expect(e, isA<QueryException>());
      }
    });

    test('4.1.5 - Unset non-existent parameter does not error', () async {
      // Unsetting a parameter that doesn't exist should not throw an error
      await expectLater(
        db.unset('non_existent_param'),
        completes,
      );
    });

    test('4.1.6 - Set multiple parameters and use together', () async {
      // Set multiple parameters
      await db.set('min_age', 20);
      await db.set('max_age', 40);
      await db.set('status', 'active');

      // Create records
      await db.createQL('person', {
        'name': 'Alice',
        'age': 25,
        'status': 'active',
      });
      await db.createQL('person', {
        'name': 'Bob',
        'age': 45,
        'status': 'active',
      });
      await db.createQL('person', {
        'name': 'Charlie',
        'age': 30,
        'status': 'inactive',
      });

      // Use multiple parameters in query
      final response = await db.queryQL(
        'SELECT * FROM person WHERE age >= \$min_age AND age <= \$max_age AND status = \$status',
      );
      final results = response.getResults();

      expect(results.length, equals(1));
      expect(results.first['name'], equals('Alice'));
    });

    test('4.1.7 - Overwrite existing parameter', () async {
      // Set initial value
      await db.set('value', 'initial');

      var response = await db.queryQL('RETURN \$value');
      expect(response.getResults().first, equals('initial'));

      // Overwrite with new value
      await db.set('value', 'updated');

      response = await db.queryQL('RETURN \$value');
      expect(response.getResults().first, equals('updated'));
    });

    test('4.1.8 - Set parameter with empty string name throws exception', () async {
      await expectLater(
        db.set('', 'value'),
        throwsA(isA<ParameterException>()),
      );
    });
  });
}
