/// Base class and implementations for type-safe where clauses.
///
/// This library provides the foundation for building type-safe where conditions
/// with support for logical operators (AND, OR) and proper precedence handling.
///
/// ## Basic Usage
///
/// ```dart
/// // Simple condition
/// final condition = EqualsCondition('status', 'active');
///
/// // Combined with AND
/// final combined = EqualsCondition('status', 'active') &
///                  GreaterThanCondition('age', 18);
///
/// // Combined with OR
/// final orCondition = EqualsCondition('role', 'admin') |
///                     EqualsCondition('role', 'moderator');
/// ```
///
/// ## Complex Conditions
///
/// ```dart
/// // Parentheses for precedence
/// final complex = (ageCondition1 | ageCondition2) & statusCondition;
/// ```
library;

import '../database.dart';

/// Base class for all where conditions.
///
/// This abstract class defines the interface for type-safe where conditions
/// and implements operator overloading for logical AND (&) and OR (|).
///
/// All concrete condition classes (EqualsCondition, BetweenCondition, etc.)
/// extend this base class.
abstract class WhereCondition {
  /// Converts this condition to a SurrealQL WHERE clause fragment.
  ///
  /// [db] - Database instance (reserved for future parameter binding)
  ///
  /// Returns a SurrealQL string fragment representing this condition.
  String toSurrealQL(Database db);

  /// Combines this condition with another using logical AND.
  ///
  /// Creates an AndCondition that requires both this condition and
  /// the other condition to be true.
  ///
  /// Example:
  /// ```dart
  /// final combined = condition1 & condition2;
  /// ```
  WhereCondition operator &(WhereCondition other) => AndCondition(this, other);

  /// Combines this condition with another using logical OR.
  ///
  /// Creates an OrCondition that requires either this condition or
  /// the other condition to be true.
  ///
  /// Example:
  /// ```dart
  /// final combined = condition1 | condition2;
  /// ```
  WhereCondition operator |(WhereCondition other) => OrCondition(this, other);
}

/// Logical AND condition combining two conditions.
///
/// This condition is true when both the left and right conditions are true.
/// Generates SurrealQL with proper parentheses for precedence.
class AndCondition extends WhereCondition {
  /// Creates an AND condition.
  ///
  /// [left] - The left-hand condition
  /// [right] - The right-hand condition
  AndCondition(this.left, this.right);

  /// The left-hand condition.
  final WhereCondition left;

  /// The right-hand condition.
  final WhereCondition right;

  @override
  String toSurrealQL(Database db) {
    return '(${left.toSurrealQL(db)} AND ${right.toSurrealQL(db)})';
  }

  @override
  String toString() => 'AndCondition($left, $right)';
}

/// Logical OR condition combining two conditions.
///
/// This condition is true when either the left or right condition is true.
/// Generates SurrealQL with proper parentheses for precedence.
class OrCondition extends WhereCondition {
  /// Creates an OR condition.
  ///
  /// [left] - The left-hand condition
  /// [right] - The right-hand condition
  OrCondition(this.left, this.right);

  /// The left-hand condition.
  final WhereCondition left;

  /// The right-hand condition.
  final WhereCondition right;

  @override
  String toSurrealQL(Database db) {
    return '(${left.toSurrealQL(db)} OR ${right.toSurrealQL(db)})';
  }

  @override
  String toString() => 'OrCondition($left, $right)';
}

/// Equality condition (field = value).
///
/// This condition checks if a field equals a specific value.
class EqualsCondition<T> extends WhereCondition {
  /// Creates an equality condition.
  ///
  /// [fieldPath] - The field path (e.g., 'name' or 'location.city')
  /// [value] - The value to compare against
  EqualsCondition(this.fieldPath, this.value);

  /// The field path to check.
  final String fieldPath;

  /// The value to compare against.
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath = ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'EqualsCondition($fieldPath, $value)';
}

/// Between condition (field >= min AND field <= max).
///
/// This condition checks if a field value is between two values (inclusive).
class BetweenCondition<T> extends WhereCondition {
  /// Creates a between condition.
  ///
  /// [fieldPath] - The field path to check
  /// [min] - The minimum value (inclusive)
  /// [max] - The maximum value (inclusive)
  BetweenCondition(this.fieldPath, this.min, this.max);

  /// The field path to check.
  final String fieldPath;

  /// The minimum value (inclusive).
  final T min;

  /// The maximum value (inclusive).
  final T max;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath >= ${_formatValue(min)} AND $fieldPath <= ${_formatValue(max)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'BetweenCondition($fieldPath, $min, $max)';
}

/// Greater than condition (field > value).
class GreaterThanCondition<T> extends WhereCondition {
  /// Creates a greater than condition.
  GreaterThanCondition(this.fieldPath, this.value);

