/// Annotations for ORM relationship definitions and ID field marking.
///
/// This library provides decorators that enable relationship mapping and
/// type-safe ORM functionality in SurrealDB. These annotations work alongside
/// the existing @SurrealTable and @SurrealField annotations to define how
/// entities relate to each other in the graph database.
///
/// ## Relationship Types
///
/// SurrealDB supports three types of relationships:
///
/// ### 1. Record Links (@SurrealRecord)
/// Direct references to other records using record IDs.
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealField(type: StringType())
///   final String id;
///
///   // Single record link
///   @SurrealRecord()
///   final Profile? profile;
///
///   // List of record links
///   @SurrealRecord()
///   final List<Post>? posts;
/// }
/// ```
///
/// ### 2. Graph Relations (@SurrealRelation)
/// Bidirectional graph traversal using SurrealDB's graph syntax (->/<-/<->).
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealField(type: StringType())
///   final String id;
///
///   // Outgoing relation: user ->likes-> posts
///   @SurrealRelation(name: 'likes', direction: RelationDirection.out)
///   final List<Post> likedPosts;
///
///   // Incoming relation: user <-authored<- posts
///   @SurrealRelation(name: 'authored', direction: RelationDirection.inbound)
///   final List<Post> authoredPosts;
///
///   // Bidirectional: user <->follows<-> users
///   @SurrealRelation(
///     name: 'follows',
///     direction: RelationDirection.both,
///     targetTable: 'users',
///   )
///   final List<User> connections;
/// }
/// ```
///
/// ### 3. Edge Tables (@SurrealEdge)
/// Many-to-many relationships with metadata stored on the edge.
///
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
///   final String role; // Edge metadata
///
///   @SurrealField(type: DatetimeType())
///   final DateTime createdAt; // Edge metadata
/// }
/// ```
///
/// ## ID Field Marking (@SurrealId)
///
/// By default, the ORM looks for a field named 'id' to identify the record ID.
/// Use @SurrealId to explicitly mark a different field as the ID:
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealId()
///   @SurrealField(type: StringType())
///   final String userId; // Non-standard ID field name
///
///   @SurrealField(type: StringType())
///   final String name;
/// }
/// ```
library;

/// Marks a field as a record link relationship.
///
/// This annotation is used for direct references to other records in SurrealDB.
/// It generates FETCH clauses in queries to load related records.
///
/// ## Single Record Link
///
/// ```dart
/// @SurrealRecord()
/// final Profile profile;
/// ```
///
/// Generates query: `SELECT * FROM users FETCH profile`
///
/// ## List of Record Links
///
/// ```dart
/// @SurrealRecord()
/// final List<Post> posts;
/// ```
///
/// Generates query: `SELECT * FROM users FETCH posts`
///
/// ## Explicit Target Table
///
/// When the target table name differs from the Dart type name:
///
/// ```dart
/// @SurrealRecord(tableName: 'user_profiles')
/// final Profile profile;
/// ```
///
/// ## Explicit Foreign Key
///
/// When the foreign key field name in the target table differs from convention:
///
/// ```dart
/// @SurrealRecord(foreignKey: 'user_id')
/// final List<Post> posts;
/// ```
///
/// This is used when generating filtered includes with subqueries. The foreign key
/// must match the field name in the target table that references the parent record.
///
/// ## Non-Optional Relations
///
/// Non-nullable relationships are automatically included in queries:
///
/// ```dart
/// @SurrealRecord()
/// final Organization organization; // Auto-included (non-nullable)
///
/// @SurrealRecord()
/// final Profile? profile; // Optional, included only when requested
/// ```
class SurrealRecord {
  /// Optional explicit target table name.
  ///
  /// When null, the table name is inferred from the field's type name.
  /// Use this when the SurrealDB table name differs from the Dart class name.
  ///
  /// Example:
  /// ```dart
  /// @SurrealRecord(tableName: 'user_profiles')
  /// final Profile profile;
  /// ```
  final String? tableName;

