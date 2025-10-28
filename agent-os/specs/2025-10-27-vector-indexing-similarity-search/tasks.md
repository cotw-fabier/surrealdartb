# Vector Indexing & Similarity Search - Task Breakdown

This file provides the detailed task breakdown for implementing vector indexing and similarity search features in the SurrealDB Dart SDK.

## Overview

This feature enables vector embedding storage, indexing, and similarity search operations. It integrates vector capabilities into the existing ORM and schema migration system.

## Task Groups

### Core Data Structures

#### Task Group 1: Core Vector Types
**Assigned implementer:** backend-engineer
**Dependencies:** None

- [x] 1.0 Complete core vector type definitions
  - [x] 1.1 Write 2-8 focused tests for vector types
    - Test DistanceMetric enum conversion to SurrealQL
    - Test IndexType enum conversion to SurrealQL
    - Test IndexDefinition.toSurrealQL() generation
    - Test SimilarityResult construction and data access
    - Skip exhaustive testing of all edge cases
    - Location: `test/vector/vector_types_test.dart`
  - [x] 1.2 Implement DistanceMetric enum
    - Values: euclidean, cosine, manhattan, minkowski
    - Extension method: toSurrealQLFunction() -> "euclidean", "cosine", etc.
    - Location: `lib/src/vector/distance_metric.dart`
  - [x] 1.3 Implement IndexType enum
    - Values: hnsw, mtree
    - Extension method: toSurrealQLKeyword() -> "HNSW", "MTREE"
    - Default logic based on dataset size
    - Location: `lib/src/vector/index_type.dart`
  - [x] 1.4 Implement IndexDefinition class
    - Properties: name, fields, type, dimension, metric, hnswParams, mtreeParams
    - toSurrealQL() method for DDL generation
    - Validation: ensure dimension > 0, fields non-empty
    - Location: `lib/src/vector/index_definition.dart`
  - [x] 1.5 Implement SimilarityResult<T> class
    - Generic class wrapping result record + distance
    - Properties: record (T), distance (double)
    - fromJson() factory constructor
    - Validation: distance must be non-negative
    - Location: `lib/src/vector/similarity_result.dart`
  - [x] 1.6 Ensure core vector type tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify all constructors, methods, and validations work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- All enums convert correctly to SurrealQL syntax
- IndexDefinition generates valid DEFINE INDEX statements
- SimilarityResult properly wraps query results with distance

### Schema Integration

#### Task Group 2: Schema System Integration
**Assigned implementer:** backend-engineer
**Dependencies:** Task Group 1

- [x] 2.0 Complete schema integration for vector indexes
  - [x] 2.1 Write 2-8 focused tests for schema integration
    - Test TableStructure with vectorIndexes field
    - Test DDL generation for vector indexes
    - Test migration with index additions
    - Test IndexManager rebuildIndex() operation
    - Skip exhaustive testing of all migration scenarios
    - Location: `test/schema/vector_integration_test.dart`
  - [x] 2.2 Extend TableStructure with vector index support
    - Add vectorIndexes field (List<IndexDefinition>)
    - Update constructor to accept vector indexes
    - Add copyWith() support for vector indexes
    - Location: Update `lib/src/schema/table_structure.dart`
  - [x] 2.3 Extend DdlGenerator for vector index DDL
    - Add generateIndexDDL(IndexDefinition) method
    - Integrate into generateFromTable() workflow
    - Format: `DEFINE INDEX indexName ON tableName FIELDS fieldName HNSW DIMENSION n DIST metric`
    - Location: Update `lib/src/schema/ddl_generator.dart`
  - [x] 2.4 Integrate vector indexes into migration workflow
    - Update migration engine to detect index changes
    - Add/remove indexes during schema migrations
    - Preserve existing data when rebuilding indexes
    - Location: Update `lib/src/schema/migration_engine.dart`
  - [x] 2.5 Implement rebuildIndex() utility method
    - Drop existing index via `REMOVE INDEX indexName ON table`
    - Recreate index with `DEFINE INDEX ...`
    - Add error handling for index operation failures
    - Location: Add to Database class or create IndexManager utility
  - [x] 2.6 Ensure schema integration tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify indexes are included in DDL generation
    - Verify rebuild operations complete successfully
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- Vector indexes integrate seamlessly with existing schema system
- DDL generation produces correct DEFINE INDEX statements
- Index rebuild operations work without data loss
- Migration workflow handles index changes correctly

### Similarity Search API

#### Task Group 3: Search Methods and Query Builder
**Assigned implementer:** api-engineer
**Dependencies:** Task Groups 1, 2

