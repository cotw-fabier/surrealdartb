/// Simple inline validation for deserialization fix
import 'dart:convert';
import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  print('\n=== SIMPLE DESERIALIZATION VALIDATION ===\n');

  Database? db;
  bool allTestsPassed = true;

  try {
    // 1. Connect
    print('[1/7] Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('      PASS - Connected\n');

    // 2. Create record
    print('[2/7] Creating test record...');
    final person = await db.create('person', {
      'name': 'Alice',
      'age': 25,
      'email': 'alice@test.com',
      'active': true,
    });
    print('      Created: ${jsonEncode(person)}\n');

    // 3. Validate field values
    print('[3/7] Validating field values are not null...');
    if (person['name'] == null) {
      print('      FAIL - name is null!');
      allTestsPassed = false;
    } else if (person['name'] != 'Alice') {
      print('      FAIL - name is "${person['name']}", expected "Alice"');
      allTestsPassed = false;
    } else {
      print('      PASS - name = "${person['name']}"');
    }

    if (person['age'] == null) {
      print('      FAIL - age is null!');
      allTestsPassed = false;
    } else if (person['age'] != 25) {
      print('      FAIL - age is ${person['age']}, expected 25');
      allTestsPassed = false;
    } else {
      print('      PASS - age = ${person['age']}');
    }

    if (person['email'] == null) {
      print('      FAIL - email is null!');
      allTestsPassed = false;
    } else if (person['email'] != 'alice@test.com') {
      print('      FAIL - email is "${person['email']}", expected "alice@test.com"');
      allTestsPassed = false;
    } else {
      print('      PASS - email = "${person['email']}"');
    }

    if (person['active'] == null) {
      print('      FAIL - active is null!');
      allTestsPassed = false;
    } else if (person['active'] != true) {
      print('      FAIL - active is ${person['active']}, expected true');
      allTestsPassed = false;
    } else {
      print('      PASS - active = ${person['active']}');
    }
    print('');

    // 4. Check for type wrappers
    print('[4/7] Checking for type wrapper artifacts...');
    final jsonStr = jsonEncode(person);
    final wrappers = <String>[];

    if (jsonStr.contains('"Strand"')) wrappers.add('Strand');
    if (jsonStr.contains('"Number"')) wrappers.add('Number');
    if (jsonStr.contains('"Bool"')) wrappers.add('Bool');
    if (jsonStr.contains('"Object"')) wrappers.add('Object');
    if (jsonStr.contains('"Array"')) wrappers.add('Array');
    if (jsonStr.contains('"Thing"')) wrappers.add('Thing');

    if (wrappers.isNotEmpty) {
      print('      FAIL - Found type wrappers: ${wrappers.join(", ")}');
      allTestsPassed = false;
    } else {
      print('      PASS - No type wrappers found');
    }
    print('');

    // 5. Validate Thing ID format
    print('[5/7] Validating Thing ID format...');
    final id = person['id'];
    if (id == null) {
      print('      FAIL - id is null!');
      allTestsPassed = false;
    } else if (id is! String) {
      print('      FAIL - id is not a String, it is ${id.runtimeType}');
      allTestsPassed = false;
    } else if (!id.startsWith('person:')) {
      print('      FAIL - id "$id" does not start with "person:"');
      allTestsPassed = false;
    } else if (id.contains('Thing')) {
      print('      FAIL - id "$id" contains "Thing" wrapper');
      allTestsPassed = false;
    } else {
      print('      PASS - id = "$id" (correct format)');
    }
    print('');

    // 6. Test SELECT query
    print('[6/7] Testing SELECT query...');
    final persons = await db.select('person');
    if (persons.isEmpty) {
      print('      FAIL - SELECT returned no records');
      allTestsPassed = false;
    } else {
      final selectedPerson = persons.first as Map<String, dynamic>;
      if (selectedPerson['name'] != 'Alice') {
        print('      FAIL - SELECT returned wrong name: "${selectedPerson['name']}"');
        allTestsPassed = false;
      } else {
        print('      PASS - SELECT returned correct data');
      }
    }
    print('');

    // 7. Test UPDATE
    print('[7/7] Testing UPDATE...');
    final updated = await db.update(person['id'] as String, {
      'name': 'Alice',
      'age': 26,
      'email': 'alice@test.com',
      'active': true,
    });
    if (updated['age'] != 26) {
      print('      FAIL - UPDATE failed, age is ${updated['age']}');
      allTestsPassed = false;
    } else {
      print('      PASS - UPDATE successful, age = ${updated['age']}');
    }
    print('');

    // Final result
    print('=== VALIDATION RESULT ===\n');
    if (allTestsPassed) {
      print('✓ ALL TESTS PASSED');
      print('\nConclusions:');
      print('  • Field values appear correctly (not null)');
      print('  • No type wrapper artifacts in JSON');
      print('  • Thing IDs formatted as "table:id"');
      print('  • Deserialization fix is WORKING!\n');
    } else {
      print('✗ SOME TESTS FAILED');
      print('\nThe deserialization fix still has issues.\n');
    }

  } catch (e, stackTrace) {
    print('\n✗ EXCEPTION OCCURRED\n');
    print('Error: $e\n');
    print('Stack trace:');
    print(stackTrace);
    print('');
    allTestsPassed = false;
  } finally {
    if (db != null && !db.isClosed) {
      await db.close();
    }
  }

  // Exit with appropriate code
  if (!allTestsPassed) {
    throw Exception('Validation failed');
  }
}
