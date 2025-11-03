# Authentication

**File:** `lib/src/types/credentials.dart`

**IMPORTANT:** Authentication has limited functionality in embedded mode. Full authentication features require remote SurrealDB connection.

## Credential Types

### RootCredentials

Root-level authentication (highest privilege).

```dart
RootCredentials({
  required String username,
  required String password,
})
```

**Example:**
```dart
final creds = RootCredentials(
  username: 'root',
  password: 'root_password',
);
```

### NamespaceCredentials

Namespace-level authentication.

```dart
NamespaceCredentials({
  required String username,
  required String password,
  required String namespace,
})
```

**Example:**
```dart
final creds = NamespaceCredentials(
  username: 'ns_admin',
  password: 'ns_password',
  namespace: 'production',
);
```

### DatabaseCredentials

Database-level authentication.

```dart
DatabaseCredentials({
  required String username,
  required String password,
  required String namespace,
  required String database,
})
```

**Example:**
```dart
final creds = DatabaseCredentials(
  username: 'db_user',
  password: 'db_password',
  namespace: 'production',
  database: 'main',
);
```

### ScopeCredentials

Scope-based authentication (custom auth logic).

```dart
ScopeCredentials({
  required String namespace,
  required String database,
  required String scope,
  Map<String, dynamic>? params,
})
```

**Example:**
```dart
final creds = ScopeCredentials(
  namespace: 'production',
  database: 'main',
  scope: 'user_scope',
  params: {
    'email': 'user@example.com',
    'password': 'user_password',
  },
);
```

**Scope definition (SurrealQL):**
```sql
DEFINE SCOPE user_scope
  SIGNUP (CREATE user SET email = $email, pass = crypto::argon2::generate($password))
  SIGNIN (SELECT * FROM user WHERE email = $email AND crypto::argon2::compare(pass, $password));
```

### RecordCredentials

Record-level authentication (SurrealDB 2.0+).

```dart
RecordCredentials({
  required String namespace,
  required String database,
  required String access,
  Map<String, dynamic>? params,
})
```

**Example:**
```dart
final creds = RecordCredentials(
  namespace: 'production',
  database: 'main',
  access: 'user_access',
  params: {
    'email': 'user@example.com',
    'password': 'user_password',
  },
);
```

## Authentication Methods

### signin()

Sign in with credentials.

```dart
Future<Jwt> signin(Credentials credentials)
```

**Example:**
```dart
final jwt = await db.signin(DatabaseCredentials(
  username: 'admin',
  password: 'admin_pass',
  namespace: 'prod',
  database: 'main',
));

print('Token: ${jwt.token}');
```

### signup()

Sign up new user (scope/record auth only).

```dart
Future<Jwt> signup(Credentials credentials)
```

**Example:**
```dart
final jwt = await db.signup(ScopeCredentials(
  namespace: 'prod',
  database: 'main',
  scope: 'user_scope',
  params: {
    'email': 'new@example.com',
    'password': 'secure_password',
  },
));
```

### authenticate()

Use existing JWT token.

```dart
Future<void> authenticate(Jwt token)
```

**Example:**
```dart
// Store token
final jwt = await db.signin(credentials);
await storage.save('jwt', jwt.token);

// Later: restore session
final storedToken = await storage.get('jwt');
await db.authenticate(Jwt(storedToken));
```

### invalidate()

Clear current session.

```dart
Future<void> invalidate()
```

**Example:**
```dart
await db.invalidate();
// Session cleared, auth required for protected resources
```

## Jwt Type

**File:** `lib/src/types/types.dart`

```dart
class Jwt {
  final String token;

  Jwt(this.token);
}
```

## Usage Patterns

### Basic Authentication Flow

```dart
// 1. Connect
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: './db',
  namespace: 'app',
  database: 'main',
);

// 2. Sign in
try {
  final jwt = await db.signin(DatabaseCredentials(
    username: 'user',
    password: 'pass',
    namespace: 'app',
    database: 'main',
  ));

  // 3. Store token for session persistence
  await saveToken(jwt.token);

} on AuthenticationException catch (e) {
  print('Login failed: ${e.message}');
}
```

### Scope-Based User Registration

```dart
// 1. Define scope
await db.queryQL('''
  DEFINE SCOPE user_scope
    SIGNUP (
      CREATE user SET
        email = \$email,
        pass = crypto::argon2::generate(\$password),
        created_at = time::now()
    )
    SIGNIN (
      SELECT * FROM user
      WHERE email = \$email
      AND crypto::argon2::compare(pass, \$password)
    );
''');

// 2. Sign up
final jwt = await db.signup(ScopeCredentials(
  namespace: 'app',
  database: 'main',
  scope: 'user_scope',
  params: {
    'email': 'user@example.com',
    'password': 'secure_pass',
  },
));

// 3. User created and authenticated
```

