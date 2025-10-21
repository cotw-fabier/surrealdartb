/// Unit tests for FFI bindings layer.
///
/// These tests verify the low-level FFI utilities and bindings work correctly.
/// Note: These tests require the Rust FFI layer to be compiled and available.

import 'dart:ffi';
import 'package:test/test.dart';
import 'package:ffi/ffi.dart';

import 'package:surrealdartb/src/ffi/ffi_utils.dart';
import 'package:surrealdartb/src/exceptions.dart';

void main() {
  group('String Conversion Utilities', () {
    test('stringToCString converts Dart string to C string', () {
      final dartString = 'Hello, World!';
      final cString = stringToCString(dartString);

      expect(cString, isNot(nullptr));
      expect(cString.toDartString(), equals(dartString));

      freeCString(cString);
    });

    test('cStringToDartString converts C string to Dart string', () {
      final original = 'Test String';
      final cString = original.toNativeUtf8(allocator: malloc);

      final dartString = cStringToDartString(cString);

      expect(dartString, equals(original));

      malloc.free(cString);
    });

    test('cStringToDartString throws on null pointer', () {
      expect(
        () => cStringToDartString(nullptr),
        throwsArgumentError,
      );
    });

    test('freeCString handles null pointer safely', () {
      expect(() => freeCString(nullptr), returnsNormally);
    });

    test('freeCString frees allocated memory', () {
      final cString = stringToCString('Memory test');
      expect(() => freeCString(cString), returnsNormally);
    });
  });

  group('Error Code Mapping', () {
    test('throwIfError does nothing on success (code 0)', () {
      expect(() => throwIfError(0), returnsNormally);
      expect(() => throwIfError(0, 'success message'), returnsNormally);
    });

    test('throwIfError throws ConnectionException for code -2', () {
      expect(
        () => throwIfError(-2, 'Connection failed'),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('throwIfError throws QueryException for code -3', () {
      expect(
        () => throwIfError(-3, 'Query failed'),
        throwsA(isA<QueryException>()),
      );
    });

    test('throwIfError throws AuthenticationException for code -4', () {
      expect(
        () => throwIfError(-4, 'Auth failed'),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('throwIfError throws DatabaseException for code -1', () {
      expect(
        () => throwIfError(-1, 'General error'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('throwIfError includes error code in exception', () {
      try {
        throwIfError(-2, 'Connection error');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<ConnectionException>());
        final ce = e as ConnectionException;
        expect(ce.errorCode, equals(-2));
        expect(ce.message, equals('Connection error'));
      }
    });
  });

  group('Pointer Validation', () {
    test('validateNonNull accepts non-null pointer', () {
      final ptr = malloc<Int32>();
      expect(() => validateNonNull(ptr, 'Should not throw'), returnsNormally);
      malloc.free(ptr);
    });

    test('validateNonNull throws on null pointer', () {
      expect(
        () => validateNonNull(nullptr, 'Null pointer error'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('validateSuccess accepts zero error code', () {
      expect(() => validateSuccess(0, 'Operation'), returnsNormally);
    });

    test('validateSuccess throws on non-zero error code', () {
      expect(
        () => validateSuccess(-1, 'Operation failed'),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
