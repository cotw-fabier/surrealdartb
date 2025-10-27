/// Metadata classes for ORM relationship definitions.
///
/// This library provides metadata structures that store information about
/// relationships detected from annotations on entity classes. The metadata
/// is used during code generation and query building to properly handle
/// relationship loading and serialization.
///
/// ## Relationship Types
///
/// ### RecordLinkMetadata
/// Represents a direct record reference using record IDs.
/// Generated from @SurrealRecord annotations.
///
/// ### GraphRelationMetadata
/// Represents a graph traversal relationship using SurrealDB's graph syntax.
/// Generated from @SurrealRelation annotations.
///
/// ### EdgeTableMetadata
/// Represents a many-to-many relationship with metadata stored on the edge.
/// Generated from @SurrealEdge annotations.
library;

import '../schema/orm_annotations.dart';

/// Base sealed class for all relationship metadata types.
///
/// This sealed class enables exhaustive pattern matching when processing
/// different relationship types during code generation and query building.
///
/// Use pattern matching to handle different metadata variants:
/// ```dart
/// String generateInclude(RelationshipMetadata meta) {
///   return switch (meta) {
///     RecordLinkMetadata() => 'FETCH ${meta.fieldName}',
///     GraphRelationMetadata() => '->${meta.relationName}->',
///     EdgeTableMetadata() => 'RELATE ${meta.edgeTableName}',
///   };
/// }
/// ```
sealed class RelationshipMetadata {
  /// Creates relationship metadata.
  ///
  /// [fieldName] - The Dart field name for this relationship
  /// [targetType] - The target entity type name
  /// [isList] - Whether this relationship returns a list of records
  /// [isOptional] - Whether this relationship field is nullable
  const RelationshipMetadata({
    required this.fieldName,
    required this.targetType,
    required this.isList,
    required this.isOptional,
  });

  /// The name of the field in the Dart class.
  ///
  /// Example: 'posts', 'profile', 'likedPosts'
  final String fieldName;

  /// The target entity type name.
  ///
  /// This is the Dart class name of the related entity.
  /// Example: 'Post', 'Profile', 'User'
  final String targetType;

  /// Whether this relationship returns a list of records.
  ///
  /// true for List<T> fields, false for single T fields.
  final bool isList;

  /// Whether this relationship field is optional (nullable).
  ///
  /// Non-optional relationships are automatically included in queries.
  final bool isOptional;
}

/// Metadata for record link relationships (@SurrealRecord).
///
/// Record links are direct references to other records using record IDs.
/// They generate FETCH clauses in SurrealQL queries.
///
/// Example:
/// ```dart
/// @SurrealRecord()
/// final Profile? profile;
/// ```
///
/// Generates:
/// ```dart
/// RecordLinkMetadata(
///   fieldName: 'profile',
///   targetType: 'Profile',
///   isList: false,
///   isOptional: true,
///   tableName: null, // Inferred from type
/// )
/// ```
final class RecordLinkMetadata extends RelationshipMetadata {
  /// Creates record link metadata.
  ///
  /// [fieldName] - The Dart field name
  /// [targetType] - The target entity type name
  /// [isList] - Whether this is a list relationship
  /// [isOptional] - Whether the field is nullable
  /// [tableName] - Optional explicit table name (overrides inferred name)
  /// [foreignKey] - Optional explicit foreign key field in target table
  const RecordLinkMetadata({
    required super.fieldName,
    required super.targetType,
    required super.isList,
    required super.isOptional,
    this.tableName,
    this.foreignKey,
  });

  /// Optional explicit target table name.
  ///
  /// When null, the table name is inferred from the target type name.
  /// When specified, overrides the inferred table name.
  ///
  /// Example:
  /// ```dart
  /// @SurrealRecord(tableName: 'user_profiles')
  /// final Profile profile;
  /// ```
  final String? tableName;

  /// Optional explicit foreign key field name in the target table.
  ///
  /// When null, the foreign key is inferred using naming conventions.
  /// When specified, uses this exact field name in generated subqueries.
  ///
  /// **Important:** This is the field name in the **target** table that
  /// references the parent record.
  ///
  /// Example:
  /// ```dart
  /// @SurrealRecord(foreignKey: 'user_id')
  /// final List<Post> posts;
  /// ```
  ///
  /// Generates: `WHERE user_id = $parent.id` in subqueries
  final String? foreignKey;

  /// Gets the effective table name for this relationship.
  ///
  /// Returns the explicit table name if provided, otherwise converts
  /// the target type name to lowercase (e.g., 'Profile' -> 'profile').
  String get effectiveTableName =>
      tableName ?? _camelCaseToSnakeCase(targetType);

