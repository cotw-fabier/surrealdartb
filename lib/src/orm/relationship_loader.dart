/// Relationship loading logic for ORM include system.
///
/// This library provides functions for generating SurrealQL clauses for
/// loading related records with filtering, sorting, and limiting capabilities.
///
/// ## Features
///
/// - Generate FETCH clauses for record link relationships
/// - Generate graph traversal syntax for graph relations
/// - Support WHERE clauses on included relationships
/// - Support LIMIT and ORDER BY on included relationships
/// - Support nested includes with independent filtering at each level
///
/// ## Usage
///
/// ```dart
/// // Generate simple FETCH clause
/// final clause = generateFetchClause(metadata);
/// // Returns: "FETCH posts"
///
/// // Generate FETCH with filtering
/// final spec = IncludeSpec('posts',
///   where: EqualsCondition('status', 'published'),
///   limit: 10,
///   orderBy: 'createdAt',
///   descending: true,
/// );
/// final clause = generateFetchClause(metadata, spec: spec);
/// // Returns: "FETCH posts WHERE status = 'published' ORDER BY createdAt DESC LIMIT 10"
/// ```
library;

import '../database.dart';
import 'include_spec.dart';
import 'relationship_metadata.dart';
import 'where_condition.dart';
import '../schema/orm_annotations.dart';

/// Generates a FETCH clause for a record link relationship.
///
/// This function creates a SurrealQL FETCH clause that can optionally include
/// filtering, sorting, and limiting of the related records.
///
/// ## Basic FETCH
///
/// ```dart
/// final metadata = RecordLinkMetadata(
///   fieldName: 'posts',
///   targetType: 'Post',
///   isList: true,
///   isOptional: true,
/// );
/// final clause = generateFetchClause(metadata);
/// // Returns: "FETCH posts"
/// ```
///
/// ## FETCH with WHERE clause
///
/// ```dart
/// final spec = IncludeSpec('posts',
///   where: EqualsCondition('status', 'published'),
/// );
/// final clause = generateFetchClause(metadata, spec: spec, db: database);
/// // Returns: "FETCH posts WHERE status = 'published'"
/// ```
///
/// ## FETCH with LIMIT and ORDER BY
///
/// ```dart
/// final spec = IncludeSpec('posts',
///   limit: 10,
///   orderBy: 'createdAt',
///   descending: true,
/// );
/// final clause = generateFetchClause(metadata, spec: spec);
/// // Returns: "FETCH posts ORDER BY createdAt DESC LIMIT 10"
/// ```
///
/// ## FETCH with all options
///
/// ```dart
/// final spec = IncludeSpec('posts',
///   where: EqualsCondition('status', 'published') &
///          GreaterThanCondition('views', 100),
///   limit: 5,
///   orderBy: 'createdAt',
///   descending: true,
/// );
/// final clause = generateFetchClause(metadata, spec: spec, db: database);
/// // Returns: "FETCH posts WHERE (status = 'published' AND views > 100) ORDER BY createdAt DESC LIMIT 5"
/// ```
///
/// Parameters:
/// - [metadata]: The record link metadata for this relationship
/// - [spec]: Optional include specification with filtering/sorting/limiting
/// - [db]: Optional database instance for parameter binding in where clauses
///
/// Returns a SurrealQL FETCH clause string.
String generateFetchClause(
  RecordLinkMetadata metadata, {
  IncludeSpec? spec,
  Database? db,
}) {
  final buffer = StringBuffer('FETCH ${metadata.fieldName}');

  // Add WHERE clause if specified
  if (spec?.where != null && db != null) {
    buffer.write(' WHERE ${spec!.where!.toSurrealQL(db)}');
  }

  // Add ORDER BY clause if specified
  if (spec?.orderBy != null) {
    buffer.write(' ORDER BY ${spec!.orderBy}');
    if (spec.descending == true) {
      buffer.write(' DESC');
    }
  }

  // Add LIMIT clause if specified
  if (spec?.limit != null) {
    buffer.write(' LIMIT ${spec!.limit}');
  }

  return buffer.toString();
}

