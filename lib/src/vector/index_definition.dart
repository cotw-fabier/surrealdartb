/// Index definition for vector similarity search.
///
/// This library provides the IndexDefinition class which represents the
/// configuration for a vector index in SurrealDB.
library;

import 'distance_metric.dart';
import 'index_type.dart';

/// Definition for a vector similarity search index.
///
/// Represents the configuration needed to create a vector index in SurrealDB.
/// Includes index type, distance metric, dimensions, and optional parameters
/// for specific index types (HNSW, MTREE).
///
/// Example:
/// ```dart
/// // Basic MTREE index for 768-dimensional embeddings
/// final index = IndexDefinition(
///   indexName: 'idx_embedding',
///   tableName: 'documents',
///   fieldName: 'embedding',
///   distanceMetric: DistanceMetric.cosine,
///   dimensions: 768,
///   indexType: IndexType.mtree,
/// );
///
/// // HNSW index with custom parameters
/// final hnswIndex = IndexDefinition(
///   indexName: 'idx_large_embeddings',
///   tableName: 'documents',
///   fieldName: 'embedding',
///   distanceMetric: DistanceMetric.euclidean,
///   dimensions: 1536,
///   indexType: IndexType.hnsw,
///   m: 16,
///   efc: 200,
/// );
/// ```
class IndexDefinition {
  /// The name of the index.
  ///
  /// Must be unique within the table. Used in DDL statements and for
  /// identifying the index for operations like rebuild or drop.
  final String indexName;

  /// The name of the table this index belongs to.
  ///
  /// Specifies which table the index is created on.
  final String tableName;

  /// The name of the vector field to index.
  ///
  /// Must be a field that contains vector data in the table.
  final String fieldName;

  /// The distance metric to use for similarity calculations.
  ///
  /// Determines how similarity is measured between vectors during search.
  /// Common choices:
  /// - [DistanceMetric.cosine] for text embeddings
  /// - [DistanceMetric.euclidean] for general-purpose similarity
  final DistanceMetric distanceMetric;

  /// The type of index structure to use.
  ///
  /// Determines the index implementation strategy. Can be set to
  /// [IndexType.auto] to let the system choose based on dataset size.
  final IndexType indexType;

  /// The number of dimensions in the vector.
  ///
  /// Must match the dimension count of vectors stored in the indexed field.
  /// Common values:
  /// - 384: MiniLM sentence transformers
  /// - 768: BERT-base embeddings
  /// - 1536: OpenAI ada-002 embeddings
  final int dimensions;

  /// HNSW parameter: maximum number of connections per node.
  ///
  /// Only applicable for [IndexType.hnsw] indexes.
  /// Higher values increase recall and memory usage but slow down construction.
  /// Typical range: 4-64. Default in many systems: 16.
  final int? m;

  /// HNSW parameter: size of the dynamic candidate list during construction.
  ///
  /// Only applicable for [IndexType.hnsw] indexes.
  /// Higher values improve index quality but slow down construction.
  /// Typical range: 100-400. Should be >= M.
  final int? efc;

  /// MTREE parameter: maximum node capacity.
  ///
  /// Only applicable for [IndexType.mtree] indexes.
  /// Determines how many entries can be stored in each tree node.
  /// Higher values reduce tree depth but increase per-node search time.
  final int? capacity;

  /// Creates an IndexDefinition with the specified configuration.
  ///
  /// Parameters:
  /// - [indexName]: Name of the index (must be unique within table)
  /// - [tableName]: Name of the table to create the index on
  /// - [fieldName]: Name of the vector field to index
  /// - [distanceMetric]: Distance metric for similarity calculations
  /// - [indexType]: Type of index structure (defaults to auto-selection)
  /// - [dimensions]: Number of vector dimensions
  /// - [m]: HNSW parameter - connections per node (optional)
  /// - [efc]: HNSW parameter - construction candidate list size (optional)
  /// - [capacity]: MTREE parameter - node capacity (optional)
  ///
  /// Throws [ArgumentError] if validation fails (e.g., dimensions <= 0).
  ///
  /// Example:
  /// ```dart
  /// final index = IndexDefinition(
  ///   indexName: 'idx_products_embedding',
  ///   tableName: 'products',
  ///   fieldName: 'description_embedding',
  ///   distanceMetric: DistanceMetric.cosine,
  ///   dimensions: 384,
  ///   indexType: IndexType.auto,
  /// );
  /// ```
  const IndexDefinition({
    required this.indexName,
    required this.tableName,
    required this.fieldName,
    required this.distanceMetric,
    this.indexType = IndexType.auto,
    required this.dimensions,
    this.m,
    this.efc,
    this.capacity,
  });

