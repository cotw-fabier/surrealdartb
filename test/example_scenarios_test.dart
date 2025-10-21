/// Tests for CLI example scenarios.
///
/// These tests verify that the example scenarios execute without crashing
/// and handle errors appropriately. They are intentionally limited in scope
/// (2-8 focused tests) as per the testing strategy.
library;

import 'package:test/test.dart';

import '../example/scenarios/connect_verify.dart';
import '../example/scenarios/crud_operations.dart';
import '../example/scenarios/storage_comparison.dart';

void main() {
  group('CLI Example Scenarios', () {
    test('connect and verify scenario executes without error', () async {
      // This test verifies the basic scenario completes successfully
      await expectLater(
        runConnectVerifyScenario(),
        completes,
        reason: 'Connect and verify scenario should complete without throwing',
      );
    });

    test('CRUD operations scenario executes without error', () async {
      // This test verifies the full CRUD lifecycle completes successfully
      await expectLater(
        runCrudScenario(),
        completes,
        reason: 'CRUD operations scenario should complete without throwing',
      );
    });

    test('storage comparison scenario executes without error', () async {
      // This test verifies both storage backends work correctly
      // Note: This may take longer due to RocksDB initialization
      await expectLater(
        runStorageComparisonScenario(),
        completes,
        reason: 'Storage comparison scenario should complete without throwing',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('connect scenario handles database lifecycle correctly', () async {
      // Verify the scenario can be run multiple times without issues
      await runConnectVerifyScenario();
      await runConnectVerifyScenario();

      // If we get here without exceptions, the test passes
      expect(true, isTrue, reason: 'Multiple runs should succeed');
    });

    test('CRUD scenario properly cleans up resources', () async {
      // Run scenario twice to ensure cleanup happened properly
      await runCrudScenario();
      await runCrudScenario();

      // If we get here without exceptions, cleanup worked
      expect(true, isTrue, reason: 'Multiple CRUD runs should succeed');
    });
  });
}