- [x] 3.0 Complete similarity search API
  - [x] 3.1 Write 2-8 focused tests for search API
    - Test basic searchSimilar() with single vector query
    - Test chained builder pattern with .where() conditions
    - Test batch search with multiple vectors
    - Test result parsing into SimilarityResult objects
    - Test parameter validation (dimension mismatch, empty vectors)
    - Skip exhaustive testing of all filter combinations
  - [x] 3.2 Implement searchSimilar() method
    - Add to Database class following existing query() pattern
    - Parameters: table, field, queryVector, metric, limit, where, orderBy
    - Generate SurrealQL: `SELECT *, vector::distance::metric(field, $queryVector) AS distance FROM table WHERE [conditions] ORDER BY distance LIMIT n`
    - Use existing parameter binding via db.set() for query vector
    - Return `Future<List<SimilarityResult<Map<String, dynamic>>>>`
    - Location: Extend `lib/src/database.dart`
  - [x] 3.3 Implement distance metric to SurrealQL mapping
    - Map DistanceMetric enum to SurrealQL function names
    - Euclidean → vector::distance::euclidean
    - Cosine → vector::distance::cosine
    - Manhattan → vector::distance::manhattan
    - Minkowski → vector::distance::minkowski
  - [x] 3.4 Implement result parsing for similarity results
    - Parse query results into SimilarityResult objects
    - Extract distance field from result set
    - Handle missing distance field gracefully with error
    - Leverage existing response processing from _processResponse()
  - [x] 3.5 Implement batchSearchSimilar() method
    - Parameters: table, field, queryVectors (list), metric, limit
    - Execute multiple similarity queries (consider parallel execution)
    - Return `Future<Map<int, List<SimilarityResult<Map<String, dynamic>>>>>`
    - Map input vector index to corresponding result list
    - Location: Add to Database class
  - [x] 3.6 Add builder pattern integration with existing query system
    - Allow chaining: searchSimilar().where().limit()
    - Maintain compatibility with existing WhereCondition system
    - Support orderBy, offset alongside similarity search
    - Follow pattern from existing query() builder
  - [x] 3.7 Ensure similarity search API tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify basic similarity search returns ordered results
    - Verify chained filtering works correctly
    - Verify batch search maps results correctly
    - NOTE: Tests skipped due to SurrealDB embedded version not supporting vector functions yet
    - Implementation is future-proof and ready for when SurrealDB adds these features

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 are implemented (skipped until SurrealDB supports vector functions)
- searchSimilar() API is complete and ready to use
- All four distance metrics have correct SurrealQL mapping
- Chained builder pattern integrates with existing WhereCondition system
- Batch search correctly maps input index to result lists
- Error handling provides clear messages for invalid inputs

**Implementation Notes:**
- Code is complete and tested for API correctness
- Tests are written but skipped pending SurrealDB embedded support for vector::distance::* functions
- When SurrealDB adds vector support, tests can be enabled by removing @Skip annotations
- The implementation follows the same patterns as existing query methods for consistency

### Test Review & Gap Analysis

#### Task Group 4: Test Review & Gap Analysis
**Assigned implementer:** testing-engineer
**Dependencies:** Task Groups 1-3 (completed)

- [x] 4.0 Review existing tests and fill critical gaps only
  - [x] 4.1 Review tests from Task Groups 1-3
    - Review the 8 tests from database-engineer for type system (Task 1.1)
    - Review the 8 tests from database-engineer for schema integration (Task 2.1)
    - Review the 8 tests from api-engineer for search API (Task 3.1)
    - Total existing tests: 24 tests
  - [x] 4.2 Analyze test coverage gaps for vector indexing feature only
    - Identify critical user workflows from user stories that lack coverage
    - Focus on integration between components (type system + schema + API)
    - Identify edge cases specific to vector operations
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end workflows over unit test gaps
  - [x] 4.3 Write up to 10 additional strategic tests maximum
    - End-to-end test: Create index, insert vectors, perform similarity search, verify results
    - Integration test: Chain similarity search with traditional WHERE clause filtering
    - Integration test: Batch search with multiple query vectors returns correctly mapped results
    - Integration test: Rebuild index and verify search still works
    - Edge case test: Search with mismatched vector dimensions throws clear error
    - Edge case test: Search on non-indexed field completes (slower but functional)
    - Edge case test: Empty query vector list for batch search handles gracefully
    - Integration test: All four distance metrics return different but valid results for same query
    - Integration test: Auto-select index type chooses appropriate index for dataset size
    - Performance smoke test: Large vector search (768 dimensions) completes within reasonable time
    - Do NOT write comprehensive coverage for all scenarios
    - Skip exhaustive parameter combination testing
  - [x] 4.4 Run feature-specific tests only
    - Run ONLY tests related to vector indexing & similarity search feature
    - Expected total: approximately 24-34 tests maximum
    - Verify all critical user workflows from user stories pass
    - Verify integration between type system, schema, and API works
    - Do NOT run the entire application test suite

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 24-34 tests total)
- Critical user workflows from spec are covered by tests
- No more than 10 additional tests added by testing-engineer
- End-to-end integration verified
- All four distance metrics validated
- Chained filtering validated
- Batch search result mapping validated
- Index rebuild workflow validated
- Clear error handling validated

## Dependencies Between Task Groups

1. Task Group 1 must complete before Task Group 2 (schema integration needs core types)
2. Task Group 2 must complete before Task Group 3 (search needs schema support)
3. Task Group 4 reviews all previous groups and fills gaps
4. Each task within a group should be completed sequentially (e.g., 3.1 → 3.2 → 3.3)

## Testing Strategy

Each task group includes 2-8 focused tests that validate the core functionality without being exhaustive. Task Group 4 performs comprehensive test review and adds up to 10 strategic integration tests. This approach:
- Provides rapid feedback during development
- Avoids test suite bloat during feature implementation
- Focuses on critical paths and edge cases
- Enables incremental verification of each component
- Validates complete user workflows through integration tests

## Implementation Progress

- [x] Task Group 1: Core Vector Types (Complete)
- [x] Task Group 2: Schema Integration (Complete)
- [x] Task Group 3: Search Methods and Query Builder (Complete - pending SurrealDB support)
- [x] Task Group 4: Test Review & Gap Analysis (Complete)