  /// Optional explicit foreign key field name in the target table.
  ///
  /// When null, the foreign key is inferred using naming conventions (typically 'author').
  /// Use this when the target table uses a different field name to reference the parent.
  ///
  /// **Important:** This is the field name in the **target** table that points back
  /// to the parent record, not a field in the parent table.
  ///
  /// Example:
  /// ```dart
  /// @SurrealTable('users')
  /// class User {
  ///   // Posts table has 'user_id' field that references users
  ///   @SurrealRecord(foreignKey: 'user_id')
  ///   final List<Post> posts;
  ///
  ///   // Comments table has 'author' field that references users
  ///   @SurrealRecord(foreignKey: 'author')
  ///   final List<Comment> comments;
  /// }
  /// ```
  ///
  /// This generates subqueries like:
  /// ```sql
  /// SELECT *, (SELECT * FROM posts WHERE user_id = $parent.id) AS posts
  /// FROM users
  /// ```
  final String? foreignKey;

  /// Creates a SurrealRecord annotation.
  ///
  /// Both [tableName] and [foreignKey] parameters are optional.
  /// - [tableName]: Overrides inferred table name (e.g., `Profile` -> `profile`)
  /// - [foreignKey]: Specifies the foreign key field in the target table
  const SurrealRecord({this.tableName, this.foreignKey});
}

/// Direction for graph relation traversal.
///
/// SurrealDB supports three types of graph traversal:
/// - **out**: Outgoing edges from this record (->)
/// - **inbound**: Incoming edges to this record (<-)
/// - **both**: Bidirectional edges (<->)
///
/// ## Usage
///
/// ```dart
/// @SurrealRelation(name: 'likes', direction: RelationDirection.out)
/// final List<Post> likedPosts;
/// ```
enum RelationDirection {
  /// Outgoing relation: follow edges going out from this record.
  ///
  /// Graph syntax: `->relationName->targetTable`
  ///
  /// Example: user ->likes-> post
  out,

  /// Incoming relation: follow edges coming into this record.
  ///
  /// Graph syntax: `<-relationName<-targetTable`
  ///
  /// Example: post <-likes<- user
  inbound,

  /// Bidirectional relation: follow edges in both directions.
  ///
  /// Graph syntax: `<->relationName<->targetTable`
  ///
  /// Example: user <->follows<-> user
  both,
}

/// Marks a field as a graph traversal relationship.
///
/// This annotation is used for relationships that use SurrealDB's graph
/// traversal syntax with directional edges. It generates graph query
/// expressions using ->, <-, or <-> operators.
///
/// ## Outgoing Relation
///
/// ```dart
/// @SurrealRelation(name: 'likes', direction: RelationDirection.out)
/// final List<Post> likedPosts;
/// ```
///
/// Generates query: `SELECT * FROM users, ->likes->posts`
///
/// ## Incoming Relation
///
/// ```dart
/// @SurrealRelation(name: 'authored', direction: RelationDirection.inbound)
/// final List<Post> authoredPosts;
/// ```
///
/// Generates query: `SELECT * FROM users, <-authored<-posts`
///
/// ## Bidirectional Relation
///
/// ```dart
/// @SurrealRelation(
///   name: 'follows',
///   direction: RelationDirection.both,
///   targetTable: 'users',
/// )
/// final List<User> connections;
/// ```
///
/// Generates query: `SELECT * FROM users, <->follows<->users`
///
/// ## Without Target Table (Wildcard)
///
/// ```dart
/// @SurrealRelation(name: 'likes', direction: RelationDirection.out)
/// final List<dynamic> liked; // Any table
/// ```
///
/// Generates query: `SELECT * FROM users, ->likes->*`
class SurrealRelation {
  /// The name of the relation edge.
  ///
  /// This corresponds to the edge table name in SurrealDB graph syntax.
  /// For example, if you have a RELATE statement like:
  /// `RELATE user:john->likes->post:1`
  ///
  /// The relation name would be 'likes'.
  final String name;

