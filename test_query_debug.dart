import 'package:surrealdartb/surrealdartb.dart';

void main() async {
  print('Starting query debug test...');

  try {
    print('Step 1: Connecting to database...');
    final db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );

    print('Step 2: Connected successfully!');

    print('Step 3: About to execute query: INFO FOR DB;');
    final response = await db.query('INFO FOR DB;').timeout(
      Duration(seconds: 5),
      onTimeout: () {
        print('TIMEOUT: Query took longer than 5 seconds');
        throw Exception('Query timeout');
      },
    );

    print('Step 4: Query completed! Results: ${response.getResults()}');

    await db.close();
    print('Step 5: Database closed successfully');
  } catch (e, st) {
    print('ERROR: $e');
    print('Stack trace: $st');
  }
}
