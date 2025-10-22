/// RecordId type for SurrealDB table:id identifiers.
///
/// This library provides the RecordId class which represents a SurrealDB
/// record identifier in the format "table:id".
library;

/// Represents a SurrealDB record identifier.
///
/// A RecordId consists of a table name and an ID, which can be either a
/// string or a number. The string representation follows the format "table:id".
///
/// Example:
/// ```dart
/// // Create from table and id
/// final person = RecordId('person', 'alice');
/// print(person); // person:alice
///
/// // Parse from string
/// final parsed = RecordId.parse('person:alice');
/// print(parsed.table); // person
/// print(parsed.id); // alice
///
/// // Numeric ID
/// final user = RecordId('user', 123);
/// print(user); // user:123
/// ```
class RecordId {
  /// Creates a RecordId with the given table and id.
  ///
  /// The [table] must be a non-empty string representing a valid SurrealDB
  /// table name (alphanumeric and underscores, starting with a letter).
  ///
  /// The [id] can be either a String or a number (int or double).
  ///
  /// Throws [ArgumentError] if table is empty or invalid, or if id is null
  /// or of an unsupported type.
  RecordId(String table, dynamic id) : _table = table, _id = id {
    // Validate table name
    if (table.isEmpty) {
      throw ArgumentError('Table name cannot be empty');
    }

    // Basic validation: table should start with letter or underscore
    // and contain only alphanumeric characters and underscores
    final validTablePattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!validTablePattern.hasMatch(table)) {
      throw ArgumentError(
        'Invalid table name: $table. Must start with letter or underscore '
        'and contain only alphanumeric characters and underscores.',
      );
    }

    // Validate id type
    if (id == null) {
      throw ArgumentError('ID cannot be null');
    }

    if (id is! String && id is! int && id is! double) {
      throw ArgumentError(
        'ID must be a String, int, or double, got ${id.runtimeType}',
      );
    }

    // Validate string ID is not empty
    if (id is String && id.isEmpty) {
      throw ArgumentError('String ID cannot be empty');
    }
  }

  /// Parses a RecordId from a string in "table:id" format.
  ///
  /// The string must contain exactly one colon separator. The table part
  /// must be a valid table name, and the id part will be parsed as a
  /// number if possible, otherwise kept as a string.
  ///
  /// Throws [ArgumentError] if the format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final person = RecordId.parse('person:alice');
  /// final user = RecordId.parse('user:123'); // id will be int 123
  /// ```
  factory RecordId.parse(String recordId) {
    if (recordId.isEmpty) {
      throw ArgumentError('RecordId string cannot be empty');
    }

    final parts = recordId.split(':');
    if (parts.length != 2) {
      throw ArgumentError(
        'Invalid RecordId format: $recordId. Expected format: table:id',
      );
    }

    final table = parts[0];
    final idStr = parts[1];

    if (table.isEmpty) {
      throw ArgumentError('Table name cannot be empty in RecordId: $recordId');
    }

    if (idStr.isEmpty) {
      throw ArgumentError('ID cannot be empty in RecordId: $recordId');
    }

    // Try to parse as number
    dynamic id = idStr;
    final intValue = int.tryParse(idStr);
    if (intValue != null) {
      id = intValue;
    } else {
      final doubleValue = double.tryParse(idStr);
      if (doubleValue != null) {
        id = doubleValue;
      }
    }

    return RecordId(table, id);
  }

  /// Creates a RecordId from JSON.
  ///
  /// The JSON can be either:
  /// - A string in "table:id" format
  /// - A map with "table" and "id" fields
  ///
  /// Throws [ArgumentError] if the JSON format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final rid1 = RecordId.fromJson('person:alice');
  /// final rid2 = RecordId.fromJson({'table': 'person', 'id': 'alice'});
  /// ```
  factory RecordId.fromJson(dynamic json) {
    if (json is String) {
      return RecordId.parse(json);
    }

    if (json is Map<String, dynamic>) {
      final table = json['table'];
      final id = json['id'];

      if (table == null || id == null) {
        throw ArgumentError(
          'RecordId JSON map must contain both "table" and "id" fields',
        );
      }

      if (table is! String) {
        throw ArgumentError(
          'RecordId "table" field must be a String, got ${table.runtimeType}',
        );
      }

      return RecordId(table, id);
    }

    throw ArgumentError(
      'RecordId JSON must be a String or Map<String, dynamic>, '
      'got ${json.runtimeType}',
    );
  }

  final String _table;
  final dynamic _id;

  /// The table name.
  String get table => _table;

  /// The record ID (can be String, int, or double).
  dynamic get id => _id;

  /// Returns the string representation in "table:id" format.
  ///
  /// Example:
  /// ```dart
  /// final rid = RecordId('person', 'alice');
  /// print(rid.toString()); // person:alice
  /// ```
  @override
  String toString() => '$_table:$_id';

  /// Converts to JSON for FFI transport.
  ///
  /// Returns the string representation in "table:id" format, which is the
  /// standard SurrealDB format for record identifiers.
  ///
  /// Example:
  /// ```dart
  /// final rid = RecordId('person', 'alice');
  /// final json = rid.toJson(); // "person:alice"
  /// ```
  String toJson() => toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecordId && other._table == _table && other._id == _id;
  }

  @override
  int get hashCode => Object.hash(_table, _id);
}
