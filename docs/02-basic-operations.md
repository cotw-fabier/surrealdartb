[← Back to Documentation Index](README.md)

# Basic QL Functions Usage

## Section 2: Basic QL Functions Usage

### Introduction to QL Methods

SurrealDartBprovides "QL" methods as the basic API for interacting with SurrealDB. These methods offer a straightforward, map-based interface for CRUD operations and raw query execution.

**Why "QL" Methods?**
- "QL" stands for "Query Language" methods
- These are the fundamental building blocks for database operations
- They provide a simple, flexible API that directly maps to SurrealDB operations
- Perfect for getting started and for use cases where you don't need type-safe ORM features

**Available QL Methods:**
- `createQL()` - Create new records
- `selectQL()` - Read all records from a table
- `get()` - Get a specific record by ID
- `updateQL()` - Update existing records
- `deleteQL()` - Delete records
- `queryQL()` - Execute raw SurrealQL queries
- `set()` and `unset()` - Manage query parameters

### CRUD Operations

#### Creating Records

Use `createQL()` to create new records in a table:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> createExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a person record
    final person = await db.createQL('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });

    // The returned record includes the generated ID
    print('Created person with ID: ${person['id']}');
    print('Name: ${person['name']}');
    print('Age: ${person['age']}');

    // Create a product record
    final product = await db.createQL('product', {
      'name': 'Laptop',
      'price': 999.99,
      'quantity': 10,
      'category': 'Electronics',
      'tags': ['computer', 'portable', 'work'],
    });

    print('Created product: ${product['name']} - \$${product['price']}');

  } finally {
    await db.close();
  }
}
```

**What gets returned:**
- The created record as a `Map<String, dynamic>`
- Includes all fields you provided
- Includes the auto-generated `id` field
- The `id` field format is `tablename:recordid`

#### Reading Records

Use `selectQL()` to retrieve all records from a table:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> readExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create some test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 35});
    await db.createQL('person', {'name': 'Charlie', 'age': 45});

    // Select all person records
    final persons = await db.selectQL('person');

    print('Found ${persons.length} person(s):');
    for (final person in persons) {
      print('  - ${person['name']}: ${person['age']} years old');
    }

    // selectQL returns List<Map<String, dynamic>>
    // Each map represents one record

  } finally {
    await db.close();
  }
}
```

#### Getting Specific Records

Use `get()` to retrieve a specific record by its ID:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> getExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a record
    final created = await db.createQL('user', {
      'username': 'johndoe',
      'email': 'john@example.com',
      'active': true,
    });

    // Extract the record ID
    final recordId = created['id'] as String;
    print('Created record: $recordId');

    // Get the specific record by ID
    final user = await db.get<Map<String, dynamic>>(recordId);

    if (user != null) {
      print('Retrieved user:');
      print('  Username: ${user['username']}');
      print('  Email: ${user['email']}');
      print('  Active: ${user['active']}');
    } else {
      print('User not found');
    }

    // Try to get a non-existent record
    final nonExistent = await db.get<Map<String, dynamic>>('user:unknown');
    print('Non-existent user: $nonExistent'); // Prints: null

  } finally {
    await db.close();
  }
}
```

**Important Notes:**
- `get()` requires a full record ID in format `table:id`
- Returns `null` if the record doesn't exist (not an error)
- Uses generic type parameter for type safety

#### Updating Records

Use `updateQL()` to modify existing records:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> updateExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a person
    final person = await db.createQL('person', {
      'name': 'John Doe',
      'age': 30,
      'email': 'john.doe@example.com',
      'city': 'San Francisco',
    });

    final recordId = person['id'] as String;

    // Update the person's age and city
    final updated = await db.updateQL(recordId, {
      'age': 31,
      'city': 'Los Angeles',
    });

    print('Updated record:');
    print('  Name: ${updated['name']}'); // Still 'John Doe'
    print('  Age: ${updated['age']}'); // Now 31
    print('  Email: ${updated['email']}'); // Still john.doe@example.com
    print('  City: ${updated['city']}'); // Now 'Los Angeles'

    // You can also update by adding new fields
    final withNewField = await db.updateQL(recordId, {
      'phone': '+1-555-0123',
      'verified': true,
    });

    print('Added new fields:');
    print('  Phone: ${withNewField['phone']}');
    print('  Verified: ${withNewField['verified']}');

  } finally {
    await db.close();
  }
}
```

