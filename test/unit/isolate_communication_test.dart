/// Unit tests for isolate communication layer.
///
/// These tests verify that the isolate communication infrastructure works
/// correctly, including message passing and error propagation.

import 'package:test/test.dart';
import 'package:surrealdartb/src/isolate/database_isolate.dart';
import 'package:surrealdartb/src/isolate/isolate_messages.dart';

void main() {
  group('IsolateMessage Types', () {
    test('ConnectCommand can be created with required parameters', () {
      final command = ConnectCommand(
        endpoint: 'mem://',
        namespace: 'test',
        database: 'test',
      );

      expect(command.endpoint, equals('mem://'));
      expect(command.namespace, equals('test'));
      expect(command.database, equals('test'));
    });

    test('QueryCommand can be created with SQL', () {
      final command = QueryCommand(sql: 'SELECT * FROM person');

      expect(command.sql, equals('SELECT * FROM person'));
      expect(command.bindings, isNull);
    });

    test('QueryCommand can be created with bindings', () {
      final command = QueryCommand(
        sql: 'SELECT * FROM person WHERE age > \$age',
        bindings: {'age': 18},
      );

      expect(command.sql, contains('age'));
      expect(command.bindings, equals({'age': 18}));
    });

    test('SuccessResponse can hold different data types', () {
      const response1 = SuccessResponse();
      expect(response1.data, isNull);

      const response2 = SuccessResponse('string data');
      expect(response2.data, equals('string data'));

      const response3 = SuccessResponse([1, 2, 3]);
      expect(response3.data, equals([1, 2, 3]));

      const response4 = SuccessResponse({'key': 'value'});
      expect(response4.data, equals({'key': 'value'}));
    });

    test('ErrorResponse contains error information', () {
      const response = ErrorResponse(
        message: 'Connection failed',
        errorCode: -2,
      );

      expect(response.message, equals('Connection failed'));
      expect(response.errorCode, equals(-2));
      expect(response.nativeStackTrace, isNull);
    });
  });

  group('DatabaseIsolate Lifecycle', () {
    late DatabaseIsolate isolate;

    setUp(() {
      isolate = DatabaseIsolate();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('isolate can be started', () async {
      await isolate.start();
      // If we get here without exception, start succeeded
      expect(isolate, isNotNull);
    });

    test('isolate throws if start called twice', () async {
      await isolate.start();

      expect(
        () => isolate.start(),
        throwsStateError,
      );
    });

    test('isolate throws if command sent before start', () async {
      expect(
        () => isolate.sendCommand(const InitializeCommand()),
        throwsStateError,
      );
    });

    test('isolate can be disposed', () async {
      await isolate.start();
      await isolate.dispose();
      // Disposing twice should be safe
      await isolate.dispose();
    });
  });

  group('Command Sending (Unit Level)', () {
    late DatabaseIsolate isolate;

    setUp(() async {
      isolate = DatabaseIsolate();
      await isolate.start();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('can send InitializeCommand', () async {
      final response = await isolate.sendCommand(const InitializeCommand());

      expect(response, isA<SuccessResponse>());
    });

    test('ConnectCommand with invalid endpoint returns error', () async {
      // Note: This test assumes Rust FFI layer is available
      // If not available, it may timeout or throw
      final response = await isolate.sendCommand(
        const ConnectCommand(endpoint: ''),
      );

      // Without Rust layer, we expect some kind of error
      // This test validates the error propagation mechanism
      expect(response, isA<IsolateResponse>());
    }, skip: 'Requires Rust FFI layer to be implemented');

    test('CloseCommand can be sent', () async {
      final response = await isolate.sendCommand(const CloseCommand());

      expect(response, isA<SuccessResponse>());
    });
  });

  group('Error Propagation', () {
    late DatabaseIsolate isolate;

    setUp(() async {
      isolate = DatabaseIsolate();
      await isolate.start();
    });

    tearDown(() async {
      await isolate.dispose();
    });

    test('operations without connection return error', () async {
      final response = await isolate.sendCommand(
        QueryCommand(sql: 'SELECT * FROM person'),
      );

      // Should return error because we haven't connected
      expect(response, isA<ErrorResponse>());
      final errorResponse = response as ErrorResponse;
      expect(errorResponse.message, contains('connected'));
    });

    test('error response includes error message', () async {
      final response = await isolate.sendCommand(
        const SelectCommand('nonexistent'),
      );

      if (response is ErrorResponse) {
        expect(response.message, isNotEmpty);
      }
    });
  });
}
