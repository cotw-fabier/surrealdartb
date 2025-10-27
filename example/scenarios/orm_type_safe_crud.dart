/// Demonstrates the complete Type-Safe ORM Layer.
///
/// This scenario shows how to:
/// - Define models with ORM annotations
/// - Generate code with build_runner
/// - Use type-safe CRUD operations
/// - Build complex queries with where clauses
/// - Use logical operators (AND, OR)
/// - Work with relationships and filtered includes
/// - Leverage compile-time type safety
library;

import 'package:surrealdartb/surrealdartb.dart';

/// Runs the Type-Safe ORM scenario.
///
/// **IMPORTANT NOTE**: This scenario demonstrates the ORM API conceptually.
/// To actually use these features in your code, you need to:
/// 1. Define your models with @SurrealTable annotations (see models/ directory)
/// 2. Run `dart run build_runner build` to generate ORM code
/// 3. Use the generated extensions and query builders
///
/// For now, this scenario uses the QL suffix methods to demonstrate
/// the same operations you would perform with the ORM layer.
///
/// Throws [DatabaseException] if any operation fails.
Future<void> runOrmTypeSafeCrudScenario() async {
  print('\n=== Scenario 6: Type-Safe ORM Layer ===\n');

  Database? db;

  try {
    // ===================================================================
    // SECTION A: Understanding the ORM Approach
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION A: ORM vs. Traditional Approach                  ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Traditional Approach (QL suffix methods):');
    print('  final user = await db.createQL(\'users\', {');
    print('    \'name\': \'John\',');
    print('    \'age\': 30,');
    print('  });');
    print('');
    print('ORM Approach (Type-Safe):');
    print('  final user = User(name: \'John\', age: 30);');
    print('  final created = await db.create(user);');
    print('');
    print('✓ Benefits: Compile-time safety, IDE autocomplete, validation\n');

    // ===================================================================
    // SECTION B: Model Definition with Annotations
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION B: Define Models with Annotations                ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Step 1: Define your model class with annotations:');
    print('');
    print('  @SurrealTable(\'users\')');
    print('  class User {');
    print('    @SurrealId()');
    print('    String? id;');
    print('');
    print('    @SurrealField(type: StringType())');
    print('    final String name;');
    print('');
    print('    @SurrealField(');
    print('      type: NumberType(format: NumberFormat.integer),');
    print('      assertClause: r\'\$value >= 18\',');
    print('    )');
    print('    final int age;');
    print('');
    print('    @SurrealField(type: StringType(), indexed: true)');
    print('    final String email;');
    print('');
    print('    // Relationships');
    print('    @SurrealRecord()');
    print('    Profile? profile;  // One-to-one');
    print('');
    print('    @SurrealRecord()');
    print('    List<Post>? posts;  // One-to-many');
    print('  }');
    print('');
    print('✓ Models defined with full type safety and constraints\n');

    // ===================================================================
    // SECTION C: Code Generation
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION C: Generate ORM Code                             ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('Step 2: Run build_runner to generate ORM code:');
    print('');
    print('  \$ dart run build_runner build');
    print('');
    print('This generates user.surreal.dart with:');
    print('  • UserORM extension (toSurrealMap, fromSurrealMap, validate)');
    print('  • UserQueryBuilder for type-safe queries');
    print('  • UserWhereBuilder for complex where clauses');
    print('  • Static helpers for table and schema access');
    print('');
    print('✓ Code generation complete - ready to use!\n');

    // ===================================================================
    // SECTION D: Type-Safe CRUD Operations
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION D: Type-Safe CRUD Operations                     ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // Connect to database
    print('Connecting to database...');
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
    print('✓ Connected\n');

    // Demonstrate CRUD with QL methods (same operations you'd do with ORM)
    print('CREATE Operation:');
    print('  ORM: final created = await db.create(user);');
    print('');
    final user = await db.createQL('users', {
      'name': 'Alice Johnson',
      'age': 28,
      'email': 'alice@example.com',
      'status': 'active',
    });
    print('✓ Created user:');
    print('  ID: ${user['id']}');
    print('  Name: ${user['name']}');
    print('  Age: ${user['age']}');
    print('  Email: ${user['email']}\n');

    final userId = user['id'] as String;

    print('UPDATE Operation:');
    print('  ORM: user.age = 29; await db.update(user);');
    print('');
    final updated = await db.updateQL(userId, {
      'age': 29,
    });
    print('✓ Updated user age: ${updated['age']}\n');

    print('DELETE Operation:');
    print('  ORM: await db.delete(user);');
    print('');
    // We'll delete later to keep using the record

    // ===================================================================
    // SECTION E: Advanced Query Builder
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION E: Advanced Query Builder                        ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // Create more sample data
    await db.createQL('users', {
      'name': 'Bob Smith',
      'age': 35,
      'email': 'bob@example.com',
      'status': 'active',
    });
    await db.createQL('users', {
      'name': 'Charlie Brown',
      'age': 42,
      'email': 'charlie@example.com',
      'status': 'suspended',
    });
    await db.createQL('users', {
      'name': 'Diana Prince',
      'age': 25,
      'email': 'diana@example.com',
      'status': 'active',
    });

    print('Simple Query:');
    print('  ORM: db.query<User>()');
    print('        .where((t) => t.age.greaterThan(18))');
    print('        .orderBy(\'name\')');
    print('        .execute()');
    print('');
    final simpleQuery = await db.queryQL('SELECT * FROM users WHERE age > 18 ORDER BY name');
    final simpleResults = simpleQuery.getResults();
    print('✓ Found ${simpleResults.length} users over 18:');
    for (final u in simpleResults) {
      print('  - ${u['name']} (${u['age']} years old)');
    }
    print('');

    print('Complex Query with AND operator:');
    print('  ORM: db.query<User>()');
    print('        .where((t) =>');
    print('          t.age.between(25, 40) & t.status.equals(\'active\')');
    print('        )');
    print('        .execute()');
    print('');
    final andQuery = await db.queryQL(
      'SELECT * FROM users WHERE age >= 25 AND age <= 40 AND status = \'active\'',
    );
    final andResults = andQuery.getResults();
    print('✓ Found ${andResults.length} active users aged 25-40:');
    for (final u in andResults) {
      print('  - ${u['name']} (${u['age']} years, ${u['status']})');
    }
    print('');

    print('Complex Query with OR operator:');
    print('  ORM: db.query<User>()');
    print('        .where((t) =>');
    print('          (t.age.lessThan(30) | t.age.greaterThan(40)) &');
    print('          t.status.equals(\'active\')');
    print('        )');
    print('        .execute()');
    print('');
    final orQuery = await db.queryQL(
      'SELECT * FROM users WHERE (age < 30 OR age > 40) AND status = \'active\'',
    );
    final orResults = orQuery.getResults();
    print('✓ Found ${orResults.length} active users under 30 or over 40:');
    for (final u in orResults) {
      print('  - ${u['name']} (${u['age']} years, ${u['status']})');
    }
    print('');

    // ===================================================================
    // SECTION F: Relationships & Filtered Includes
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION F: Relationships & Filtered Includes             ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    // Create some posts
    print('Creating sample posts...');
    await db.createQL('posts', {
      'title': 'Getting Started with SurrealDB',
      'content': 'This is a great database!',
      'status': 'published',
      'createdAt': DateTime.now().toIso8601String(),
      'author': userId,
    });
    await db.createQL('posts', {
      'title': 'Draft Post',
      'content': 'Work in progress',
      'status': 'draft',
      'createdAt': DateTime.now().toIso8601String(),
      'author': userId,
    });
    print('✓ Created 2 posts\n');

    print('Basic Include (Fetch author with post):');
    print('  ORM: db.query<Post>()');
    print('        .include(\'author\')');
    print('        .execute()');
    print('');
    final basicInclude = await db.queryQL('SELECT *, author.* FROM posts FETCH author');
    final includedPosts = basicInclude.getResults();
    print('✓ Found ${includedPosts.length} posts with authors:');
    for (final p in includedPosts) {
      final author = p['author'] is Map ? p['author'] as Map : null;
      print('  - "${p['title']}" by ${author?['name'] ?? 'Unknown'}');
    }
    print('');

    print('Filtered Include (Only published posts):');
    print('  ORM: db.query<User>()');
    print('        .include(\'posts\',');
    print('          where: (p) => p.status.equals(\'published\'),');
    print('          orderBy: \'createdAt\',');
    print('          descending: true');
    print('        )');
    print('        .execute()');
    print('');
    print('Generated SurrealQL (uses correlated subquery):');
    print('  SELECT *,');
    print('    (SELECT * FROM posts');
    print('     WHERE author = \$parent.id AND status = \'published\'');
    print('     ORDER BY createdAt DESC) AS posts');
    print('  FROM users WHERE name = \'Alice Johnson\'');
    print('');
    final filteredInclude = await db.queryQL(
      'SELECT *, '
      '(SELECT * FROM posts WHERE author = \$parent.id AND status = \'published\' '
      'ORDER BY createdAt DESC LIMIT 5) AS posts '
      'FROM users WHERE name = \'Alice Johnson\'',
    );
    final usersWithPosts = filteredInclude.getResults();
    print('✓ Users with published posts:');
    for (final u in usersWithPosts) {
      final posts = u['posts'];
      final postCount = posts is List ? posts.length : 0;
      print('  - ${u['name']}: $postCount published post(s) included');
    }
    print('');

    print('Nested Includes:');
    print('  ORM: db.query<User>()');
    print('        .include(\'posts\',');
    print('          include: [\'comments\', \'tags\'],');
    print('          where: (p) => p.status.equals(\'published\')');
    print('        )');
    print('        .execute()');
    print('');
    print('✓ Would fetch users → published posts → comments & tags\n');

    // ===================================================================
    // SECTION G: Summary
    // ===================================================================
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ SECTION G: Summary & Next Steps                          ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');

    print('What you learned:');
    print('  ✓ How to define models with ORM annotations');
    print('  ✓ How to generate ORM code with build_runner');
    print('  ✓ Type-safe CRUD operations (create, update, delete)');
    print('  ✓ Advanced query builder with where clauses');
    print('  ✓ Logical operators (AND, OR) for complex queries');
    print('  ✓ Relationships with filtered includes');
    print('  ✓ Nested includes with independent filtering');
    print('');
    print('Key Benefits:');
    print('  • Compile-time type safety - catch errors before runtime');
    print('  • IDE autocomplete - discover available fields and methods');
    print('  • Automatic validation - enforce constraints at Dart level');
    print('  • Clean code - less boilerplate, more readable');
    print('  • Backward compatible - QL methods still available');
    print('');
    print('To use in your project:');
    print('  1. Add annotations to your model classes');
    print('  2. Run: dart run build_runner build');
    print('  3. Use generated extensions and query builders');
    print('  4. Enjoy type-safe database operations!');
    print('');
    print('See models/ directory for complete examples.\n');

  } finally {
    if (db != null) {
      await db.close();
      print('✓ Database connection closed\n');
    }
  }
}
