/// JWT token wrapper for SurrealDB authentication.
///
/// This class wraps a JWT (JSON Web Token) string and provides methods
/// for serialization and secure token access. The token is kept private
/// to prevent accidental exposure, and must be explicitly accessed via
/// the [asInsecureToken] method.
library;

/// Wrapper class for JWT authentication tokens.
///
/// JWT tokens are used for authentication in SurrealDB. This class provides
/// a type-safe way to handle tokens with serialization support for FFI transport.
///
/// Example:
/// ```dart
/// final jwt = Jwt('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
/// final tokenString = jwt.asInsecureToken();
/// ```
class Jwt {
  /// Creates a JWT wrapper from a token string.
  ///
  /// [token] - The JWT token string
  Jwt(this._token);

  /// Creates a JWT from a JSON object.
  ///
  /// The JSON object should contain a 'token' field with the JWT string.
  ///
  /// Example:
  /// ```dart
  /// final jwt = Jwt.fromJson({'token': 'eyJhbGci...'});
  /// ```
  factory Jwt.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String) {
      throw ArgumentError('JWT token must be a string');
    }
    return Jwt(token);
  }

  /// The JWT token string (kept private to prevent accidental exposure)
  final String _token;

  /// Returns the token string.
  ///
  /// **Security Warning**: This method exposes the raw token string.
  /// Only use this when you explicitly need to access the token value,
  /// such as when sending it to the native layer for authentication.
  ///
  /// The method name intentionally includes "Insecure" to make it clear
  /// that the token is being exposed.
  String asInsecureToken() => _token;

  /// Serializes the JWT to JSON for FFI transport.
  ///
  /// Returns a Map containing the token string.
  Map<String, dynamic> toJson() => {'token': _token};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Jwt && runtimeType == other.runtimeType && _token == other._token;

  @override
  int get hashCode => _token.hashCode;

  @override
  String toString() => 'Jwt(***hidden***)';
}
