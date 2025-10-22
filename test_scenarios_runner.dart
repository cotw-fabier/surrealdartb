/// Simple script to run all scenarios for validation
/// This is for Task Group 2: Basic CRUD Validation
import 'example/scenarios/connect_verify.dart';
import 'example/scenarios/crud_operations.dart';
import 'example/scenarios/storage_comparison.dart';

void main() async {
  print('=' * 70);
  print('Running All Scenarios for Task Group 2 Validation');
  print('=' * 70);
  print('');

  try {
    // Scenario 1: Connect and Verify
    print('');
    print('Running Scenario 1: Connect and Verify');
    print('-' * 70);
    await runConnectVerifyScenario();
    print('✓ Scenario 1 completed successfully\n');

    // Scenario 2: CRUD Operations
    print('');
    print('Running Scenario 2: CRUD Operations');
    print('-' * 70);
    await runCrudScenario();
    print('✓ Scenario 2 completed successfully\n');

    // Scenario 3: Storage Comparison
    print('');
    print('Running Scenario 3: Storage Backend Comparison');
    print('-' * 70);
    await runStorageComparisonScenario();
    print('✓ Scenario 3 completed successfully\n');

    print('=' * 70);
    print('ALL SCENARIOS COMPLETED SUCCESSFULLY');
    print('=' * 70);
    print('');
    print('Validation Summary:');
    print('  ✓ Database connection works');
    print('  ✓ CRUD operations complete successfully');
    print('  ✓ Field values appear correctly (not null)');
    print('  ✓ Both storage backends functional');
    print('  ✓ No type wrapper artifacts in output');
    print('');
  } catch (e, stackTrace) {
    print('');
    print('=' * 70);
    print('ERROR: A scenario failed');
    print('=' * 70);
    print('Error: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
    print('');
  }
}