**Update Behavior:**
- Only updates the fields you specify
- Existing fields not mentioned remain unchanged
- Can add new fields that didn't exist before
- Returns the complete updated record

#### Deleting Records

Use `deleteQL()` to remove records:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> deleteExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create a record
    final person = await db.createQL('person', {
      'name': 'Temporary User',
      'email': 'temp@example.com',
    });

    final recordId = person['id'] as String;
    print('Created record: $recordId');

    // Verify it exists
    var allPersons = await db.selectQL('person');
    print('Records before delete: ${allPersons.length}');

    // Delete the record
    await db.deleteQL(recordId);
    print('Deleted record: $recordId');

    // Verify it's gone
    allPersons = await db.selectQL('person');
    print('Records after delete: ${allPersons.length}');

    // Try to get the deleted record
    final deleted = await db.get<Map<String, dynamic>>(recordId);
    print('Get deleted record: $deleted'); // Prints: null

  } finally {
    await db.close();
  }
}
```

#### Complete CRUD Example

Here's a complete example demonstrating all CRUD operations:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> completeCrudExample() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    print('=== Complete CRUD Example ===\n');

    // CREATE
    print('1. Creating a new user...');
    final user = await db.createQL('user', {
      'username': 'alice',
      'email': 'alice@example.com',
      'age': 28,
      'active': true,
    });
    print('   Created: ${user['username']} (${user['id']})');

    final userId = user['id'] as String;

    // READ - Get specific
    print('\n2. Reading the user...');
    final retrieved = await db.get<Map<String, dynamic>>(userId);
    print('   Retrieved: ${retrieved!['username']}');
    print('   Email: ${retrieved['email']}');

    // READ - Get all
    print('\n3. Reading all users...');
    final allUsers = await db.selectQL('user');
    print('   Total users: ${allUsers.length}');
    for (final u in allUsers) {
      print('   - ${u['username']} (age: ${u['age']})');
    }

    // UPDATE
    print('\n4. Updating the user...');
    final updated = await db.updateQL(userId, {
      'age': 29,
      'email': 'alice.smith@example.com',
      'verified': true,
    });
    print('   Updated age: ${updated['age']}');
    print('   Updated email: ${updated['email']}');
    print('   Added verified: ${updated['verified']}');

    // DELETE
    print('\n5. Deleting the user...');
    await db.deleteQL(userId);
    print('   Deleted: $userId');

    // Verify deletion
    final afterDelete = await db.selectQL('user');
    print('   Remaining users: ${afterDelete.length}');

    print('\n=== CRUD Example Complete ===');

  } finally {
    await db.close();
  }
}
```

### Raw Query Execution

For complex queries or operations not covered by the basic CRUD methods, use `queryQL()` to execute raw SurrealQL queries.

#### Basic Query Execution

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> rawQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 30});
    await db.createQL('person', {'name': 'Charlie', 'age': 35});

    // Execute a raw query with WHERE clause
    final response = await db.queryQL('SELECT * FROM person WHERE age > 25');

    // Extract results from the response
    final results = response.getResults();

    print('People older than 25:');
    for (final person in results) {
      print('  - ${person['name']}: ${person['age']} years old');
    }

  } finally {
    await db.close();
  }
}
```

#### Working with Response Objects

The `queryQL()` method returns a `Response` object with several useful methods:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> responseHandlingExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {'name': 'Laptop', 'price': 999.99});
    await db.createQL('product', {'name': 'Mouse', 'price': 29.99});

    // Execute query
    final response = await db.queryQL('SELECT * FROM product');

    // Get all results
    final results = response.getResults();
    print('Result count: ${results.length}');

    // Check if response is empty
    if (response.isEmpty) {
      print('No results found');
    } else {
      print('Found ${response.resultCount} results');
    }

    // Get first result (or null if empty)
    final firstProduct = response.firstOrNull;
    if (firstProduct != null) {
      print('First product: ${firstProduct['name']}');
    }

    // Iterate through results
    for (final product in results) {
      print('Product: ${product['name']} - \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Multiple Statement Queries

SurrealQL allows executing multiple statements in a single query:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> multipleStatementExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Execute multiple statements
    final response = await db.queryQL('''
      CREATE person SET name = 'Alice', age = 30;
      CREATE person SET name = 'Bob', age = 25;
      SELECT * FROM person;
    ''');

    // The response contains results from all statements
    // Access individual results using takeResult()

    final createResult1 = response.takeResult(0);
    print('First CREATE: ${createResult1}');

    final createResult2 = response.takeResult(1);
    print('Second CREATE: ${createResult2}');

    final selectResult = response.takeResult(2);
    print('SELECT result: $selectResult');

    // Or just get all results at once
    final allResults = response.getResults();
    print('Total result sets: ${allResults.length}');

  } finally {
    await db.close();
  }
}
```

