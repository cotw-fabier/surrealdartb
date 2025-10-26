/// Integration tests for vector data storage and retrieval through Database API.
///
/// These tests verify that VectorValue can be stored, retrieved, and manipulated
/// through the existing CRUD operations without requiring new FFI functions.
library;

import 'dart:io';

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Vector Database Integration', () {
    late Database db;
    late Directory tempDir;

    setUp(() async {
      // Create temporary directory for test database
      tempDir = await Directory.systemTemp.createTemp('vector_test_');
      final dbPath = '${tempDir.path}/test.db';

      // Connect to database
      db = await Database.connect(
        backend: StorageBackend.rocksdb,
        path: dbPath,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Clean up
      await db.close();
      await Future.delayed(const Duration(milliseconds: 300));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('create record with vector field using VectorValue.toJson()', () async {
      // Create a vector embedding
      final embedding = VectorValue.f32([0.1, 0.2, 0.3, 0.4, 0.5]);

      // Create record with vector field
      final record = await db.create('documents', {
        'title': 'Test Document',
        'content': 'Test content',
        'embedding': embedding.toJson(),
      });

      // Verify record was created
      expect(record['title'], equals('Test Document'));
      expect(record['content'], equals('Test content'));
      expect(record['embedding'], isA<List>());
      expect(record['embedding'], hasLength(5));

      // Verify we can convert back to VectorValue
      final retrievedVector = VectorValue.fromJson(record['embedding']);
      expect(retrievedVector.dimensions, equals(5));
      expect(retrievedVector.format, equals(VectorFormat.f32));

      // Verify values are approximately equal (accounting for F32 precision)
      final expectedValues = [0.1, 0.2, 0.3, 0.4, 0.5];
      final actualValues = retrievedVector.toJson();
      for (var i = 0; i < expectedValues.length; i++) {
        expect(
          (actualValues[i] - expectedValues[i]).abs(),
          lessThan(0.0001),
          reason: 'Element $i mismatch',
        );
      }
    });

    test('retrieve vector from database and convert with VectorValue.fromJson()', () async {
      // Create a record with a vector
      final originalVector = VectorValue.fromList([1.0, 2.0, 3.0, 4.0]);
      final created = await db.create('embeddings', {
        'name': 'test_vector',
        'data': originalVector.toJson(),
      });

      final recordId = created['id'] as String;

      // Retrieve the record
      final retrieved = await db.get<Map<String, dynamic>>(recordId);

      // Verify record exists and has vector data
      expect(retrieved, isNotNull);
      expect(retrieved!['name'], equals('test_vector'));
      expect(retrieved['data'], isA<List>());

      // Convert back to VectorValue and verify
      final retrievedVector = VectorValue.fromJson(retrieved['data']);
      expect(retrievedVector.dimensions, equals(4));

      // Verify approximate equality
      final expectedValues = [1.0, 2.0, 3.0, 4.0];
      final actualValues = retrievedVector.toJson();
      for (var i = 0; i < expectedValues.length; i++) {
        expect(
          (actualValues[i] - expectedValues[i]).abs(),
          lessThan(0.0001),
          reason: 'Element $i mismatch',
        );
      }
    });

    test('update vector field in existing record', () async {
      // Create initial record
      final initialVector = VectorValue.f32([0.1, 0.2, 0.3]);
      final created = await db.create('vectors', {
        'version': 1,
        'embedding': initialVector.toJson(),
      });

      final recordId = created['id'] as String;

      // Update with new vector
      final updatedVector = VectorValue.f32([0.4, 0.5, 0.6]);
      final updated = await db.update(recordId, {
        'version': 2,
        'embedding': updatedVector.toJson(),
      });

      // Verify update
      expect(updated['version'], equals(2));
      final resultVector = VectorValue.fromJson(updated['embedding']);

      // Verify approximate equality
      final expectedValues = [0.4, 0.5, 0.6];
      final actualValues = resultVector.toJson();
      for (var i = 0; i < expectedValues.length; i++) {
        expect(
          (actualValues[i] - expectedValues[i]).abs(),
          lessThan(0.0001),
          reason: 'Element $i mismatch',
        );
      }
    });

    test('batch insert multiple records with vectors using db.query', () async {
      // Create multiple vectors
      final vec1 = VectorValue.fromList([1.0, 0.0, 0.0]);
      final vec2 = VectorValue.fromList([0.0, 1.0, 0.0]);
      final vec3 = VectorValue.fromList([0.0, 0.0, 1.0]);

      // Use query for batch insert with parameters
      await db.set('vec1', vec1.toJson());
      await db.set('vec2', vec2.toJson());
      await db.set('vec3', vec3.toJson());

      final response = await db.query('''
        INSERT INTO batch_vectors [
          { name: "x_axis", vector: \$vec1 },
          { name: "y_axis", vector: \$vec2 },
          { name: "z_axis", vector: \$vec3 }
        ]
      ''');

      final results = response.getResults();

      // SurrealDB INSERT returns the created records directly in the first result
      expect(results, isNotEmpty);

      // Verify batch insert worked by selecting all records
      final allRecords = await db.select('batch_vectors');
      expect(allRecords, hasLength(3));

      // Verify each vector
      final xAxis = allRecords.firstWhere((r) => r['name'] == 'x_axis');
      final xVector = VectorValue.fromJson(xAxis['vector']);
      expect(xVector.toJson()[0], closeTo(1.0, 0.0001));
      expect(xVector.toJson()[1], closeTo(0.0, 0.0001));
      expect(xVector.toJson()[2], closeTo(0.0, 0.0001));

      final yAxis = allRecords.firstWhere((r) => r['name'] == 'y_axis');
      final yVector = VectorValue.fromJson(yAxis['vector']);
      expect(yVector.toJson()[0], closeTo(0.0, 0.0001));
      expect(yVector.toJson()[1], closeTo(1.0, 0.0001));
      expect(yVector.toJson()[2], closeTo(0.0, 0.0001));

      final zAxis = allRecords.firstWhere((r) => r['name'] == 'z_axis');
      final zVector = VectorValue.fromJson(zAxis['vector']);
      expect(zVector.toJson()[0], closeTo(0.0, 0.0001));
      expect(zVector.toJson()[1], closeTo(0.0, 0.0001));
      expect(zVector.toJson()[2], closeTo(1.0, 0.0001));
    });

    test('vector serialization round-trip through FFI', () async {
      // Test with different vector formats
      final testVectors = [
        VectorValue.f32([1.5, 2.5, 3.5]),
        VectorValue.f64([1.123456789, 2.987654321]),
        VectorValue.i16([100, 200, 300, 400]),
        VectorValue.i32([1000, 2000, 3000]),
      ];

      for (var i = 0; i < testVectors.length; i++) {
        final vector = testVectors[i];

        // Create record
        final created = await db.create('format_test', {
          'index': i,
          'format': vector.format.name,
          'data': vector.toJson(),
        });

        // Retrieve and verify
        final recordId = created['id'] as String;
        final retrieved = await db.get<Map<String, dynamic>>(recordId);

        expect(retrieved, isNotNull);
        final retrievedVector = VectorValue.fromJson(
          retrieved!['data'],
          format: vector.format,
        );

        // Verify format and dimensions match
        expect(retrievedVector.format, equals(vector.format));
        expect(retrievedVector.dimensions, equals(vector.dimensions));

        // Verify data matches (allowing for floating-point precision)
        final originalData = vector.toJson();
        final retrievedData = retrievedVector.toJson();
        expect(retrievedData.length, equals(originalData.length));

        for (var j = 0; j < originalData.length; j++) {
          expect(
            (retrievedData[j] - originalData[j]).abs(),
            lessThan(0.0001),
            reason: 'Vector element $j mismatch',
          );
        }

        // Clean up for next iteration
        await db.delete(recordId);
      }
    });

    test('store and retrieve large vector (768 dimensions)', () async {
      // Create a realistic embedding vector (common size for many models)
      final largeVector = VectorValue.fromList(
        List.generate(768, (i) => (i % 100) / 100.0),
      );

      expect(largeVector.dimensions, equals(768));

      // Store in database
      final created = await db.create('large_embeddings', {
        'model': 'test-model',
        'embedding': largeVector.toJson(),
      });

      // Retrieve and verify
      final recordId = created['id'] as String;
      final retrieved = await db.get<Map<String, dynamic>>(recordId);

      expect(retrieved, isNotNull);
      final retrievedVector = VectorValue.fromJson(retrieved!['embedding']);

      expect(retrievedVector.dimensions, equals(768));
      expect(retrievedVector.format, equals(VectorFormat.f32));

      // Verify data integrity for large vector
      final originalData = largeVector.toJson();
      final retrievedData = retrievedVector.toJson();

      expect(retrievedData.length, equals(768));
      for (var i = 0; i < 768; i++) {
        expect(
          (retrievedData[i] - originalData[i]).abs(),
          lessThan(0.0001),
          reason: 'Large vector element $i mismatch',
        );
      }
    });
  });
}
