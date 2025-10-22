/// Credential types for SurrealDB authentication.
///
/// This library defines a hierarchy of credential classes used for
/// authentication with SurrealDB at different levels (root, namespace,
/// database, scope, and record).
library;

/// Base class for all credential types.
///
/// All credential classes must extend this base and implement [toJson]
/// for serialization to the native FFI layer.
abstract class Credentials {
  /// Serializes the credentials to JSON for FFI transport.
  Map<String, dynamic> toJson();
}

/// Root-level credentials for database administration.
///
/// Root credentials provide full access to all namespaces and databases.
/// Use these only for administrative operations.
///
/// Example:
/// ```dart
/// final creds = RootCredentials('root', 'rootPassword123');
/// final jwt = await db.signin(creds);
/// ```
class RootCredentials extends Credentials {
  /// Creates root-level credentials.
  ///
  /// [username] - The root username
  /// [password] - The root password
  RootCredentials(this.username, this.password);

  /// The root username
  final String username;

  /// The root password
  final String password;

  @override
  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RootCredentials &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password;

  @override
  int get hashCode => Object.hash(username, password);

  @override
  String toString() => 'RootCredentials(username: $username)';
}

/// Namespace-level credentials for namespace administration.
///
/// Namespace credentials provide access to a specific namespace and all
/// databases within it.
///
/// Example:
/// ```dart
/// final creds = NamespaceCredentials('nsUser', 'nsPass', 'myNamespace');
/// final jwt = await db.signin(creds);
/// ```
class NamespaceCredentials extends Credentials {
  /// Creates namespace-level credentials.
  ///
  /// [username] - The namespace username
  /// [password] - The namespace password
  /// [namespace] - The namespace name
  NamespaceCredentials(this.username, this.password, this.namespace);

  /// The namespace username
  final String username;

  /// The namespace password
  final String password;

  /// The namespace name
  final String namespace;

  @override
  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'namespace': namespace,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NamespaceCredentials &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password &&
          namespace == other.namespace;

  @override
  int get hashCode => Object.hash(username, password, namespace);

  @override
  String toString() =>
      'NamespaceCredentials(username: $username, namespace: $namespace)';
}

/// Database-level credentials for database access.
///
/// Database credentials provide access to a specific database within
/// a namespace.
///
/// Example:
/// ```dart
/// final creds = DatabaseCredentials(
///   'dbUser',
///   'dbPass',
///   'myNamespace',
///   'myDatabase',
/// );
/// final jwt = await db.signin(creds);
/// ```
class DatabaseCredentials extends Credentials {
  /// Creates database-level credentials.
  ///
  /// [username] - The database username
  /// [password] - The database password
  /// [namespace] - The namespace name
  /// [database] - The database name
  DatabaseCredentials(
    this.username,
    this.password,
    this.namespace,
    this.database,
  );

  /// The database username
  final String username;

  /// The database password
  final String password;

  /// The namespace name
  final String namespace;

  /// The database name
  final String database;

  @override
  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'namespace': namespace,
        'database': database,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DatabaseCredentials &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password &&
          namespace == other.namespace &&
          database == other.database;

  @override
  int get hashCode => Object.hash(username, password, namespace, database);

  @override
  String toString() =>
      'DatabaseCredentials(username: $username, namespace: $namespace, database: $database)';
}

/// Scope-level credentials for scope-based authentication.
///
/// Scope credentials are used to authenticate users within a defined scope,
/// typically used for application users rather than administrators.
///
/// Example:
/// ```dart
/// final creds = ScopeCredentials(
///   'myNamespace',
///   'myDatabase',
///   'user_scope',
///   {
///     'email': 'user@example.com',
///     'password': 'userPass123',
///   },
/// );
/// final jwt = await db.signup(creds);
/// ```
class ScopeCredentials extends Credentials {
  /// Creates scope-level credentials.
  ///
  /// [namespace] - The namespace name
  /// [database] - The database name
  /// [scope] - The scope name
  /// [params] - Additional parameters for the scope (e.g., email, password)
  ScopeCredentials(
    this.namespace,
    this.database,
    this.scope,
    this.params,
  );

  /// The namespace name
  final String namespace;

  /// The database name
  final String database;

  /// The scope name
  final String scope;

  /// Additional parameters for the scope authentication
  final Map<String, dynamic> params;

  @override
  Map<String, dynamic> toJson() => {
        'namespace': namespace,
        'database': database,
        'scope': scope,
        ...params,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ScopeCredentials || runtimeType != other.runtimeType) {
      return false;
    }

    // Deep comparison of params map
    if (params.length != other.params.length) return false;
    for (final key in params.keys) {
      if (!other.params.containsKey(key) || params[key] != other.params[key]) {
        return false;
      }
    }

    return namespace == other.namespace &&
        database == other.database &&
        scope == other.scope;
  }

  @override
  int get hashCode => Object.hash(namespace, database, scope, Object.hashAll(params.entries));

  @override
  String toString() =>
      'ScopeCredentials(namespace: $namespace, database: $database, scope: $scope)';
}

/// Record-level credentials for record access authentication.
///
/// Record credentials are used to authenticate access to specific records
/// using a record access method.
///
/// Example:
/// ```dart
/// final creds = RecordCredentials(
///   'myNamespace',
///   'myDatabase',
///   'record_access',
///   {
///     'recordId': 'person:john',
///     'token': 'accessToken123',
///   },
/// );
/// final jwt = await db.signin(creds);
/// ```
class RecordCredentials extends Credentials {
  /// Creates record-level credentials.
  ///
  /// [namespace] - The namespace name
  /// [database] - The database name
  /// [access] - The record access method name
  /// [params] - Additional parameters for the record access
  RecordCredentials(
    this.namespace,
    this.database,
    this.access,
    this.params,
  );

  /// The namespace name
  final String namespace;

  /// The database name
  final String database;

  /// The record access method name
  final String access;

  /// Additional parameters for the record access authentication
  final Map<String, dynamic> params;

  @override
  Map<String, dynamic> toJson() => {
        'namespace': namespace,
        'database': database,
        'access': access,
        ...params,
      };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RecordCredentials || runtimeType != other.runtimeType) {
      return false;
    }

    // Deep comparison of params map
    if (params.length != other.params.length) return false;
    for (final key in params.keys) {
      if (!other.params.containsKey(key) || params[key] != other.params[key]) {
        return false;
      }
    }

    return namespace == other.namespace &&
        database == other.database &&
        access == other.access;
  }

  @override
  int get hashCode => Object.hash(namespace, database, access, Object.hashAll(params.entries));

  @override
  String toString() =>
      'RecordCredentials(namespace: $namespace, database: $database, access: $access)';
}
