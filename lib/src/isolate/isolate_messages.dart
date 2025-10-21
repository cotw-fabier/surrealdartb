/// Message types for isolate communication.
///
/// This library defines the message protocol used to communicate between
/// the main isolate and the background database isolate. All message types
/// must contain only primitive types and SendPorts to be sendable across
/// isolate boundaries.
library;

import 'dart:isolate';

/// Base class for commands sent to the database isolate.
///
/// All commands must be sendable across isolate boundaries, which means
/// they can only contain:
/// - Primitive types (int, double, String, bool, null)
/// - Lists and Maps of primitives
/// - SendPort instances
///
/// Commands are processed by the isolate entry point and result in
/// either a SuccessResponse or ErrorResponse.
sealed class IsolateCommand {
  const IsolateCommand();
}

/// Command to initialize the database isolate.
///
/// This command should be sent first to set up the native library
/// bindings and prepare the isolate for database operations.
final class InitializeCommand extends IsolateCommand {
  const InitializeCommand();
}

/// Command to connect to a database.
///
/// This creates a new database instance and establishes a connection.
/// Optionally sets namespace and database context if provided.
final class ConnectCommand extends IsolateCommand {
  const ConnectCommand({
    required this.endpoint,
    this.namespace,
    this.database,
  });

  /// Database endpoint (e.g., "mem://", "file:///path/to/db")
  final String endpoint;

  /// Optional namespace to use after connection
  final String? namespace;

  /// Optional database to use after connection
  final String? database;
}

/// Command to execute a SurrealQL query.
///
/// Executes the provided SQL query and returns the results.
/// Optional bindings can be provided for parameterized queries.
final class QueryCommand extends IsolateCommand {
  const QueryCommand({
    required this.sql,
    this.bindings,
  });

  /// SurrealQL query string
  final String sql;

  /// Optional query parameter bindings
  ///
  /// Note: Initial implementation may not fully support bindings,
  /// this is reserved for future enhancement.
  final Map<String, dynamic>? bindings;
}

/// Command to select all records from a table.
final class SelectCommand extends IsolateCommand {
  const SelectCommand(this.table);

  /// Table name to select from
  final String table;
}

/// Command to create a new record in a table.
final class CreateCommand extends IsolateCommand {
  const CreateCommand({
    required this.table,
    required this.data,
  });

  /// Table name to create record in
  final String table;

  /// Record data as key-value pairs
  final Map<String, dynamic> data;
}

/// Command to update an existing record.
final class UpdateCommand extends IsolateCommand {
  const UpdateCommand({
    required this.resource,
    required this.data,
  });

  /// Resource identifier (e.g., "person:john")
  final String resource;

  /// Update data as key-value pairs
  final Map<String, dynamic> data;
}

/// Command to delete a record.
final class DeleteCommand extends IsolateCommand {
  const DeleteCommand(this.resource);

  /// Resource identifier (e.g., "person:john")
  final String resource;
}

/// Command to set the active namespace.
final class UseNamespaceCommand extends IsolateCommand {
  const UseNamespaceCommand(this.namespace);

  /// Namespace name
  final String namespace;
}

/// Command to set the active database.
final class UseDatabaseCommand extends IsolateCommand {
  const UseDatabaseCommand(this.database);

  /// Database name
  final String database;
}

/// Command to close the database connection and shut down the isolate.
final class CloseCommand extends IsolateCommand {
  const CloseCommand();
}

/// Base class for responses from the database isolate.
///
/// Responses are sent back to the main isolate after processing
/// a command. They can either indicate success with data or failure
/// with an error message.
sealed class IsolateResponse {
  const IsolateResponse();
}

/// Response indicating successful command execution.
///
/// Contains optional result data from the operation.
final class SuccessResponse extends IsolateResponse {
  const SuccessResponse([this.data]);

  /// Optional result data
  ///
  /// Type depends on the command that was executed:
  /// - ConnectCommand: null
  /// - QueryCommand: List<Map<String, dynamic>> (query results)
  /// - SelectCommand: List<Map<String, dynamic>> (records)
  /// - CreateCommand: Map<String, dynamic> (created record)
  /// - UpdateCommand: Map<String, dynamic> (updated record)
  /// - DeleteCommand: null
  final dynamic data;
}

/// Response indicating command execution failed.
///
/// Contains error information including message and optional
/// error code from the native layer.
final class ErrorResponse extends IsolateResponse {
  const ErrorResponse({
    required this.message,
    this.errorCode,
    this.nativeStackTrace,
  });

  /// Human-readable error message
  final String message;

  /// Optional error code from native layer
  final int? errorCode;

  /// Optional stack trace from native code
  final String? nativeStackTrace;
}

/// Internal message type for command/response pairing.
///
/// This is used internally to associate a command with a response port.
/// It is not part of the public API.
typedef CommandMessage = (IsolateCommand command, SendPort responsePort);