/// Generates a graph traversal expression for a graph relation.
///
/// This function creates a SurrealQL graph traversal expression using the
/// appropriate direction operator (->, <-, <->) and optional filtering.
///
/// ## Outgoing Relation
///
/// ```dart
/// final metadata = GraphRelationMetadata(
///   fieldName: 'likedPosts',
///   targetType: 'Post',
///   isList: true,
///   isOptional: false,
///   relationName: 'likes',
///   direction: RelationDirection.out,
///   targetTable: 'posts',
/// );
/// final expr = generateGraphTraversal(metadata);
/// // Returns: "->likes->posts"
/// ```
///
/// ## Incoming Relation
///
/// ```dart
/// final metadata = GraphRelationMetadata(
///   fieldName: 'authors',
///   targetType: 'User',
///   isList: true,
///   isOptional: false,
///   relationName: 'authored',
///   direction: RelationDirection.inbound,
///   targetTable: 'users',
/// );
/// final expr = generateGraphTraversal(metadata);
/// // Returns: "<-authored<-users"
/// ```
///
/// ## Bidirectional Relation
///
/// ```dart
/// final metadata = GraphRelationMetadata(
///   fieldName: 'connections',
///   targetType: 'User',
///   isList: true,
///   isOptional: false,
///   relationName: 'follows',
///   direction: RelationDirection.both,
///   targetTable: 'users',
/// );
/// final expr = generateGraphTraversal(metadata);
/// // Returns: "<->follows<->users"
/// ```
///
/// ## Wildcard Target
///
/// ```dart
/// final metadata = GraphRelationMetadata(
///   fieldName: 'liked',
///   targetType: 'dynamic',
///   isList: true,
///   isOptional: false,
///   relationName: 'likes',
///   direction: RelationDirection.out,
///   targetTable: null, // Wildcard
/// );
/// final expr = generateGraphTraversal(metadata);
/// // Returns: "->likes->*"
/// ```
///
/// ## With Filtering
///
/// When an IncludeSpec with a WHERE clause is provided, the graph traversal
/// is wrapped in parentheses with a WHERE clause:
///
/// ```dart
/// final spec = IncludeSpec('likedPosts',
///   where: EqualsCondition('status', 'published'),
/// );
/// final expr = generateGraphTraversal(metadata, spec: spec, db: database);
/// // Returns: "(->likes->posts WHERE status = 'published')"
/// ```
///
/// Parameters:
/// - [metadata]: The graph relation metadata for this relationship
/// - [spec]: Optional include specification with filtering
/// - [db]: Optional database instance for parameter binding in where clauses
///
/// Returns a SurrealQL graph traversal expression string.
String generateGraphTraversal(
  GraphRelationMetadata metadata, {
  IncludeSpec? spec,
  Database? db,
}) {
  final targetTable = metadata.effectiveTargetTable;
  String traversal;

  // Generate the appropriate graph syntax based on direction
  switch (metadata.direction) {
    case RelationDirection.out:
      traversal = '->${metadata.relationName}->$targetTable';
      break;
    case RelationDirection.inbound:
      traversal = '<-${metadata.relationName}<-$targetTable';
      break;
    case RelationDirection.both:
      traversal = '<->${metadata.relationName}<->$targetTable';
      break;
  }

  // If there's a WHERE clause, wrap the traversal in parentheses
  if (spec?.where != null && db != null) {
    traversal = '($traversal WHERE ${spec!.where!.toSurrealQL(db)})';
  }

  return traversal;
}

/// Generates a RELATE statement for creating an edge table record.
///
/// This function creates a SurrealQL RELATE statement for establishing a
/// relationship through an edge table with optional metadata.
///
/// ## Basic RELATE
///
/// ```dart
/// final metadata = EdgeTableMetadata(
///   fieldName: 'UserPostEdge',
///   targetType: 'UserPostEdge',
///   isList: false,
///   isOptional: false,
///   edgeTableName: 'user_posts',
///   sourceField: 'user',
///   targetField: 'post',
///   metadataFields: [],
/// );
/// final stmt = generateRelateStatement(
///   metadata,
///   sourceId: 'user:john',
///   targetId: 'post:123',
/// );
/// // Returns: "RELATE user:john->user_posts->post:123"
/// ```
///
/// ## RELATE with Metadata
///
/// ```dart
/// final metadata = EdgeTableMetadata(
///   fieldName: 'UserPostEdge',
///   targetType: 'UserPostEdge',
///   isList: false,
///   isOptional: false,
///   edgeTableName: 'user_posts',
///   sourceField: 'user',
///   targetField: 'post',
///   metadataFields: ['role', 'createdAt'],
/// );
/// final stmt = generateRelateStatement(
///   metadata,
///   sourceId: 'user:john',
///   targetId: 'post:123',
///   content: {
///     'role': 'author',
///     'createdAt': '2024-01-01T00:00:00Z',
///   },
/// );
/// // Returns: "RELATE user:john->user_posts->post:123 SET role = 'author', createdAt = '2024-01-01T00:00:00Z'"
/// ```
///
/// Parameters:
/// - [metadata]: The edge table metadata
/// - [sourceId]: The source record ID (e.g., 'user:john')
/// - [targetId]: The target record ID (e.g., 'post:123')
/// - [content]: Optional metadata to store on the edge
///
/// Returns a SurrealQL RELATE statement string.
String generateRelateStatement(
  EdgeTableMetadata metadata, {
  required String sourceId,
  required String targetId,
  Map<String, dynamic>? content,
}) {
  final buffer = StringBuffer(
    'RELATE $sourceId->${metadata.edgeTableName}->$targetId',
  );

  // Add SET clause if content is provided
  if (content != null && content.isNotEmpty) {
    buffer.write(' SET ');
    final entries = content.entries.map((entry) {
      final value = _formatValue(entry.value);
      return '${entry.key} = $value';
    }).join(', ');
    buffer.write(entries);
  }

  return buffer.toString();
}

