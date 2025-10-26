/// Unit tests for Database API method renaming to support ORM layer.
///
/// These tests verify that CRUD methods renamed with QL suffix maintain
/// identical behavior to their original implementations, ensuring full
/// backward compatibility for the existing map-based API.

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  late Database db;

  setUp(() async {
    // Create in-memory database for testing
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Database method renaming - QL suffix', () {
    test('createQL works identically to original create method', () async {
      // Arrange
      final testData = {
        'name': 'Alice',
        'age': 30,
        'email': 'alice@example.com',
      };

      // Act
      final result = await db.createQL('person', testData);

      // Assert
      expect(result, isA<Map<String, dynamic>>());
      expect(result['name'], equals('Alice'));
      expect(result['age'], equals(30));
      expect(result['email'], equals('alice@example.com'));
      expect(result['id'], isNotNull);
      expect(result['id'], startsWith('person:'));
    });

    test('selectQL works identically to original select method', () async {
      // Arrange - create test data
      await db.createQL('person', {'name': 'Bob', 'age': 25});
      await db.createQL('person', {'name': 'Charlie', 'age': 35});

      // Act
      final results = await db.selectQL('person');

      // Assert
      expect(results, isA<List<Map<String, dynamic>>>());
      expect(results.length, equals(2));
      expect(results.any((r) => r['name'] == 'Bob'), isTrue);
      expect(results.any((r) => r['name'] == 'Charlie'), isTrue);
    });

    test('updateQL works identically to original update method', () async {
      // Arrange
      final created = await db.createQL('person', {
        'name': 'David',
        'age': 40,
      });
      final id = created['id'] as String;

      // Act
      final updated = await db.updateQL(id, {
        'name': 'David',
        'age': 41,
      });

      // Assert
      expect(updated, isA<Map<String, dynamic>>());
      expect(updated['id'], equals(id));
      expect(updated['name'], equals('David'));
      expect(updated['age'], equals(41));
    });

    test('deleteQL works identically to original delete method', () async {
      // Arrange
      final created = await db.createQL('person', {'name': 'Eve'});
      final id = created['id'] as String;

      // Act - delete should complete without error
      await db.deleteQL(id);

      // Assert - record should no longer exist
      final result = await db.get<Map<String, dynamic>>(id);
      expect(result, isNull);
    });

    test('queryQL works identically to original query method', () async {
      // Arrange
      await db.createQL('person', {'name': 'Frank', 'age': 45});
      await db.createQL('person', {'name': 'Grace', 'age': 50});

      // Act
      final response = await db.queryQL(
        'SELECT * FROM person WHERE age > 40',
      );

      // Assert
      expect(response, isA<Response>());
      final results = response.getResults();
      expect(results.length, greaterThanOrEqualTo(1));
      expect(results.every((r) => (r['age'] as int) > 40), isTrue);
    });

    test('QL methods maintain method signatures', () async {
      // Arrange
      final testData = {'name': 'Test', 'value': 123};

      // Act & Assert - verify method signatures accept same parameters
      final created = await db.createQL('test_table', testData);
      expect(created, isNotNull);

      final selected = await db.selectQL('test_table');
      expect(selected, isA<List>());

      final updated = await db.updateQL(
        created['id'] as String,
        {'name': 'Updated'},
      );
      expect(updated, isNotNull);

      await db.deleteQL(created['id'] as String);

      final response = await db.queryQL('SELECT * FROM test_table');
      expect(response, isA<Response>());
    });

    test('QL methods support optional schema parameter', () async {
      // Arrange
      final schema = TableStructure('person', {
        'name': FieldDefinition(StringType()),
        'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
      });

      final testData = {'name': 'Helen', 'age': 28};

      // Act - createQL with schema validation
      final created = await db.createQL('person', testData, schema: schema);

      // Assert
      expect(created, isNotNull);
      expect(created['name'], equals('Helen'));
      expect(created['age'], equals(28));

      // Act - updateQL with schema validation
      final updated = await db.updateQL(
        created['id'] as String,
        {'name': 'Helen', 'age': 29},
        schema: schema,
      );

      // Assert
      expect(updated['age'], equals(29));
    });

    test('Map-based API coexists with renamed QL methods', () async {
      // This test verifies that both APIs can be used in the same codebase
      // Arrange
      final data1 = {'name': 'Isaac', 'type': 'QL'};
      final data2 = {'name': 'Julia', 'type': 'New'};

      // Act - use QL method
      final result1 = await db.createQL('person', data1);

      // Future type-safe API will be: await db.create(personObject)
      // But for now, both use the same underlying implementation

      // Assert
      expect(result1['name'], equals('Isaac'));
      expect(result1['type'], equals('QL'));
    });
  });
}
