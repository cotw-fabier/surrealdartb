/// Tests for vector index type system components.
///
/// Covers DistanceMetric, IndexType, IndexDefinition, and SimilarityResult classes.
library;

import 'package:surrealdartb/src/vector/distance_metric.dart';
import 'package:surrealdartb/src/vector/index_type.dart';
import 'package:surrealdartb/src/vector/index_definition.dart';
import 'package:surrealdartb/src/vector/similarity_result.dart';
import 'package:test/test.dart';

void main() {
  group('DistanceMetric', () {
    test('converts to SurrealQL function names correctly', () {
      expect(
        DistanceMetric.euclidean.toSurrealQLFunction(),
        equals('euclidean'),
      );
      expect(
        DistanceMetric.cosine.toSurrealQLFunction(),
        equals('cosine'),
      );
      expect(
        DistanceMetric.manhattan.toSurrealQLFunction(),
        equals('manhattan'),
      );
      expect(
        DistanceMetric.minkowski.toSurrealQLFunction(),
        equals('minkowski'),
      );
    });

    test('converts to full SurrealQL function path', () {
      expect(
        DistanceMetric.euclidean.toFullSurrealQLFunction(),
        equals('vector::distance::euclidean'),
      );
      expect(
        DistanceMetric.cosine.toFullSurrealQLFunction(),
        equals('vector::distance::cosine'),
      );
    });
  });

  group('IndexType', () {
    test('converts to SurrealQL keywords correctly', () {
      expect(IndexType.mtree.toSurrealQL(), equals('MTREE'));
      expect(IndexType.hnsw.toSurrealQL(), equals('HNSW'));
      expect(IndexType.flat.toSurrealQL(), equals('FLAT'));
      expect(IndexType.auto.toSurrealQL(), isNull);
    });

    test('auto-selection chooses appropriate index for dataset size', () {
      // Small dataset: <1000 vectors -> FLAT
      expect(
        IndexType.auto.resolve(datasetSize: 500),
        equals(IndexType.flat),
      );

      // Medium dataset: 1000-100000 vectors -> MTREE
      expect(
        IndexType.auto.resolve(datasetSize: 5000),
        equals(IndexType.mtree),
      );
      expect(
        IndexType.auto.resolve(datasetSize: 50000),
        equals(IndexType.mtree),
      );

      // Large dataset: >100000 vectors -> HNSW
      expect(
        IndexType.auto.resolve(datasetSize: 150000),
        equals(IndexType.hnsw),
      );
    });

    test('explicit index types remain unchanged when resolved', () {
      expect(
        IndexType.mtree.resolve(datasetSize: 100),
        equals(IndexType.mtree),
      );
      expect(
        IndexType.hnsw.resolve(datasetSize: 100),
        equals(IndexType.hnsw),
      );
    });
  });

  group('IndexDefinition', () {
    test('constructs with required parameters and validates', () {
      final index = IndexDefinition(
        indexName: 'idx_test',
        tableName: 'documents',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 768,
        indexType: IndexType.mtree,
      );

      expect(() => index.validate(), returnsNormally);
      expect(index.indexName, equals('idx_test'));
      expect(index.dimensions, equals(768));
    });

    test('generates valid DEFINE INDEX statement for MTREE', () {
      final index = IndexDefinition(
        indexName: 'idx_embedding',
        tableName: 'docs',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 384,
        indexType: IndexType.mtree,
        capacity: 40,
      );

      final ddl = index.toSurrealQL();
      expect(ddl, contains('DEFINE INDEX idx_embedding'));
      expect(ddl, contains('ON docs'));
      expect(ddl, contains('FIELDS embedding'));
      expect(ddl, contains('MTREE'));
      expect(ddl, contains('DISTANCE COSINE'));
      expect(ddl, contains('DIMENSION 384'));
      expect(ddl, contains('CAPACITY 40'));
    });

    test('generates valid DEFINE INDEX statement for HNSW', () {
      final index = IndexDefinition(
        indexName: 'idx_large',
        tableName: 'articles',
        fieldName: 'vec',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 1536,
        indexType: IndexType.hnsw,
        m: 16,
        efc: 200,
      );

      final ddl = index.toSurrealQL();
      expect(ddl, contains('DEFINE INDEX idx_large'));
      expect(ddl, contains('HNSW'));
      expect(ddl, contains('DISTANCE EUCLIDEAN'));
      expect(ddl, contains('DIMENSION 1536'));
      expect(ddl, contains('M 16'));
      expect(ddl, contains('EFC 200'));
    });

    test('validates parameter constraints', () {
      // Invalid dimensions
      expect(
        () => IndexDefinition(
          indexName: 'idx_bad',
          tableName: 'test',
          fieldName: 'vec',
          distanceMetric: DistanceMetric.euclidean,
          dimensions: 0,
        ).validate(),
        throwsArgumentError,
      );

      // Invalid M parameter
      expect(
        () => IndexDefinition(
          indexName: 'idx_bad',
          tableName: 'test',
          fieldName: 'vec',
          distanceMetric: DistanceMetric.euclidean,
          dimensions: 128,
          indexType: IndexType.hnsw,
          m: -5,
        ).validate(),
        throwsArgumentError,
      );

      // HNSW parameters on non-HNSW index
      expect(
        () => IndexDefinition(
          indexName: 'idx_bad',
          tableName: 'test',
          fieldName: 'vec',
          distanceMetric: DistanceMetric.euclidean,
          dimensions: 128,
          indexType: IndexType.mtree,
          m: 16,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('resolves auto index type when generating DDL', () {
      final index = IndexDefinition(
        indexName: 'idx_auto',
        tableName: 'docs',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 768,
        indexType: IndexType.auto,
      );

      // Should resolve to MTREE for medium dataset
      final ddl = index.toSurrealQL(datasetSize: 5000);
      expect(ddl, contains('MTREE'));
    });
  });

  group('SimilarityResult', () {
    test('constructs with record and distance', () {
      final result = SimilarityResult<Map<String, dynamic>>(
        record: {'id': 'doc:1', 'title': 'Test'},
        distance: 0.85,
      );

      expect(result.record['id'], equals('doc:1'));
      expect(result.distance, equals(0.85));
    });

    test('deserializes from JSON with distance field', () {
      final json = {
        'id': 'doc:1',
        'title': 'Example Document',
        'content': 'Some content',
        'distance': 0.42,
      };

      final result = SimilarityResult<Map<String, dynamic>>.fromJson(json);

      expect(result.distance, equals(0.42));
      expect(result.record['id'], equals('doc:1'));
      expect(result.record['title'], equals('Example Document'));
      expect(result.record.containsKey('distance'), isFalse);
    });

    test('deserializes list of results from JSON', () {
      final jsonList = [
        {'id': 'doc:1', 'title': 'First', 'distance': 0.1},
        {'id': 'doc:2', 'title': 'Second', 'distance': 0.3},
        {'id': 'doc:3', 'title': 'Third', 'distance': 0.5},
      ];

      final results =
          SimilarityResult.listFromJson<Map<String, dynamic>>(jsonList);

      expect(results.length, equals(3));
      expect(results[0].distance, equals(0.1));
      expect(results[1].record['title'], equals('Second'));
      expect(results[2].distance, equals(0.5));
    });

    test('throws error when distance field is missing', () {
      final invalidJson = {
        'id': 'doc:1',
        'title': 'No distance field',
      };

      expect(
        () => SimilarityResult<Map<String, dynamic>>.fromJson(invalidJson),
        throwsArgumentError,
      );
    });

    test('serializes back to JSON with distance field', () {
      final result = SimilarityResult<Map<String, dynamic>>(
        record: {'id': 'doc:1', 'title': 'Test'},
        distance: 0.85,
      );

      final json = result.toJson();

      expect(json['id'], equals('doc:1'));
      expect(json['title'], equals('Test'));
      expect(json['distance'], equals(0.85));
    });
  });
}
