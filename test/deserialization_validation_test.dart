/// Validation tests for Task Group 2: Basic CRUD Validation
///
/// These tests verify that the deserialization fix (using serde_json::to_value())
/// correctly produces clean JSON output without type wrappers.
///
/// Test Focus:
/// - SELECT returns clean JSON (no type wrappers like "Strand", "Number", etc.)
/// - CREATE returns records with correct field values (not null)
/// - Nested structures deserialize properly (objects in arrays, arrays in objects)
/// - Thing IDs formatted as "table:id" strings
library;

import 'dart:convert';
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 2: Deserialization Validation Tests', () {
    late Database db;

    setUp(() async {
      // Connect to in-memory database before each test
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Clean up database connection after each test
      if (!db.isClosed) {
        await db.close();
      }
    });

    test('Test 1: SELECT returns clean JSON (no type wrappers)', () async {
      // Create a test record with various data types
      final createResponse = await db.create('person', {
        'name': 'Alice Smith',
        'age': 28,
        'isActive': true,
        'email': 'alice@example.com',
      });

      expect(createResponse, isA<Map<String, dynamic>>());
      expect(createResponse['name'], equals('Alice Smith'));

      // Now SELECT and verify response format
      final selectResponse = await db.select('person');

      expect(selectResponse, isA<List>());
      expect(selectResponse, isNotEmpty);

      final record = selectResponse.first as Map<String, dynamic>;

      // Verify no type wrapper artifacts
      expect(record['name'], isA<String>());
      expect(record['name'], equals('Alice Smith'));
      expect(record['name'], isNot(contains('Strand')));

      expect(record['age'], isA<num>());
      expect(record['age'], equals(28));
      expect(record['age'].toString(), isNot(contains('Number')));

      expect(record['isActive'], isA<bool>());
      expect(record['isActive'], equals(true));

      expect(record['email'], isA<String>());
      expect(record['email'], equals('alice@example.com'));

      // Verify the raw JSON representation doesn't contain type wrappers
      final jsonString = jsonEncode(record);
      expect(jsonString, isNot(contains('"Strand"')));
      expect(jsonString, isNot(contains('"Number"')));
      expect(jsonString, isNot(contains('"Bool"')));
    });

    test('Test 2: CREATE returns record with correct field values (not null)',
        () async {
      // Create record with multiple field types
      final record = await db.create('product', {
        'name': 'Laptop',
        'price': 999.99,
        'quantity': 42,
        'inStock': true,
        'tags': ['electronics', 'computers'],
        'specs': {
          'cpu': 'Intel i7',
          'ram': '16GB',
          'storage': '512GB SSD',
        },
      });

      // Verify record structure
      expect(record, isA<Map<String, dynamic>>());

      // Verify all fields are NOT null and have correct types
      expect(record['name'], isNotNull);
      expect(record['name'], equals('Laptop'));
      expect(record['name'], isA<String>());

      expect(record['price'], isNotNull);
      expect(record['price'], equals(999.99));
      expect(record['price'], isA<num>());

      expect(record['quantity'], isNotNull);
      expect(record['quantity'], equals(42));
      expect(record['quantity'], isA<int>());

      expect(record['inStock'], isNotNull);
      expect(record['inStock'], equals(true));
      expect(record['inStock'], isA<bool>());

      expect(record['tags'], isNotNull);
      expect(record['tags'], isA<List>());
      expect((record['tags'] as List).length, equals(2));

      expect(record['specs'], isNotNull);
      expect(record['specs'], isA<Map>());

      // Verify nested object fields
      final specs = record['specs'] as Map<String, dynamic>;
      expect(specs['cpu'], equals('Intel i7'));
      expect(specs['ram'], equals('16GB'));
      expect(specs['storage'], equals('512GB SSD'));

      // All values should be clean - not wrapped in type tags
      expect(specs['cpu'], isA<String>());
      expect(specs['cpu'], isNot(contains('Strand')));
    });

    test('Test 3: Nested structures deserialize properly', () async {
      // Create record with complex nested structure
      final complexRecord = await db.create('order', {
        'orderId': 'ORD-12345',
        'customer': {
          'name': 'Bob Johnson',
          'address': {
            'street': '123 Main St',
            'city': 'San Francisco',
            'state': 'CA',
            'zip': '94102',
          },
          'contactNumbers': ['+1-555-1234', '+1-555-5678'],
        },
        'items': [
          {
            'product': 'Widget A',
            'quantity': 2,
            'price': 19.99,
          },
          {
            'product': 'Widget B',
            'quantity': 1,
            'price': 29.99,
          },
        ],
        'total': 69.97,
      });

      expect(complexRecord, isA<Map<String, dynamic>>());

      // Verify nested object (customer)
      expect(complexRecord['customer'], isNotNull);
      expect(complexRecord['customer'], isA<Map>());

      final customer = complexRecord['customer'] as Map<String, dynamic>;
      expect(customer['name'], equals('Bob Johnson'));
      expect(customer['name'], isA<String>());

      // Verify deeply nested object (address)
      expect(customer['address'], isNotNull);
      expect(customer['address'], isA<Map>());

      final address = customer['address'] as Map<String, dynamic>;
      expect(address['street'], equals('123 Main St'));
      expect(address['city'], equals('San Francisco'));
      expect(address['state'], equals('CA'));
      expect(address['zip'], equals('94102'));

      // Verify all address fields are clean strings
      expect(address['street'], isA<String>());
      expect(address['city'], isA<String>());
      expect(address['state'], isA<String>());
      expect(address['zip'], isA<String>());

      // Verify array in object (contactNumbers)
      expect(customer['contactNumbers'], isNotNull);
      expect(customer['contactNumbers'], isA<List>());

      final numbers = customer['contactNumbers'] as List;
      expect(numbers.length, equals(2));
      expect(numbers[0], equals('+1-555-1234'));
      expect(numbers[1], equals('+1-555-5678'));
      expect(numbers[0], isA<String>());
      expect(numbers[1], isA<String>());

      // Verify array of objects (items)
      expect(complexRecord['items'], isNotNull);
      expect(complexRecord['items'], isA<List>());

      final items = complexRecord['items'] as List;
      expect(items.length, equals(2));

      final item1 = items[0] as Map<String, dynamic>;
      expect(item1['product'], equals('Widget A'));
      expect(item1['quantity'], equals(2));
      expect(item1['price'], equals(19.99));

      final item2 = items[1] as Map<String, dynamic>;
      expect(item2['product'], equals('Widget B'));
      expect(item2['quantity'], equals(1));
      expect(item2['price'], equals(29.99));

      // Verify no type wrappers in complex structure
      final jsonString = jsonEncode(complexRecord);
      expect(jsonString, isNot(contains('"Strand"')));
      expect(jsonString, isNot(contains('"Number"')));
      expect(jsonString, isNot(contains('"Object"')));
      expect(jsonString, isNot(contains('"Array"')));
    });

    test('Test 4: Thing IDs formatted as "table:id" strings', () async {
      // Create multiple records
      final person1 = await db.create('person', {
        'name': 'Charlie',
        'age': 35,
      });

      final person2 = await db.create('person', {
        'name': 'Diana',
        'age': 42,
      });

      // Verify IDs exist and are properly formatted
      expect(person1['id'], isNotNull);
      expect(person1['id'], isA<String>());

      final id1 = person1['id'] as String;
      expect(id1, matches(RegExp(r'^person:[a-zA-Z0-9]+$')));
      expect(id1, startsWith('person:'));

      expect(person2['id'], isNotNull);
      expect(person2['id'], isA<String>());

      final id2 = person2['id'] as String;
      expect(id2, matches(RegExp(r'^person:[a-zA-Z0-9]+$')));
      expect(id2, startsWith('person:'));

      // IDs should be different
      expect(id1, isNot(equals(id2)));

      // Query with SELECT and verify IDs remain in correct format
      final persons = await db.select('person');
      expect(persons.length, equals(2));

      for (final person in persons) {
        final personMap = person as Map<String, dynamic>;
        expect(personMap['id'], isNotNull);
        expect(personMap['id'], isA<String>());

        final personId = personMap['id'] as String;
        expect(personId, matches(RegExp(r'^person:[a-zA-Z0-9]+$')));
        expect(personId, startsWith('person:'));

        // Verify no Thing type wrapper artifacts
        expect(personId, isNot(contains('Thing')));
        expect(personId, isNot(contains('{')));
        expect(personId, isNot(contains('}')));
      }

      // Use raw query to verify ID format is consistent
      final queryResponse = await db.query('SELECT id FROM person');
      final queryResults = queryResponse.getResults();

      expect(queryResults, isNotEmpty);
      final queryResult = queryResults.first as List;

      for (final item in queryResult) {
        final itemMap = item as Map<String, dynamic>;
        expect(itemMap['id'], isNotNull);
        expect(itemMap['id'], isA<String>());

        final itemId = itemMap['id'] as String;
        expect(itemId, matches(RegExp(r'^person:[a-zA-Z0-9]+$')));
      }
    });
  });
}