### Session Persistence

```dart
class AuthService {
  Database? _db;
  String? _token;

  Future<void> login(String email, String password) async {
    final jwt = await _db!.signin(ScopeCredentials(
      namespace: 'app',
      database: 'main',
      scope: 'user',
      params: {'email': email, 'password': password},
    ));

    _token = jwt.token;
    await _storage.write('auth_token', jwt.token);
  }

  Future<void> restoreSession() async {
    _token = await _storage.read('auth_token');
    if (_token != null) {
      await _db!.authenticate(Jwt(_token!));
    }
  }

  Future<void> logout() async {
    await _db!.invalidate();
    _token = null;
    await _storage.delete('auth_token');
  }
}
```

### Token Refresh Pattern

```dart
// SurrealDB tokens have expiration
// Implement refresh logic

Future<void> ensureAuthenticated() async {
  if (await isTokenExpired(_token)) {
    // Re-authenticate
    final jwt = await db.signin(storedCredentials);
    _token = jwt.token;
    await saveToken(jwt.token);
  } else {
    // Use existing token
    await db.authenticate(Jwt(_token!));
  }
}
```

## Embedded Mode Limitations

**IMPORTANT:** Embedded SurrealDB has reduced auth capabilities:

1. **No User Management:** Cannot create database users in embedded mode
2. **Scope Auth Preferred:** Use scope-based or record-based authentication
3. **Local Only:** Auth state not synced with remote instances
4. **No Sessions:** Each connection requires re-authentication
5. **Limited Permissions:** Most operations unrestricted in embedded mode

**Recommended for Embedded:**
- Scope-based auth with custom logic
- Record-based auth (SurrealDB 2.0+)
- Application-level authentication
- OS-level file permissions for security

## Security Best Practices

### Password Hashing

Always use Argon2 for passwords:

```dart
await db.queryQL('''
  DEFINE SCOPE user
    SIGNUP (
      CREATE user SET
        email = \$email,
        pass = crypto::argon2::generate(\$password)
    )
    SIGNIN (
      SELECT * FROM user
      WHERE email = \$email
      AND crypto::argon2::compare(pass, \$password)
    );
''');
```

### Token Storage

```dart
// DON'T: Store in plaintext
localStorage.setItem('token', jwt.token);

// DO: Use secure storage
await FlutterSecureStorage().write(key: 'jwt', value: jwt.token);
```

### Credentials in Code

```dart
// DON'T: Hardcode credentials
final creds = RootCredentials(username: 'root', password: 'password');

// DO: Use environment variables or secure config
final creds = RootCredentials(
  username: Platform.environment['DB_USER']!,
  password: Platform.environment['DB_PASS']!,
);
```

## Exception Handling

**Exception:** `AuthenticationException`

```dart
try {
  await db.signin(credentials);
} on AuthenticationException catch (e) {
  if (e.message.contains('credentials')) {
    print('Invalid username or password');
  } else if (e.message.contains('permission')) {
    print('Insufficient permissions');
  } else {
    print('Authentication failed: ${e.message}');
  }
}
```

## Common Patterns

### Multi-Tenant Auth

```dart
Future<Database> connectForTenant(String tenantId, Credentials creds) async {
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: './db/$tenantId',
    namespace: tenantId,
    database: 'main',
  );

  await db.signin(creds);
  return db;
}
```

### Role-Based Access

Define in scope:

```sql
DEFINE SCOPE user
  SIGNUP (
    CREATE user SET
      email = $email,
      pass = crypto::argon2::generate($password),
      role = 'user'  -- Default role
  )
  SIGNIN (
    SELECT * FROM user
    WHERE email = $email
    AND crypto::argon2::compare(pass, $password)
  );

-- Table-level permissions
DEFINE TABLE documents SCHEMAFULL
  PERMISSIONS
    FOR select WHERE $auth.role = 'admin' OR owner = $auth.id
    FOR create WHERE $auth != NONE
    FOR update, delete WHERE owner = $auth.id OR $auth.role = 'admin';
```

## Gotchas

1. **Embedded Limitations:** Most auth features designed for remote connections
2. **Scope Required:** signup() only works with ScopeCredentials or RecordCredentials
3. **Token Expiration:** Tokens expire - implement refresh logic
4. **Case Sensitivity:** Usernames are case-sensitive
5. **Namespace/DB Scope:** Credentials tied to specific namespace/database
6. **No Session State:** invalidate() clears local state only
7. **Permissions:** PERMISSIONS clauses only enforced in some contexts
