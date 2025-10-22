/// Interactive CLI example for SurrealDB Dart FFI bindings.
///
/// This example demonstrates the core functionality of the surrealdartb
/// library through an interactive menu-driven interface. Users can choose
/// from different scenarios to see the library in action.
///
/// Run this example with: `dart run example/cli_example.dart`
library;

import 'dart:io';

import 'scenarios/authentication.dart';
import 'scenarios/connect_verify.dart';
import 'scenarios/crud_operations.dart';
import 'scenarios/parameters_functions.dart';
import 'scenarios/storage_comparison.dart';

/// Main entry point for the CLI example application.
///
/// Displays an interactive menu allowing users to select and run
/// different demonstration scenarios showing SurrealDB features.
void main() async {
  _printWelcome();

  var running = true;

  while (running) {
    _printMenu();

    final choice = _getUserChoice();

    switch (choice) {
      case '1':
        await _runScenario('Connect and Verify', runConnectVerifyScenario);
      case '2':
        await _runScenario('CRUD Operations', runCrudScenario);
      case '3':
        await _runScenario('Storage Comparison', runStorageComparisonScenario);
      case '4':
        await _runScenario(
            'Authentication Features', runAuthenticationScenario);
      case '5':
        await _runScenario(
            'Parameters & Functions', runParametersFunctionsScenario);
      case '6':
        print('\nThank you for using SurrealDB Dart FFI bindings!');
        print('Goodbye!\n');
        running = false;
      default:
        print('\n✗ Invalid choice. Please enter a number between 1 and 6.\n');
    }
  }
}

/// Prints the welcome banner.
void _printWelcome() {
  print('');
  print('╔════════════════════════════════════════════════════════════╗');
  print('║                                                            ║');
  print('║        SurrealDB Dart FFI Bindings - CLI Example          ║');
  print('║                                                            ║');
  print('║  This interactive example demonstrates core features of   ║');
  print('║  the SurrealDB Dart library through various scenarios.    ║');
  print('║                                                            ║');
  print('╚════════════════════════════════════════════════════════════╝');
  print('');
}

/// Prints the interactive menu.
void _printMenu() {
  print('┌────────────────────────────────────────────────────────────┐');
  print('│ Available Scenarios:                                       │');
  print('├────────────────────────────────────────────────────────────┤');
  print('│ 1. Connect and Verify Connectivity                        │');
  print('│    • Basic connection to in-memory database               │');
  print('│    • Set namespace and database context                   │');
  print('│    • Execute INFO query to verify connection              │');
  print('│                                                            │');
  print('│ 2. CRUD Operations Demonstration                          │');
  print('│    • Create, read, update, delete records                 │');
  print('│    • Query execution and result handling                  │');
  print('│    • Type-safe operations                                 │');
  print('│                                                            │');
  print('│ 3. Storage Backend Comparison                             │');
  print('│    • Compare in-memory (mem://) storage                   │');
  print('│    • Compare persistent (RocksDB) storage                 │');
  print('│    • Demonstrate data persistence behavior                │');
  print('│                                                            │');
  print('│ 4. Authentication Features (NEW!)                         │');
  print('│    • Sign in with different credential types              │');
  print('│    • Sign up new users                                    │');
  print('│    • JWT token authentication                             │');
  print('│    • Session invalidation                                 │');
  print('│                                                            │');
  print('│ 5. Parameters & Functions (NEW!)                          │');
  print('│    • Set and use query parameters                         │');
  print('│    • Execute built-in SurrealQL functions                 │');
  print('│    • Define and run custom functions                      │');
  print('│    • Get database version                                 │');
  print('│                                                            │');
  print('│ 6. Exit                                                    │');
  print('└────────────────────────────────────────────────────────────┘');
  print('');
}

/// Gets the user's menu choice.
///
/// Prompts the user for input and returns the choice as a string.
/// Returns an empty string if input is null.
String _getUserChoice() {
  stdout.write('Enter your choice (1-6): ');
  final input = stdin.readLineSync();
  return input?.trim() ?? '';
}

/// Runs a scenario with error handling.
///
/// Executes the provided scenario function and handles any errors
/// that occur during execution. Displays clear error messages to
/// the user if the scenario fails.
///
/// Parameters:
/// - [name] - The display name of the scenario
/// - [scenario] - The async function to execute
Future<void> _runScenario(
  String name,
  Future<void> Function() scenario,
) async {
  try {
    await scenario();
  } catch (e, stackTrace) {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║ ERROR OCCURRED                                             ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('');
    print('Scenario: $name');
    print('Error: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
    print('');
    print('The scenario encountered an error and could not complete.');
    print('Please check the error message above for details.\n');
  }

  // Pause before returning to menu
  print('Press Enter to return to menu...');
  stdin.readLineSync();
  print('');
}
