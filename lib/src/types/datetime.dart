/// Datetime type for SurrealDB datetime values.
///
/// This library provides the Datetime class which wraps SurrealDB datetime
/// with conversion to/from Dart DateTime.
library;

/// Wraps a SurrealDB datetime value with conversion to/from Dart DateTime.
///
/// SurrealDB datetimes are serialized in ISO 8601 format for FFI transport.
/// This class provides convenient conversion between Dart's DateTime and
/// the string representation used by SurrealDB.
///
/// Example:
/// ```dart
/// // Create from Dart DateTime
/// final now = Datetime(DateTime.now());
/// print(now.toIso8601String());
///
/// // Parse from ISO 8601 string
/// final parsed = Datetime.parse('2023-10-21T12:00:00Z');
/// final dartDateTime = parsed.toDateTime();
///
/// // Serialize for FFI
/// final json = now.toJson(); // ISO 8601 string
/// ```
class Datetime {
  /// Creates a Datetime from a Dart DateTime.
  ///
  /// The DateTime is stored and can be converted back to a Dart DateTime
  /// or serialized to ISO 8601 format.
  ///
  /// Example:
  /// ```dart
  /// final now = Datetime(DateTime.now());
  /// final specific = Datetime(DateTime(2023, 10, 21, 12, 0, 0));
  /// ```
  Datetime(DateTime dateTime) : _dateTime = dateTime;

  /// Parses a Datetime from an ISO 8601 string.
  ///
  /// Throws [FormatException] if the string is not a valid ISO 8601 datetime.
  ///
  /// Example:
  /// ```dart
  /// final dt1 = Datetime.parse('2023-10-21T12:00:00Z');
  /// final dt2 = Datetime.parse('2023-10-21T12:00:00.123Z');
  /// final dt3 = Datetime.parse('2023-10-21T12:00:00+05:30');
  /// ```
  factory Datetime.parse(String iso8601) {
    try {
      final dateTime = DateTime.parse(iso8601);
      return Datetime(dateTime);
    } catch (e) {
      throw FormatException(
        'Invalid ISO 8601 datetime string: $iso8601',
        iso8601,
      );
    }
  }

  /// Creates a Datetime from JSON.
  ///
  /// The JSON must be an ISO 8601 datetime string.
  ///
  /// Throws [ArgumentError] if JSON is not a string, or [FormatException]
  /// if the string is not a valid ISO 8601 datetime.
  ///
  /// Example:
  /// ```dart
  /// final dt = Datetime.fromJson('2023-10-21T12:00:00Z');
  /// ```
  factory Datetime.fromJson(dynamic json) {
    if (json is! String) {
      throw ArgumentError(
        'Datetime JSON must be a String, got ${json.runtimeType}',
      );
    }
    return Datetime.parse(json);
  }

  final DateTime _dateTime;

  /// Converts to a Dart DateTime.
  ///
  /// Returns the underlying DateTime value.
  ///
  /// Example:
  /// ```dart
  /// final surrealDt = Datetime.parse('2023-10-21T12:00:00Z');
  /// final dartDt = surrealDt.toDateTime();
  /// print(dartDt.year); // 2023
  /// ```
  DateTime toDateTime() => _dateTime;

  /// Converts to ISO 8601 string format.
  ///
  /// This is the format used by SurrealDB for datetime serialization.
  ///
  /// Example:
  /// ```dart
  /// final dt = Datetime(DateTime(2023, 10, 21, 12, 0, 0));
  /// print(dt.toIso8601String()); // 2023-10-21T12:00:00.000
  /// ```
  String toIso8601String() => _dateTime.toIso8601String();

  /// Converts to JSON for FFI transport.
  ///
  /// Returns the ISO 8601 string representation.
  ///
  /// Example:
  /// ```dart
  /// final dt = Datetime(DateTime.now());
  /// final json = dt.toJson(); // ISO 8601 string
  /// ```
  String toJson() => toIso8601String();

  @override
  String toString() => toIso8601String();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Datetime && other._dateTime == _dateTime;
  }

  @override
  int get hashCode => _dateTime.hashCode;
}
