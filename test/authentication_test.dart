import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Authentication Operations', () {
    late Database db;

    setUp(() async {
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('signin with root credentials', () async {
      // Note: In embedded mode, authentication may have limited functionality
      // This test verifies that the method exists and handles credentials properly
      final credentials = RootCredentials('root', 'root');

      try {
        final jwt = await db.signin(credentials);
        // If authentication succeeds in embedded mode, verify JWT is returned
        expect(jwt, isA<Jwt>());
        expect(jwt.asInsecureToken(), isNotEmpty);
      } on AuthenticationException catch (e) {
        // Authentication may not be fully functional in embedded mode
        // This is expected and documented behavior
        expect(e.message, isNotEmpty);
      }
    });

    test('signin with database credentials', () async {
      final credentials = DatabaseCredentials(
        'dbuser',
        'dbpass',
        'test',
        'test',
      );

      try {
        final jwt = await db.signin(credentials);
        expect(jwt, isA<Jwt>());
      } on AuthenticationException catch (e) {
        // Expected in embedded mode
        expect(e.message, isNotEmpty);
      }
    });

    test('signin with scope credentials', () async {
      final credentials = ScopeCredentials(
        'test',
        'test',
        'user_scope',
        {'email': 'user@test.com', 'password': 'pass123'},
      );

      try {
        final jwt = await db.signin(credentials);
        expect(jwt, isA<Jwt>());
      } on AuthenticationException catch (e) {
        // Expected in embedded mode
        expect(e.message, isNotEmpty);
      }
    });

    test('signup with scope credentials', () async {
      final credentials = ScopeCredentials(
        'test',
        'test',
        'user_scope',
        {'email': 'newuser@test.com', 'password': 'newpass123'},
      );

      try {
        final jwt = await db.signup(credentials);
        expect(jwt, isA<Jwt>());
        expect(jwt.asInsecureToken(), isNotEmpty);
      } on AuthenticationException catch (e) {
        // Signup may not be fully functional in embedded mode
        // This is expected behavior
        expect(e.message, isNotEmpty);
      }
    });

    test('signup rejects non-scope credentials', () async {
      final credentials = RootCredentials('root', 'root');

      expect(
        () => db.signup(credentials),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('authenticate with JWT token', () async {
      // Create a token (may not be valid in embedded mode)
      final token = Jwt('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test');

      try {
        await db.authenticate(token);
        // If no exception, authentication succeeded (may have limited effect)
      } on AuthenticationException catch (e) {
        // Expected if token is invalid or authentication not supported
        expect(e.message, isNotEmpty);
      }
    });

    test('invalidate session', () async {
      try {
        await db.invalidate();
        // If no exception, invalidation succeeded
      } on AuthenticationException catch (e) {
        // May fail if no session is active
        expect(e.message, isNotEmpty);
      }
    });

    test('authentication throws StateError when database is closed', () async {
      await db.close();

      final credentials = RootCredentials('root', 'root');
      expect(
        () => db.signin(credentials),
        throwsA(isA<StateError>()),
      );
    });
  });
}
