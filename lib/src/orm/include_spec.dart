/// Include specification for relationship loading with filtering.
///
/// This class represents a request to include (eager-load) a relationship
/// when querying entities, with optional filtering, sorting, and limiting
/// of the related records.
///
/// ## Basic Usage
///
/// ```dart
/// // Simple include without filtering
/// final spec = IncludeSpec('posts');
///
/// // Include with where clause
/// final spec = IncludeSpec(
///   'posts',
///   where: (p) => p.whereStatus(equals: 'published'),
/// );
///
/// // Include with limit and orderBy
/// final spec = IncludeSpec(
///   'posts',
///   limit: 10,
///   orderBy: 'createdAt',
///   descending: true,
/// );
/// ```
///
/// ## Nested Includes
///
/// ```dart
/// // Include posts with nested comments
/// final spec = IncludeSpec(
///   'posts',
///   include: [
///     IncludeSpec('comments', limit: 5),
///     IncludeSpec('tags'),
///   ],
/// );
/// ```
library;

import 'where_condition.dart';

/// Specification for including a relationship in a query.
///
/// This class configures how a related entity should be loaded:
/// - Which relationship to include (by field name)
/// - Optional where clause to filter related records
/// - Optional limit to restrict number of related records
/// - Optional orderBy to sort related records
/// - Optional nested includes for multi-level loading
class IncludeSpec {
  /// Creates an include specification.
  ///
  /// [relationName] - The name of the relationship field to include
  /// [where] - Optional where clause to filter related records
  /// [limit] - Optional maximum number of related records to load
  /// [orderBy] - Optional field name to sort related records by
  /// [descending] - Whether to sort in descending order (default: false)
  /// [include] - Optional nested includes for related records
  const IncludeSpec(
    this.relationName, {
    this.where,
    this.limit,
    this.orderBy,
    this.descending,
    this.include,
  });

  /// The name of the relationship field to include.
  ///
  /// This should match a field annotated with @SurrealRecord,
  /// @SurrealRelation, or @SurrealEdge in the entity class.
  final String relationName;

  /// Optional where clause to filter the included related records.
  ///
  /// The where clause uses the WhereCondition system to build
  /// type-safe filtering expressions for the related entity.
  ///
  /// Example:
  /// ```dart
  /// where: (p) => p.whereStatus(equals: 'published')
  /// ```
  final WhereCondition? where;

  /// Optional maximum number of related records to include.
  ///
  /// When specified, only the first N related records will be
  /// loaded. Combined with orderBy, this enables "top N" queries.
  ///
  /// Example:
  /// ```dart
  /// limit: 10  // Include only first 10 related records
  /// ```
  final int? limit;

  /// Optional field name to sort related records by.
  ///
  /// When specified, related records will be sorted by this field
  /// before being returned. Combine with [descending] to control
  /// sort direction.
  ///
  /// Example:
  /// ```dart
  /// orderBy: 'createdAt'  // Sort by creation time
  /// ```
  final String? orderBy;

  /// Whether to sort in descending order.
  ///
  /// Only applies when [orderBy] is specified. When true, sorts
  /// from highest to lowest. When false or null, sorts from
  /// lowest to highest (ascending).
  final bool? descending;

  /// Optional nested includes for related records.
  ///
  /// Allows loading multi-level relationships in a single query.
  /// Each nested include has its own independent filtering,
  /// limiting, and sorting configuration.
  ///
  /// Example:
  /// ```dart
  /// include: [
  ///   IncludeSpec('comments', limit: 5),
  ///   IncludeSpec('tags'),
  /// ]
  /// ```
  final List<IncludeSpec>? include;

  @override
  String toString() {
    final parts = <String>['IncludeSpec($relationName'];

    if (where != null) {
      parts.add('where: <condition>');
    }
    if (limit != null) {
      parts.add('limit: $limit');
    }
    if (orderBy != null) {
      parts.add('orderBy: $orderBy');
    }
    if (descending != null) {
      parts.add('descending: $descending');
    }
    if (include != null && include!.isNotEmpty) {
      parts.add('include: [${include!.length} specs]');
    }

    return '${parts.join(', ')})';
  }
}