  /// Converts PascalCase to snake_case for table names.
  ///
  /// Example: 'UserProfile' -> 'user_profile'
  static String _camelCaseToSnakeCase(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => '_${match.group(1)!.toLowerCase()}',
        )
        .replaceFirst('_', '');
  }
}

/// Metadata for graph traversal relationships (@SurrealRelation).
///
/// Graph relations use SurrealDB's graph syntax to traverse edges.
/// They generate graph traversal expressions like ->relation-> or <-relation<-.
///
/// Example:
/// ```dart
/// @SurrealRelation(name: 'likes', direction: RelationDirection.out)
/// final List<Post> likedPosts;
/// ```
///
/// Generates:
/// ```dart
/// GraphRelationMetadata(
///   fieldName: 'likedPosts',
///   targetType: 'Post',
///   isList: true,
///   isOptional: false,
///   relationName: 'likes',
///   direction: RelationDirection.out,
///   targetTable: null, // Wildcard
/// )
/// ```
final class GraphRelationMetadata extends RelationshipMetadata {
  /// Creates graph relation metadata.
  ///
  /// [fieldName] - The Dart field name
  /// [targetType] - The target entity type name
  /// [isList] - Whether this is a list relationship
  /// [isOptional] - Whether the field is nullable
  /// [relationName] - The name of the graph edge relation
  /// [direction] - The direction of graph traversal
  /// [targetTable] - Optional target table constraint
  const GraphRelationMetadata({
    required super.fieldName,
    required super.targetType,
    required super.isList,
    required super.isOptional,
    required this.relationName,
    required this.direction,
    this.targetTable,
  });

  /// The name of the graph edge relation.
  ///
  /// This corresponds to the edge table name in RELATE statements.
  /// Example: 'likes', 'follows', 'authored'
  final String relationName;

  /// The direction of graph traversal.
  ///
  /// - [RelationDirection.out]: Follow outgoing edges (->)
  /// - [RelationDirection.inbound]: Follow incoming edges (<-)
  /// - [RelationDirection.both]: Follow edges in both directions (<->)
  final RelationDirection direction;

  /// Optional target table constraint.
  ///
  /// When null, uses wildcard (*) to match any table.
  /// When specified, limits traversal to edges pointing to this table.
  final String? targetTable;

  /// Gets the effective target table for this relationship.
  ///
  /// Returns the explicit target table if provided, otherwise uses wildcard.
  String get effectiveTargetTable => targetTable ?? '*';
}

/// Metadata for edge table definitions (@SurrealEdge).
///
/// Edge tables define many-to-many relationships with metadata stored on
/// the edge itself. They must have exactly two @SurrealRecord fields
/// (source and target) plus optional metadata fields.
///
/// Example:
/// ```dart
/// @SurrealEdge('user_posts')
/// class UserPostEdge {
///   @SurrealRecord()
///   final User user;
///
///   @SurrealRecord()
///   final Post post;
///
///   @SurrealField(type: StringType())
///   final String role;
/// }
/// ```
///
/// Generates:
/// ```dart
/// EdgeTableMetadata(
///   fieldName: 'UserPostEdge',
///   targetType: 'UserPostEdge',
///   isList: false,
///   isOptional: false,
///   edgeTableName: 'user_posts',
///   sourceField: 'user',
///   targetField: 'post',
///   metadataFields: ['role'],
/// )
/// ```
final class EdgeTableMetadata extends RelationshipMetadata {
  /// Creates edge table metadata.
  ///
  /// [fieldName] - The edge class name
  /// [targetType] - The edge class type name
  /// [isList] - Always false for edge tables
  /// [isOptional] - Always false for edge tables
  /// [edgeTableName] - The database table name for this edge
  /// [sourceField] - The field name for the source record
  /// [targetField] - The field name for the target record
  /// [metadataFields] - List of field names for edge metadata
  const EdgeTableMetadata({
    required super.fieldName,
    required super.targetType,
    required super.isList,
    required super.isOptional,
    required this.edgeTableName,
    required this.sourceField,
    required this.targetField,
    required this.metadataFields,
  });

  /// The database table name for this edge.
  ///
  /// Example: 'user_posts', 'person_knows_person'
  final String edgeTableName;

  /// The field name for the source record.
  ///
  /// This must be a @SurrealRecord annotated field.
  final String sourceField;

  /// The field name for the target record.
  ///
  /// This must be a @SurrealRecord annotated field.
  final String targetField;

  /// List of field names for edge metadata.
  ///
  /// These are additional fields beyond the source and target records
  /// that store information about the relationship itself.
  ///
  /// Example: ['role', 'createdAt', 'contributionCount']
  final List<String> metadataFields;
}
