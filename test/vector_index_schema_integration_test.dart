/// Tests for vector index schema integration.
///
/// This test suite validates that vector indexes integrate seamlessly with
/// the existing schema system, including DDL generation, migration workflow,
/// and index management operations.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/src/schema/table_structure.dart';
import 'package:surrealdartb/src/schema/ddl_generator.dart';
import 'package:surrealdartb/src/schema/surreal_types.dart';
import 'package:surrealdartb/src/vector/index_definition.dart';
import 'package:surrealdartb/src/vector/distance_metric.dart';
import 'package:surrealdartb/src/vector/index_type.dart';
import 'package:surrealdartb/src/types/vector_value.dart';

void main() {
  group('Vector Index Schema Integration', () {
    test('TableStructure accepts vectorIndexes field', () {
      // Arrange: Create a table with vector indexes
      final table = TableStructure('documents', {
        'title': FieldDefinition(StringType()),
        'embedding': FieldDefinition(VectorType.f32(768)),
      });

      // Define vector index
      final index = IndexDefinition(
        indexName: 'idx_embedding',
        tableName: 'documents',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 768,
        indexType: IndexType.mtree,
      );

      // Act: Attach vector indexes to table
      table.vectorIndexes = [index];

      // Assert: Vector indexes are stored correctly
      expect(table.vectorIndexes, isNotNull);
      expect(table.vectorIndexes!.length, equals(1));
      expect(table.vectorIndexes!.first.indexName, equals('idx_embedding'));
    });

    test('DDL generator produces correct DEFINE INDEX statements for vector indexes', () {
      // Arrange: Create table with vector index
      final table = TableStructure('products', {
        'name': FieldDefinition(StringType()),
        'description_embedding': FieldDefinition(VectorType.f32(384)),
      });

      final index = IndexDefinition(
        indexName: 'idx_products_embedding',
        tableName: 'products',
        fieldName: 'description_embedding',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 384,
        indexType: IndexType.hnsw,
        m: 16,
        efc: 200,
      );

      table.vectorIndexes = [index];

      // Act: Generate DDL
      final generator = DdlGenerator();
      final ddlStatements = generator.generateVectorIndexDDL(table);

      // Assert: Correct DEFINE INDEX statement is generated
      expect(ddlStatements.length, equals(1));
      final statement = ddlStatements.first;
      expect(statement, contains('DEFINE INDEX idx_products_embedding'));
      expect(statement, contains('ON products'));
      expect(statement, contains('FIELDS description_embedding'));
      expect(statement, contains('HNSW'));
      expect(statement, contains('DISTANCE EUCLIDEAN'));
      expect(statement, contains('DIMENSION 384'));
      expect(statement, contains('M 16'));
      expect(statement, contains('EFC 200'));
    });

    test('Migration workflow includes vector indexes after tables and fields', () {
      // Arrange: Create table with fields and vector index
      final table = TableStructure('articles', {
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'embedding': FieldDefinition(VectorType.f32(1536)),
      });

      final index = IndexDefinition(
        indexName: 'idx_articles_embedding',
        tableName: 'articles',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 1536,
        indexType: IndexType.mtree,
        capacity: 40,
      );

      table.vectorIndexes = [index];

      // Act: Generate full DDL for table creation
      final generator = DdlGenerator();
      final allStatements = generator.generateFullTableDDL(table);

      // Assert: Statements are in correct order
      expect(allStatements.length, greaterThanOrEqualTo(5)); // table + 3 fields + index

      // Find statement indices
      int tableDefIndex = -1;
      int lastFieldDefIndex = -1;
      int indexDefIndex = -1;

      for (int i = 0; i < allStatements.length; i++) {
        if (allStatements[i].startsWith('DEFINE TABLE')) {
          tableDefIndex = i;
        } else if (allStatements[i].startsWith('DEFINE FIELD')) {
          lastFieldDefIndex = i;
        } else if (allStatements[i].startsWith('DEFINE INDEX') &&
            allStatements[i].contains('HNSW') || allStatements[i].contains('MTREE')) {
          indexDefIndex = i;
        }
      }

      // Verify order: TABLE -> FIELDS -> VECTOR INDEX
      expect(tableDefIndex, greaterThanOrEqualTo(0));
      expect(lastFieldDefIndex, greaterThan(tableDefIndex));
      expect(indexDefIndex, greaterThan(lastFieldDefIndex));
    });

    test('Index drop generates correct REMOVE INDEX statement', () {
      // Arrange: Create index definition
      final index = IndexDefinition(
        indexName: 'idx_test_embedding',
        tableName: 'test_table',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.manhattan,
        dimensions: 512,
        indexType: IndexType.mtree,
      );

      // Act: Generate DROP statement
      final generator = DdlGenerator();
      final dropStatement = generator.generateRemoveVectorIndex(
        index.tableName,
        index.indexName,
      );

      // Assert: Correct REMOVE INDEX statement
      expect(dropStatement, equals('REMOVE INDEX idx_test_embedding ON test_table'));
    });

    test('Index rebuild generates drop and recreate statements', () {
      // Arrange: Create index definition
      final index = IndexDefinition(
        indexName: 'idx_rebuild_test',
        tableName: 'rebuild_table',
        fieldName: 'vec_field',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 256,
        indexType: IndexType.hnsw,
        m: 12,
        efc: 150,
      );

      // Act: Generate rebuild statements (drop + define)
      final generator = DdlGenerator();
      final rebuildStatements = generator.generateRebuildVectorIndex(index);

      // Assert: Two statements in correct order
      expect(rebuildStatements.length, equals(2));
      expect(rebuildStatements[0], startsWith('REMOVE INDEX'));
      expect(rebuildStatements[0], contains('idx_rebuild_test'));
      expect(rebuildStatements[1], startsWith('DEFINE INDEX'));
      expect(rebuildStatements[1], contains('idx_rebuild_test'));
      expect(rebuildStatements[1], contains('HNSW'));
    });

    test('Multiple vector indexes on same table generate separate DDL statements', () {
      // Arrange: Create table with two vector fields and indexes
      final table = TableStructure('multi_vector_table', {
        'title': FieldDefinition(StringType()),
        'embedding_en': FieldDefinition(VectorType.f32(768)),
        'embedding_fr': FieldDefinition(VectorType.f32(768)),
      });

      final index1 = IndexDefinition(
        indexName: 'idx_embedding_en',
        tableName: 'multi_vector_table',
        fieldName: 'embedding_en',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 768,
        indexType: IndexType.mtree,
      );

      final index2 = IndexDefinition(
        indexName: 'idx_embedding_fr',
        tableName: 'multi_vector_table',
        fieldName: 'embedding_fr',
        distanceMetric: DistanceMetric.euclidean,
        dimensions: 768,
        indexType: IndexType.hnsw,
        m: 16,
      );

      table.vectorIndexes = [index1, index2];

      // Act: Generate DDL
      final generator = DdlGenerator();
      final ddlStatements = generator.generateVectorIndexDDL(table);

      // Assert: Two separate DEFINE INDEX statements
      expect(ddlStatements.length, equals(2));
      expect(ddlStatements[0], contains('idx_embedding_en'));
      expect(ddlStatements[0], contains('COSINE'));
      expect(ddlStatements[1], contains('idx_embedding_fr'));
      expect(ddlStatements[1], contains('EUCLIDEAN'));
      expect(ddlStatements[1], contains('HNSW'));
    });

    test('Vector index with auto type resolves to concrete type in DDL', () {
      // Arrange: Create index with auto type
      final index = IndexDefinition(
        indexName: 'idx_auto_type',
        tableName: 'auto_table',
        fieldName: 'embedding',
        distanceMetric: DistanceMetric.cosine,
        dimensions: 384,
        indexType: IndexType.auto, // Auto-select
      );

      // Act: Generate DDL with dataset size hint
      final ddl = index.toSurrealQL(datasetSize: 50000);

      // Assert: Auto is resolved to concrete type (MTREE for 50k records)
      expect(ddl, contains('DEFINE INDEX'));
      expect(ddl, contains('idx_auto_type'));
      // Auto should resolve to MTREE for medium datasets
      expect(ddl, contains('MTREE'));
      expect(ddl, isNot(contains('AUTO')));
    });
  });
}
