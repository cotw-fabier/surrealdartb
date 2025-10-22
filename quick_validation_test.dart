/// Quick validation test for deserialization fix
import 'dart:convert';
import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  print('Quick Validation Test - Deserialization Fix');
  print('=' * 60);

  Database? db;

  try {
    print('\n1. Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('   ✓ Connected successfully');

    print('\n2. Creating test record...');
    final person = await db.create('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john@example.com',
      'active': true,
      'tags': ['developer', 'tester'],
      'metadata': {
        'created': '2025-10-21',
        'department': 'Engineering',
      },
    });
    print('   ✓ Record created');
    print('   Record ID: ${person['id']}');
    print('   Full record: ${jsonEncode(person)}');

    print('\n3. Validating field values...');
    assert(person['name'] == 'John Doe', 'Name should be John Doe');
    assert(person['age'] == 30, 'Age should be 30');
    assert(person['email'] == 'john@example.com', 'Email mismatch');
    assert(person['active'] == true, 'Active should be true');
    print('   ✓ All field values are correct and NOT null');

    print('\n4. Checking for type wrappers...');
    final jsonStr = jsonEncode(person);
    assert(!jsonStr.contains('"Strand"'), 'Found Strand type wrapper');
    assert(!jsonStr.contains('"Number"'), 'Found Number type wrapper');
    assert(!jsonStr.contains('"Bool"'), 'Found Bool type wrapper');
    assert(!jsonStr.contains('"Array"'), 'Found Array type wrapper');
    assert(!jsonStr.contains('"Object"'), 'Found Object type wrapper');
    print('   ✓ No type wrappers found in JSON');

    print('\n5. Validating Thing ID format...');
    final id = person['id'] as String;
    assert(id.startsWith('person:'), 'ID should start with "person:"');
    assert(id.length > 7, 'ID should have an identifier part');
    assert(!id.contains('Thing'), 'ID should not contain "Thing" wrapper');
    print('   ✓ Thing ID formatted correctly: $id');

    print('\n6. Testing SELECT query...');
    final persons = await db.select('person');
    assert(persons.isNotEmpty, 'SELECT should return records');
    assert(persons.length == 1, 'Should have 1 record');

    final selectedPerson = persons.first as Map<String, dynamic>;
    assert(selectedPerson['name'] == 'John Doe', 'Selected name mismatch');
    assert(selectedPerson['age'] == 30, 'Selected age mismatch');
    print('   ✓ SELECT returns clean data');

    print('\n7. Testing nested structures...');
    final tags = person['tags'] as List;
    assert(tags.length == 2, 'Should have 2 tags');
    assert(tags[0] == 'developer', 'First tag mismatch');
    assert(tags[1] == 'tester', 'Second tag mismatch');

    final metadata = person['metadata'] as Map<String, dynamic>;
    assert(metadata['created'] == '2025-10-21', 'Created date mismatch');
    assert(metadata['department'] == 'Engineering', 'Department mismatch');
    print('   ✓ Nested structures deserialize correctly');

    print('\n' + '=' * 60);
    print('✓ ALL VALIDATION CHECKS PASSED');
    print('=' * 60);
    print('\nConclusions:');
    print('  • Field values appear correctly (not null)');
    print('  • No type wrapper artifacts in JSON output');
    print('  • Thing IDs formatted as "table:id" strings');
    print('  • Nested structures deserialize properly');
    print('  • Deserialization fix is working correctly!\n');

  } catch (e, stackTrace) {
    print('\n' + '=' * 60);
    print('✗ VALIDATION FAILED');
    print('=' * 60);
    print('Error: $e');
    print('\nStack trace:');
    print(stackTrace);
    print('');
  } finally {
    if (db != null && !db.isClosed) {
      print('Closing database...');
      await db.close();
      print('✓ Database closed\n');
    }
  }
}
