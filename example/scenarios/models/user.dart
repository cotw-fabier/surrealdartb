/// Example User model demonstrating ORM annotations.
///
/// This model shows:
/// - Basic field annotations with types
/// - ID field marking with @SurrealId
/// - Relationship annotations (@SurrealRecord)
/// - Field constraints and validation
library;

import 'package:surrealdartb/surrealdartb.dart';

import 'post.dart';
import 'profile.dart';

part 'user.surreal.dart';

/// User model with complete ORM annotations.
///
/// After defining this model, run:
/// ```bash
/// dart run build_runner build
/// ```
///
/// This generates `user.surreal.dart` with:
/// - UserORM extension (toSurrealMap, fromSurrealMap, validate)
/// - UserQueryBuilder for type-safe queries
/// - UserWhereBuilder for complex where clauses
@SurrealTable('users')
class User {
  /// The unique identifier for this user.
  /// Using @SurrealId marks this as the ID field.
  /// Without this annotation, a field named 'id' would be used automatically.
  @SurrealId()
  String? id;

  /// User's full name (required field).
  @SurrealField(type: StringType())
  final String name;

  /// User's age (must be 18 or older due to ASSERT clause).
  @SurrealField(
    type: NumberType(format: NumberFormat.integer),
    assertClause: r'$value >= 18',
  )
  final int age;

  /// User's email address (indexed for fast lookups, unique constraint).
  @SurrealField(
    type: StringType(),
    indexed: true,
    assertClause: r'string::is::email($value)',
  )
  final String email;

  /// User's account status (active, suspended, deleted).
  @SurrealField(
    type: StringType(),
    defaultValue: 'active',
  )
  final String status;

  /// Optional profile (one-to-one relationship).
  /// This is a record link to the profiles table.
  /// Being nullable makes it optional - not auto-included in queries.
  @SurrealRecord()
  Profile? profile;

  /// User's posts (one-to-many relationship).
  /// This is a list of record links to the posts table.
  /// Being nullable makes it optional - must be explicitly included.
  @SurrealRecord()
  List<Post>? posts;

  /// Constructor
  User({
    this.id,
    required this.name,
    required this.age,
    required this.email,
    this.status = 'active',
    this.profile,
    this.posts,
  });

  @override
  String toString() => 'User(id: $id, name: $name, age: $age, email: $email)';
}
