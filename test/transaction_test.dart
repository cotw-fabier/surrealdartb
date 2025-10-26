/// Tests for transaction support.
///
/// These tests verify that:
/// - transaction() commits on success
/// - transaction() rolls back on exception
/// - Transaction-scoped database operations work correctly
/// - Callback return value propagates
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:surrealdartb/src/ffi/bindings.dart' as bindings;

void main() {
  // Initialize Rust logger before any tests run
  setUpAll(() {
    print('[INIT] Initializing Rust logger...');
    bindings.initLogger();
    print('[INIT] Rust logger initialized. Set RUST_LOG=info to see Rust logs.');
  });

  group('Transaction Support', () {
    late Database db;

    setUp(() async {
      print('[TEST SETUP] Creating database connection...');
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
      print('[TEST SETUP] Database connected successfully');
    });

    tearDown(() async {
      print('[TEST TEARDOWN] Closing database connection...');
      await db.close();
      print('[TEST TEARDOWN] Database closed');
    });

    test('transaction commits on success', () async {
      print('\n[TEST] Starting: transaction commits on success');

      // Execute transaction
      final result = await db.transaction((txn) async {
        print('[TEST] Inside transaction: creating person record...');
        // Create a record within transaction
        final person = await txn.create('person', {
          'name': 'Alice',
          'age': 30,
        });
        print('[TEST] Created person: $person');
        return person;
      });

      print('[TEST] Transaction completed, result: $result');

      // Verify the transaction was committed
      expect(result, isNotNull);
      expect(result['name'], 'Alice');
      expect(result['age'], 30);

      // Verify the record exists after transaction
      print('[TEST] Verifying record exists after commit...');
      final persons = await db.select('person');
      print('[TEST] Records found: $persons');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Alice');
      print('[TEST] Test completed successfully\n');
    });

    test('transaction rolls back on exception', () async {
      print('\n[TEST] Starting: transaction rolls back on exception');

      // First, verify no records exist
      var persons = await db.select('person');
      print('[TEST] Initial person count: ${persons.length}');
      expect(persons, isEmpty);

      // Execute transaction that throws an exception
      print('[TEST] Executing transaction that will throw exception...');
      expect(
        () async {
          await db.transaction((txn) async {
            // Create a record
            print('[TEST] Inside transaction: creating person record...');
            final person = await txn.create('person', {
              'name': 'Bob',
              'age': 25,
            });
            print('[TEST] Created person: $person');

            // Throw an exception to trigger rollback
            print('[TEST] Throwing exception to trigger rollback...');
            throw Exception('Test exception to trigger rollback');
          });
        },
        throwsException,
      );
      print('[TEST] Exception was thrown as expected');

      // Verify the record was rolled back (should not exist)
      print('[TEST] Verifying record was rolled back...');
      persons = await db.select('person');
      print('[TEST] Person count after rollback: ${persons.length}');
      print('[TEST] Records found: $persons');
      expect(persons, isEmpty);
      print('[TEST] Test completed successfully\n');
    });

    test('transaction-scoped database operations', () async {
      print('\n[TEST] Starting: transaction-scoped database operations');

      // Execute transaction with multiple operations
      final result = await db.transaction((txn) async {
        // Create multiple records within transaction
        print('[TEST] Creating person 1...');
        final person1 = await txn.create('person', {
          'name': 'Charlie',
          'age': 35,
        });
        print('[TEST] Created person1: $person1');

        print('[TEST] Creating person 2...');
        final person2 = await txn.create('person', {
          'name': 'Diana',
          'age': 28,
        });
        print('[TEST] Created person2: $person2');

        // Return both IDs
        return {
          'person1_id': person1['id'],
          'person2_id': person2['id'],
        };
      });

      print('[TEST] Transaction completed, result: $result');

      // Verify both records were created
      expect(result['person1_id'], isNotNull);
      expect(result['person2_id'], isNotNull);

      print('[TEST] Verifying both records exist...');
      final persons = await db.select('person');
      print('[TEST] Records found: ${persons.length}');
      expect(persons, hasLength(2));
      print('[TEST] Test completed successfully\n');
    });

    test('callback return value propagates', () async {
      print('\n[TEST] Starting: callback return value propagates');

      // Execute transaction and verify return value
      final testValue = {'result': 'success', 'count': 42};

      final result = await db.transaction((txn) async {
        // Create a record but return a different value
        print('[TEST] Creating person in transaction...');
        await txn.create('person', {
          'name': 'Eve',
          'age': 32,
        });
        print('[TEST] Returning test value: $testValue');

        return testValue;
      });

      print('[TEST] Transaction completed, result: $result');

      // Verify the returned value matches
      expect(result, equals(testValue));
      expect(result['result'], 'success');
      expect(result['count'], 42);
      print('[TEST] Test completed successfully\n');
    });

    test('transaction with query operations', () async {
      print('\n[TEST] Starting: transaction with query operations');

      // Setup: Create initial record outside transaction
      print('[TEST] Creating initial record outside transaction...');
      await db.create('person', {
        'name': 'Initial',
        'age': 40,
      });

      // Execute transaction with query and update
      await db.transaction((txn) async {
        // Query within transaction
        print('[TEST] Querying persons within transaction...');
        final persons = await txn.select('person');
        print('[TEST] Found ${persons.length} persons');
        expect(persons, hasLength(1));

        // Update within transaction
        final personId = persons[0]['id'];
        print('[TEST] Updating person: $personId');
        await txn.update(personId, {
          'name': 'Updated',
          'age': 41,
        });
        print('[TEST] Update completed');
      });

      // Verify the update was committed
      print('[TEST] Verifying update was committed...');
      final persons = await db.select('person');
      print('[TEST] Records found: $persons');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Updated');
      expect(persons[0]['age'], 41);
      print('[TEST] Test completed successfully\n');
    });

    test('transaction rollback discards all changes', () async {
      print('\n[TEST] Starting: transaction rollback discards all changes');

      // Create initial record
      print('[TEST] Creating initial record...');
      await db.create('person', {
        'name': 'Original',
        'age': 50,
      });

      // Verify initial state
      var persons = await db.select('person');
      print('[TEST] Initial state: ${persons.length} records');
      print('[TEST] Initial records: $persons');
      expect(persons, hasLength(1));

      // Execute transaction that fails
      print('[TEST] Executing transaction that will fail...');
      try {
        await db.transaction((txn) async {
          // Create additional records
          print('[TEST] Creating person 1 in transaction...');
          final p1 = await txn.create('person', {
            'name': 'Should Rollback 1',
            'age': 51,
          });
          print('[TEST] Created person 1: $p1');

          print('[TEST] Creating person 2 in transaction...');
          final p2 = await txn.create('person', {
            'name': 'Should Rollback 2',
            'age': 52,
          });
          print('[TEST] Created person 2: $p2');

          // Check state before exception
          print('[TEST] Checking state before exception...');
          final personsInTxn = await txn.select('person');
          print('[TEST] Records visible in transaction: ${personsInTxn.length}');
          print('[TEST] Records: $personsInTxn');

          // Throw exception
          print('[TEST] Throwing exception to trigger rollback...');
          throw Exception('Rollback test');
        });
      } catch (e) {
        // Expected exception
        print('[TEST] Caught expected exception: $e');
      }

      // Verify only original record remains
      print('[TEST] Verifying rollback completed...');
      persons = await db.select('person');
      print('[TEST] Final state: ${persons.length} records');
      print('[TEST] Final records: $persons');
      expect(persons, hasLength(1));
      expect(persons[0]['name'], 'Original');
      print('[TEST] Test completed successfully\n');
    });

    test('nested operations within transaction', () async {
      print('\n[TEST] Starting: nested operations within transaction');

      // Execute transaction with nested async operations
      final result = await db.transaction((txn) async {
        // Create person
        print('[TEST] Creating person...');
        final person = await txn.create('person', {
          'name': 'Frank',
          'age': 45,
        });
        print('[TEST] Created person: $person');

        // Create related account
        print('[TEST] Creating account...');
        final account = await txn.create('account', {
          'owner_id': person['id'],
          'balance': 1000,
        });
        print('[TEST] Created account: $account');

        // Create transaction record
        print('[TEST] Creating transaction record...');
        await txn.create('transaction', {
          'account_id': account['id'],
          'amount': 1000,
          'type': 'deposit',
        });
        print('[TEST] Created transaction record');

        return {
          'person': person,
          'account': account,
        };
      });

      print('[TEST] Transaction completed, result: $result');

      // Verify all related records were created
      expect(result["person"]!["name"], "Frank");
      expect(result["account"]!["balance"], 1000);

      print('[TEST] Verifying all records exist...');
      final persons = await db.select('person');
      final accounts = await db.select('account');
      final transactions = await db.select('transaction');

      print('[TEST] Persons: ${persons.length}, Accounts: ${accounts.length}, Transactions: ${transactions.length}');
      expect(persons, hasLength(1));
      expect(accounts, hasLength(1));
      expect(transactions, hasLength(1));
      print('[TEST] Test completed successfully\n');
    });

    test('transaction with delete operations', () async {
      print('\n[TEST] Starting: transaction with delete operations');

      // Create records first
      print('[TEST] Creating person 1...');
      final person1 = await db.create('person', {
        'name': 'ToDelete1',
        'age': 60,
      });
      print('[TEST] Created person1: $person1');

      print('[TEST] Creating person 2...');
      final person2 = await db.create('person', {
        'name': 'ToDelete2',
        'age': 61,
      });
      print('[TEST] Created person2: $person2');

      // Verify created
      var persons = await db.select('person');
      print('[TEST] Initial record count: ${persons.length}');
      expect(persons, hasLength(2));

      // Delete within transaction
      print('[TEST] Executing transaction with deletes...');
      await db.transaction((txn) async {
        print('[TEST] Deleting person 1...');
        await txn.delete(person1['id']);
        print('[TEST] Deleting person 2...');
        await txn.delete(person2['id']);
        print('[TEST] Deletes completed');
      });

      // Verify both deleted
      print('[TEST] Verifying deletes were committed...');
      persons = await db.select('person');
      print('[TEST] Final record count: ${persons.length}');
      expect(persons, isEmpty);
      print('[TEST] Test completed successfully\n');
    });
  });
}