/// Formats a value for use in SurrealQL.
///
/// Handles proper quoting and escaping for different value types.
String _formatValue(dynamic value) {
  if (value is String) {
    return "'${value.replaceAll("'", "\\'")}'";
  }
  if (value is bool || value is num) {
    return value.toString();
  }
  if (value == null) {
    return 'NONE';
  }
  return "'$value'";
}

/// Builds a complete include clause with nested includes.
///
/// This function recursively builds FETCH clauses for nested includes,
/// allowing multi-level relationship loading with independent filtering
/// at each level.
///
/// ## Single Level Include
///
/// ```dart
/// final specs = [IncludeSpec('posts')];
/// final clause = buildIncludeClauses(specs, relationships);
/// // Returns: "FETCH posts"
/// ```
///
/// ## Multi-Level Nested Includes
///
/// ```dart
/// final specs = [
///   IncludeSpec('posts',
///     where: EqualsCondition('status', 'published'),
///     limit: 5,
///     include: [
///       IncludeSpec('comments',
///         where: EqualsCondition('approved', true),
///         limit: 10,
///       ),
///       IncludeSpec('tags'),
///     ],
///   ),
/// ];
/// final clause = buildIncludeClauses(specs, relationships, db: database);
/// // Returns: "FETCH posts WHERE status = 'published' LIMIT 5 { FETCH comments WHERE approved = true LIMIT 10, FETCH tags }"
/// ```
///
/// ## Multiple Top-Level Includes
///
/// ```dart
/// final specs = [
///   IncludeSpec('posts', limit: 10),
///   IncludeSpec('profile'),
/// ];
/// final clause = buildIncludeClauses(specs, relationships);
/// // Returns: "FETCH posts LIMIT 10, FETCH profile"
/// ```
///
/// Parameters:
/// - [specs]: List of include specifications to build
/// - [relationships]: Map of field names to relationship metadata
/// - [db]: Optional database instance for parameter binding
///
/// Returns a complete SurrealQL include clause string.
String buildIncludeClauses(
  List<IncludeSpec> specs,
  Map<String, RelationshipMetadata> relationships, {
  Database? db,
}) {
  final clauses = <String>[];

  for (final spec in specs) {
    final metadata = relationships[spec.relationName];
    if (metadata == null) {
      throw ArgumentError(
        'Unknown relationship: ${spec.relationName}. '
        'Available relationships: ${relationships.keys.join(", ")}',
      );
    }

    String clause;

    // Generate appropriate clause based on relationship type
    switch (metadata) {
      case RecordLinkMetadata():
        clause = generateFetchClause(metadata, spec: spec, db: db);
        break;
      case GraphRelationMetadata():
        clause = generateGraphTraversal(metadata, spec: spec, db: db);
        break;
      case EdgeTableMetadata():
        // Edge tables don't use FETCH, they're created via RELATE
        // This shouldn't be used in include clauses
        throw ArgumentError(
          'Edge tables cannot be used in include clauses. '
          'Use createEdge() to create edge relationships.',
        );
    }

    // Add nested includes if present
    if (spec.include != null && spec.include!.isNotEmpty) {
      final nestedClauses = buildIncludeClauses(
        spec.include!,
        relationships,
        db: db,
      );
      clause = '$clause { $nestedClauses }';
    }

    clauses.add(clause);
  }

  return clauses.join(', ');
}

/// Determines which relationships should be auto-included.
///
/// Non-optional (non-nullable) relationships are automatically included
/// in queries to ensure complete object graphs are always loaded.
///
/// ## Example
///
/// ```dart
/// final relationships = {
///   'profile': RecordLinkMetadata(
///     fieldName: 'profile',
///     targetType: 'Profile',
///     isList: false,
///     isOptional: false, // Non-optional, will auto-include
///   ),
///   'posts': RecordLinkMetadata(
///     fieldName: 'posts',
///     targetType: 'Post',
///     isList: true,
///     isOptional: true, // Optional, won't auto-include
///   ),
/// };
///
/// final autoIncludes = determineAutoIncludes(relationships);
/// // Returns: {'profile'}
/// ```
///
/// Parameters:
/// - [relationships]: Map of field names to relationship metadata
///
/// Returns a set of field names for relationships that should be auto-included.
Set<String> determineAutoIncludes(
  Map<String, RelationshipMetadata> relationships,
) {
  final autoIncludes = <String>{};

  for (final entry in relationships.entries) {
    final metadata = entry.value;
    // Auto-include non-optional relationships
    if (!metadata.isOptional) {
      autoIncludes.add(entry.key);
    }
  }

  return autoIncludes;
}
