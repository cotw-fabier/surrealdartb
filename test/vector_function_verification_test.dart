/// Verification test to check if vector::distance::* functions work in embedded SurrealDB.
///
/// This test verifies whether the embedded SurrealDB engine supports
/// vector distance functions. Run this test to determine if similarity
/// search tests should be skipped or not.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Vector Function Verification', () {
    late Database db;

    setUp(() async {
      // Create in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      // Create test table with vector field
      await db.queryQL('''
        DEFINE TABLE test_vectors SCHEMAFULL;
        DEFINE FIELD name ON test_vectors TYPE string;
        DEFINE FIELD embedding ON test_vectors TYPE array;
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('VERIFICATION: vector::distance::euclidean function exists', () async {
      print('\n=== VERIFICATION TEST ===');
      print('Testing if vector::distance::euclidean works in embedded SurrealDB...\n');

      // Insert test vectors
      await db.createQL('test_vectors', {
        'name': 'Vector A',
        'embedding': [1.0, 0.0, 0.0],
      });
      await db.createQL('test_vectors', {
        'name': 'Vector B',
        'embedding': [0.8, 0.6, 0.0],
      });
      await db.createQL('test_vectors', {
        'name': 'Vector C',
        'embedding': [0.0, 1.0, 0.0],
      });

      print('✓ Inserted 3 test vectors');

      // Try to use vector::distance::euclidean function
      try {
        final query = '''
          SELECT *, vector::distance::euclidean(embedding, [1.0, 0.0, 0.0]) AS distance
          FROM test_vectors
          ORDER BY distance ASC
        ''';

        print('\nExecuting query:');
        print(query);
        print('');

        final response = await db.queryQL(query);
        final results = response.getResults();

        print('✅ SUCCESS! Query executed without error');
        print('Number of results: ${results.length}');
        print('First result: ${results.firstOrNull}');
        print('\n=== CONCLUSION: vector::distance::euclidean IS SUPPORTED ===\n');

        // Verify we got results with distance field
        expect(results, isNotEmpty);
        expect(results.first, containsPair('distance', anything));

        print('All similarity search tests should be ENABLED (remove skip annotations)');
      } catch (e) {
        print('❌ FAILED! Error occurred:');
        print('Error type: ${e.runtimeType}');
        print('Error message: $e');
        print('\n=== CONCLUSION: vector::distance::euclidean NOT SUPPORTED ===\n');
        print('Similarity search tests should remain SKIPPED');

        // Re-throw to fail the test
        rethrow;
      }
    });

    test('VERIFICATION: vector::distance::cosine function exists', () async {
      // Insert test vector
      await db.createQL('test_vectors', {
        'name': 'Test',
        'embedding': [1.0, 0.0, 0.0],
      });

      // Try cosine distance
      final query = '''
        SELECT *, vector::distance::cosine(embedding, [1.0, 0.0, 0.0]) AS distance
        FROM test_vectors
      ''';

      final response = await db.queryQL(query);
      final results = response.getResults();
      expect(results, isNotEmpty);
      expect(results.first, containsPair('distance', anything));
    });

    test('VERIFICATION: vector::distance::manhattan function exists', () async {
      // Insert test vector
      await db.createQL('test_vectors', {
        'name': 'Test',
        'embedding': [1.0, 0.0, 0.0],
      });

      // Try manhattan distance
      final query = '''
        SELECT *, vector::distance::manhattan(embedding, [1.0, 0.0, 0.0]) AS distance
        FROM test_vectors
      ''';

      final response = await db.queryQL(query);
      final results = response.getResults();
      expect(results, isNotEmpty);
      expect(results.first, containsPair('distance', anything));
    });

    test('VERIFICATION: vector::distance::minkowski function exists', () async {
      // Insert test vector
      await db.createQL('test_vectors', {
        'name': 'Test',
        'embedding': [1.0, 0.0, 0.0],
      });

      // Try minkowski distance
      final query = '''
        SELECT *, vector::distance::minkowski(embedding, [1.0, 0.0, 0.0]) AS distance
        FROM test_vectors
      ''';

      final response = await db.queryQL(query);
      final results = response.getResults();
      expect(results, isNotEmpty);
      expect(results.first, containsPair('distance', anything));
    });
  });
}
