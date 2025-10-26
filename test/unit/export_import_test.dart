/// Unit tests for export and import operations.
///
/// This test file validates the basic export/import functionality:
/// - Export creates a file
/// - Import loads from a file
/// - Round-trip export/import preserves data
/// - File I/O error handling
///
/// Limitations of initial implementation:
/// - No advanced configuration support
/// - No table selection or format options
/// - Basic functionality only
library;

import 'dart:io';
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Export and Import Operations', () {
    late Database db;
    late String testDir;

    setUp(() async {
      // Create a temporary directory for test files
      testDir = Directory.systemTemp.createTempSync('surreal_export_test_').path;

      // Create and connect to in-memory database
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();

      // Clean up test directory
      final dir = Directory(testDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('export() creates file with database content', () async {
      // Create some test data
      await db.createQL('person', {'name': 'Alice', 'age': 30});
      await db.createQL('person', {'name': 'Bob', 'age': 25});

      final exportPath = '$testDir/export.surql';

      // Export database
      await db.export(exportPath);

      // Verify file was created
      final file = File(exportPath);
      expect(await file.exists(), isTrue, reason: 'Export file should exist');

      // Verify file is not empty
      final content = await file.readAsString();
      expect(content.isNotEmpty, isTrue, reason: 'Export file should not be empty');
    });

    test('import() loads data from file', () async {
      final exportPath = '$testDir/export.surql';

      // Create and export initial data
      await db.createQL('person', {'name': 'Alice', 'age': 30});
      await db.export(exportPath);

      // Delete all records
      await db.deleteQL('person');

      // Verify deletion
      final beforeImport = await db.selectQL('person');
      expect(beforeImport.getResults(), isEmpty, reason: 'Records should be deleted');

      // Import the data back
      await db.import(exportPath);

      // Verify data was imported
      final afterImport = await db.selectQL('person');
      final records = afterImport.getResults();
      expect(records.isNotEmpty, isTrue, reason: 'Records should be imported');
    });

    test('round-trip export/import preserves data', () async {
      // Create test data with various types
      final originalPerson = await db.createQL('person', {
        'name': 'Charlie',
        'age': 35,
        'email': 'charlie@example.com',
        'active': true,
      });

      final exportPath = '$testDir/roundtrip.surql';

      // Export database
      await db.export(exportPath);

      // Delete the record
      await db.deleteQL('person');

      // Import it back
      await db.import(exportPath);

      // Verify data matches
      final imported = await db.selectQL('person');
      final records = imported.getResults();

      expect(records, hasLength(1), reason: 'Should have one record after import');

      final importedPerson = records[0][0];
      expect(importedPerson['name'], equals('Charlie'));
      expect(importedPerson['age'], equals(35));
      expect(importedPerson['email'], equals('charlie@example.com'));
      expect(importedPerson['active'], equals(true));
    });

    test('export() throws ExportException on invalid path', () async {
      // Try to export to an invalid/inaccessible path
      const invalidPath = '/invalid/path/that/does/not/exist/export.surql';

      expect(
        () => db.export(invalidPath),
        throwsA(isA<ExportException>()),
        reason: 'Should throw ExportException for invalid path',
      );
    });

    test('import() throws ImportException on non-existent file', () async {
      const nonExistentPath = '$testDir/nonexistent.surql';

      expect(
        () => db.import(nonExistentPath),
        throwsA(isA<ImportException>()),
        reason: 'Should throw ImportException for non-existent file',
      );
    });

    test('import() throws ImportException on invalid file content', () async {
      // Create a file with invalid content
      final invalidPath = '$testDir/invalid.surql';
      final file = File(invalidPath);
      await file.writeAsString('This is not valid SurrealQL');

      expect(
        () => db.import(invalidPath),
        throwsA(isA<ImportException>()),
        reason: 'Should throw ImportException for invalid file content',
      );
    });

    test('export() handles empty database', () async {
      final exportPath = '$testDir/empty.surql';

      // Export empty database
      await db.export(exportPath);

      // Verify file was created
      final file = File(exportPath);
      expect(await file.exists(), isTrue, reason: 'Export file should exist even for empty database');
    });

    test('round-trip with multiple tables', () async {
      // Create data in multiple tables
      await db.createQL('person', {'name': 'Alice'});
      await db.createQL('company', {'name': 'Acme Corp'});
      await db.createQL('product', {'name': 'Widget', 'price': 9.99});

      final exportPath = '$testDir/multitable.surql';

      // Export
      await db.export(exportPath);

      // Delete all data
      await db.deleteQL('person');
      await db.deleteQL('company');
      await db.deleteQL('product');

      // Import
      await db.import(exportPath);

      // Verify all tables restored
      final persons = await db.selectQL('person');
      expect(persons.getResults().isNotEmpty, isTrue, reason: 'Person table should have data');

      final companies = await db.selectQL('company');
      expect(companies.getResults().isNotEmpty, isTrue, reason: 'Company table should have data');

      final products = await db.selectQL('product');
      expect(products.getResults().isNotEmpty, isTrue, reason: 'Product table should have data');
    });
  });
}
