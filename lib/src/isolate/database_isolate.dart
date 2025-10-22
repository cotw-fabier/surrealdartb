/// Background isolate for database operations.
///
/// This library provides the DatabaseIsolate class which manages a dedicated
/// background isolate for all database operations. This ensures that blocking
/// native calls do not freeze the UI thread.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../exceptions.dart';
import '../ffi/bindings.dart' as bindings;
import '../ffi/ffi_utils.dart';
import '../ffi/native_types.dart';
import 'isolate_messages.dart';

/// Manages a background isolate for database operations.
///
/// This class spawns and manages a dedicated isolate that handles all
/// database operations. Commands are sent to the isolate via SendPort,
/// and responses are received via ReceivePort.
///
/// All database operations are serialized through this single isolate
/// to ensure thread safety when interacting with the native layer.
///
/// Example usage:
/// ```dart
/// final isolate = DatabaseIsolate();
/// await isolate.start();
///
/// try {
///   final response = await isolate.sendCommand(
///     ConnectCommand(endpoint: 'mem://'),
///   );
///   // Handle response
/// } finally {
///   await isolate.dispose();
/// }
/// ```
class DatabaseIsolate {
  /// The spawned isolate instance.
  Isolate? _isolate;

  /// SendPort for sending commands to the isolate.
  SendPort? _sendPort;

  /// ReceivePort for receiving the isolate's SendPort during initialization.
  ReceivePort? _initPort;

  /// Completer for tracking isolate initialization.
  Completer<void>? _initCompleter;

