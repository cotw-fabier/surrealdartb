/// Example Post model demonstrating relationships and advanced features.
///
/// This model shows:
/// - Reverse relationship to User
/// - DateTime fields
/// - Optional fields
/// - Nested relationships (comments)
library;

import 'package:surrealdartb/surrealdartb.dart';

import 'user.dart';

/// Post model with ORM annotations.
@SurrealTable('posts')
class Post {
  @SurrealId()
  String? id;

  /// The post title (required).
  @SurrealField(type: StringType())
  final String title;

  /// The post content body (required).
  @SurrealField(type: StringType())
  final String content;

  /// Post status: 'draft', 'published', 'archived'
  @SurrealField(
    type: StringType(),
    defaultValue: 'draft',
  )
  final String status;

  /// When this post was created.
  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  /// When this post was last updated (optional).
  @SurrealField(type: DatetimeType(), optional: true)
  DateTime? updatedAt;

  /// The author of this post (reverse relationship to User).
  /// This is a required relationship - user must exist.
  /// Being non-nullable means it will be auto-included in queries.
  @SurrealRecord()
  final User author;

  /// Constructor
  Post({
    this.id,
    required this.title,
    required this.content,
    this.status = 'draft',
    DateTime? createdAt,
    this.updatedAt,
    required this.author,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Post(id: $id, title: $title, status: $status)';
}
