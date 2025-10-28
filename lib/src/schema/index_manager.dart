/// Index management operations for SurrealDB.
///
/// This library provides utilities for managing database indexes,
/// including vector indexes for similarity search.
library;

import '../database.dart';
import '../exceptions.dart';
import '../vector/index_definition.dart';
import 'ddl_generator.dart';

/// Manager for database index operations.
///
/// Provides methods for creating, dropping, and rebuilding indexes,
/// including vector similarity search indexes.
///
/// ## Usage
///
/// ```dart
/// // Create index manager
/// final indexManager = IndexManager(db);
///
/// // Define a vector index
/// final index = IndexDefinition(
///   indexName: 'idx_embedding',
///   tableName: 'documents',
///   fieldName: 'embedding',
///   distanceMetric: DistanceMetric.cosine,
///   dimensions: 768,
///   indexType: IndexType.mtree,
/// );
///
/// // Create the index
/// await indexManager.createIndex(index);
///
/// // Rebuild the index
/// await indexManager.rebuildIndex(index);
///
/// // Drop the index
/// await indexManager.dropIndex('documents', 'idx_embedding');
/// ```
class IndexManager {
  /// Creates an IndexManager for the specified database.
  ///
  /// [db] - The database connection to use for index operations
  IndexManager(this.db);

  /// The database connection used for index operations.
  final Database db;

  /// The DDL generator for creating index statements.
  final DdlGenerator _ddlGenerator = DdlGenerator();

  /// Creates a vector index.
  ///
  /// Generates and executes a DEFINE INDEX statement based on the provided
  /// index definition. The index enables efficient similarity search on
  /// vector fields.
  ///
  /// [index] - The index definition specifying the index configuration
  ///
  /// Throws [DatabaseException] if index creation fails.
  ///
  /// Example:
  /// ```dart
  /// final index = IndexDefinition(
  ///   indexName: 'idx_products_embedding',
  ///   tableName: 'products',
  ///   fieldName: 'description_embedding',
  ///   distanceMetric: DistanceMetric.euclidean,
  ///   dimensions: 384,
  ///   indexType: IndexType.hnsw,
  ///   m: 16,
  ///   efc: 200,
  /// );
  ///
  /// await indexManager.createIndex(index);
  /// ```
  Future<void> createIndex(IndexDefinition index) async {
    try {
      // Validate the index definition
      index.validate();

      // Generate DDL statement
      final ddl = index.toSurrealQL();

      // Execute the DDL
      await db.queryQL(ddl);
    } catch (e) {
      throw DatabaseException(
        'Failed to create index ${index.indexName}: $e',
      );
    }
  }

  /// Drops a vector index.
  ///
  /// Removes an existing index from the database. This operation is
  /// typically performed before rebuilding an index or when an index
  /// is no longer needed.
  ///
  /// [tableName] - The name of the table containing the index
  /// [indexName] - The name of the index to drop
  ///
  /// Throws [DatabaseException] if index removal fails.
  ///
  /// Example:
  /// ```dart
  /// await indexManager.dropIndex('documents', 'idx_embedding');
  /// ```
  Future<void> dropIndex(String tableName, String indexName) async {
    try {
      // Generate REMOVE INDEX statement
      final ddl = _ddlGenerator.generateRemoveVectorIndex(tableName, indexName);

      // Execute the DDL
      await db.queryQL(ddl);
    } catch (e) {
      throw DatabaseException(
        'Failed to drop index $indexName on table $tableName: $e',
      );
    }
  }

  /// Rebuilds a vector index using drop-and-recreate approach.
  ///
  /// This operation first drops the existing index and then recreates it
  /// with the same configuration. This is useful when you need to rebuild
  /// an index after significant data changes or to apply updated parameters.
  ///
  /// **Note**: The index is temporarily unavailable during the rebuild.
  /// Queries on the indexed field will still work but may be slower during
  /// this period.
  ///
  /// [index] - The index definition specifying the index to rebuild
  ///
  /// Throws [DatabaseException] if the rebuild operation fails.
  ///
  /// Example:
  /// ```dart
  /// final index = IndexDefinition(
  ///   indexName: 'idx_embedding',
  ///   tableName: 'documents',
  ///   fieldName: 'embedding',
  ///   distanceMetric: DistanceMetric.cosine,
  ///   dimensions: 768,
  ///   indexType: IndexType.mtree,
  ///   capacity: 40,
  /// );
  ///
  /// // Rebuild the index
  /// await indexManager.rebuildIndex(index);
  /// ```
  Future<void> rebuildIndex(IndexDefinition index) async {
    try {
      // Validate the index definition
      index.validate();

      // Generate rebuild statements (drop + create)
      final ddlStatements = _ddlGenerator.generateRebuildVectorIndex(index);

      // Execute both statements in sequence
      for (final ddl in ddlStatements) {
        await db.queryQL(ddl);
      }
    } catch (e) {
      throw DatabaseException(
        'Failed to rebuild index ${index.indexName}: $e',
      );
    }
  }

  /// Creates multiple vector indexes at once.
  ///
  /// Batch creates multiple indexes in sequence. This is more efficient
  /// than calling [createIndex] individually for each index.
  ///
  /// [indexes] - List of index definitions to create
  ///
  /// Throws [DatabaseException] if any index creation fails.
  ///
  /// Example:
  /// ```dart
  /// final indexes = [
  ///   IndexDefinition(
  ///     indexName: 'idx_embedding_en',
  ///     tableName: 'documents',
  ///     fieldName: 'embedding_en',
  ///     distanceMetric: DistanceMetric.cosine,
  ///     dimensions: 768,
  ///   ),
  ///   IndexDefinition(
  ///     indexName: 'idx_embedding_fr',
  ///     tableName: 'documents',
  ///     fieldName: 'embedding_fr',
  ///     distanceMetric: DistanceMetric.euclidean,
  ///     dimensions: 768,
  ///   ),
  /// ];
  ///
  /// await indexManager.createIndexes(indexes);
  /// ```
  Future<void> createIndexes(List<IndexDefinition> indexes) async {
    for (final index in indexes) {
      await createIndex(index);
    }
  }

  /// Drops multiple vector indexes at once.
  ///
  /// Batch drops multiple indexes in sequence. This is more efficient
  /// than calling [dropIndex] individually for each index.
  ///
  /// [indexes] - Map of table names to lists of index names to drop
  ///
  /// Throws [DatabaseException] if any index removal fails.
  ///
  /// Example:
  /// ```dart
  /// final indexesToDrop = {
  ///   'documents': ['idx_embedding_en', 'idx_embedding_fr'],
  ///   'products': ['idx_description_embedding'],
  /// };
  ///
  /// await indexManager.dropIndexes(indexesToDrop);
  /// ```
  Future<void> dropIndexes(Map<String, List<String>> indexes) async {
    for (final entry in indexes.entries) {
      final tableName = entry.key;
      final indexNames = entry.value;

      for (final indexName in indexNames) {
        await dropIndex(tableName, indexName);
      }
    }
  }
}
