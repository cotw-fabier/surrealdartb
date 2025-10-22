import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  print('Starting debug test...');

  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    print('Connected. Creating record...');

    final person = await db.create('person', {
      'name': 'Test Person',
      'age': 25,
    });

    print('SUCCESS! Created record: $person');
    print('  Name: ${person['name']}');
    print('  Age: ${person['age']}');
    print('  ID: ${person['id']}');
  } catch (e, stack) {
    print('ERROR: $e');
    print('Stack: $stack');
  } finally {
    print('Closing database...');
    await db.close();
    print('Done!');
  }
}