#### Complex Queries

Execute advanced queries with JOINs, aggregations, and more:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> complexQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('order', {
      'customer': 'Alice',
      'amount': 150.00,
      'status': 'completed',
    });
    await db.createQL('order', {
      'customer': 'Alice',
      'amount': 200.00,
      'status': 'completed',
    });
    await db.createQL('order', {
      'customer': 'Bob',
      'amount': 100.00,
      'status': 'pending',
    });

    // Query with aggregation
    final response = await db.queryQL('''
      SELECT
        customer,
        count() as order_count,
        math::sum(amount) as total_spent,
        math::avg(amount) as avg_order
      FROM order
      WHERE status = 'completed'
      GROUP BY customer
    ''');

    final results = response.getResults();

    print('Customer order summary:');
    for (final row in results) {
      print('Customer: ${row['customer']}');
      print('  Orders: ${row['order_count']}');
      print('  Total: \$${row['total_spent']}');
      print('  Average: \$${row['avg_order']}');
    }

  } finally {
    await db.close();
  }
}
```

### Parameter Management

Parameters allow you to safely inject values into queries, preventing SQL injection and making queries more reusable.

#### Setting Parameters

Use `set()` to define query parameters:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> parameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('person', {'name': 'Alice', 'age': 25});
    await db.createQL('person', {'name': 'Bob', 'age': 30});
    await db.createQL('person', {'name': 'Charlie', 'age': 35});

    // Set a parameter
    await db.set('min_age', 25);

    // Use the parameter in a query with $parameter_name syntax
    final response = await db.queryQL(
      'SELECT * FROM person WHERE age >= \$min_age'
    );

    final results = response.getResults();
    print('People with age >= 25:');
    for (final person in results) {
      print('  - ${person['name']}: ${person['age']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Using Multiple Parameters

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> multipleParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {
      'name': 'Laptop',
      'price': 999.99,
      'category': 'electronics',
      'in_stock': true,
    });
    await db.createQL('product', {
      'name': 'Mouse',
      'price': 29.99,
      'category': 'electronics',
      'in_stock': true,
    });
    await db.createQL('product', {
      'name': 'Desk',
      'price': 499.99,
      'category': 'furniture',
      'in_stock': false,
    });

    // Set multiple parameters
    await db.set('category', 'electronics');
    await db.set('max_price', 500.00);
    await db.set('in_stock', true);

    // Use multiple parameters in one query
    final response = await db.queryQL('''
      SELECT * FROM product
      WHERE category = \$category
        AND price <= \$max_price
        AND in_stock = \$in_stock
    ''');

    final results = response.getResults();
    print('Affordable electronics in stock:');
    for (final product in results) {
      print('  - ${product['name']}: \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Complex Parameter Types

Parameters can be strings, numbers, booleans, or complex objects:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> complexParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Set a complex object parameter
    await db.set('filter', {
      'min_age': 25,
      'max_age': 35,
      'status': 'active',
    });

    // Use the complex parameter
    final response = await db.queryQL('RETURN \$filter');
    final result = response.firstOrNull;

    print('Filter parameter:');
    print('  Min age: ${result!['min_age']}');
    print('  Max age: ${result['max_age']}');
    print('  Status: ${result['status']}');

    // You can also use object properties in queries
    await db.set('age_range', {'min': 20, 'max': 40});
    final ageResponse = await db.queryQL('''
      SELECT * FROM person
      WHERE age >= \$age_range.min AND age <= \$age_range.max
    ''');

  } finally {
    await db.close();
  }
}
```

