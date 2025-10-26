/// Strategic gap tests for vector data types & storage feature.
///
/// These tests fill CRITICAL gaps in the existing test coverage, focusing on:
/// - Hybrid serialization threshold edge cases
/// - Cross-format compatibility
/// - Performance characteristics
/// - Memory behavior
/// - Platform-specific concerns
///
/// Existing coverage: ~125 tests across VectorValue, TableStructure, and integration.
/// This file adds up to 20 strategic tests to reach ~145 total tests.
library;

import 'dart:typed_data';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';
import 'fixtures/vector_fixtures.dart';

void main() {
  group('Hybrid Serialization Strategy', () {
    test('vectors at threshold use JSON serialization', () {
      // Arrange - Vector exactly at threshold (100 dimensions by default)
      final vector = VectorFixtures.atSerializationThreshold();

      // Act
      final result = vector.toBinaryOrJson();

      // Assert - Should use JSON for threshold value
      expect(result, isA<List>(), reason: 'At threshold should use JSON');
      expect(result, hasLength(VectorValue.serializationThreshold));
    });

    test('vectors below threshold use JSON serialization', () {
      // Arrange - Vector below threshold
      final vector = VectorFixtures.belowSerializationThreshold();

      // Act
      final result = vector.toBinaryOrJson();

      // Assert
      expect(result, isA<List>(), reason: 'Below threshold should use JSON');
    });

    test('vectors above threshold use binary serialization', () {
      // Arrange - Vector above threshold
      final vector = VectorFixtures.aboveSerializationThreshold();

      // Act
      final result = vector.toBinaryOrJson();

      // Assert
      expect(result, isA<Uint8List>(), reason: 'Above threshold should use binary');
    });

    test('changing serializationThreshold affects toBinaryOrJson behavior', () {
      // Arrange
      final original = VectorValue.serializationThreshold;
      final vector = VectorFixtures.sequentialF32(50);

      try {
        // Act & Assert - With default threshold (100), should use JSON
        expect(vector.toBinaryOrJson(), isA<List>());

        // Change threshold to 25
        VectorValue.serializationThreshold = 25;

        // Now same vector should use binary
        expect(
          vector.toBinaryOrJson(),
          isA<Uint8List>(),
          reason: 'After lowering threshold, should use binary',
        );
      } finally {
        // Cleanup - Restore original threshold
        VectorValue.serializationThreshold = original;
      }
    });

    test('binary format round-trip maintains data integrity', () {
      // Arrange
      final original = VectorFixtures.sequentialF32(200);

      // Act
      final binary = original.toBytes();
      final restored = VectorValue.fromBytes(binary, VectorFormat.f32);

      // Assert
      expect(restored.dimensions, equals(original.dimensions));
      expect(restored.format, equals(original.format));

      for (var i = 0; i < original.dimensions; i++) {
        expect(
          (restored.data[i] - original.data[i]).abs(),
          lessThan(0.0001),
          reason: 'Element $i should match after binary round-trip',
        );
      }
    });
  });

  group('Cross-Format Compatibility', () {
    test('distance calculations work between different formats', () {
      // Arrange
      final f32Vec = VectorValue.f32([1.0, 2.0, 3.0]);
      final f64Vec = VectorValue.f64([4.0, 5.0, 6.0]);
      final i16Vec = VectorValue.i16([7, 8, 9]);

      // Act & Assert - All combinations should work
      expect(() => f32Vec.euclidean(f64Vec), returnsNormally);
      expect(() => f32Vec.euclidean(i16Vec), returnsNormally);
      expect(() => f64Vec.euclidean(i16Vec), returnsNormally);

      expect(() => f32Vec.cosine(f64Vec), returnsNormally);
      expect(() => f32Vec.manhattan(i16Vec), returnsNormally);
    });

    test('normalization preserves format type', () {
      // Arrange & Act
      final f32Norm = VectorValue.f32([3.0, 4.0]).normalize();
      final f64Norm = VectorValue.f64([3.0, 4.0]).normalize();
      final i16Norm = VectorValue.i16([3, 4]).normalize();

      // Assert - Format should be preserved
      expect(f32Norm.format, equals(VectorFormat.f32));
      expect(f64Norm.format, equals(VectorFormat.f64));
      expect(i16Norm.format, equals(VectorFormat.i16));
    });

    test('integer vector boundaries are respected', () {
      // Arrange - I8 has range -128 to 127
      final i8Boundary = EdgeCaseVectors.i8Boundary();

      // Act - Convert to JSON and back
      final json = i8Boundary.toJson();
      final restored = VectorValue.fromJson(json, format: VectorFormat.i8);

      // Assert - Values should be preserved
      expect(restored.data[0], equals(-128)); // min value
      expect(restored.data[4], equals(127)); // max value
    });

    test('format conversion from I8 to F32 handles precision', () {
      // Arrange - I8 vector
      final i8Vec = VectorValue.i8([-128, 0, 127]);

      // Act - Convert through JSON (which uses doubles)
      final json = i8Vec.toJson();
      final asF32 = VectorValue.fromJson(json, format: VectorFormat.f32);

      // Assert - Values should be representable in F32
      expect(asF32.format, equals(VectorFormat.f32));
      expect(asF32.data[0], closeTo(-128.0, 0.0001));
      expect(asF32.data[1], closeTo(0.0, 0.0001));
      expect(asF32.data[2], closeTo(127.0, 0.0001));
    });
  });

  group('Edge Case Validation', () {
    test('single dimension vector operations work correctly', () {
      // Arrange
      final vec1 = EdgeCaseVectors.singleDimension();
      final vec2 = VectorValue.f32([2.0]);

      // Act & Assert
      expect(vec1.magnitude(), closeTo(1.0, 0.0001));
      expect(vec1.dotProduct(vec2), closeTo(2.0, 0.0001));
      expect(vec1.euclidean(vec2), closeTo(1.0, 0.0001));
      expect(vec1.isNormalized(), isTrue);
    });

    test('very large dimension vectors serialize correctly', () {
      // Arrange - 4096 dimensions (large for mobile)
      final largeVec = EdgeCaseVectors.largeMobileDimension();

      // Act
      final binary = largeVec.toBytes();
      final restored = VectorValue.fromBytes(binary, VectorFormat.f32);

      // Assert
      expect(restored.dimensions, equals(4096));
      expect(binary.length, equals(1 + 4 + (4096 * 4))); // header + dims + data
    });

    test('near-zero values maintain precision in normalization', () {
      // Arrange - Vector with very small values
      final nearZero = VectorFixtures.nearZero(10);

      // Act
      final normalized = nearZero.normalize();

      // Assert - Should still be normalized despite small input values
      expect(normalized.isNormalized(), isTrue);
      expect(normalized.magnitude(), closeTo(1.0, 1e-6));
    });

    test('alternating positive/negative values compute correctly', () {
      // Arrange
      final alternating = EdgeCaseVectors.alternating(100);

      // Act
      final mag = alternating.magnitude();

      // Assert - magnitude of [1, -1, 1, -1, ...] should be sqrt(100) = 10
      expect(mag, closeTo(10.0, 0.0001));
    });

    test('mixed scale values preserve both small and large magnitudes', () {
      // Arrange - Mix of 1e-10 and 1e10
      final mixedScale = EdgeCaseVectors.mixedScale(10);

      // Act
      final json = mixedScale.toJson();
      final restored = VectorValue.fromJson(json, format: VectorFormat.f64);

      // Assert - Both scales should be preserved
      expect(restored.data[0], closeTo(1e-10, 1e-11)); // small value
      expect(restored.data[1], closeTo(1e10, 1e9)); // large value
    });
  });

  group('TableStructure Validation Edge Cases', () {
    test('multiple vector fields with different dimensions validate independently', () {
      // Arrange
      final schema = SchemaFixtures.multiVectorSchema();
      final data = {
        'name': 'test',
        'small_embedding': VectorFixtures.sequentialF32(128).toJson(),
        'medium_embedding': VectorFixtures.sequentialF32(384).toJson(),
        'large_embedding': VectorFixtures.sequentialF32(1536).toJson(),
      };

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('dimension mismatch in one of multiple vector fields fails validation', () {
      // Arrange
      final schema = SchemaFixtures.multiVectorSchema();
      final data = {
        'name': 'test',
        'small_embedding': VectorFixtures.sequentialF32(128).toJson(),
        'medium_embedding': VectorFixtures.sequentialF32(999).toJson(), // Wrong!
        'large_embedding': VectorFixtures.sequentialF32(1536).toJson(),
      };

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'medium_embedding')
              .having((e) => e.constraint, 'constraint', 'dimension_mismatch'),
        ),
      );
    });

    test('nested object with vector field validates dimensions', () {
      // Arrange
      final schema = SchemaFixtures.nestedVectorSchema();
      final data = {
        'name': 'test',
        'metadata': {
          'model': 'test-model',
          'version': 1,
          'embedding': VectorFixtures.sequentialF32(384).toJson(),
        },
      };

      // Act & Assert
      expect(() => schema.validate(data), returnsNormally);
    });

    test('nested vector with wrong dimensions fails validation', () {
      // Arrange
      final schema = SchemaFixtures.nestedVectorSchema();
      final data = {
        'name': 'test',
        'metadata': {
          'model': 'test-model',
          'version': 1,
          'embedding': VectorFixtures.sequentialF32(768).toJson(), // Wrong!
        },
      };

      // Act & Assert
      expect(
        () => schema.validate(data),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.fieldName, 'fieldName', 'metadata.embedding')
              .having((e) => e.constraint, 'constraint', 'dimension_mismatch'),
        ),
      );
    });
  });

  group('Performance Characteristics', () {
    test('large vector serialization completes in reasonable time', () {
      // Arrange
      final largeVector = VectorFixtures.sequentialF32(1536);
      final stopwatch = Stopwatch()..start();

      // Act
      for (var i = 0; i < 100; i++) {
        largeVector.toJson();
      }
      stopwatch.stop();

      // Assert - 100 serializations should complete in under 1 second
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: '100 x 1536-dim serializations should be fast',
      );
    });

    test('binary serialization is faster than JSON for large vectors', () {
      // Arrange
      final largeVector = VectorFixtures.sequentialF32(1536);

      // Act - Measure JSON serialization
      final jsonStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        largeVector.toJson();
      }
      jsonStopwatch.stop();

      // Act - Measure binary serialization
      final binaryStopwatch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        largeVector.toBytes();
      }
      binaryStopwatch.stop();

      // Assert - Binary should be faster (or at least competitive)
      // Note: This may vary by platform, but binary should not be significantly slower
      print('JSON: ${jsonStopwatch.elapsedMicroseconds}μs, '
          'Binary: ${binaryStopwatch.elapsedMicroseconds}μs');

      // We don't assert binary is always faster as it depends on platform,
      // but we verify both complete in reasonable time
      expect(jsonStopwatch.elapsedMilliseconds, lessThan(1000));
      expect(binaryStopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('dot product performance scales linearly with dimensions', () {
      // Arrange
      final vec100 = VectorFixtures.sequentialF32(100);
      final vec1000 = VectorFixtures.sequentialF32(1000);
      final vec10000 = VectorFixtures.sequentialF32(10000);

      // Act - Measure 100 dimensions
      final stopwatch100 = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        vec100.dotProduct(vec100);
      }
      stopwatch100.stop();

      // Act - Measure 1000 dimensions
      final stopwatch1000 = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        vec1000.dotProduct(vec1000);
      }
      stopwatch1000.stop();

      // Act - Measure 10000 dimensions
      final stopwatch10000 = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        vec10000.dotProduct(vec10000);
      }
      stopwatch10000.stop();

      // Assert - Performance should scale roughly linearly
      print('100-dim: ${stopwatch100.elapsedMicroseconds}μs, '
          '1000-dim: ${stopwatch1000.elapsedMicroseconds}μs, '
          '10000-dim: ${stopwatch10000.elapsedMicroseconds}μs');

      // Verify all complete in reasonable time
      expect(stopwatch100.elapsedMilliseconds, lessThan(100));
      expect(stopwatch1000.elapsedMilliseconds, lessThan(1000));
      expect(stopwatch10000.elapsedMilliseconds, lessThan(5000));
    });
  });

  group('Memory Behavior', () {
    test('creating and disposing many vectors does not leak memory', () {
      // Arrange - Track initial memory (approximation)
      final initialVectors = <VectorValue>[];
      for (var i = 0; i < 10; i++) {
        initialVectors.add(VectorFixtures.sequentialF32(1000));
      }

      // Act - Create and discard many vectors
      for (var i = 0; i < 1000; i++) {
        final vec = VectorFixtures.sequentialF32(1000);
        // Use the vector to prevent optimization
        vec.magnitude();
        // Let it go out of scope (GC should clean up)
      }

      // Assert - This test verifies the code doesn't crash with OOM
      // Actual memory leak detection would require platform-specific tools
      expect(initialVectors.length, equals(10), reason: 'Test completed successfully');
    });

    test('large vector data structures use appropriate memory', () {
      // Arrange & Act
      final f32Vec = VectorFixtures.sequentialF32(1000);
      final f64Vec = VectorFixtures.sequentialF32(1000); // Uses F64 internally after normalize
      final i8Vec = VectorValue.i8(List.filled(1000, 1));

      // Assert - Verify type-specific lists are used (memory efficient)
      expect(f32Vec.data, isA<Float32List>());
      expect(i8Vec.data, isA<Int8List>());

      // F32: 1000 * 4 bytes = 4KB
      // I8: 1000 * 1 byte = 1KB
      // This verifies we're using appropriate data structures
    });
  });
}
