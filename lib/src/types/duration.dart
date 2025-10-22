/// Duration type for SurrealDB duration values.
///
/// This library provides the SurrealDuration class which wraps SurrealDB
/// duration with conversion to/from Dart Duration.
library;

/// Wraps a SurrealDB duration value with conversion to/from Dart Duration.
///
/// SurrealDB durations support a more flexible string syntax than standard
/// ISO 8601 durations, including units like "2h30m", "5d", "1w3d", etc.
///
/// Named SurrealDuration to avoid conflict with Dart's built-in Duration class.
///
/// Supported units:
/// - ns: nanoseconds
/// - us/µs: microseconds
/// - ms: milliseconds
/// - s: seconds
/// - m: minutes
/// - h: hours
/// - d: days
/// - w: weeks
///
/// Example:
/// ```dart
/// // Create from Dart Duration
/// final duration = SurrealDuration(Duration(hours: 2, minutes: 30));
/// print(duration.toString()); // 2h30m
///
/// // Parse from SurrealDB string
/// final parsed = SurrealDuration.parse('2h30m');
/// final dartDuration = parsed.toDuration();
///
/// // Complex duration
/// final complex = SurrealDuration.parse('1w3d5h30m');
/// ```
class SurrealDuration {
  /// Creates a SurrealDuration from a Dart Duration.
  ///
  /// The Duration is stored and can be converted back to a Dart Duration
  /// or serialized to SurrealDB string format.
  ///
  /// Example:
  /// ```dart
  /// final dur = SurrealDuration(Duration(hours: 2, minutes: 30));
  /// ```
  SurrealDuration(Duration duration) : _duration = duration;

  /// Parses a SurrealDuration from a SurrealDB duration string.
  ///
  /// Supports units: ns, us/µs, ms, s, m, h, d, w
  ///
  /// Throws [FormatException] if the string format is invalid.
  ///
  /// Example:
  /// ```dart
  /// final d1 = SurrealDuration.parse('2h30m');
  /// final d2 = SurrealDuration.parse('5d');
  /// final d3 = SurrealDuration.parse('1w3d5h30m15s');
  /// ```
  factory SurrealDuration.parse(String str) {
    if (str.isEmpty) {
      throw FormatException('Duration string cannot be empty');
    }

    // Pattern to match number followed by unit
    final pattern = RegExp(r'(\d+(?:\.\d+)?)(ns|us|µs|ms|s|m|h|d|w)');
    final matches = pattern.allMatches(str);

    if (matches.isEmpty) {
      throw FormatException(
        'Invalid duration format: $str. Expected format like "2h30m" or "5d"',
        str,
      );
    }

    var totalMicroseconds = 0;

    for (final match in matches) {
      final valueStr = match.group(1)!;
      final unit = match.group(2)!;

      final value = double.parse(valueStr);

      // Convert to microseconds based on unit
      final microseconds = switch (unit) {
        'ns' => (value / 1000).round(),
        'us' || 'µs' => value.round(),
        'ms' => (value * 1000).round(),
        's' => (value * 1000000).round(),
        'm' => (value * 60 * 1000000).round(),
        'h' => (value * 60 * 60 * 1000000).round(),
        'd' => (value * 24 * 60 * 60 * 1000000).round(),
        'w' => (value * 7 * 24 * 60 * 60 * 1000000).round(),
        _ => throw FormatException('Unknown unit: $unit', str),
      };

      totalMicroseconds += microseconds;
    }

    return SurrealDuration(Duration(microseconds: totalMicroseconds));
  }

  /// Creates a SurrealDuration from JSON.
  ///
  /// The JSON must be a SurrealDB duration string.
  ///
  /// Throws [ArgumentError] if JSON is not a string, or [FormatException]
  /// if the string is not a valid duration.
  ///
  /// Example:
  /// ```dart
  /// final dur = SurrealDuration.fromJson('2h30m');
  /// ```
  factory SurrealDuration.fromJson(dynamic json) {
    if (json is! String) {
      throw ArgumentError(
        'SurrealDuration JSON must be a String, got ${json.runtimeType}',
      );
    }
    return SurrealDuration.parse(json);
  }

  final Duration _duration;

  /// Converts to a Dart Duration.
  ///
  /// Returns the underlying Duration value.
  ///
  /// Example:
  /// ```dart
  /// final surrealDur = SurrealDuration.parse('2h30m');
  /// final dartDur = surrealDur.toDuration();
  /// print(dartDur.inHours); // 2
  /// print(dartDur.inMinutes); // 150
  /// ```
  Duration toDuration() => _duration;

  /// Converts to SurrealDB duration string format.
  ///
  /// The string uses the most appropriate units to represent the duration
  /// compactly. For example, 150 minutes becomes "2h30m".
  ///
  /// Example:
  /// ```dart
  /// final dur = SurrealDuration(Duration(hours: 2, minutes: 30));
  /// print(dur.toString()); // 2h30m
  /// ```
  @override
  String toString() {
    if (_duration == Duration.zero) {
      return '0s';
    }

    final buffer = StringBuffer();
    var remaining = _duration.inMicroseconds;

    // Weeks
    final weeks = remaining ~/ (7 * 24 * 60 * 60 * 1000000);
    if (weeks > 0) {
      buffer.write('${weeks}w');
      remaining -= weeks * 7 * 24 * 60 * 60 * 1000000;
    }

    // Days
    final days = remaining ~/ (24 * 60 * 60 * 1000000);
    if (days > 0) {
      buffer.write('${days}d');
      remaining -= days * 24 * 60 * 60 * 1000000;
    }

    // Hours
    final hours = remaining ~/ (60 * 60 * 1000000);
    if (hours > 0) {
      buffer.write('${hours}h');
      remaining -= hours * 60 * 60 * 1000000;
    }

    // Minutes
    final minutes = remaining ~/ (60 * 1000000);
    if (minutes > 0) {
      buffer.write('${minutes}m');
      remaining -= minutes * 60 * 1000000;
    }

    // Seconds
    final seconds = remaining ~/ 1000000;
    if (seconds > 0) {
      buffer.write('${seconds}s');
      remaining -= seconds * 1000000;
    }

    // Milliseconds
    final milliseconds = remaining ~/ 1000;
    if (milliseconds > 0) {
      buffer.write('${milliseconds}ms');
      remaining -= milliseconds * 1000;
    }

    // Microseconds
    if (remaining > 0) {
      buffer.write('${remaining}us');
    }

    return buffer.toString();
  }

  /// Converts to JSON for FFI transport.
  ///
  /// Returns the SurrealDB duration string representation.
  ///
  /// Example:
  /// ```dart
  /// final dur = SurrealDuration(Duration(hours: 2));
  /// final json = dur.toJson(); // "2h"
  /// ```
  String toJson() => toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SurrealDuration && other._duration == _duration;
  }

  @override
  int get hashCode => _duration.hashCode;
}
