/// Unit tests for authentication types and exceptions (Task Group 1.2).
///
/// These tests verify:
/// - JWT token wrapping and serialization
/// - Credentials hierarchy JSON serialization
/// - Notification class with generic type parameter
/// - Exception construction and message formatting
///
/// Total tests: 8 focused tests covering critical type behaviors
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 1.2: Authentication Types & Exceptions', () {
    // Test 1: JWT token wrapping and serialization
    test('Test 1: JWT token wrapping and serialization', () {
      final token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature';
      final jwt = Jwt(token);

      // Verify token is accessible via asInsecureToken
      expect(jwt.asInsecureToken(), equals(token));

      // Verify JSON serialization
      final json = jwt.toJson();
      expect(json, isA<Map<String, dynamic>>());
      expect(json['token'], equals(token));

      // Verify deserialization from JSON
      final jwt2 = Jwt.fromJson(json);
      expect(jwt2.asInsecureToken(), equals(token));
      expect(jwt2, equals(jwt));
    });

    // Test 2: Credential class JSON serialization - RootCredentials
    test('Test 2: RootCredentials JSON serialization', () {
      final creds = RootCredentials('root', 'rootpass123');

      final json = creds.toJson();
      expect(json['username'], equals('root'));
      expect(json['password'], equals('rootpass123'));
      expect(json.containsKey('namespace'), isFalse);
    });

    // Test 3: NamespaceCredentials and DatabaseCredentials
    test('Test 3: NamespaceCredentials and DatabaseCredentials', () {
      // Namespace credentials
      final nsCreds = NamespaceCredentials('nsUser', 'nsPass', 'myNamespace');
      final nsJson = nsCreds.toJson();
      expect(nsJson['username'], equals('nsUser'));
      expect(nsJson['password'], equals('nsPass'));
      expect(nsJson['namespace'], equals('myNamespace'));

      // Database credentials
      final dbCreds = DatabaseCredentials(
        'dbUser',
        'dbPass',
        'myNamespace',
        'myDatabase',
      );
      final dbJson = dbCreds.toJson();
      expect(dbJson['username'], equals('dbUser'));
      expect(dbJson['password'], equals('dbPass'));
      expect(dbJson['namespace'], equals('myNamespace'));
      expect(dbJson['database'], equals('myDatabase'));
    });

    // Test 4: ScopeCredentials and RecordCredentials with params
    test('Test 4: ScopeCredentials and RecordCredentials with params', () {
      // Scope credentials
      final scopeCreds = ScopeCredentials(
        'myNamespace',
        'myDatabase',
        'user_scope',
        {'email': 'user@example.com', 'password': 'pass123'},
      );
      final scopeJson = scopeCreds.toJson();
      expect(scopeJson['namespace'], equals('myNamespace'));
      expect(scopeJson['database'], equals('myDatabase'));
      expect(scopeJson['scope'], equals('user_scope'));
      expect(scopeJson['email'], equals('user@example.com'));
      expect(scopeJson['password'], equals('pass123'));

      // Record credentials
      final recordCreds = RecordCredentials(
        'myNamespace',
        'myDatabase',
        'record_access',
        {'recordId': 'person:john', 'token': 'token123'},
      );
      final recordJson = recordCreds.toJson();
      expect(recordJson['namespace'], equals('myNamespace'));
      expect(recordJson['database'], equals('myDatabase'));
      expect(recordJson['access'], equals('record_access'));
      expect(recordJson['recordId'], equals('person:john'));
      expect(recordJson['token'], equals('token123'));
    });

    // Test 5: Notification with generic type parameter
    test('Test 5: Notification with generic type parameter', () {
      final data = {'id': 'person:alice', 'name': 'Alice', 'age': 25};
      final notification = Notification<Map<String, dynamic>>(
        'query-123',
        NotificationAction.create,
        data,
      );

      expect(notification.queryId, equals('query-123'));
      expect(notification.action, equals(NotificationAction.create));
      expect(notification.data, equals(data));
      expect(notification.data['name'], equals('Alice'));
    });

    // Test 6: Notification deserialization from JSON
    test('Test 6: Notification deserialization from JSON', () {
      final json = {
        'queryId': 'query-456',
        'action': 'update',
        'data': {'id': 'person:bob', 'name': 'Bob', 'age': 30},
      };

      final notification = Notification.fromJson(
        json,
        (data) => data as Map<String, dynamic>,
      );

      expect(notification.queryId, equals('query-456'));
      expect(notification.action, equals(NotificationAction.update));
      expect(notification.data, isA<Map<String, dynamic>>());
      expect(notification.data['name'], equals('Bob'));

      // Test delete action
      final deleteJson = {
        'queryId': 'query-789',
        'action': 'delete',
        'data': {'id': 'person:charlie'},
      };

      final deleteNotification = Notification.fromJson(
        deleteJson,
        (data) => data as Map<String, dynamic>,
      );

      expect(deleteNotification.action, equals(NotificationAction.delete));
    });

    // Test 7: Exception construction and message formatting
    test('Test 7: Exception construction and message formatting', () {
      // TransactionException
      final txException = TransactionException(
        'Transaction commit failed',
        errorCode: -500,
        nativeStackTrace: 'at rust::transaction::commit',
      );
      expect(txException.message, equals('Transaction commit failed'));
      expect(txException.errorCode, equals(-500));
      expect(txException.nativeStackTrace, contains('rust::transaction'));
      expect(txException.toString(), contains('TransactionException'));
      expect(txException.toString(), contains('error code: -500'));

      // LiveQueryException
      final liveException = LiveQueryException('Subscription failed');
      expect(liveException.message, equals('Subscription failed'));
      expect(liveException.toString(), contains('LiveQueryException'));

      // ParameterException
      final paramException = ParameterException('Invalid parameter');
      expect(paramException.toString(), contains('ParameterException'));

      // ExportException
      final exportException = ExportException('Export failed');
      expect(exportException.toString(), contains('ExportException'));

      // ImportException
      final importException = ImportException('Import failed');
      expect(importException.toString(), contains('ImportException'));
    });

    // Test 8: All exception types extend DatabaseException
    test('Test 8: All exception types extend DatabaseException', () {
      expect(TransactionException('test'), isA<DatabaseException>());
      expect(LiveQueryException('test'), isA<DatabaseException>());
      expect(ParameterException('test'), isA<DatabaseException>());
      expect(ExportException('test'), isA<DatabaseException>());
      expect(ImportException('test'), isA<DatabaseException>());
      expect(AuthenticationException('test'), isA<DatabaseException>());

      // Verify they can be caught as DatabaseException
      try {
        throw TransactionException('test error');
      } on DatabaseException catch (e) {
        expect(e, isA<TransactionException>());
        expect(e.message, equals('test error'));
      }
    });
  });
}