  final String fieldPath;
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath > ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'GreaterThanCondition($fieldPath, $value)';
}

/// Less than condition (field < value).
class LessThanCondition<T> extends WhereCondition {
  /// Creates a less than condition.
  LessThanCondition(this.fieldPath, this.value);

  final String fieldPath;
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath < ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'LessThanCondition($fieldPath, $value)';
}

/// Greater than or equal condition (field >= value).
class GreaterOrEqualCondition<T> extends WhereCondition {
  /// Creates a greater than or equal condition.
  GreaterOrEqualCondition(this.fieldPath, this.value);

  final String fieldPath;
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath >= ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'GreaterOrEqualCondition($fieldPath, $value)';
}

/// Less than or equal condition (field <= value).
class LessOrEqualCondition<T> extends WhereCondition {
  /// Creates a less than or equal condition.
  LessOrEqualCondition(this.fieldPath, this.value);

  final String fieldPath;
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath <= ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'LessOrEqualCondition($fieldPath, $value)';
}

/// Contains condition for string fields (field CONTAINS value).
class ContainsCondition extends WhereCondition {
  /// Creates a contains condition.
  ContainsCondition(this.fieldPath, this.value);

  final String fieldPath;
  final String value;

  @override
  String toSurrealQL(Database db) {
    return "$fieldPath CONTAINS '${value.replaceAll("'", "\\'")}'";
  }

  @override
  String toString() => 'ContainsCondition($fieldPath, $value)';
}

/// Case-insensitive pattern matching condition using ~ operator.
///
/// Supports SurrealDB's regex-like pattern matching with wildcards:
/// - % (any characters)
/// - _ (single character)
class IlikeCondition extends WhereCondition {
  /// Creates a case-insensitive pattern matching condition.
  IlikeCondition(this.fieldPath, this.pattern);

  final String fieldPath;
  final String pattern;

  @override
  String toSurrealQL(Database db) {
    return "$fieldPath ~ '${pattern.replaceAll("'", "\\'")}'";
  }

  @override
  String toString() => 'IlikeCondition($fieldPath, $pattern)';
}

/// Starts with condition for prefix matching.
///
/// Checks if a string field starts with a specific prefix.
class StartsWithCondition extends WhereCondition {
  /// Creates a starts with condition.
  StartsWithCondition(this.fieldPath, this.prefix);

  final String fieldPath;
  final String prefix;

  @override
  String toSurrealQL(Database db) {
    // Use regex pattern for starts with: ^prefix
    return "$fieldPath ~ '^${prefix.replaceAll("'", "\\'")}'";
  }

  @override
  String toString() => 'StartsWithCondition($fieldPath, $prefix)';
}

/// Ends with condition for suffix matching.
///
/// Checks if a string field ends with a specific suffix.
class EndsWithCondition extends WhereCondition {
  /// Creates an ends with condition.
  EndsWithCondition(this.fieldPath, this.suffix);

  final String fieldPath;
  final String suffix;

  @override
  String toSurrealQL(Database db) {
    // Use regex pattern for ends with: suffix$
    return "$fieldPath ~ '${suffix.replaceAll("'", "\'")}\$'";
  }

  @override
  String toString() => 'EndsWithCondition($fieldPath, $suffix)';
}

/// In list condition for matching any value in a list.
///
/// Checks if a field value matches any value in the specified list.
class InListCondition<T> extends WhereCondition {
  /// Creates an in list condition.
  InListCondition(this.fieldPath, this.values);

  final String fieldPath;
  final List<T> values;

  @override
  String toSurrealQL(Database db) {
    final formattedValues = values.map((v) => _formatValue(v)).join(', ');
    return '$fieldPath IN [$formattedValues]';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'InListCondition($fieldPath, $values)';
}

/// Not equals condition (field != value).
class NotEqualsCondition<T> extends WhereCondition {
  /// Creates a not equals condition.
  NotEqualsCondition(this.fieldPath, this.value);

  final String fieldPath;
  final T value;

  @override
  String toSurrealQL(Database db) {
    return '$fieldPath != ${_formatValue(value)}';
  }

  String _formatValue(dynamic val) {
    if (val is String) {
      return "'${val.replaceAll("'", "\\'")}'";
    }
    if (val is bool || val is num) {
      return val.toString();
    }
    return "'$val'";
  }

  @override
  String toString() => 'NotEqualsCondition($fieldPath, $value)';
}
