/// Authentication demonstration scenario for SurrealDB Dart FFI bindings.
///
/// This scenario demonstrates authentication features including signin,
/// signup, authenticate with tokens, and session invalidation.
///
/// Note: Authentication in embedded mode has some limitations compared
/// to remote server mode. This example shows what works in embedded mode.
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the authentication demonstration scenario.
///
/// Demonstrates:
/// - Signing in with different credential types
/// - Signing up new users
/// - Authenticating with JWT tokens
/// - Session invalidation
/// - Token storage and retrieval patterns
Future<void> runAuthenticationScenario() async {
  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║                                                            ║');
  print('║           Authentication Features Demonstration            ║');
  print('║                                                            ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  print('=== Authentication in Embedded Mode ===\n');
  print('⚠️  Note: Authentication in embedded mode has limitations.');
  print('   Scope-based access control may not fully apply.');
  print('   Token refresh is not supported.\n');

  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'auth_demo',
    database: 'users',
  );

  try {
    // Demonstrate different authentication levels
    await _demonstrateSignin(db);
    await _demonstrateSignup(db);
    await _demonstrateTokenAuthentication(db);
    await _demonstrateSessionInvalidation(db);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║                                                            ║');
    print('║       ✓ Authentication Scenario Completed Successfully    ║');
    print('║                                                            ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
  } finally {
    await db.close();
    print('✓ Database closed\n');
  }
}

/// Demonstrates signin with different credential types.
Future<void> _demonstrateSignin(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('1. Sign In with Credentials');
  print('─────────────────────────────────────────────────────────────\n');

  try {
    // Root-level signin
    print('Attempting root-level signin...');
    final rootJwt = await db.signin(RootCredentials('root', 'root'));
    print('✓ Root signin successful');
    print('  Token type: JWT');
    print('  Token length: ${rootJwt.asInsecureToken().length} characters\n');

    // Database-level signin
    print('Attempting database-level signin...');
    final dbJwt = await db.signin(DatabaseCredentials(
      'dbuser',
      'dbpass',
      'auth_demo',
      'users',
    ));
    print('✓ Database signin successful');
    print('  Token type: JWT\n');

    // Scope-level signin (may have limited functionality in embedded mode)
    print('Attempting scope-level signin...');
    print('⚠️  Note: Scope auth may have limited functionality in embedded mode');
    try {
      final scopeJwt = await db.signin(ScopeCredentials(
        'auth_demo',
        'users',
        'user_scope',
        {
          'email': 'demo@example.com',
          'password': 'demopass',
        },
      ));
      print('✓ Scope signin successful (functionality may be limited)');
      print('  Token type: JWT\n');
    } catch (e) {
      print('⚠️  Scope signin not fully supported in embedded mode: $e\n');
    }
  } catch (e) {
    print('✗ Authentication error: $e\n');
  }
}

/// Demonstrates signup functionality.
Future<void> _demonstrateSignup(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('2. Sign Up New Users');
  print('─────────────────────────────────────────────────────────────\n');

  print('⚠️  Note: Signup functionality may be limited in embedded mode\n');

  try {
    // Attempt to signup a new user with scope credentials
    print('Attempting user signup with scope credentials...');
    final jwt = await db.signup(ScopeCredentials(
      'auth_demo',
      'users',
      'user_scope',
      {
        'email': 'newuser@example.com',
        'password': 'securepassword',
        'name': 'New User',
        'role': 'standard_user',
      },
    ));

    print('✓ User signup successful');
    print('  User authenticated with new credentials');
    print('  Token received: ${jwt.asInsecureToken().substring(0, 20)}...\n');
  } catch (e) {
    print('⚠️  Signup not fully supported in embedded mode: $e');
    print('   In embedded mode, user management may be limited.\n');
  }
}

/// Demonstrates authentication with JWT tokens.
Future<void> _demonstrateTokenAuthentication(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('3. Authenticate with JWT Token');
  print('─────────────────────────────────────────────────────────────\n');

  try {
    // First, get a token via signin
    print('Step 1: Sign in to get a JWT token...');
    final jwt = await db.signin(RootCredentials('root', 'root'));
    print('✓ Signin successful, token received\n');

    // Extract token string (e.g., for storage)
    print('Step 2: Extract token string for storage...');
    final tokenString = jwt.asInsecureToken();
    print('✓ Token extracted');
    print('  Token (first 40 chars): ${tokenString.substring(0, 40)}...');
    print('  Use case: Save this token for later sessions\n');

    // Simulate loading token from storage
    print('Step 3: Simulate loading token from storage...');
    final storedToken = Jwt(tokenString);
    print('✓ Token loaded from storage (simulation)\n');

    // Authenticate with the stored token
    print('Step 4: Authenticate with stored token...');
    await db.authenticate(storedToken);
    print('✓ Authentication successful');
    print('  Session is now authenticated');
    print('  Subsequent operations will use this authentication\n');
  } catch (e) {
    print('✗ Token authentication error: $e\n');
  }
}

/// Demonstrates session invalidation.
Future<void> _demonstrateSessionInvalidation(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('4. Session Invalidation (Sign Out)');
  print('─────────────────────────────────────────────────────────────\n');

  try {
    // First authenticate
    print('Step 1: Authenticate a session...');
    final jwt = await db.signin(RootCredentials('root', 'root'));
    await db.authenticate(jwt);
    print('✓ Session authenticated\n');

    // Invalidate the session
    print('Step 2: Invalidate the session (sign out)...');
    await db.invalidate();
    print('✓ Session invalidated');
    print('  Authentication cleared');
    print('  Use case: User logout, security cleanup\n');

    print('⚠️  Note: After invalidation, authenticated operations');
    print('   will fail until signin/authenticate is called again.\n');
  } catch (e) {
    print('✗ Invalidation error: $e\n');
  }
}
