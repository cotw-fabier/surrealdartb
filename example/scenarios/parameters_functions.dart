/// Parameter management and function execution demonstration.
///
/// This scenario demonstrates parameter management (set, unset) and
/// SurrealQL function execution (built-in and user-defined functions).
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the parameters and functions demonstration scenario.
///
/// Demonstrates:
/// - Setting and unsetting query parameters
/// - Using parameters in queries
/// - Executing built-in SurrealQL functions
/// - Defining and executing custom functions
/// - Getting database version
Future<void> runParametersFunctionsScenario() async {
  print('\n╔════════════════════════════════════════════════════════════╗');
  print('║                                                            ║');
  print('║     Parameters & Functions Features Demonstration         ║');
  print('║                                                            ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'demo',
    database: 'functions',
  );

  try {
    await _demonstrateParameterManagement(db);
    await _demonstrateBuiltInFunctions(db);
    await _demonstrateCustomFunctions(db);
    await _demonstrateDatabaseVersion(db);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║                                                            ║');
    print('║    ✓ Parameters & Functions Scenario Completed            ║');
    print('║                                                            ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
  } finally {
    await db.close();
    print('✓ Database closed\n');
  }
}

/// Demonstrates parameter management.
Future<void> _demonstrateParameterManagement(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('1. Parameter Management');
  print('─────────────────────────────────────────────────────────────\n');

  // Create sample data first
  print('Setting up sample data...');
  await db.createQL('person', {
    'name': 'Alice',
    'age': 25,
    'status': 'active',
    'city': 'New York',
  });
  await db.createQL('person', {
    'name': 'Bob',
    'age': 30,
    'status': 'active',
    'city': 'London',
  });
  await db.createQL('person', {
    'name': 'Charlie',
    'age': 35,
    'status': 'inactive',
    'city': 'Paris',
  });
  print('✓ Created 3 sample person records\n');

  // Set parameters
  print('Setting query parameters...');
  await db.set('min_age', 18);
  await db.set('max_age', 65);
  await db.set('status_filter', 'active');
  print('✓ Set parameters: min_age=18, max_age=65, status_filter=active\n');

  // Use parameters in query
  print('Executing query with parameters...');
  final response = await db.queryQL('''
    SELECT * FROM person
    WHERE age >= \$min_age
    AND age <= \$max_age
    AND status = \$status_filter
    ORDER BY age
  ''');

  final results = response.getResults();
  print('✓ Query executed successfully');
  print('  Found ${results.length} matching records:');
  for (final person in results) {
    print('  - ${person['name']}, age ${person['age']}, ${person['status']}');
  }
  print('');

  // Demonstrate parameter reuse
  print('Changing parameter and re-running query...');
  await db.set('status_filter', 'inactive');
  final response2 = await db.queryQL('''
    SELECT * FROM person
    WHERE status = \$status_filter
  ''');

  final results2 = response2.getResults();
  print('✓ Query with updated parameter:');
  print('  Found ${results2.length} inactive record(s)');
  print('');

  // Unset parameters
  print('Unsetting parameters...');
  await db.unset('min_age');
  await db.unset('max_age');
  await db.unset('status_filter');
  print('✓ Parameters unset (safe operation, no error if not exist)\n');
}

/// Demonstrates built-in SurrealQL functions.
Future<void> _demonstrateBuiltInFunctions(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('2. Built-in SurrealQL Functions');
  print('─────────────────────────────────────────────────────────────\n');

  // Random functions
  print('Random number generation:');
  final randomFloat = await db.run<double>('rand::float');
  print('  rand::float() = $randomFloat');
  final randomInt = await db.run<int>('rand::int', [1, 100]);
  print('  rand::int(1, 100) = $randomInt\n');

  // String functions
  print('String manipulation:');
  final upperCase = await db.run<String>('string::uppercase', ['hello world']);
  print('  string::uppercase("hello world") = $upperCase');
  final lowerCase = await db.run<String>('string::lowercase', ['HELLO WORLD']);
  print('  string::lowercase("HELLO WORLD") = $lowerCase\n');

  // Math functions
  print('Math functions:');
  final sqrt = await db.run<double>('math::sqrt', [16.0]);
  print('  math::sqrt(16) = $sqrt');
  final ceil = await db.run<double>('math::ceil', [4.3]);
  print('  math::ceil(4.3) = ${ceil.toInt()}');
  final floor = await db.run<double>('math::floor', [4.8]);
  print('  math::floor(4.8) = ${floor.toInt()}\n');

  // Time functions
  print('Time functions:');
  try {
    final now = await db.run<String>('time::now');
    print('  time::now() = $now\n');
  } catch (e) {
    print('  time::now() - Note: $e\n');
  }
}

/// Demonstrates custom user-defined functions.
Future<void> _demonstrateCustomFunctions(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('3. User-Defined Functions');
  print('─────────────────────────────────────────────────────────────\n');

  // Define a custom function for tax calculation
  print('Defining custom function: fn::calculate_tax...');
  await db.queryQL('''
    DEFINE FUNCTION fn::calculate_tax(\$amount: number, \$rate: number) {
      RETURN \$amount * \$rate;
    };
  ''');
  print('✓ Function defined\n');

  // Execute the custom function
  print('Executing fn::calculate_tax(100, 0.08)...');
  final tax = await db.run<double>('fn::calculate_tax', [100.0, 0.08]);
  print('✓ Tax calculated: \$${tax.toStringAsFixed(2)}');
  print('  Use case: Server-side business logic, reusable calculations\n');

  // Define another custom function
  print('Defining custom function: fn::full_name...');
  await db.queryQL('''
    DEFINE FUNCTION fn::full_name(\$first: string, \$last: string) {
      RETURN \$first + " " + \$last;
    };
  ''');
  print('✓ Function defined\n');

  // Execute the name function
  print('Executing fn::full_name("John", "Doe")...');
  final fullName = await db.run<String>('fn::full_name', ['John', 'Doe']);
  print('✓ Full name: $fullName\n');
}

/// Demonstrates getting database version.
Future<void> _demonstrateDatabaseVersion(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('4. Database Version');
  print('─────────────────────────────────────────────────────────────\n');

  print('Getting SurrealDB version...');
  final version = await db.version();
  print('✓ SurrealDB version: $version');
  print('  Use case: Compatibility checks, diagnostics\n');
}