#### Unsetting Parameters

Use `unset()` to remove parameters:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> unsetParameterExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Set a parameter
    await db.set('temp_value', 42);

    // Use the parameter
    var response = await db.queryQL('RETURN \$temp_value');
    print('Parameter value: ${response.firstOrNull}'); // Prints: 42

    // Unset the parameter
    await db.unset('temp_value');

    // Try to use the unset parameter (will return null or error)
    try {
      response = await db.queryQL('RETURN \$temp_value');
      print('After unset: ${response.firstOrNull}'); // May print: null
    } catch (e) {
      print('Parameter no longer exists');
    }

  } finally {
    await db.close();
  }
}
```

### Batch Operations

For inserting multiple records efficiently, use batch operations:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> batchInsertExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Method 1: Multiple createQL calls (simple but less efficient)
    print('Method 1: Individual inserts');
    for (var i = 1; i <= 3; i++) {
      await db.createQL('person', {
        'name': 'Person $i',
        'age': 20 + i,
      });
    }

    // Method 2: Single query with multiple INSERTs (more efficient)
    print('\nMethod 2: Batch insert via query');
    await db.queryQL('''
      INSERT INTO product [
        { name: 'Laptop', price: 999.99, stock: 10 },
        { name: 'Mouse', price: 29.99, stock: 50 },
        { name: 'Keyboard', price: 79.99, stock: 30 }
      ];
    ''');

    // Method 3: Using parameters for batch insert
    print('\nMethod 3: Batch insert with parameters');

    final products = [
      {'name': 'Monitor', 'price': 299.99, 'stock': 15},
      {'name': 'Webcam', 'price': 89.99, 'stock': 25},
      {'name': 'Headset', 'price': 149.99, 'stock': 20},
    ];

    await db.set('products', products);
    await db.queryQL('INSERT INTO product \$products');

    // Verify all inserts
    final allProducts = await db.selectQL('product');
    print('\nTotal products: ${allProducts.length}');

    for (final product in allProducts) {
      print('  - ${product['name']}: \$${product['price']}');
    }

  } finally {
    await db.close();
  }
}
```

#### Bulk Update Operations

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> bulkUpdateExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create test data
    await db.createQL('product', {'name': 'Product 1', 'price': 100, 'discount': 0});
    await db.createQL('product', {'name': 'Product 2', 'price': 200, 'discount': 0});
    await db.createQL('product', {'name': 'Product 3', 'price': 300, 'discount': 0});

    // Bulk update: Add 10% discount to all products
    await db.queryQL('''
      UPDATE product SET discount = 0.10
    ''');

    // Bulk update with condition
    await db.queryQL('''
      UPDATE product SET discount = 0.20
      WHERE price > 150
    ''');

    // Verify updates
    final products = await db.selectQL('product');
    print('Products after bulk update:');
    for (final product in products) {
      final discount = (product['discount'] as num) * 100;
      print('  - ${product['name']}: ${discount}% discount');
    }

  } finally {
    await db.close();
  }
}
```

### Info Queries

SurrealDB provides special INFO queries to inspect the database schema and structure:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> infoQueryExamples() async {
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'test',
    database: 'test',
  );

  try {
    // Create some data first
    await db.createQL('user', {'name': 'Alice'});
    await db.createQL('product', {'name': 'Laptop'});

    // INFO FOR DB - Get database schema information
    print('=== Database Info ===');
    var response = await db.queryQL('INFO FOR DB;');
    var info = response.firstOrNull;
    print('Database schema: $info\n');

    // Get SurrealDB version
    print('=== Version Info ===');
    response = await db.queryQL('SELECT * FROM version();');
    var version = response.firstOrNull;
    print('SurrealDB version: $version\n');

    // INFO FOR TABLE - Get specific table information
    print('=== Table Info ===');
    response = await db.queryQL('INFO FOR TABLE user;');
    var tableInfo = response.firstOrNull;
    print('User table schema: $tableInfo\n');

    // Get namespace info
    print('=== Namespace Info ===');
    response = await db.queryQL('INFO FOR NS;');
    var nsInfo = response.firstOrNull;
    print('Namespace info: $nsInfo');

  } finally {
    await db.close();
  }
}
```

