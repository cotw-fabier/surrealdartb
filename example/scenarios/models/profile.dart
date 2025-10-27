/// Example Profile model for one-to-one relationship demonstration.
///
/// This model shows:
/// - One-to-one relationship pattern
/// - Optional fields
/// - Nested object fields
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Profile model - extended user information.
@SurrealTable('profiles')
class Profile {
  @SurrealId()
  String? id;

  /// User's bio/description (optional).
  @SurrealField(type: StringType(), optional: true)
  String? bio;

  /// User's website URL (optional).
  @SurrealField(type: StringType(), optional: true)
  String? website;

  /// User's location/city (optional).
  @SurrealField(type: StringType(), optional: true)
  String? location;

  /// Avatar URL (optional).
  @SurrealField(type: StringType(), optional: true)
  String? avatarUrl;

  /// When the profile was created.
  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  /// Constructor
  Profile({
    this.id,
    this.bio,
    this.website,
    this.location,
    this.avatarUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  String toString() => 'Profile(id: $id, location: $location)';
}