  /// The direction of graph traversal.
  ///
  /// Determines whether to follow edges going out, coming in, or both:
  /// - [RelationDirection.out]: ->relationName->
  /// - [RelationDirection.inbound]: <-relationName<-
  /// - [RelationDirection.both]: <->relationName<->
  final RelationDirection direction;

  /// Optional target table constraint.
  ///
  /// When specified, limits graph traversal to edges pointing to records
  /// in the specified table. When null, uses wildcard (*) to match any table.
  ///
  /// Example:
  /// ```dart
  /// // Specific target
  /// @SurrealRelation(
  ///   name: 'likes',
  ///   direction: RelationDirection.out,
  ///   targetTable: 'posts',
  /// )
  /// final List<Post> likedPosts;
  ///
  /// // Any target (wildcard)
  /// @SurrealRelation(
  ///   name: 'likes',
  ///   direction: RelationDirection.out,
  /// )
  /// final List<dynamic> liked;
  /// ```
  final String? targetTable;

  /// Creates a SurrealRelation annotation.
  ///
  /// The [name] and [direction] parameters are required.
  /// The [targetTable] parameter is optional and defaults to wildcard (*).
  const SurrealRelation({
    required this.name,
    required this.direction,
    this.targetTable,
  });
}

/// Marks a class as an edge table definition.
///
/// Edge tables are special tables in SurrealDB that define many-to-many
/// relationships with additional metadata stored on the relationship itself.
///
/// An edge table must have:
/// - Exactly two @SurrealRecord fields (source and target)
/// - Zero or more additional fields for edge metadata
///
/// ## Example
///
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
///   final String role; // Metadata: 'author', 'editor', 'reviewer'
///
///   @SurrealField(type: DatetimeType())
///   final DateTime createdAt; // Metadata: when relationship created
///
///   @SurrealField(type: NumberType())
///   final int contributionCount; // Metadata: number of contributions
/// }
/// ```
///
/// ## Creating Edge Records
///
/// ```dart
/// // Using RELATE syntax
/// await db.query('''
///   RELATE user:john->user_posts->post:123
///   SET role = 'author', createdAt = time::now()
/// ''');
///
/// // Using the ORM (future feature)
/// final edge = UserPostEdge(
///   user: john,
///   post: myPost,
///   role: 'author',
///   createdAt: DateTime.now(),
/// );
/// await db.createEdge(edge);
/// ```
///
/// ## Querying Through Edge Tables
///
/// ```dart
/// // Get user's posts with role information
/// SELECT user.*, ->user_posts->post.*
/// FROM user:john
/// FETCH post, user_posts
/// ```
class SurrealEdge {
  /// The name of the edge table in SurrealDB.
  ///
  /// This should follow SurrealDB naming conventions (lowercase, underscores).
  /// Typically named as `{source}_{target}` or `{source}_{relation}_{target}`.
  ///
  /// Examples: 'user_posts', 'user_likes_posts', 'person_knows_person'
  final String edgeTableName;

  /// Creates a SurrealEdge annotation.
  ///
  /// The [edgeTableName] parameter is required and specifies the table name
  /// in the SurrealDB database for this edge table.
  const SurrealEdge(this.edgeTableName);
}

/// Marks a field as the ID field for a record.
///
/// By default, the ORM looks for a field named 'id' to identify the record's
/// unique identifier. Use this annotation when your ID field has a different
/// name or when you need to explicitly mark the ID field.
///
/// ## Default ID Detection
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   final String id; // Automatically detected as ID field
///   final String name;
/// }
/// ```
///
/// ## Explicit ID Marking
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealId()
///   final String userId; // Explicitly marked as ID field
///   final String name;
/// }
/// ```
///
/// ## When to Use
///
/// - When your ID field is not named 'id'
/// - When you have multiple fields containing 'id' in the name
/// - When you want to make the ID field explicit for clarity
/// - When using a custom ID generation strategy
///
/// ## Note
///
/// Only one field per class should have the @SurrealId annotation.
/// The generator will throw an error if multiple fields are marked as ID.
class SurrealId {
  /// Creates a SurrealId annotation.
  ///
  /// This is a marker annotation with no parameters.
  const SurrealId();
}
