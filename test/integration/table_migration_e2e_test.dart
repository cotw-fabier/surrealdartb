/// End-to-end integration tests for table definition generation and migration system.
///
/// This test suite covers critical integration gaps across all phases (1-6),
/// testing complete workflows that span multiple components:
/// - Code generation → Database connection → Auto-migration
/// - Schema evolution across database restarts
/// - Complex scenarios with vectors, nested objects, and multiple tables
/// - Migration history persistence
/// - Real-world usage patterns
///
/// These tests verify that all components work together correctly in realistic scenarios.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'dart:io';

void main() {
  group('End-to-End Table Migration Integration Tests', () {
    late Directory tempDir;

    setUp(() {
      // Create temporary directory for file-based tests
      tempDir = Directory.systemTemp.createTempSync('e2e_migration_test_');
    });

    tearDown(() {
      // Clean up temporary files
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('E2E-1: Complete workflow - table definitions to auto-migration',
        () async {
      // This test simulates the complete developer workflow:
      // 1. Define table structures (simulating generated code)
      // 2. Connect to database with auto-migration enabled
      // 3. Verify tables are created automatically
      // 4. Insert and query data
      // 5. Verify migration history is recorded

      // Arrange: Define table structures (as if generated from annotations)
      final userTable = TableStructure('users', {
        'username': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), indexed: true),
        'created_at': FieldDefinition(DatetimeType()),
        'is_active': FieldDefinition(BoolType(), defaultValue: true),
      });

      final postTable = TableStructure('posts', {
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'author_id': FieldDefinition(StringType()),
        'published': FieldDefinition(BoolType(), defaultValue: false),
        'views': FieldDefinition(
          NumberType(format: NumberFormat.integer),
          defaultValue: 0,
        ),
      });

      // Act: Connect with auto-migration
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test_e2e',
        database: 'workflow_test',
        tableDefinitions: [userTable, postTable],
        autoMigrate: true,
      );

      try {
        // Assert: Tables should be created
        final userCreated = await db.create('users', {
          'username': 'testuser',
          'email': 'test@example.com',
          'created_at': DateTime.now().toIso8601String(),
        });

        expect(userCreated['username'], equals('testuser'));
        expect(userCreated['is_active'], isTrue); // Default value

        final postCreated = await db.create('posts', {
          'title': 'First Post',
          'content': 'Hello World',
          'author_id': userCreated['id'],
        });

        expect(postCreated['published'], isFalse); // Default value
        expect(postCreated['views'], equals(0)); // Default value

        // Verify migration history
        final historyResponse = await db.query(
          'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 1',
        );
        final history = historyResponse.getResults();

        expect(history, isNotEmpty);
        final lastMigration = history.first as Map<String, dynamic>;
        expect(lastMigration['status'], equals('success'));
        expect(lastMigration['schema_snapshot'], isNotNull);
      } finally {
        await db.close();
      }
    });

    test('E2E-2: Schema evolution across database restarts', () async {
      // This test simulates schema changes across app restarts:
      // 1. Connect with initial schema
      // 2. Close connection
      // 3. Reopen with modified schema
      // 4. Verify changes are detected and applied

      final dbPath = '${tempDir.path}/evolution_test.db';

      // Phase 1: Initial schema
      final initialTables = [
        TableStructure('products', {
          'name': FieldDefinition(StringType()),
          'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),
        }),
      ];

      var db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'evolution',
        tableDefinitions: initialTables,
        autoMigrate: true,
      );

      // Create initial data
      await db.create('products', {
        'name': 'Widget',
        'price': 19.99,
      });

      await db.close();

      // Phase 2: Restart with evolved schema
      final evolvedTables = [
        TableStructure('products', {
          'name': FieldDefinition(StringType()),
          'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),
          'description': FieldDefinition(
            StringType(),
            optional: true,
          ), // New field
          'stock': FieldDefinition(
            NumberType(format: NumberFormat.integer),
            defaultValue: 0,
          ), // New field with default
        }),
      ];

      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'evolution',
        tableDefinitions: evolvedTables,
        autoMigrate: true,
      );

      try {
        // Verify existing data is preserved
        final existingProducts = await db.query('SELECT * FROM products');
        final products = existingProducts.getResults();
        expect(products, hasLength(1));
        expect(products.first['name'], equals('Widget'));

        // Verify new fields can be used
        await db.create('products', {
          'name': 'Gadget',
          'price': 29.99,
          'description': 'A useful gadget',
          'stock': 50,
        });

        // Verify migration history shows evolution
        final historyResponse = await db.query(
          'SELECT * FROM _migrations ORDER BY applied_at DESC',
        );
        final history = historyResponse.getResults();

        // Should have 2 migrations: initial and evolution
        expect(history.length, greaterThanOrEqualTo(2));
      } finally {
        await db.close();
      }
    });

    test('E2E-3: Vector fields end-to-end workflow', () async {
      // This test verifies vector type integration across all components:
      // 1. Define table with vector field
      // 2. Auto-migrate
      // 3. Insert vector data
      // 4. Query and verify

      final documentsTable = TableStructure('documents', {
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'embedding': FieldDefinition(
          VectorType.f32(384),
        ),
        'created_at': FieldDefinition(DatetimeType()),
      });

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'vectors_e2e',
        tableDefinitions: [documentsTable],
        autoMigrate: true,
      );

      try {
        // Create document with vector embedding
        final sampleEmbedding = VectorValue.f32(
          List.generate(384, (i) => i * 0.001),
        );

        final doc = await db.create('documents', {
          'title': 'Test Document',
          'content': 'This is a test document for vector search.',
          'embedding': sampleEmbedding.data,
          'created_at': DateTime.now().toIso8601String(),
        });

        expect(doc['title'], equals('Test Document'));
        expect(doc['embedding'], isNotNull);
        expect(doc['embedding'], hasLength(384));

        // Verify vector field exists in schema
        final schemaInfo = await db.query('INFO FOR TABLE documents');
        final tableInfo = schemaInfo.getResults().first as Map<String, dynamic>;
        expect(tableInfo['fields'], contains('embedding'));
      } finally {
        await db.close();
      }
    });

    test('E2E-4: Nested object schema changes end-to-end', () async {
      // This test verifies nested object handling:
      // 1. Define table with nested objects
      // 2. Migrate
      // 3. Insert nested data
      // 4. Evolve nested schema
      // 5. Migrate again

      // Initial schema with nested object
      final profileTable = TableStructure('user_profiles', {
        'username': FieldDefinition(StringType()),
        'settings': FieldDefinition(
          ObjectType(schema: {
            'theme': FieldDefinition(StringType(), defaultValue: 'light'),
            'notifications': FieldDefinition(BoolType(), defaultValue: true),
          }),
        ),
      });

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'nested_e2e',
        tableDefinitions: [profileTable],
        autoMigrate: true,
      );

      try {
        // Insert data with nested object
        final profile = await db.create('user_profiles', {
          'username': 'alice',
          'settings': {
            'theme': 'dark',
            'notifications': false,
          },
        });

        expect(profile['settings']['theme'], equals('dark'));
        expect(profile['settings']['notifications'], isFalse);

        // Now evolve schema to add nested field
        final evolvedProfileTable = TableStructure('user_profiles', {
          'username': FieldDefinition(StringType()),
          'settings': FieldDefinition(
            ObjectType(schema: {
              'theme': FieldDefinition(StringType(), defaultValue: 'light'),
              'notifications': FieldDefinition(BoolType(), defaultValue: true),
              'language': FieldDefinition(
                StringType(),
                defaultValue: 'en',
              ), // New nested field
            }),
          ),
        });

        // Apply migration
        final engine = MigrationEngine();
        final report = await engine.executeMigration(
          db,
          [evolvedProfileTable],
          allowDestructiveMigrations: false,
        );

        expect(report.success, isTrue);

        // Create new profile with evolved schema
        final newProfile = await db.create('user_profiles', {
          'username': 'bob',
          'settings': {
            'theme': 'light',
            'notifications': true,
            'language': 'fr',
          },
        });

        expect(newProfile['settings']['language'], equals('fr'));
      } finally {
        await db.close();
      }
    });

    test('E2E-5: Complex multi-table scenario with relationships', () async {
      // This test simulates a realistic multi-table application:
      // - Users with profiles and settings
      // - Posts with vector embeddings
      // - Comments linking to posts and users
      // - Tags with many-to-many relationships

      final usersTable = TableStructure('users', {
        'username': FieldDefinition(StringType()),
        'email': FieldDefinition(StringType(), indexed: true),
        'profile': FieldDefinition(
          ObjectType(schema: {
            'bio': FieldDefinition(StringType(), optional: true),
            'avatar_url': FieldDefinition(StringType(), optional: true),
            'preferences': FieldDefinition(
              ObjectType(schema: {
                'theme': FieldDefinition(StringType(), defaultValue: 'system'),
                'email_notifications':
                    FieldDefinition(BoolType(), defaultValue: true),
              }),
            ),
          }),
        ),
        'created_at': FieldDefinition(DatetimeType()),
      });

      final postsTable = TableStructure('posts', {
        'title': FieldDefinition(StringType()),
        'content': FieldDefinition(StringType()),
        'author_id': FieldDefinition(StringType(), indexed: true),
        'embedding': FieldDefinition(VectorType.f32(128)),
        'published_at': FieldDefinition(DatetimeType(), optional: true),
        'tags': FieldDefinition(ArrayType(StringType())),
      });

      final commentsTable = TableStructure('comments', {
        'post_id': FieldDefinition(StringType(), indexed: true),
        'author_id': FieldDefinition(StringType(), indexed: true),
        'content': FieldDefinition(StringType()),
        'created_at': FieldDefinition(DatetimeType()),
        'edited': FieldDefinition(BoolType(), defaultValue: false),
      });

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'complex_e2e',
        tableDefinitions: [usersTable, postsTable, commentsTable],
        autoMigrate: true,
      );

      try {
        // Create user
        final user = await db.create('users', {
          'username': 'alice',
          'email': 'alice@example.com',
          'profile': {
            'bio': 'Software developer',
            'avatar_url': 'https://example.com/avatar.jpg',
            'preferences': {
              'theme': 'dark',
              'email_notifications': true,
            },
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        // Create post with vector embedding
        final embedding = List.generate(128, (i) => i * 0.01);
        final post = await db.create('posts', {
          'title': 'Introduction to Vectors',
          'content': 'Vectors are useful for semantic search...',
          'author_id': user['id'],
          'embedding': embedding,
          'published_at': DateTime.now().toIso8601String(),
          'tags': ['vectors', 'search', 'ai'],
        });

        // Create comment
        final comment = await db.create('comments', {
          'post_id': post['id'],
          'author_id': user['id'],
          'content': 'Great article!',
          'created_at': DateTime.now().toIso8601String(),
        });

        // Verify relationships work
        final postWithComments = await db.query('''
          SELECT *, (
            SELECT * FROM comments WHERE post_id = \$parent.id
          ) AS comments FROM posts WHERE id = '${post['id']}'
        ''');

        final result = postWithComments.getResults().first;
        expect(result['title'], equals('Introduction to Vectors'));
        expect(result['comments'], isNotEmpty);

        // Verify all tables created successfully
        final schemaResponse = await db.query('INFO FOR DB');
        final schema = schemaResponse.getResults().first as Map<String, dynamic>;
        final tables = schema['tables'] as Map<String, dynamic>;

        expect(tables, contains('users'));
        expect(tables, contains('posts'));
        expect(tables, contains('comments'));
      } finally {
        await db.close();
      }
    });

    test('E2E-6: Migration history persistence across reconnections',
        () async {
      // This test verifies migration history survives database restarts

      final dbPath = '${tempDir.path}/history_persistence_test.db';

      final initialTables = [
        TableStructure('items', {
          'name': FieldDefinition(StringType()),
        }),
      ];

      // First connection - create initial migration
      var db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'history_test',
        tableDefinitions: initialTables,
        autoMigrate: true,
      );

      await db.close();

      // Second connection - evolve schema
      final evolvedTables = [
        TableStructure('items', {
          'name': FieldDefinition(StringType()),
          'description': FieldDefinition(StringType(), optional: true),
        }),
      ];

      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'history_test',
        tableDefinitions: evolvedTables,
        autoMigrate: true,
      );

      await db.close();

      // Third connection - verify history persists
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'history_test',
        tableDefinitions: evolvedTables,
        autoMigrate: false, // Don't migrate, just connect
      );

      try {
        // Query migration history
        final historyResponse = await db.query(
          'SELECT * FROM _migrations ORDER BY applied_at ASC',
        );
        final history = historyResponse.getResults();

        // Should have at least 2 migrations from previous connections
        expect(history.length, greaterThanOrEqualTo(2));

        // Verify history entries have required fields
        for (final migration in history) {
          final m = migration as Map<String, dynamic>;
          expect(m['migration_id'], isNotNull);
          expect(m['applied_at'], isNotNull);
          expect(m['status'], equals('success'));
          expect(m['schema_snapshot'], isNotNull);
        }
      } finally {
        await db.close();
      }
    });

    test('E2E-7: Concurrent migration attempts and idempotency', () async {
      // This test verifies that:
      // 1. Running the same migration twice is idempotent
      // 2. Migration system handles no-op scenarios correctly

      final tables = [
        TableStructure('idempotent_test', {
          'field1': FieldDefinition(StringType()),
          'field2': FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'idempotency_test',
        tableDefinitions: tables,
        autoMigrate: true,
      );

      try {
        // First migration - should apply changes
        final report1 = await db.migrate();
        expect(report1.hasChanges, isFalse); // Already migrated by autoMigrate

        // Second migration with same schema - should be no-op
        final report2 = await db.migrate();
        expect(report2.hasChanges, isFalse);
        expect(report2.tablesAdded, isEmpty);
        expect(report2.fieldsAdded, isEmpty);
        expect(report2.generatedDDL, isEmpty);

        // Verify table still works correctly
        final record = await db.create('idempotent_test', {
          'field1': 'test',
          'field2': 42,
        });

        expect(record['field1'], equals('test'));
        expect(record['field2'], equals(42));
      } finally {
        await db.close();
      }
    });

    test('E2E-8: Large schema migration stress test', () async {
      // This test verifies system handles large schemas:
      // - 10 tables
      // - 50+ total fields
      // - Various field types
      // - Indexes and constraints

      final tables = <TableStructure>[];

      // Generate 10 tables with various complexity
      for (var i = 1; i <= 10; i++) {
        final fields = <String, FieldDefinition>{
          'id_field': FieldDefinition(StringType()),
          'name': FieldDefinition(StringType(), indexed: true),
          'description': FieldDefinition(StringType(), optional: true),
          'count': FieldDefinition(
            NumberType(format: NumberFormat.integer),
            defaultValue: 0,
          ),
          'active': FieldDefinition(BoolType(), defaultValue: true),
          'created_at': FieldDefinition(DatetimeType()),
        };

        // Add table-specific fields
        if (i % 2 == 0) {
          // Even tables get vector fields
          fields['embedding'] = FieldDefinition(VectorType.f32(64));
        }

        if (i % 3 == 0) {
          // Every 3rd table gets nested objects
          fields['metadata'] = FieldDefinition(
            ObjectType(schema: {
              'key1': FieldDefinition(StringType()),
              'key2':
                  FieldDefinition(NumberType(format: NumberFormat.integer)),
            }),
          );
        }

        tables.add(TableStructure('table_$i', fields));
      }

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'large_schema_test',
        tableDefinitions: tables,
        autoMigrate: true,
      );

      try {
        // Verify all tables were created
        final schemaResponse = await db.query('INFO FOR DB');
        final schema = schemaResponse.getResults().first as Map<String, dynamic>;
        final dbTables = schema['tables'] as Map<String, dynamic>;

        // Should have all 10 tables plus _migrations
        expect(dbTables.keys.length, greaterThanOrEqualTo(10));

        // Test creating records in different tables
        await db.create('table_1', {
          'id_field': 'test1',
          'name': 'Table 1 Record',
          'count': 5,
          'created_at': DateTime.now().toIso8601String(),
        });

        await db.create('table_2', {
          'id_field': 'test2',
          'name': 'Table 2 Record',
          'embedding': List.generate(64, (i) => i * 0.01),
          'created_at': DateTime.now().toIso8601String(),
        });

        await db.create('table_3', {
          'id_field': 'test3',
          'name': 'Table 3 Record',
          'metadata': {
            'key1': 'value1',
            'key2': 42,
          },
          'created_at': DateTime.now().toIso8601String(),
        });

        // Verify migration completed successfully
        final historyResponse = await db.query(
          'SELECT * FROM _migrations ORDER BY applied_at DESC LIMIT 1',
        );
        final history = historyResponse.getResults();
        expect(history, isNotEmpty);
        expect(history.first['status'], equals('success'));
      } finally {
        await db.close();
      }
    });

    test('E2E-9: Real-world annotation patterns', () async {
      // This test simulates common real-world patterns developers will use:
      // - User authentication with hashed passwords
      // - Timestamped entities
      // - Soft deletes
      // - Audit trails

      final usersTable = TableStructure('users', {
        'email': FieldDefinition(
          StringType(),
          indexed: true,
          assertClause: r'string::is::email($value)',
        ),
        'password_hash': FieldDefinition(StringType()),
        'email_verified': FieldDefinition(BoolType(), defaultValue: false),
        'created_at': FieldDefinition(DatetimeType()),
        'updated_at': FieldDefinition(DatetimeType()),
        'deleted_at': FieldDefinition(
          DatetimeType(),
          optional: true,
        ), // Soft delete
      });

      final auditLogTable = TableStructure('audit_logs', {
        'entity_type': FieldDefinition(StringType(), indexed: true),
        'entity_id': FieldDefinition(StringType(), indexed: true),
        'action': FieldDefinition(
          StringType(),
          assertClause: r"$value IN ['create', 'update', 'delete']",
        ),
        'user_id': FieldDefinition(StringType(), indexed: true),
        'changes': FieldDefinition(ObjectType()),
        'timestamp': FieldDefinition(DatetimeType()),
      });

      final sessionsTable = TableStructure('sessions', {
        'user_id': FieldDefinition(StringType(), indexed: true),
        'token': FieldDefinition(StringType(), indexed: true),
        'expires_at': FieldDefinition(DatetimeType()),
        'created_at': FieldDefinition(DatetimeType()),
        'last_activity': FieldDefinition(DatetimeType()),
        'ip_address': FieldDefinition(StringType(), optional: true),
        'user_agent': FieldDefinition(StringType(), optional: true),
      });

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'realworld_test',
        tableDefinitions: [usersTable, auditLogTable, sessionsTable],
        autoMigrate: true,
      );

      try {
        final now = DateTime.now();

        // Create user
        final user = await db.create('users', {
          'email': 'user@example.com',
          'password_hash': 'hashed_password_here',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });

        expect(user['email_verified'], isFalse);
        expect(user['deleted_at'], isNull);

        // Create session
        await db.create('sessions', {
          'user_id': user['id'],
          'token': 'session_token_123',
          'expires_at': now.add(Duration(hours: 24)).toIso8601String(),
          'created_at': now.toIso8601String(),
          'last_activity': now.toIso8601String(),
          'ip_address': '192.168.1.1',
        });

        // Create audit log
        await db.create('audit_logs', {
          'entity_type': 'user',
          'entity_id': user['id'],
          'action': 'create',
          'user_id': user['id'],
          'changes': {
            'email': 'user@example.com',
            'created': true,
          },
          'timestamp': now.toIso8601String(),
        });

        // Verify all patterns work
        final sessionQuery =
            await db.query("SELECT * FROM sessions WHERE user_id = '${user['id']}'");
        expect(sessionQuery.getResults(), hasLength(1));

        final auditQuery =
            await db.query("SELECT * FROM audit_logs WHERE action = 'create'");
        expect(auditQuery.getResults(), hasLength(1));
      } finally {
        await db.close();
      }
    });

    test('E2E-10: Cross-phase integration verification', () async {
      // This test ensures all phases work together:
      // Phase 1-2: Type mapping (basic + advanced)
      // Phase 3: Schema detection
      // Phase 4: Migration execution
      // Phase 5: Safety features
      // Phase 6: Database integration

      // Start with simple schema
      final initialTables = [
        TableStructure('integration_test', {
          'simple_string': FieldDefinition(StringType()),
          'simple_int':
              FieldDefinition(NumberType(format: NumberFormat.integer)),
        }),
      ];

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'cross_phase_test',
        tableDefinitions: initialTables,
        autoMigrate: true,
      );

      try {
        // Verify Phase 1-2: Basic types work
        await db.create('integration_test', {
          'simple_string': 'test',
          'simple_int': 42,
        });

        // Evolve to add advanced types
        final evolvedTables = [
          TableStructure('integration_test', {
            'simple_string': FieldDefinition(StringType()),
            'simple_int':
                FieldDefinition(NumberType(format: NumberFormat.integer)),
            // Add collection type
            'tags': FieldDefinition(ArrayType(StringType())),
            // Add nested object
            'metadata': FieldDefinition(
              ObjectType(schema: {
                'key': FieldDefinition(StringType()),
                'value':
                    FieldDefinition(NumberType(format: NumberFormat.integer)),
              }),
            ),
            // Add vector
            'embedding': FieldDefinition(VectorType.f32(32)),
          }),
        ];

        // Phase 3: Schema detection should find differences
        final engine = MigrationEngine();
        final dryRunReport = await engine.executeMigration(
          db,
          evolvedTables,
          dryRun: true,
        );

        expect(dryRunReport.hasChanges, isTrue);
        expect(dryRunReport.fieldsAdded['integration_test'],
            containsAll(['tags', 'metadata', 'embedding']));

        // Phase 4: Execute migration
        final migrationReport = await engine.executeMigration(
          db,
          evolvedTables,
          dryRun: false,
        );

        expect(migrationReport.success, isTrue);

        // Verify advanced types work
        await db.create('integration_test', {
          'simple_string': 'advanced',
          'simple_int': 100,
          'tags': ['tag1', 'tag2'],
          'metadata': {'key': 'test', 'value': 42},
          'embedding': List.generate(32, (i) => i * 0.1),
        });

        // Phase 5: Test safety features - try destructive change
        final destructiveTables = [
          TableStructure('integration_test', {
            'simple_string': FieldDefinition(StringType()),
            // Removing fields - destructive
          }),
        ];

        expect(
          () => engine.executeMigration(
            db,
            destructiveTables,
            allowDestructiveMigrations: false,
          ),
          throwsA(isA<MigrationException>().having(
            (e) => e.isDestructive,
            'isDestructive',
            isTrue,
          )),
        );

        // Phase 6: Database integration - rollback
        final rollbackReport = await db.rollbackMigration();
        expect(rollbackReport.success, isTrue);

        // Verify rollback worked - advanced fields should be gone
        final schemaAfterRollback = await DatabaseSchema.introspect(db);
        final table = schemaAfterRollback.getTable('integration_test');
        expect(table!.hasField('tags'), isFalse);
        expect(table.hasField('metadata'), isFalse);
        expect(table.hasField('embedding'), isFalse);
      } finally {
        await db.close();
      }
    });
  });
}
