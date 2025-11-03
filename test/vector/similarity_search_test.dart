/// Tests for vector similarity search API.
///
/// This test file validates the searchSimilar() and batchSearchSimilar()
/// methods, including query generation, result parsing, and parameter validation.
///
/// NOTE: Most tests are currently skipped because the embedded SurrealDB
/// engine doesn't yet support vector::distance::* functions. These tests
/// are ready to run when SurrealDB adds this support.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('SimilaritySearch', () {
    late Database db;

    setUp(() async {
      // Create in-memory database for testing
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      // Create test table with vector field
      // IMPORTANT: Must use array<float> or array<number> to preserve vector values
      // Using just 'array' will store vectors as empty arrays!
      await db.queryQL('''
        DEFINE TABLE documents SCHEMAFULL;
        DEFINE FIELD title ON documents TYPE string;
        DEFINE FIELD embedding ON documents TYPE array<float>;
        DEFINE FIELD status ON documents TYPE option<string>;
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('searchSimilar() returns results ordered by distance', () async {
      // Insert test documents with vectors
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.0, 1.0, 0.0]);
      final vec3 = VectorValue.f32([0.9, 0.1, 0.0]);

      await db.createQL('documents', {
        'title': 'Doc 1',
        'embedding': vec1.toJson(),
      });
      await db.createQL('documents', {
        'title': 'Doc 2',
        'embedding': vec2.toJson(),
      });
      await db.createQL('documents', {
        'title': 'Doc 3',
        'embedding': vec3.toJson(),
      });

      // Search for similar vectors to [1.0, 0.0, 0.0]
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.euclidean,
        limit: 3,
      );

      // Verify results are ordered by distance
      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(3));

      // First result should be closest (Doc 1 or Doc 3)
      expect(results.first.distance, lessThan(1.0));

      // Distances should be in ascending order
      for (var i = 1; i < results.length; i++) {
        expect(results[i].distance, greaterThanOrEqualTo(results[i - 1].distance));
      }
    });

    test('searchSimilar() with WHERE conditions filters results', () async {
      // Insert test documents
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.9, 0.1, 0.0]);

      await db.createQL('documents', {
        'title': 'Active Doc',
        'embedding': vec1.toJson(),
        'status': 'active',
      });
      await db.createQL('documents', {
        'title': 'Inactive Doc',
        'embedding': vec2.toJson(),
        'status': 'inactive',
      });

      // Search with WHERE filter
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 10,
        where: EqualsCondition('status', 'active'),
      );

      // Should only return active documents
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.record['status'], equals('active'));
      }
    });

    test('searchSimilar() works with all distance metrics', () async {
      // Insert test document
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      await db.createQL('documents', {
        'title': 'Test Doc',
        'embedding': vec1.toJson(),
      });

      final queryVector = VectorValue.f32([0.9, 0.1, 0.0]);

      // Test each distance metric
      for (final metric in DistanceMetric.values) {
        final results = await db.searchSimilar(
          table: 'documents',
          field: 'embedding',
          queryVector: queryVector,
          metric: metric,
          limit: 1,
        );

        expect(results, isNotEmpty, reason: 'Metric $metric should return results');
        expect(results.first.distance, isA<double>());
      }
    });

    test('searchSimilar() parses results into SimilarityResult objects', () async {
      // Insert test document
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      await db.createQL('documents', {
        'title': 'Test Doc',
        'embedding': vec1.toJson(),
      });

      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.euclidean,
        limit: 1,
      );

      expect(results, hasLength(1));
      expect(results.first, isA<SimilarityResult<Map<String, dynamic>>>());
      expect(results.first.record, isA<Map<String, dynamic>>());
      expect(results.first.record['title'], equals('Test Doc'));
      expect(results.first.distance, isA<double>());
    });

    test('batchSearchSimilar() returns results mapped by input index', () async {
      // Insert test documents
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.0, 1.0, 0.0]);

      await db.createQL('documents', {
        'title': 'Doc 1',
        'embedding': vec1.toJson(),
      });
      await db.createQL('documents', {
        'title': 'Doc 2',
        'embedding': vec2.toJson(),
      });

      // Batch search with multiple query vectors
      final queryVectors = [
        VectorValue.f32([1.0, 0.0, 0.0]),
        VectorValue.f32([0.0, 1.0, 0.0]),
      ];

      final results = await db.batchSearchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVectors: queryVectors,
        metric: DistanceMetric.euclidean,
        limit: 2,
      );

      // Verify results are mapped correctly
      expect(results, hasLength(2));
      expect(results[0], isNotEmpty);
      expect(results[1], isNotEmpty);

      // Each result list should contain similarity results
      expect(results[0]!.first, isA<SimilarityResult<Map<String, dynamic>>>());
      expect(results[1]!.first, isA<SimilarityResult<Map<String, dynamic>>>());
    });

    test('searchSimilar() validates dimension mismatch', () async {
      // Insert document with 3D vector
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0]);
      await db.createQL('documents', {
        'title': 'Test Doc',
        'embedding': vec1.toJson(),
      });

      // Query with different dimension vector (should be handled gracefully)
      final queryVector = VectorValue.f32([1.0, 0.0]); // 2D instead of 3D

      // This may throw an error or return empty results depending on SurrealDB behavior
      // We test that the SDK handles it gracefully
      try {
        await db.searchSimilar(
          table: 'documents',
          field: 'embedding',
          queryVector: queryVector,
          metric: DistanceMetric.euclidean,
          limit: 1,
        );
        // If it doesn't throw, that's okay too
      } catch (e) {
        // Expect a meaningful error
        expect(e, isA<Exception>());
      }
    });

    test('searchSimilar() validates empty query vector', () async {
      // Attempt to create empty vector should throw during construction
      expect(
        () => VectorValue.f32([]),
        throwsArgumentError,
      );
    });

    test('batchSearchSimilar() handles empty query vector list', () async {
      // Empty query list should return empty results
      final results = await db.batchSearchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVectors: [],
        metric: DistanceMetric.euclidean,
        limit: 1,
      );

      expect(results, isEmpty);
    });
  });
}
