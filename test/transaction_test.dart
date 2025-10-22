/// Tests for transaction support.
///
/// These tests verify that:
/// - transaction() commits on success
/// - transaction() rolls back on exception
/// - Transaction-scoped database operations work correctly
/// - Callback return value propagates
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Transaction Support', () {
    late Database db;

    setUp(() async {
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('transaction commits on success', () async {
      // Execute transaction
      final result = await db.transaction((txn) async {
        // Create a record within transaction
        final person = await txn.create('person', {
          'name': 'Alice',
          'age': 30,
        });
        return person;
      });

      // Verify the transaction was committed
      expect(result, isNotNull);
      expect(result['name'], 'Alice');
      expect(result['age'], 30);

      // Verify the record exists after transaction
      final persons = await db.select('person');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Alice');
    });

    test('transaction rolls back on exception', () async {
      // First, verify no records exist
      var persons = await db.select('person');
      expect(persons, isEmpty);

      // Execute transaction that throws an exception
      expect(
        () async {
          await db.transaction((txn) async {
            // Create a record
            await txn.create('person', {
              'name': 'Bob',
              'age': 25,
            });

            // Throw an exception to trigger rollback
            throw Exception('Test exception to trigger rollback');
          });
        },
        throwsException,
      );

      // Verify the record was rolled back (should not exist)
      persons = await db.select('person');
      expect(persons, isEmpty);
    });

    test('transaction-scoped database operations', () async {
      // Execute transaction with multiple operations
      final result = await db.transaction((txn) async {
        // Create multiple records within transaction
        final person1 = await txn.create('person', {
          'name': 'Charlie',
          'age': 35,
        });

        final person2 = await txn.create('person', {
          'name': 'Diana',
          'age': 28,
        });

        // Return both IDs
        return {
          'person1_id': person1['id'],
          'person2_id': person2['id'],
        };
      });

      // Verify both records were created
      expect(result['person1_id'], isNotNull);
      expect(result['person2_id'], isNotNull);

      final persons = await db.select('person');
      expect(persons, hasLength(2));
    });

    test('callback return value propagates', () async {
      // Execute transaction and verify return value
      final testValue = {'result': 'success', 'count': 42};

      final result = await db.transaction((txn) async {
        // Create a record but return a different value
        await txn.create('person', {
          'name': 'Eve',
          'age': 32,
        });

        return testValue;
      });

      // Verify the returned value matches
      expect(result, equals(testValue));
      expect(result['result'], 'success');
      expect(result['count'], 42);
    });

    test('transaction with query operations', () async {
      // Setup: Create initial record outside transaction
      await db.create('person', {
        'name': 'Initial',
        'age': 40,
      });

      // Execute transaction with query and update
      await db.transaction((txn) async {
        // Query within transaction
        final persons = await txn.select('person');
        expect(persons, hasLength(1));

        // Update within transaction
        final personId = persons[0]['id'];
        await txn.update(personId, {
          'name': 'Updated',
          'age': 41,
        });
      });

      // Verify the update was committed
      final persons = await db.select('person');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Updated');
      expect(persons[0]['age'], 41);
    });

    test('transaction rollback discards all changes', () async {
      // Create initial record
      await db.create('person', {
        'name': 'Original',
        'age': 50,
      });

      // Verify initial state
      var persons = await db.select('person');
      expect(persons, hasLength(1));

      // Execute transaction that fails
      try {
        await db.transaction((txn) async {
          // Create additional records
          await txn.create('person', {
            'name': 'Should Rollback 1',
            'age': 51,
          });

          await txn.create('person', {
            'name': 'Should Rollback 2',
            'age': 52,
          });

          // Throw exception
          throw Exception('Rollback test');
        });
      } catch (e) {
        // Expected exception
      }

      // Verify only original record remains
      persons = await db.select('person');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Original');
    });

    test('nested operations within transaction', () async {
      // Execute transaction with nested async operations
      final result = await db.transaction((txn) async {
        // Create person
        final person = await txn.create('person', {
          'name': 'Frank',
          'age': 45,
        });

        // Create related account
        final account = await txn.create('account', {
          'owner_id': person['id'],
          'balance': 1000,
        });

        // Create transaction record
        await txn.create('transaction', {
          'account_id': account['id'],
          'amount': 1000,
          'type': 'deposit',
        });

        return {
          'person': person,
          'account': account,
        };
      });

      // Verify all related records were created
      expect(result["person"]!["name"], "Frank");
      expect(result["account"]!["balance"], 1000);

      final persons = await db.select('person');
      final accounts = await db.select('account');
      final transactions = await db.select('transaction');

      expect(persons, hasLength(1));
      expect(accounts, hasLength(1));
      expect(transactions, hasLength(1));
    });

    test('transaction with delete operations', () async {
      // Create records first
      final person1 = await db.create('person', {
        'name': 'ToDelete1',
        'age': 60,
      });

      final person2 = await db.create('person', {
        'name': 'ToDelete2',
        'age': 61,
      });

      // Verify created
      var persons = await db.select('person');
      expect(persons, hasLength(2));

      // Delete within transaction
      await db.transaction((txn) async {
        await txn.delete(person1['id']);
        await txn.delete(person2['id']);
      });

      // Verify both deleted
      persons = await db.select('person');
      expect(persons, isEmpty);
    });
  });
}
