/// Tests for upsert operations (Task Group 2.2).
///
/// This test file covers upsert operations with multiple variants:
/// - upsert().content() for full replacement
/// - upsert().merge() for field merging
/// - upsert().patch() with PatchOp operations
///
/// These tests focus on critical functionality only.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  late Database db;

  setUp(() async {
    // Create an in-memory database for each test
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Upsert Content', () {
    test('replaces entire record with upsertContent()', () async {
      // Create initial record
      final created = await db.create('person', {
        'name': 'Alice',
        'age': 25,
        'email': 'alice@example.com',
      });

      final id = created['id'] as String;

      // Upsert with completely new content
      final result = await db.upsertContent(id, {
        'name': 'Alice Updated',
        'age': 26,
        'city': 'New York',
      });

      // Verify the record was replaced (email should be gone)
      expect(result['name'], equals('Alice Updated'));
      expect(result['age'], equals(26));
      expect(result['city'], equals('New York'));
      expect(result.containsKey('email'), isFalse);
    });

    test('creates record if it does not exist with upsertContent()', () async {
      // Upsert a non-existent record
      final result = await db.upsertContent('person:bob', {
        'name': 'Bob',
        'age': 30,
      });

      expect(result['id'], equals('person:bob'));
      expect(result['name'], equals('Bob'));
      expect(result['age'], equals(30));
    });
  });

  group('Upsert Merge', () {
    test('merges fields with upsertMerge()', () async {
      // Create initial record
      final created = await db.create('person', {
        'name': 'Charlie',
        'age': 28,
        'email': 'charlie@example.com',
      });

      final id = created['id'] as String;

      // Merge new fields (email should remain)
      final result = await db.upsertMerge(id, {
        'age': 29,
        'city': 'Boston',
      });

      // Verify only specified fields were updated
      expect(result['name'], equals('Charlie'));
      expect(result['age'], equals(29));
      expect(result['email'], equals('charlie@example.com'));
      expect(result['city'], equals('Boston'));
    });

    test('creates record if it does not exist with upsertMerge()', () async {
      // Merge into a non-existent record
      final result = await db.upsertMerge('person:diana', {
        'name': 'Diana',
        'age': 35,
      });

      expect(result['id'], equals('person:diana'));
      expect(result['name'], equals('Diana'));
      expect(result['age'], equals(35));
    });
  });

  group('Upsert Patch', () {
    test('applies PatchOp operations with upsertPatch()', () async {
      // Create initial record
      final created = await db.create('person', {
        'name': 'Eve',
        'age': 22,
        'email': 'eve@example.com',
      });

      final id = created['id'] as String;

      // Apply patch operations
      final result = await db.upsertPatch(id, [
        PatchOp.replace('/age', 23),
        PatchOp.add('/city', 'Seattle'),
        PatchOp.remove('/email'),
      ]);

      // Verify patch operations were applied
      expect(result['name'], equals('Eve'));
      expect(result['age'], equals(23));
      expect(result['city'], equals('Seattle'));
      expect(result.containsKey('email'), isFalse);
    });

    test('throws error for invalid PatchOp path format', () async {
      final created = await db.create('person', {
        'name': 'Frank',
        'age': 40,
      });

      final id = created['id'] as String;

      // This should throw because PatchOp validates paths
      expect(
        () => PatchOp.add('invalid_path', 'value'),
        throwsArgumentError,
      );
    });
  });

  group('Upsert Error Handling', () {
    test('throws error for table-only resource in upsertContent()', () async {
      // Upsert requires a specific record ID, not just a table
      expect(
        () => db.upsertContent('person', {'name': 'Test'}),
        throwsA(isA<QueryException>()),
      );
    });

    test('allows empty data in upsertContent()', () async {
      // Empty object is valid in SurrealDB - it creates a record with just an ID
      final result = await db.upsertContent('person:test', {});
      expect(result['id'], equals('person:test'));
    });
  });
}
