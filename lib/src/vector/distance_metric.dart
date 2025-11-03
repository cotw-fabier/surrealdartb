/// Distance metrics for vector similarity calculations.
///
/// This library defines the available distance metrics for measuring
/// similarity between vector embeddings in SurrealDB.
library;

/// Enum representing supported distance metrics for vector similarity.
///
/// Each metric calculates the distance/similarity between two vectors
/// using a different mathematical approach, suited for different use cases.
enum DistanceMetric {
  /// Euclidean distance (L2 norm) - measures straight-line distance.
  ///
  /// Computed as: sqrt(∑((a[i] - b[i])^2))
  ///
  /// Best for: General-purpose distance calculations and embeddings where
  /// absolute magnitude matters (e.g., image vectors, general ML embeddings).
  euclidean,

  /// Cosine distance - measures angle between vectors, ignoring magnitude.
  ///
  /// Computed as: 1 - (a·b / (||a|| * ||b||))
  ///
  /// Best for: Text embeddings, semantic similarity, document clustering
  /// where direction matters more than magnitude.
  cosine,

  /// Manhattan distance (L1 norm) - sum of absolute differences.
  ///
  /// Computed as: ∑(|a[i] - b[i]|)
  ///
  /// Best for: High-dimensional spaces, grid-based movement, when robustness
  /// to outliers is needed.
  manhattan,

  /// Minkowski distance - generalized distance metric.
  ///
  /// Computed as: (∑(|a[i] - b[i]|^p))^(1/p)
  ///
  /// Best for: Specialized applications requiring custom distance behavior.
  minkowski,
}

/// Extension methods for DistanceMetric.
extension DistanceMetricExtension on DistanceMetric {
  /// Converts the distance metric to its SurrealQL function name.
  ///
  /// Maps the enum value to the corresponding SurrealDB vector distance
  /// function name for use in queries.
  ///
  /// Returns the SurrealQL function name without the `vector::distance::`
  /// prefix (e.g., "euclidean", "cosine", "manhattan", "minkowski").
  ///
  /// Example:
  /// ```dart
  /// final metric = DistanceMetric.euclidean;
  /// print(metric.toSurrealQLFunction()); // "euclidean"
  ///
  /// // Used in query:
  /// // SELECT *, vector::distance::euclidean(embedding, $query) AS distance
  /// ```
  String toSurrealQLFunction() {
    return switch (this) {
      DistanceMetric.euclidean => 'euclidean',
      DistanceMetric.cosine => 'cosine',
      DistanceMetric.manhattan => 'manhattan',
      DistanceMetric.minkowski => 'minkowski',
    };
  }

  /// Returns the full SurrealQL function path.
  ///
  /// Returns the complete function name including the appropriate namespace
  /// prefix (`vector::distance::` or `vector::similarity::`) for use in
  /// SurrealQL queries.
  ///
  /// Note: Cosine uses the similarity namespace, while others use distance.
  ///
  /// Example:
  /// ```dart
  /// final metric1 = DistanceMetric.euclidean;
  /// print(metric1.toFullSurrealQLFunction()); // "vector::distance::euclidean"
  ///
  /// final metric2 = DistanceMetric.cosine;
  /// print(metric2.toFullSurrealQLFunction()); // "vector::similarity::cosine"
  /// ```
  String toFullSurrealQLFunction() {
    // Cosine is a similarity metric, not a distance metric
    if (this == DistanceMetric.cosine) {
      return 'vector::similarity::${toSurrealQLFunction()}';
    }
    return 'vector::distance::${toSurrealQLFunction()}';
  }

  /// Returns the uppercase metric name for use in KNN operator.
  ///
  /// The KNN operator requires uppercase metric names when specifying
  /// the distance function explicitly in queries.
  ///
  /// Example:
  /// ```dart
  /// final metric = DistanceMetric.euclidean;
  /// print(metric.toKnnOperatorName()); // "EUCLIDEAN"
  ///
  /// // Used in query:
  /// // WHERE embedding <|10, EUCLIDEAN|> $queryVector
  /// ```
  String toKnnOperatorName() {
    return switch (this) {
      DistanceMetric.euclidean => 'EUCLIDEAN',
      DistanceMetric.cosine => 'COSINE',
      DistanceMetric.manhattan => 'MANHATTAN',
      DistanceMetric.minkowski => 'MINKOWSKI',
    };
  }
}
