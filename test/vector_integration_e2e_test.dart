/// End-to-end integration tests for vector indexing and similarity search.
///
/// This test suite validates complete user workflows from index creation
/// through similarity search, covering the integration of type system,
/// schema integration, and search API components.
///
/// NOTE: Most tests are currently skipped because the embedded SurrealDB
/// engine doesn't yet support vector::similarity::* functions. These tests
/// are ready to run when SurrealDB adds this support.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Vector Integration E2E Tests', () {
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

    test('End-to-end: Create index, insert vectors, perform search, verify results',
        () async {
      // Arrange: Create table with vector field and index
      await db.queryQL('''
        DEFINE TABLE documents SCHEMAFULL;
        DEFINE FIELD title ON documents TYPE string;
        DEFINE FIELD content ON documents TYPE string;
        DEFINE FIELD embedding ON documents TYPE array;
      ''');

      // Define vector index
      final index = IndexDefinition(
        indexName: 'idx_documents_embedding',
        tableName: 'documents',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 3,
        indexType: IndexType.mtree,
      );

      // Create index
      await db.queryQL(index.toSurrealQL());

      // Insert test documents with vectors
      final doc1Vector = VectorValue.f32([1.0, 0.0, 0.0]);
      final doc2Vector = VectorValue.f32([0.0, 1.0, 0.0]);
      final doc3Vector = VectorValue.f32([0.9, 0.1, 0.0]);

      await db.createQL('documents', {
        'title': 'Document 1',
        'content': 'First document',
        'embedding': doc1Vector.toJson(),
      });
      await db.createQL('documents', {
        'title': 'Document 2',
        'content': 'Second document',
        'embedding': doc2Vector.toJson(),
      });
      await db.createQL('documents', {
        'title': 'Document 3',
        'content': 'Third document',
        'embedding': doc3Vector.toJson(),
      });

      // Act: Perform similarity search
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'documents',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 3,
      );

      // Assert: Verify results are ordered by distance
      expect(results, isNotEmpty);
      expect(results.length, lessThanOrEqualTo(3));

      // First result should be Document 1 or Document 3 (closest to query)
      expect(results.first.record['title'], isIn(['Document 1', 'Document 3']));

      // Verify distances are in ascending order
      for (var i = 1; i < results.length; i++) {
        expect(
          results[i].distance,
          greaterThanOrEqualTo(results[i - 1].distance),
          reason: 'Results should be ordered by distance (ascending)',
        );
      }

      // Verify all results contain required fields
      for (final result in results) {
        expect(result.record.containsKey('title'), isTrue);
        expect(result.record.containsKey('content'), isTrue);
        expect(result.distance, isA<double>());
        expect(result.distance, greaterThanOrEqualTo(0.0));
      }
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Integration: Chain similarity search with WHERE clause filtering',
        () async {
      // Arrange: Create table with metadata and vector field
      await db.queryQL('''
        DEFINE TABLE articles SCHEMAFULL;
        DEFINE FIELD title ON articles TYPE string;
        DEFINE FIELD category ON articles TYPE string;
        DEFINE FIELD status ON articles TYPE string;
        DEFINE FIELD embedding ON articles TYPE array;
      ''');

      // Create vector index
      final index = IndexDefinition(
        indexName: 'idx_articles_embedding',
        tableName: 'articles',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 4,
        indexType: IndexType.hnsw,
        m: 16,
        efc: 200,
      );
      await db.queryQL(index.toSurrealQL());

      // Insert articles with different statuses
      final vec1 = VectorValue.f32([1.0, 0.0, 0.0, 0.0]);
      final vec2 = VectorValue.f32([0.9, 0.1, 0.0, 0.0]);
      final vec3 = VectorValue.f32([0.8, 0.2, 0.0, 0.0]);

      await db.createQL('articles', {
        'title': 'Active Article 1',
        'category': 'tech',
        'status': 'active',
        'embedding': vec1.toJson(),
      });
      await db.createQL('articles', {
        'title': 'Inactive Article',
        'category': 'tech',
        'status': 'inactive',
        'embedding': vec2.toJson(),
      });
      await db.createQL('articles', {
        'title': 'Active Article 2',
        'category': 'science',
        'status': 'active',
        'embedding': vec3.toJson(),
      });

      // Act: Search with WHERE condition
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'articles',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.euclidean,
        limit: 10,
        where: EqualsCondition('status', 'active'),
      );

      // Assert: Only active articles returned
      expect(results, isNotEmpty);
      for (final result in results) {
        expect(result.record['status'], equals('active'),
            reason: 'WHERE filter should only return active articles');
      }

      // Should not contain the inactive article
      final titles = results.map((r) => r.record['title'] as String).toList();
      expect(titles, isNot(contains('Inactive Article')));
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Integration: Batch search with multiple vectors returns correctly mapped results',
        () async {
      // Arrange: Create table and index
      await db.queryQL('''
        DEFINE TABLE products SCHEMAFULL;
        DEFINE FIELD name ON products TYPE string;
        DEFINE FIELD embedding ON products TYPE array;
      ''');

      final index = IndexDefinition(
        indexName: 'idx_products_embedding',
        tableName: 'products',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.manhattan,
        dimensions: 2,
        indexType: IndexType.flat,
      );
      await db.queryQL(index.toSurrealQL());

      // Insert products
      await db.createQL('products', {
        'name': 'Product A',
        'embedding': VectorValue.f32([1.0, 0.0]).toJson(),
      });
      await db.createQL('products', {
        'name': 'Product B',
        'embedding': VectorValue.f32([0.0, 1.0]).toJson(),
      });
      await db.createQL('products', {
        'name': 'Product C',
        'embedding': VectorValue.f32([1.0, 1.0]).toJson(),
      });

      // Act: Batch search with multiple query vectors
      final queryVectors = [
        VectorValue.f32([1.0, 0.0]), // Should find Product A closest
        VectorValue.f32([0.0, 1.0]), // Should find Product B closest
        VectorValue.f32([0.5, 0.5]), // Should find Product C closest
      ];

      final results = await db.batchSearchSimilar(
        table: 'products',
        field: 'embedding',
        queryVectors: queryVectors,
        metric: DistanceMetric.manhattan,
        limit: 3,
      );

      // Assert: Results mapped to correct input indices
      expect(results, hasLength(3));
      expect(results[0], isNotEmpty, reason: 'Query 0 should have results');
      expect(results[1], isNotEmpty, reason: 'Query 1 should have results');
      expect(results[2], isNotEmpty, reason: 'Query 2 should have results');

      // Each result set should be a list of SimilarityResult objects
      for (var i = 0; i < 3; i++) {
        expect(results[i], isA<List<SimilarityResult<Map<String, dynamic>>>>());
        expect(results[i]!.first.record.containsKey('name'), isTrue);
        expect(results[i]!.first.distance, isA<double>());
      }
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Integration: Rebuild index and verify search still works', () async {
      // Arrange: Create table with vector field
      await db.queryQL('''
        DEFINE TABLE docs SCHEMAFULL;
        DEFINE FIELD content ON docs TYPE string;
        DEFINE FIELD vector ON docs TYPE array;
      ''');

      // Create initial index
      final index = IndexDefinition(
        indexName: 'idx_docs_vector',
        tableName: 'docs',
        fieldName: 'vector',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 3,
        indexType: IndexType.mtree,
        capacity: 40,
      );
      await db.queryQL(index.toSurrealQL());

      // Insert data
      await db.createQL('docs', {
        'content': 'First doc',
        'vector': VectorValue.f32([1.0, 0.0, 0.0]).toJson(),
      });
      await db.createQL('docs', {
        'content': 'Second doc',
        'vector': VectorValue.f32([0.0, 1.0, 0.0]).toJson(),
      });

      // Perform initial search to verify index works
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final initialResults = await db.searchSimilar(
        table: 'docs',
        field: 'vector',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 2,
      );
      expect(initialResults, isNotEmpty);

      // Act: Rebuild index using DDL generator
      final generator = DdlGenerator();
      final rebuildStatements = generator.generateRebuildVectorIndex(index);

      // Execute rebuild statements (drop + recreate)
      for (final statement in rebuildStatements) {
        await db.queryQL(statement);
      }

      // Assert: Search still works after rebuild
      final resultsAfterRebuild = await db.searchSimilar(
        table: 'docs',
        field: 'vector',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 2,
      );

      expect(resultsAfterRebuild, isNotEmpty);
      expect(resultsAfterRebuild.length, equals(initialResults.length));
      expect(
        resultsAfterRebuild.first.record['content'],
        equals(initialResults.first.record['content']),
      );
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Edge case: Search with mismatched vector dimensions handles error clearly',
        () async {
      // Arrange: Create table with 3D vectors
      await db.queryQL('''
        DEFINE TABLE items SCHEMAFULL;
        DEFINE FIELD name ON items TYPE string;
        DEFINE FIELD embedding ON items TYPE array;
      ''');

      final index = IndexDefinition(
        indexName: 'idx_items_embedding',
        tableName: 'items',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 3,
        indexType: IndexType.mtree,
      );
      await db.queryQL(index.toSurrealQL());

      // Insert 3D vector
      await db.createQL('items', {
        'name': 'Item 1',
        'embedding': VectorValue.f32([1.0, 0.0, 0.0]).toJson(),
      });

      // Act & Assert: Query with mismatched dimensions
      final queryVector2D = VectorValue.f32([1.0, 0.0]); // 2D instead of 3D

      try {
        await db.searchSimilar(
          table: 'items',
          field: 'embedding',
          queryVector: queryVector2D,
          metric: DistanceMetric.euclidean,
          limit: 1,
        );
        fail('Expected an error for dimension mismatch');
      } catch (e) {
        // Should throw a clear error (either DatabaseException or QueryException)
        expect(
          e,
          anyOf([isA<DatabaseException>(), isA<QueryException>()]),
          reason: 'Should throw appropriate exception for dimension mismatch',
        );
      }
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Edge case: Search on non-indexed field completes successfully',
        () async {
      // Arrange: Create table WITHOUT vector index
      await db.queryQL('''
        DEFINE TABLE unindexed_docs SCHEMAFULL;
        DEFINE FIELD title ON unindexed_docs TYPE string;
        DEFINE FIELD embedding ON unindexed_docs TYPE array;
      ''');

      // Insert vectors but NO index
      await db.createQL('unindexed_docs', {
        'title': 'Doc without index',
        'embedding': VectorValue.f32([1.0, 0.0, 0.0]).toJson(),
      });

      // Act: Search on non-indexed field
      final queryVector = VectorValue.f32([1.0, 0.0, 0.0]);
      final results = await db.searchSimilar(
        table: 'unindexed_docs',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 1,
      );

      // Assert: Should still work but may be slower (SurrealDB performs full scan)
      expect(results, isNotEmpty);
      expect(results.first.record['title'], equals('Doc without index'));
      expect(results.first.distance, isA<double>());
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Integration: All four distance metrics return different but valid results',
        () async {
      // Arrange: Create table with vectors
      await db.queryQL('''
        DEFINE TABLE metric_test SCHEMAFULL;
        DEFINE FIELD name ON metric_test TYPE string;
        DEFINE FIELD vec ON metric_test TYPE array;
      ''');

      // Insert test vectors
      await db.createQL('metric_test', {
        'name': 'Vector A',
        'vec': VectorValue.f32([1.0, 0.0, 0.0]).toJson(),
      });
      await db.createQL('metric_test', {
        'name': 'Vector B',
        'vec': VectorValue.f32([0.5, 0.5, 0.5]).toJson(),
      });
      await db.createQL('metric_test', {
        'name': 'Vector C',
        'vec': VectorValue.f32([0.0, 1.0, 0.0]).toJson(),
      });

      final queryVector = VectorValue.f32([0.9, 0.1, 0.0]);

      // Act: Search with all four metrics
      final euclideanResults = await db.searchSimilar(
        table: 'metric_test',
        field: 'vec',
        queryVector: queryVector,
        metric: DistanceMetric.euclidean,
        limit: 3,
      );

      final cosineResults = await db.searchSimilar(
        table: 'metric_test',
        field: 'vec',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 3,
      );

      final manhattanResults = await db.searchSimilar(
        table: 'metric_test',
        field: 'vec',
        queryVector: queryVector,
        metric: DistanceMetric.manhattan,
        limit: 3,
      );

      final minkowskiResults = await db.searchSimilar(
        table: 'metric_test',
        field: 'vec',
        queryVector: queryVector,
        metric: DistanceMetric.minkowski,
        limit: 3,
      );

      // Assert: All metrics return valid results
      expect(euclideanResults, isNotEmpty);
      expect(cosineResults, isNotEmpty);
      expect(manhattanResults, isNotEmpty);
      expect(minkowskiResults, isNotEmpty);

      // All should have distance values
      for (final result in euclideanResults) {
        expect(result.distance, isA<double>());
        expect(result.distance, greaterThanOrEqualTo(0.0));
      }

      // Distance values may differ between metrics
      // (Don't assert ordering is same, as different metrics rank differently)
      final euclideanFirst = euclideanResults.first.distance;
      final cosineFirst = cosineResults.first.distance;
      final manhattanFirst = manhattanResults.first.distance;
      final minkowskiFirst = minkowskiResults.first.distance;

      // Just verify they computed distances (may differ)
      expect([euclideanFirst, cosineFirst, manhattanFirst, minkowskiFirst],
          everyElement(isA<double>()));
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');

    test('Integration: Auto-select index type chooses appropriate index for dataset size',
        () async {
      // Arrange: Create index definition with auto type
      final smallDatasetIndex = IndexDefinition(
        indexName: 'idx_small_auto',
        tableName: 'small_table',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 128,
        indexType: IndexType.auto,
      );

      final mediumDatasetIndex = IndexDefinition(
        indexName: 'idx_medium_auto',
        tableName: 'medium_table',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 384,
        indexType: IndexType.auto,
      );

      final largeDatasetIndex = IndexDefinition(
        indexName: 'idx_large_auto',
        tableName: 'large_table',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.manhattan,
        dimensions: 768,
        indexType: IndexType.auto,
      );

      // Act: Generate DDL with different dataset sizes
      final smallDDL = smallDatasetIndex.toSurrealQL(datasetSize: 500);
      final mediumDDL = mediumDatasetIndex.toSurrealQL(datasetSize: 10000);
      final largeDDL = largeDatasetIndex.toSurrealQL(datasetSize: 200000);

      // Assert: Auto type resolved to appropriate concrete type
      expect(smallDDL, contains('FLAT'),
          reason: 'Small dataset should use FLAT index');
      expect(mediumDDL, contains('MTREE'),
          reason: 'Medium dataset should use MTREE index');
      expect(largeDDL, contains('HNSW'),
          reason: 'Large dataset should use HNSW index');

      // Should not contain AUTO in any DDL
      expect(smallDDL, isNot(contains('AUTO')));
      expect(mediumDDL, isNot(contains('AUTO')));
      expect(largeDDL, isNot(contains('AUTO')));
    });

    test('Performance smoke test: Large vector search completes within reasonable time',
        () async {
      // Arrange: Create table with large vectors (768 dimensions like OpenAI embeddings)
      await db.queryQL('''
        DEFINE TABLE large_vectors SCHEMAFULL;
        DEFINE FIELD title ON large_vectors TYPE string;
        DEFINE FIELD embedding ON large_vectors TYPE array;
      ''');

      final index = IndexDefinition(
        indexName: 'idx_large_vectors',
        tableName: 'large_vectors',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 768,
        indexType: IndexType.hnsw,
        m: 16,
        efc: 200,
      );
      await db.queryQL(index.toSurrealQL());

      // Insert a few large vectors
      for (var i = 0; i < 5; i++) {
        final largeVector = VectorValue.fromList(
          List.generate(768, (j) => (i * 0.1 + j * 0.001) % 1.0),
        );
        await db.createQL('large_vectors', {
          'title': 'Large Vector Document $i',
          'embedding': largeVector.toJson(),
        });
      }

      // Act: Measure search time
      final queryVector = VectorValue.fromList(
        List.generate(768, (i) => i * 0.001 % 1.0),
      );

      final stopwatch = Stopwatch()..start();
      final results = await db.searchSimilar(
        table: 'large_vectors',
        field: 'embedding',
        queryVector: queryVector,
        metric: DistanceMetric.cosine,
        limit: 5,
      );
      stopwatch.stop();

      // Assert: Completes within reasonable time (5 seconds for smoke test)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000),
          reason: 'Large vector search should complete within 5 seconds');

      expect(results, isNotEmpty);
      expect(results.first.record['title'], contains('Large Vector Document'));
    }, skip: 'SurrealDB embedded version does not yet support vector::similarity::* functions');
  });
}
