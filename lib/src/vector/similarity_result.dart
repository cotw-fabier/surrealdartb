/// Result wrapper for vector similarity search operations.
///
/// This library provides the SimilarityResult class which combines a record
/// with its similarity distance value from a vector search query.
library;

/// Result wrapper combining a record with its similarity distance.
///
/// Represents the result of a vector similarity search operation, containing
/// both the matched record and the distance/similarity score from the query vector.
///
/// Generic type parameter:
/// - `[T]`: The type of the record data (typically `Map<String, dynamic>` or a model class)
///
/// Example:
/// ```dart
/// // Raw map result
/// final result = SimilarityResult<Map<String, dynamic>>(
///   record: {'id': 'user:1', 'name': 'Alice'},
///   distance: 0.85,
/// );
///
/// // Typed model result
/// final typedResult = SimilarityResult<User>(
///   record: User(id: 'user:1', name: 'Alice'),
///   distance: 0.85,
/// );
/// ```
class SimilarityResult<T> {
  /// The matched record data.
  ///
  /// Contains the full record that matched the similarity search query.
  /// The type depends on how results are deserialized (raw maps or typed models).
  final T record;

  /// The similarity distance value.
  ///
  /// Represents the distance or similarity score between the query vector
  /// and this record's vector field. Lower values typically indicate higher
  /// similarity (for distance metrics), though interpretation depends on the
  /// specific distance metric used.
  ///
  /// For cosine similarity: values range from -1 to 1 (higher = more similar)
  /// For Euclidean/Manhattan: lower values = more similar
  final double distance;

  /// Creates a SimilarityResult with the given record and distance.
  ///
  /// Parameters:
  /// - [record]: The matched record data
  /// - [distance]: The similarity distance value
  ///
  /// Example:
  /// ```dart
  /// final result = SimilarityResult(
  ///   record: {'id': 'doc:1', 'title': 'Example'},
  ///   distance: 0.42,
  /// );
  /// ```
  const SimilarityResult({
    required this.record,
    required this.distance,
  });

  /// Creates a SimilarityResult from JSON data.
  ///
  /// Expects the JSON to contain a 'distance' field with the similarity score.
  /// All other fields are combined into the record data.
  ///
  /// Parameters:
  /// - [json]: Map containing record fields and a 'distance' field
  /// - [recordFromJson]: Optional function to deserialize the record data into type T.
  ///   If not provided, the record is cast directly to T (suitable for Map types).
  ///
  /// Throws [ArgumentError] if the 'distance' field is missing or not a number.
  ///
  /// Example:
  /// ```dart
  /// // For Map<String, dynamic> records
  /// final result1 = SimilarityResult<Map<String, dynamic>>.fromJson({
  ///   'id': 'doc:1',
  ///   'title': 'Example',
  ///   'distance': 0.42,
  /// });
  ///
  /// // For typed model records
  /// final result2 = SimilarityResult<User>.fromJson(
  ///   {
  ///     'id': 'user:1',
  ///     'name': 'Alice',
  ///     'distance': 0.85,
  ///   },
  ///   recordFromJson: (json) => User.fromJson(json),
  /// );
  /// ```
  factory SimilarityResult.fromJson(
    Map<String, dynamic> json, {
    T Function(Map<String, dynamic>)? recordFromJson,
  }) {
    // Extract distance field
    final distanceValue = json['distance'];
    if (distanceValue == null) {
      throw ArgumentError(
        'SimilarityResult JSON must contain a "distance" field',
      );
    }
    if (distanceValue is! num) {
      throw ArgumentError(
        'Distance field must be a number, got ${distanceValue.runtimeType}',
      );
    }

    final distance = distanceValue.toDouble();

    // Remove distance from record data
    final recordData = Map<String, dynamic>.from(json)..remove('distance');

    // Deserialize record
    final record = recordFromJson != null
        ? recordFromJson(recordData)
        : recordData as T;

    return SimilarityResult(
      record: record,
      distance: distance,
    );
  }

  /// Creates a list of SimilarityResult from a JSON array.
  ///
  /// Convenience factory for deserializing multiple results from a query response.
  ///
  /// Parameters:
  /// - [jsonList]: List of JSON maps containing record and distance data
  /// - [recordFromJson]: Optional function to deserialize record data into type T
  ///
  /// Example:
  /// ```dart
  /// final results = SimilarityResult.listFromJson([
  ///   {'id': 'doc:1', 'title': 'First', 'distance': 0.1},
  ///   {'id': 'doc:2', 'title': 'Second', 'distance': 0.3},
  /// ]);
  /// ```
  static List<SimilarityResult<T>> listFromJson<T>(
    List<dynamic> jsonList, {
    T Function(Map<String, dynamic>)? recordFromJson,
  }) {
    return jsonList.map((json) {
      if (json is! Map<String, dynamic>) {
        throw ArgumentError(
          'List elements must be JSON objects, got ${json.runtimeType}',
        );
      }
      return SimilarityResult<T>.fromJson(json, recordFromJson: recordFromJson);
    }).toList();
  }

  /// Converts the result back to JSON format.
  ///
  /// Combines the record data with the distance field into a single map.
  ///
  /// Parameters:
  /// - [recordToJson]: Optional function to serialize the record to JSON.
  ///   If not provided, assumes the record is already a Map or has toJson method.
  ///
  /// Example:
  /// ```dart
  /// final result = SimilarityResult(
  ///   record: {'id': 'doc:1', 'title': 'Example'},
  ///   distance: 0.42,
  /// );
  /// final json = result.toJson();
  /// // Returns: {'id': 'doc:1', 'title': 'Example', 'distance': 0.42}
  /// ```
  Map<String, dynamic> toJson({
    Map<String, dynamic> Function(T)? recordToJson,
  }) {
    Map<String, dynamic> recordMap;

    if (recordToJson != null) {
      recordMap = recordToJson(record);
    } else if (record is Map<String, dynamic>) {
      recordMap = record as Map<String, dynamic>;
    } else {
      // Try to call toJson if it exists (duck typing approach)
      try {
        recordMap = (record as dynamic).toJson() as Map<String, dynamic>;
      } catch (e) {
        throw StateError(
          'Cannot convert record to JSON: provide recordToJson function',
        );
      }
    }

    return {
      ...recordMap,
      'distance': distance,
    };
  }

  @override
  String toString() {
    return 'SimilarityResult(distance: $distance, record: $record)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SimilarityResult<T>) return false;
    return other.record == record && other.distance == distance;
  }

  @override
  int get hashCode => Object.hash(record, distance);
}