  /// Validates the index definition parameters.
  ///
  /// Checks that all parameters meet their constraints:
  /// - dimensions > 0
  /// - m > 0 (if specified)
  /// - efc > 0 (if specified)
  /// - capacity > 0 (if specified)
  /// - HNSW parameters only used with HNSW index type
  /// - MTREE parameters only used with MTREE index type
  ///
  /// Throws [ArgumentError] if any validation fails.
  ///
  /// Example:
  /// ```dart
  /// final index = IndexDefinition(
  ///   indexName: 'idx_test',
  ///   tableName: 'test',
  ///   fieldName: 'vec',
  ///   distanceMetric: DistanceMetric.euclidean,
  ///   dimensions: 128,
  /// );
  /// index.validate(); // Passes
  /// ```
  void validate() {
    if (dimensions <= 0) {
      throw ArgumentError(
        'Dimensions must be positive, got $dimensions',
      );
    }

    if (m != null && m! <= 0) {
      throw ArgumentError(
        'HNSW parameter M must be positive, got $m',
      );
    }

    if (efc != null && efc! <= 0) {
      throw ArgumentError(
        'HNSW parameter EFC must be positive, got $efc',
      );
    }

    if (capacity != null && capacity! <= 0) {
      throw ArgumentError(
        'MTREE parameter CAPACITY must be positive, got $capacity',
      );
    }

    // Resolve index type to check parameter compatibility
    final resolvedType = indexType.resolve();

    // Warn if HNSW parameters are used with non-HNSW index
    if ((m != null || efc != null) && resolvedType != IndexType.hnsw) {
      throw ArgumentError(
        'HNSW parameters (M, EFC) can only be used with HNSW index type, '
        'got $resolvedType',
      );
    }

    // Warn if MTREE parameters are used with non-MTREE index
    if (capacity != null && resolvedType != IndexType.mtree) {
      throw ArgumentError(
        'MTREE parameter (CAPACITY) can only be used with MTREE index type, '
        'got $resolvedType',
      );
    }

    if (indexName.trim().isEmpty) {
      throw ArgumentError('Index name cannot be empty');
    }

    if (tableName.trim().isEmpty) {
      throw ArgumentError('Table name cannot be empty');
    }

    if (fieldName.trim().isEmpty) {
      throw ArgumentError('Field name cannot be empty');
    }
  }

  /// Generates the SurrealQL DEFINE INDEX statement.
  ///
  /// Creates the DDL statement for creating this vector index in SurrealDB.
  /// Automatically resolves [IndexType.auto] to a concrete type based on
  /// heuristics if needed.
  ///
  /// The generated statement follows this format:
  /// ```sql
  /// DEFINE INDEX [indexName] ON [tableName] FIELDS [fieldName]
  /// [MTREE|HNSW|FLAT] DISTANCE [metric] DIMENSION [n]
  /// [M [value]] [EFC [value]] [CAPACITY [value]]
  /// ```
  ///
  /// Parameters:
  /// - [datasetSize]: Estimated dataset size for auto-selection (optional)
  ///
  /// Returns the complete DEFINE INDEX statement as a string.
  ///
  /// Throws [ArgumentError] if validation fails.
  ///
  /// Example:
  /// ```dart
  /// final index = IndexDefinition(
  ///   indexName: 'idx_embedding',
  ///   tableName: 'docs',
  ///   fieldName: 'embedding',
  ///   distanceMetric: DistanceMetric.cosine,
  ///   dimensions: 768,
  ///   indexType: IndexType.mtree,
  ///   capacity: 40,
  /// );
  ///
  /// print(index.toSurrealQL());
  /// // Output: DEFINE INDEX idx_embedding ON docs FIELDS embedding
  /// //         MTREE DISTANCE COSINE DIMENSION 768 CAPACITY 40
  /// ```
  String toSurrealQL({int datasetSize = 0}) {
    // Validate before generating
    validate();

    // Resolve index type if auto
    final resolvedType = indexType.resolve(datasetSize: datasetSize);
    final indexTypeKeyword = resolvedType.toSurrealQL();

    if (indexTypeKeyword == null) {
      throw StateError(
        'Index type could not be resolved to concrete type',
      );
    }

    // Build base statement
    final buffer = StringBuffer();
    buffer.write('DEFINE INDEX $indexName ON $tableName FIELDS $fieldName ');
    buffer.write('$indexTypeKeyword DISTANCE ${distanceMetric.toSurrealQLFunction().toUpperCase()} ');
    buffer.write('DIMENSION $dimensions');

    // Add optional parameters based on index type
    if (resolvedType == IndexType.hnsw) {
      if (m != null) {
        buffer.write(' M $m');
      }
      if (efc != null) {
        buffer.write(' EFC $efc');
      }
    } else if (resolvedType == IndexType.mtree) {
      if (capacity != null) {
        buffer.write(' CAPACITY $capacity');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'IndexDefinition('
        'indexName: $indexName, '
        'tableName: $tableName, '
        'fieldName: $fieldName, '
        'distanceMetric: $distanceMetric, '
        'indexType: $indexType, '
        'dimensions: $dimensions'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IndexDefinition) return false;
    return other.indexName == indexName &&
        other.tableName == tableName &&
        other.fieldName == fieldName &&
        other.distanceMetric == distanceMetric &&
        other.indexType == indexType &&
        other.dimensions == dimensions &&
        other.m == m &&
        other.efc == efc &&
        other.capacity == capacity;
  }

  @override
  int get hashCode => Object.hash(
        indexName,
        tableName,
        fieldName,
        distanceMetric,
        indexType,
        dimensions,
        m,
        efc,
        capacity,
      );
}