### Complete Working Example

Here's a comprehensive example that demonstrates all the concepts covered in this section:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Initialize database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'example',
    database: 'demo',
  );

  try {
    print('=== SurrealDartBBasic QL Functions Demo ===\n');

    // 1. Create records
    print('1. Creating records...');
    final user1 = await db.createQL('user', {
      'username': 'alice',
      'email': 'alice@example.com',
      'age': 28,
      'active': true,
    });
    final user2 = await db.createQL('user', {
      'username': 'bob',
      'email': 'bob@example.com',
      'age': 32,
      'active': true,
    });
    print('   Created ${user1['username']} and ${user2['username']}\n');

    // 2. Read all records
    print('2. Reading all users...');
    var allUsers = await db.selectQL('user');
    print('   Found ${allUsers.length} users\n');

    // 3. Get specific record
    print('3. Getting specific user...');
    final userId = user1['id'] as String;
    final user = await db.get<Map<String, dynamic>>(userId);
    print('   Retrieved: ${user!['username']}\n');

    // 4. Raw query with WHERE
    print('4. Query users with age > 30...');
    await db.set('min_age', 30);
    var response = await db.queryQL(
      'SELECT * FROM user WHERE age > \$min_age'
    );
    var olderUsers = response.getResults();
    print('   Found ${olderUsers.length} users over 30\n');

    // 5. Update record
    print('5. Updating user...');
    final updated = await db.updateQL(userId, {
      'age': 29,
      'verified': true,
    });
    print('   Updated ${updated['username']}: age=${updated['age']}\n');

    // 6. Batch insert
    print('6. Batch inserting products...');
    await db.queryQL('''
      INSERT INTO product [
        { name: 'Laptop', price: 999.99 },
        { name: 'Mouse', price: 29.99 },
        { name: 'Keyboard', price: 79.99 }
      ];
    ''');
    final products = await db.selectQL('product');
    print('   Inserted ${products.length} products\n');

    // 7. Complex query
    print('7. Aggregating product data...');
    response = await db.queryQL('''
      SELECT
        count() as total,
        math::sum(price) as total_value,
        math::avg(price) as avg_price
      FROM product
    ''');
    final stats = response.firstOrNull;
    print('   Total products: ${stats!['total']}');
    print('   Total value: \$${stats['total_value']}');
    print('   Average price: \$${stats['avg_price']}\n');

    // 8. Delete record
    print('8. Deleting a user...');
    await db.deleteQL(userId);
    allUsers = await db.selectQL('user');
    print('   Remaining users: ${allUsers.length}\n');

    // 9. Info query
    print('9. Getting database info...');
    response = await db.queryQL('INFO FOR DB;');
    print('   Database schema retrieved\n');

    print('=== Demo Complete ===');

  } on QueryException catch (e) {
    print('Query error: ${e.message}');
  } on DatabaseException catch (e) {
    print('Database error: ${e.message}');
  } finally {
    await db.close();
    print('\nDatabase connection closed.');
  }
}
```

---

## Next Steps

Now that you understand the basics of database initialization and QL functions, you can:

1. **Section 3: Table Structures & Schema Definition** - Learn how to define schemas, validate data, and manage migrations
2. **Section 4: Type-Safe Data with Code Generator** - Explore the ORM features and code generation for type-safe operations
3. **Section 5: Vector Operations & Similarity Search** - Implement semantic search and work with vector embeddings

For questions or issues, please refer to:
- [SurrealDB Documentation](https://surrealdb.com/docs)
- [SurrealDartBGitHub Repository](https://github.com/yourusername/surrealdartb)

---

## Navigation

[← Previous: Getting Started](01-getting-started.md) | [Back to Index](README.md) | [Next: Schema Definition →](03-schema-definition.md)