  /// Starts the database isolate.
  ///
  /// This spawns a new isolate and waits for it to initialize.
  /// The isolate will load the native library and prepare to
  /// receive commands.
  ///
  /// This method must be called before sending any commands.
  ///
  /// Throws [StateError] if the isolate is already running.
  Future<void> start() async {
    if (_isolate != null) {
      throw StateError('Isolate is already running');
    }

    _initPort = ReceivePort();
    _initCompleter = Completer<void>();

    // Set up listener for initialization handshake
    _initPort!.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _initCompleter!.complete();
      }
    });

    // Spawn the isolate
    _isolate = await Isolate.spawn(
      _isolateEntry,
      _initPort!.sendPort,
      debugName: 'DatabaseIsolate',
    );

    // Wait for initialization to complete
    await _initCompleter!.future;

    // Close the init port as it's no longer needed
    _initPort!.close();
    _initPort = null;
  }

  /// Sends a command to the database isolate and waits for a response.
  ///
  /// This method sends a command to the background isolate and returns
  /// a Future that completes with the response. The response can be
  /// either a SuccessResponse or an ErrorResponse.
  ///
  /// Throws [StateError] if the isolate is not running.
  /// Throws [DatabaseException] (or subclass) if the command fails.
  ///
  /// Example:
  /// ```dart
  /// final response = await isolate.sendCommand(
  ///   QueryCommand(sql: 'SELECT * FROM person'),
  /// );
  /// if (response is SuccessResponse) {
  ///   print(response.data);
  /// }
  /// ```
  Future<IsolateResponse> sendCommand(IsolateCommand command) async {
    if (_sendPort == null) {
      throw StateError('Isolate is not running. Call start() first.');
    }

    final responsePort = ReceivePort();
    final completer = Completer<IsolateResponse>();

    // Listen for response
    responsePort.listen((message) {
      if (message is IsolateResponse) {
        completer.complete(message);
        responsePort.close();
      }
    });

    // Send command with response port
    _sendPort!.send((command, responsePort.sendPort));

    return completer.future;
  }

  /// Disposes of the isolate and cleans up resources.
  ///
  /// This sends a CloseCommand to the isolate and then kills it.
  /// After calling this method, the isolate cannot be used anymore
  /// unless start() is called again.
  Future<void> dispose() async {
    if (_isolate == null) {
      return; // Already disposed
    }

    try {
      // Try to send close command for graceful shutdown
      if (_sendPort != null) {
        await sendCommand(const CloseCommand());
      }
    } catch (_) {
      // Ignore errors during shutdown
    } finally {
      // Kill the isolate
      _isolate!.kill(priority: Isolate.immediate);
      _isolate = null;
      _sendPort = null;

      // Close any remaining ports
      _initPort?.close();
      _initPort = null;
    }
  }

  /// Isolate entry point function.
  ///
  /// This function runs in the background isolate and handles all
  /// incoming commands. It maintains a database handle and processes
  /// commands sequentially.
  ///
  /// The function performs these steps:
  /// 1. Send back a SendPort for two-way communication
  /// 2. Wait for commands on the ReceivePort
  /// 3. Execute commands using FFI bindings
  /// 4. Send back responses (success or error)
  /// 5. Clean up on CloseCommand
  static void _isolateEntry(SendPort mainSendPort) {
    // Create a ReceivePort for receiving commands
    final commandPort = ReceivePort();

    // Send our SendPort back to the main isolate
    mainSendPort.send(commandPort.sendPort);

    // Store the database handle (null until connected)
    Pointer<NativeDatabase>? dbHandle;

    // Listen for commands
    commandPort.listen((message) {
      if (message is! CommandMessage) {
        return; // Invalid message format
      }

      final (command, responsePort) = message;

      try {
        final response = _handleCommand(command, dbHandle);

        // Update handle if it was a connect command
        if (command is ConnectCommand && response is SuccessResponse) {
          // Extract the handle address from the response and convert to Pointer
          if (response.data is int) {
            dbHandle = Pointer<NativeDatabase>.fromAddress(response.data as int);
          }
        }

        // Send response
        responsePort.send(response);
      } catch (e, stackTrace) {
        // Catch any unexpected errors and send error response
        responsePort.send(ErrorResponse(
          message: 'Unexpected error: $e',
          nativeStackTrace: stackTrace.toString(),
        ));
      }
    });
  }

  /// Handles a single command in the isolate.
  ///
  /// This is a static function that processes commands using the FFI bindings.
  /// It maintains the database handle between commands.
  static IsolateResponse _handleCommand(
    IsolateCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    try {
      return switch (command) {
        InitializeCommand() => _handleInitialize(),
        ConnectCommand() => _handleConnect(command),
        QueryCommand() => _handleQuery(command, dbHandle),
        SelectCommand() => _handleSelect(command, dbHandle),
        CreateCommand() => _handleCreate(command, dbHandle),
        UpdateCommand() => _handleUpdate(command, dbHandle),
        DeleteCommand() => _handleDelete(command, dbHandle),
        UseNamespaceCommand() => _handleUseNamespace(command, dbHandle),
        UseDatabaseCommand() => _handleUseDatabase(command, dbHandle),
        CloseCommand() => _handleClose(dbHandle),
      };
    } catch (e) {
      if (e is DatabaseException) {
        return ErrorResponse(
          message: e.message,
          errorCode: e.errorCode,
          nativeStackTrace: e.nativeStackTrace,
        );
      } else {
        return ErrorResponse(message: e.toString());
      }
    }
  }

  static IsolateResponse _handleInitialize() {
    // Native library is loaded automatically when bindings are imported
    return const SuccessResponse();
  }

  static IsolateResponse _handleConnect(ConnectCommand command) {
    final endpointPtr = stringToCString(command.endpoint);
    try {
      final handle = bindings.dbNew(endpointPtr);
      validateNonNull(handle, 'Failed to create database instance');

      // Connect to database
      final connectResult = bindings.dbConnect(handle);
      if (connectResult != 0) {
        final errorPtr = bindings.getLastError();
        final errorMsg =
            errorPtr != nullptr ? cStringToDartString(errorPtr) : 'Connection failed';
        bindings.freeString(errorPtr);
        bindings.dbClose(handle);
        throwIfError(connectResult, errorMsg);
      }

      // Set namespace if provided
      if (command.namespace != null) {
        final nsPtr = stringToCString(command.namespace!);
        try {
          final result = bindings.dbUseNs(handle, nsPtr);
          if (result != 0) {
            final errorPtr = bindings.getLastError();
            final errorMsg = errorPtr != nullptr
                ? cStringToDartString(errorPtr)
                : 'Failed to set namespace';
            bindings.freeString(errorPtr);
            throwIfError(result, errorMsg);
          }
        } finally {
          freeCString(nsPtr);
        }
      }

      // Set database if provided
      if (command.database != null) {
        final dbPtr = stringToCString(command.database!);
        try {
          final result = bindings.dbUseDb(handle, dbPtr);
          if (result != 0) {
            final errorPtr = bindings.getLastError();
            final errorMsg = errorPtr != nullptr
                ? cStringToDartString(errorPtr)
                : 'Failed to set database';
            bindings.freeString(errorPtr);
            throwIfError(result, errorMsg);
          }
        } finally {
          freeCString(dbPtr);
        }
      }

      // Return the handle address as data (to be stored at isolate level)
      return SuccessResponse(handle.address);
    } finally {
      freeCString(endpointPtr);
    }
  }

  static IsolateResponse _handleQuery(
    QueryCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final sqlPtr = stringToCString(command.sql);
    try {
      final responseHandle = bindings.dbQuery(dbHandle, sqlPtr);
      validateNonNull(responseHandle, 'Query execution failed');

      try {
        // Check for errors
        if (bindings.responseHasErrors(responseHandle) != 0) {
          final errorPtr = bindings.getLastError();
          final errorMsg =
              errorPtr != nullptr ? cStringToDartString(errorPtr) : 'Query failed';
          bindings.freeString(errorPtr);
          throw QueryException(errorMsg);
        }

        // Get results as JSON
        final resultsPtr = bindings.responseGetResults(responseHandle);
        validateNonNull(resultsPtr, 'Failed to get query results');

        try {
          final resultsJson = cStringToDartString(resultsPtr);
          final results = json.decode(resultsJson) as List<dynamic>;
          return SuccessResponse(results);
        } finally {
          bindings.freeString(resultsPtr);
        }
      } finally {
        bindings.responseFree(responseHandle);
      }
    } finally {
      freeCString(sqlPtr);
    }
  }

  static IsolateResponse _handleSelect(
    SelectCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final tablePtr = stringToCString(command.table);
    try {
      final responseHandle = bindings.dbSelect(dbHandle, tablePtr);
      validateNonNull(responseHandle, 'Select operation failed');

      try {
        final resultsPtr = bindings.responseGetResults(responseHandle);
        validateNonNull(resultsPtr, 'Failed to get select results');

        try {
          final resultsJson = cStringToDartString(resultsPtr);
          final results = json.decode(resultsJson) as List<dynamic>;
          return SuccessResponse(results);
        } finally {
          bindings.freeString(resultsPtr);
        }
      } finally {
        bindings.responseFree(responseHandle);
      }
    } finally {
      freeCString(tablePtr);
    }
  }

  static IsolateResponse _handleCreate(
    CreateCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final tablePtr = stringToCString(command.table);
    final dataJson = json.encode(command.data);
    final dataPtr = stringToCString(dataJson);

    try {
      final responseHandle = bindings.dbCreate(dbHandle, tablePtr, dataPtr);
      validateNonNull(responseHandle, 'Create operation failed');

      try {
        final resultsPtr = bindings.responseGetResults(responseHandle);
        validateNonNull(resultsPtr, 'Failed to get create results');

        try {
          final resultsJson = cStringToDartString(resultsPtr);
          final result = json.decode(resultsJson);
          return SuccessResponse(result);
        } finally {
          bindings.freeString(resultsPtr);
        }
      } finally {
        bindings.responseFree(responseHandle);
      }
    } finally {
      freeCString(tablePtr);
      freeCString(dataPtr);
    }
  }

  static IsolateResponse _handleUpdate(
    UpdateCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final resourcePtr = stringToCString(command.resource);
    final dataJson = json.encode(command.data);
    final dataPtr = stringToCString(dataJson);

    try {
      final responseHandle = bindings.dbUpdate(dbHandle, resourcePtr, dataPtr);
      validateNonNull(responseHandle, 'Update operation failed');

      try {
        final resultsPtr = bindings.responseGetResults(responseHandle);
        validateNonNull(resultsPtr, 'Failed to get update results');

        try {
          final resultsJson = cStringToDartString(resultsPtr);
          final result = json.decode(resultsJson);
          return SuccessResponse(result);
        } finally {
          bindings.freeString(resultsPtr);
        }
      } finally {
        bindings.responseFree(responseHandle);
      }
    } finally {
      freeCString(resourcePtr);
      freeCString(dataPtr);
    }
  }

  static IsolateResponse _handleDelete(
    DeleteCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final resourcePtr = stringToCString(command.resource);
    try {
      final responseHandle = bindings.dbDelete(dbHandle, resourcePtr);
      validateNonNull(responseHandle, 'Delete operation failed');

      try {
        bindings.responseFree(responseHandle);
        return const SuccessResponse();
      } catch (e) {
        bindings.responseFree(responseHandle);
        rethrow;
      }
    } finally {
      freeCString(resourcePtr);
    }
  }

  static IsolateResponse _handleUseNamespace(
    UseNamespaceCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final nsPtr = stringToCString(command.namespace);
    try {
      final result = bindings.dbUseNs(dbHandle, nsPtr);
      if (result != 0) {
        final errorPtr = bindings.getLastError();
        final errorMsg =
            errorPtr != nullptr ? cStringToDartString(errorPtr) : 'Failed to set namespace';
        bindings.freeString(errorPtr);
        throwIfError(result, errorMsg);
      }
      return const SuccessResponse();
    } finally {
      freeCString(nsPtr);
    }
  }

  static IsolateResponse _handleUseDatabase(
    UseDatabaseCommand command,
    Pointer<NativeDatabase>? dbHandle,
  ) {
    if (dbHandle == null) {
      throw DatabaseException('Not connected to database');
    }

    final dbPtr = stringToCString(command.database);
    try {
      final result = bindings.dbUseDb(dbHandle, dbPtr);
      if (result != 0) {
        final errorPtr = bindings.getLastError();
        final errorMsg =
            errorPtr != nullptr ? cStringToDartString(errorPtr) : 'Failed to set database';
        bindings.freeString(errorPtr);
        throwIfError(result, errorMsg);
      }
      return const SuccessResponse();
    } finally {
      freeCString(dbPtr);
    }
  }

  static IsolateResponse _handleClose(Pointer<NativeDatabase>? dbHandle) {
    if (dbHandle != null) {
      bindings.dbClose(dbHandle);
    }
    return const SuccessResponse();
  }
}
