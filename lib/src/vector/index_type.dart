/// Index types for vector search optimization.
///
/// This library provides the IndexType enum which represents the different
/// index structures supported by SurrealDB for vector similarity search.
library;

/// Index type enumeration for vector search optimization.
///
/// Represents the different index structures that can be used to optimize
/// vector similarity search operations in SurrealDB.
enum IndexType {
  /// M-Tree (Metric Tree) index.
  ///
  /// A tree-based index structure optimized for metric spaces.
  /// Provides balanced performance for medium-sized datasets.
  ///
  /// Best for: 1,000 to 100,000 vectors.
  /// Characteristics: Good balance of build time, memory, and query speed.
  mtree,

  /// HNSW (Hierarchical Navigable Small World) index.
  ///
  /// A graph-based approximate nearest neighbor index.
  /// Optimized for large-scale vector search with high recall.
  ///
  /// Best for: >100,000 vectors.
  /// Characteristics: Fast queries, higher memory usage, longer build time.
  hnsw,

  /// Flat (exhaustive search) index.
  ///
  /// No index structure - performs exact nearest neighbor search by
  /// comparing query vector against all stored vectors.
  ///
  /// Best for: <1,000 vectors or when exact results are required.
  /// Characteristics: No build time, low memory, slower queries on large datasets.
  flat,

  /// Automatic index type selection.
  ///
  /// Lets the system choose the optimal index type based on dataset size.
  /// Uses heuristics to select between FLAT, MTREE, and HNSW.
  ///
  /// Selection strategy:
  /// - Small datasets (<1,000): FLAT
  /// - Medium datasets (1,000-100,000): MTREE
  /// - Large datasets (>100,000): HNSW
  auto,
}

/// Extension methods for IndexType.
extension IndexTypeExtension on IndexType {
  /// Converts the index type to its SurrealQL keyword.
  ///
  /// Maps the enum value to the corresponding SurrealDB index type keyword
  /// for use in DEFINE INDEX statements.
  ///
  /// Returns the SurrealQL keyword (e.g., "MTREE", "HNSW", "FLAT").
  /// Returns null for [IndexType.auto] as it requires dataset size analysis.
  ///
  /// Example:
  /// ```dart
  /// final indexType = IndexType.mtree;
  /// print(indexType.toSurrealQL()); // "MTREE"
  ///
  /// // Used in DDL:
  /// // DEFINE INDEX idx_name ON table FIELDS field MTREE DISTANCE euclidean
  /// ```
  String? toSurrealQL() {
    return switch (this) {
      IndexType.mtree => 'MTREE',
      IndexType.hnsw => 'HNSW',
      IndexType.flat => 'FLAT',
      IndexType.auto => null, // Requires resolution to concrete type
    };
  }

  /// Resolves auto-selection to a concrete index type based on dataset size.
  ///
  /// Applies heuristics to choose the optimal index type for the given
  /// dataset size. If this index type is not [IndexType.auto], returns
  /// self unchanged.
  ///
  /// Selection strategy:
  /// - Small datasets (<1,000 vectors): FLAT
  /// - Medium datasets (1,000-100,000 vectors): MTREE
  /// - Large datasets (>100,000 vectors): HNSW
  ///
  /// Parameters:
  /// - [datasetSize]: Estimated number of vectors in the dataset
  ///
  /// Returns the resolved concrete index type.
  ///
  /// Example:
  /// ```dart
  /// final autoType = IndexType.auto;
  /// final resolved = autoType.resolve(50000); // Returns IndexType.mtree
  ///
  /// final explicitType = IndexType.hnsw;
  /// final unchanged = explicitType.resolve(500); // Returns IndexType.hnsw
  /// ```
  IndexType resolve({int datasetSize = 0}) {
    if (this != IndexType.auto) {
      return this;
    }

    // Apply auto-selection heuristics
    if (datasetSize < 1000) {
      return IndexType.flat;
    } else if (datasetSize < 100000) {
      return IndexType.mtree;
    } else {
      return IndexType.hnsw;
    }
  }

  /// Checks if this index type is a concrete type (not auto).
  ///
  /// Returns true if this is a concrete index type that can be used
  /// directly in DDL statements, false if it requires resolution.
  ///
  /// Example:
  /// ```dart
  /// print(IndexType.mtree.isConcrete()); // true
  /// print(IndexType.auto.isConcrete()); // false
  /// ```
  bool isConcrete() => this != IndexType.auto;
}
