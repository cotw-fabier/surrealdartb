/// Demonstrates complete CRUD (Create, Read, Update, Delete) operations.
///
/// This scenario shows how to:
/// - Connect to an in-memory database
/// - Create a new record
/// - Query records
/// - Update an existing record
/// - Delete a record
/// - Handle errors gracefully
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the CRUD operations scenario.
///
/// This scenario demonstrates two approaches to CRUD operations:
/// - Section A: Basic CRUD with SurrealQL (simple, direct database operations)
/// - Section B: Schema-Validated CRUD with TableStructure (type-safe with validation)
///
/// This shows the progression from basic to advanced usage, demonstrating
/// when to use schema validation for production applications.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runCrudScenario() async {
  print('\n=== Scenario 2: CRUD Operations ===\n');

  Database? db;

  try {
    // ===================================================================
    // SECTION A: Basic CRUD Operations (No Schema Validation)
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION A: Basic CRUD Operations                         ║');
    print('║ (Direct SurrealQL - Simple & Fast)                       ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // Step 1: Connect to database
    print('Step 1: Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected successfully\n');

    // Step 2: Create a new person record
    print('Step 2: Creating a new person record...');
    final person = await db.createQL('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });
    print('✓ Record created:');
    print('  ID: ${person['id']}');
    print('  Name: ${person['name']}');
    print('  Age: ${person['age']}');
    print('  Email: ${person['email']}');
    print('  City: ${person['city']}\n');

    // Extract the record ID for later operations
    final recordId = person['id'] as String;

    // Step 3: Query all person records
    print('Step 3: Querying all person records...');
    final persons = await db.selectQL('person');
    print('✓ Found ${persons.length} record(s)');
    for (final p in persons) {
      print('  - ${p['name']} (${p['age']} years old)');
    }
    print('');

    // Step 4: Update the record
    print('Step 4: Updating person record...');
    final updated = await db.updateQL(recordId, {
      'age': 31,
      'email': 'john.updated@example.com',
      'city': 'Los Angeles',
    });
    print('✓ Record updated:');
    print('  ID: ${updated['id']}');
    print('  Name: ${updated['name']}');
    print('  Age: ${updated['age']} (was 30)');
    print('  Email: ${updated['email']} (was john.doe@example.com)');
    print('  City: ${updated['city']} (was San Francisco)\n');

    // Step 5: Verify the update with a query
    print('Step 5: Verifying update with query...');
    final response = await db.queryQL('SELECT * FROM person WHERE age > 30');
    final results = response.getResults();
    print('✓ Query result for age > 30:');
    if (results.isEmpty) {
      print('  No records found');
    } else {
      for (final r in results) {
        print('  - ${r['name']}: ${r['age']} years old');
      }
    }
    print('');

    // Step 6: Delete the record
    print('Step 6: Deleting person record...');
    await db.deleteQL(recordId);
    print('✓ Record deleted: $recordId\n');

    // Step 7: Verify deletion
    print('Step 7: Verifying deletion...');
    final remaining = await db.selectQL('person');
    print('✓ Remaining records: ${remaining.length}');
    if (remaining.isEmpty) {
      print('  All records have been deleted\n');
    }

    // Success summary
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ Section A Complete - Basic CRUD: SUCCESS ✓               ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // ===================================================================
    // SECTION B: Schema-Validated CRUD Operations (With TableStructure)
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION B: Schema-Validated CRUD Operations              ║');
    print('║ (TableStructure - Type-Safe & Validated)                 ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    await _demonstrateSchemaValidatedCrud(db);
  } on ConnectionException catch (e) {
    print('\n✗ Connection failed: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } on QueryException catch (e) {
    print('\n✗ Query failed: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } on DatabaseException catch (e) {
    print('\n✗ Database error: ${e.message}');
    if (e.errorCode != null) {
      print('  Error code: ${e.errorCode}');
    }
    rethrow;
  } catch (e) {
    print('\n✗ Unexpected error: $e');
    rethrow;
  } finally {
    // Always close the database connection
    if (db != null) {
      print('Closing database connection...');
      await db.close();
      print('✓ Database closed\n');
    }
  }
}

/// Demonstrates CRUD operations with schema validation using TableStructure.
///
/// This approach provides:
/// - Type-safe schema definitions
/// - Dart-side validation before database operations
/// - Clear validation error messages with field-level details
/// - Production-ready patterns for data integrity
Future<void> _demonstrateSchemaValidatedCrud(Database db) async {
  // Step 1: Define the schema using TableStructure
  print('Step 1: Defining product schema with TableStructure...');
  final productSchema = TableStructure('product', {
    'name': FieldDefinition(StringType(), optional: false),
    'price': FieldDefinition(
      NumberType(format: NumberFormat.floating),
      optional: false,
    ),
    'quantity': FieldDefinition(
      NumberType(format: NumberFormat.integer),
      optional: false,
    ),
    'category': FieldDefinition(StringType(), optional: true),
    'tags': FieldDefinition(
      ArrayType(StringType()),
      optional: true,
    ),
  });
  print('✓ Schema defined with 5 fields (3 required, 2 optional)\n');

  // Step 2: Create a product with schema validation
  print('Step 2: Creating product with schema validation...');
  final productData = {
    'name': 'Laptop',
    'price': 999.99,
    'quantity': 10,
    'category': 'Electronics',
    'tags': ['computer', 'portable', 'work'],
  };

  // Validate before creating
  try {
    productSchema.validate(productData);
    print('✓ Data validated successfully (Dart-side validation)');
  } on ValidationException catch (e) {
    print('✗ Validation failed: ${e.message}');
    if (e.fieldName != null) {
      print('  Field: ${e.fieldName}');
    }
    rethrow;
  }

  final product = await db.createQL('product', productData, schema: productSchema);
  print('✓ Product created:');
  print('  ID: ${product['id']}');
  print('  Name: ${product['name']}');
  print('  Price: \$${product['price']}');
  print('  Quantity: ${product['quantity']}');
  print('  Category: ${product['category']}');
  print('  Tags: ${product['tags']}\n');

  final productId = product['id'] as String;

  // Step 3: Attempt to update with invalid data (demonstrate validation)
  print('Step 3: Testing validation with invalid data...');
  final invalidUpdate = {
    'price': -50.0, // Negative price - should pass schema but may fail business logic
    'quantity': 5,
  };

  try {
    // Schema validates types, not business rules
    productSchema.validate(invalidUpdate);
    print('✓ Schema validation passed (types are correct)');
    print('  Note: Schema validates structure, not business rules');
    print('  (Business rules like "price > 0" would need custom validation)\n');
  } catch (e) {
    print('✗ Validation failed: $e\n');
  }

  // Step 4: Update with valid data
  print('Step 4: Updating product with valid data...');
  final validUpdate = {
    'price': 899.99,
    'quantity': 8,
    'category': 'Electronics & Computers',
  };

  // Note: UPDATE operations use partial validation automatically.
  // This means we only need to provide the fields we want to update,
  // not all required fields. The schema validates the types of the
  // fields being updated, ensuring data integrity.
  final updated = await db.updateQL(productId, validUpdate, schema: productSchema);
  print('✓ Product updated:');
  print('  Price: \$${updated['price']} (was \$999.99)');
  print('  Quantity: ${updated['quantity']} (was 10)');
  print('  Category: ${updated['category']}\n');

  // Step 5: Demonstrate missing required field error
  print('Step 5: Testing required field validation...');
  final missingRequired = {
    'name': 'Incomplete Product',
    // Missing 'price' and 'quantity' - both required!
  };

  try {
    productSchema.validate(missingRequired);
    print('✗ Should have failed validation!');
  } on ValidationException catch (e) {
    print('✓ Caught validation error (as expected):');
    print('  ${e.message}');
    if (e.fieldName != null) {
      print('  Failed field: ${e.fieldName}');
    }
    print('  This error was caught BEFORE database call (Dart-side validation)\n');
  }

  // Step 6: Query and clean up
  print('Step 6: Querying products...');
  final products = await db.selectQL('product');
  print('✓ Found ${products.length} product(s)');
  for (final p in products) {
    print('  - ${p['name']}: \$${p['price']}');
  }
  print('');

  print('Step 7: Cleaning up...');
  await db.deleteQL(productId);
  print('✓ Product deleted\n');

  // Summary
  print('╔═══════════════════════════════════════════════════════════╗');
  print('║ Section B Complete - Schema-Validated CRUD: SUCCESS ✓    ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  print('=== Key Takeaways ===');
  print('1. Basic CRUD (Section A):');
  print('   - Fast and simple for prototyping');
  print('   - Validation happens at database level');
  print('   - Good for simple use cases\n');
  print('2. Schema-Validated CRUD (Section B):');
  print('   - Type-safe with compile-time checking');
  print('   - Dart-side validation catches errors early');
  print('   - Better error messages with field details');
  print('   - Production-ready for complex applications\n');
  print('Choose the approach that fits your needs!');
  print('You can even mix both in the same application.\n');
}
