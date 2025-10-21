/// Query response wrapper class.
///
/// This library provides the Response class which wraps query results
/// and provides convenient methods for accessing and processing the data.
library;

/// Wrapper for query results from SurrealDB.
///
/// This class encapsulates the results of a query execution, providing
/// methods to access the results, check for errors, and extract specific
/// result items.
///
/// Query results are typically returned as a list of records, where each
/// record is a Map<String, dynamic>.
///
/// Example:
/// ```dart
/// final response = await db.query('SELECT * FROM person');
/// final results = response.getResults();
/// for (final record in results) {
///   print(record['name']);
/// }
/// ```
class Response {
  /// Creates a Response from raw query results.
  ///
  /// The [data] parameter should be the parsed JSON results from the
  /// native layer, typically a List of Maps.
  Response(this._data);

  /// Raw result data from the query.
  ///
  /// This can be:
  /// - A List<Map<String, dynamic>> for query results
  /// - A Map<String, dynamic> for single record operations
  /// - null for operations that don't return data
  final dynamic _data;

  /// List of errors encountered during query execution, if any.
  final List<String> _errors = [];

  /// Returns the query results as a list of records.
  ///
  /// Each record is represented as a Map<String, dynamic> where keys
  /// are field names and values are field values.
  ///
  /// If the query returned no results, returns an empty list.
  /// If the result is a single record, wraps it in a list.
  ///
  /// Example:
  /// ```dart
  /// final results = response.getResults();
  /// for (final record in results) {
  ///   final name = record['name'] as String;
  ///   final age = record['age'] as int;
  ///   print('$name is $age years old');
  /// }
  /// ```
  List<Map<String, dynamic>> getResults() {
    if (_data == null) {
      return [];
    }

    if (_data is List) {
      return (_data as List).cast<Map<String, dynamic>>();
    }

    if (_data is Map<String, dynamic>) {
      return [_data as Map<String, dynamic>];
    }

    return [];
  }

  /// Checks if the response contains any errors.
  ///
  /// Returns true if errors were encountered during query execution,
  /// false otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (response.hasErrors()) {
  ///   print('Errors: ${response.getErrors()}');
  /// }
  /// ```
  bool hasErrors() {
    return _errors.isNotEmpty;
  }

  /// Returns the list of error messages.
  ///
  /// If no errors occurred, returns an empty list.
  ///
  /// Example:
  /// ```dart
  /// final errors = response.getErrors();
  /// for (final error in errors) {
  ///   print('Error: $error');
  /// }
  /// ```
  List<String> getErrors() {
    return List.unmodifiable(_errors);
  }

  /// Extracts a specific result by index.
  ///
  /// This is useful when you know the query returns multiple result sets
  /// (e.g., from multiple statements) and you want to access a specific one.
  ///
  /// Parameters:
  /// - [index] - Zero-based index of the result to retrieve
  ///
  /// Returns the result at the specified index, or null if the index
  /// is out of bounds.
  ///
  /// Example:
  /// ```dart
  /// // Query with multiple statements
  /// final response = await db.query('''
  ///   SELECT * FROM person;
  ///   SELECT * FROM company;
  /// ''');
  ///
  /// final persons = response.takeResult(0);
  /// final companies = response.takeResult(1);
  /// ```
  dynamic takeResult(int index) {
    if (_data is! List) {
      return index == 0 ? _data : null;
    }

    final list = _data as List;
    if (index < 0 || index >= list.length) {
      return null;
    }

    return list[index];
  }

  /// Returns the number of results in the response.
  ///
  /// For list results, returns the list length.
  /// For single results, returns 1.
  /// For null results, returns 0.
  ///
  /// Example:
  /// ```dart
  /// final count = response.resultCount;
  /// print('Query returned $count results');
  /// ```
  int get resultCount {
    if (_data == null) {
      return 0;
    }

    if (_data is List) {
      return (_data as List).length;
    }

    return 1;
  }

  /// Returns true if the response contains no results.
  ///
  /// Example:
  /// ```dart
  /// if (response.isEmpty) {
  ///   print('No results found');
  /// }
  /// ```
  bool get isEmpty {
    return resultCount == 0;
  }

  /// Returns true if the response contains at least one result.
  ///
  /// Example:
  /// ```dart
  /// if (response.isNotEmpty) {
  ///   print('Found ${response.resultCount} results');
  /// }
  /// ```
  bool get isNotEmpty {
    return resultCount > 0;
  }

  /// Returns the first result, or null if no results.
  ///
  /// This is a convenience method for accessing the first record
  /// when you expect a single result.
  ///
  /// Example:
  /// ```dart
  /// final person = response.firstOrNull;
  /// if (person != null) {
  ///   print(person['name']);
  /// }
  /// ```
  Map<String, dynamic>? get firstOrNull {
    final results = getResults();
    return results.isEmpty ? null : results.first;
  }

  /// Returns the raw data from the response.
  ///
  /// This provides direct access to the underlying data structure,
  /// which may be a List, Map, or null depending on the query.
  ///
  /// Example:
  /// ```dart
  /// final raw = response.raw;
  /// print('Raw data type: ${raw.runtimeType}');
  /// ```
  dynamic get raw => _data;

  @override
  String toString() {
    if (hasErrors()) {
      return 'Response(errors: $_errors)';
    }
    return 'Response(count: $resultCount)';
  }
}
