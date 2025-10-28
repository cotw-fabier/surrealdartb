# Specification: Vector Indexing & Similarity Search

## Goal

Enable efficient similarity search on vector embeddings by adding vector index creation, management, and similarity search query capabilities to the existing SurrealDB Dart SDK. This feature builds upon the completed Vector Data Types & Storage feature to provide production-ready vector search functionality for AI/ML applications.

## User Stories

- As a developer building an AI application, I want to define vector indexes on embedding fields so that I can perform fast similarity searches
- As a developer, I want to automatically select the optimal index type based on my dataset size so that I get good performance without manual tuning
- As a developer using the ORM pattern, I want to chain similarity search with traditional WHERE clauses so that I can filter results by both vector similarity and metadata
- As a developer, I want to search for similar vectors using different distance metrics (Euclidean, Cosine, Manhattan, Minkowski) so that I can choose the metric appropriate for my use case
- As a developer, I want to perform batch similarity searches on multiple query vectors so that I can efficiently process multiple queries in one operation
- As a developer managing evolving schemas, I want to rebuild vector indexes when necessary so that my indexes stay in sync with my data

## Core Requirements

### Functional Requirements

**Index Definition and Creation:**
- Index definition structure similar to existing table/field definitions that generates DEFINE INDEX statements
- Support for all four distance metrics via DistanceMetric enum: Euclidean, Cosine, Manhattan, Minkowski
- Explicit index type selection (MTREE, HNSW) with optional auto-select based on dataset size
- Optional index configuration parameters (M, EFC, CAPACITY) with sensible defaults
- Index definitions integrate with existing schema definition patterns

**Similarity Search API:**
- Dedicated similarity search method that returns results with distance values
- Custom SimilarityResult wrapper type containing record data and distance
- Integration with existing ORM query() builder pattern for chained operations
- Chained builder pattern supporting combined filtering: `.searchSimilar().where().limit()`
- Support for orderBy, limit, offset alongside similarity search

**Batch Search Capabilities:**
- Batch similarity search API accepting multiple query vectors
- Results structured as Map<int, List<SimilarityResult>> mapping input index to results
- Efficient execution of multiple similarity queries

**Index Management:**
- Index rebuild function using drop-and-recreate approach
- Manual control over when indexes are rebuilt
- Clear error messages when index operations fail

### Non-Functional Requirements

- Maintain consistency with existing SDK architecture and coding patterns
- Follow established builder pattern conventions from query() method
- Use existing FFI infrastructure for native database calls
- Keep implementation focused on core functionality without performance metrics initially
- Ensure type safety throughout the API using Dart's type system
- Generate clear, idiomatic SurrealQL for all index and search operations

## Visual Design

No visual assets provided - this is a backend/API feature.

## Reusable Components

### Existing Code to Leverage

**VectorValue Class (lib/src/types/vector_value.dart):**
- VectorFormat enum (f32, f64, i8, i16, i32, i64) - reuse for index format detection
- Distance calculation methods: euclidean(), manhattan(), cosine() - leverage for validation
- Vector validation and dimension checking - reuse in index creation
- Serialization methods (toJson(), toBytes()) - use for query parameters

**Schema System (lib/src/schema/):**
- TableStructure and FieldDefinition patterns - model IndexDefinition similarly
- DDL generation pattern from DdlGenerator class - create similar IndexDdlGenerator
- Existing annotation pattern (@SurrealField, @SurrealTable) - follow for @VectorIndex
- Type system from surreal_types.dart - extend for index-specific types

**Query Infrastructure (lib/src/database.dart):**
- Existing query() method builder pattern - extend for similarity search
- WhereCondition chaining mechanism - integrate similarity conditions
- Parameter binding via db.set() - use for vector query parameters
- Response processing from _processResponse() - adapt for similarity results

**ORM Components (lib/src/orm/):**
- WhereBuilder and field condition classes - create VectorFieldCondition
- IncludeSpec pattern - model SimilaritySearchSpec similarly
- Where condition chaining with & and | operators - maintain compatibility

### New Components Required

**IndexDefinition Class:**
- New class to represent vector index configuration
- Cannot reuse TableStructure because indexes have different properties (distance metrics, index types, etc.)
- Needs to support index-specific parameters like M, EFC, CAPACITY

**DistanceMetric Enum:**
- New enum for Euclidean, Cosine, Manhattan, Minkowski
- Cannot reuse existing VectorValue distance methods directly as enum
- Provides type-safe distance metric selection

**IndexType Enum:**
- New enum for MTREE, HNSW, FLAT
- No existing equivalent in codebase
- Required for explicit index type control

**SimilarityResult Class:**
- New wrapper type combining record data with distance value
- No existing result wrapper includes similarity scores
- Necessary to return both the record and how similar it is

**SimilaritySearchBuilder:**
- New builder class for fluent similarity search API
- Extends query builder pattern but adds vector-specific methods
- Allows chaining with existing where() conditions

## Technical Approach

### Database Schema

**Index Definition Structure:**
- Create IndexDefinition class parallel to FieldDefinition
- Store index metadata: field name, distance metric, index type, dimensions
- Generate SurrealQL: `DEFINE INDEX idx_name ON table FIELDS field MTREE|HNSW DISTANCE metric DIMENSION n [M=val] [EFC=val] [CAPACITY=val]`

**Integration with Existing Schema:**
- Add optional List<IndexDefinition> to TableStructure
- Extend DdlGenerator to handle index DDL generation
- Include index creation in migration workflow

### API Design

**Distance Metric Enum:**
```dart
enum DistanceMetric {
  euclidean,
  cosine,
  manhattan,
  minkowski,
}
```

**Index Type Enum:**
```dart
enum IndexType {
  mtree,
  hnsw,
  flat,
  auto, // Auto-select based on dataset size
}
```

**Index Definition:**
```dart
class IndexDefinition {
  final String fieldName;
  final DistanceMetric distanceMetric;
  final IndexType indexType;
  final int dimensions;
  final int? m; // HNSW parameter
  final int? efc; // HNSW parameter
  final int? capacity; // MTREE parameter

  const IndexDefinition({
    required this.fieldName,
    required this.distanceMetric,
    this.indexType = IndexType.auto,
    required this.dimensions,
    this.m,
    this.efc,
    this.capacity,
  });
}
```

**Similarity Result:**
```dart
class SimilarityResult<T> {
  final T record;
  final double distance;

  const SimilarityResult({
    required this.record,
    required this.distance,
  });
}
```

**Similarity Search Integration:**

Add to Database class:
```dart
/// Performs similarity search on a vector field
Future<List<SimilarityResult<Map<String, dynamic>>>> searchSimilar({
  required String table,
  required String field,
  required VectorValue queryVector,
  required DistanceMetric metric,
  int limit = 10,
  WhereCondition? where,
  String? orderBy,
  bool ascending = true,
}) async {
  // Implementation generates SurrealQL like:
  // SELECT *, vector::similarity::metric(field, $queryVector) AS distance
  // FROM table
  // WHERE [conditions]
  // ORDER BY distance [ASC|DESC]
  // LIMIT n
}
```

**Batch Search:**
```dart
/// Performs batch similarity search on multiple query vectors
Future<Map<int, List<SimilarityResult<Map<String, dynamic>>>>> batchSearchSimilar({
  required String table,
  required String field,
  required List<VectorValue> queryVectors,
  required DistanceMetric metric,
  int limit = 10,
}) async {
  // Implementation executes multiple similarity queries
  // Returns map of input index to result list
}
```

**Index Management:**

Add to TableStructure or create IndexManager:
```dart
/// Rebuilds a vector index (drop and recreate)
Future<void> rebuildIndex({
  required String table,
  required String indexName,
}) async {
  // Implementation:
  // 1. DROP INDEX indexName ON table
  // 2. DEFINE INDEX indexName ON table ... (with original definition)
}
```

### Frontend Integration

Not applicable - this is a backend-only feature.

### Testing Requirements

**Unit Tests:**
- IndexDefinition serialization to SurrealQL
- DistanceMetric enum conversion to SurrealQL function names
- IndexType auto-selection logic based on dataset size
- SimilarityResult construction and data access
- Parameter validation for index configuration

**Integration Tests:**
- Create vector index on table with embedding field
- Perform similarity search with each distance metric
- Chain similarity search with WHERE conditions
- Batch similarity search with multiple vectors
- Rebuild index and verify functionality
- Index creation with custom HNSW/MTREE parameters

**Edge Case Tests:**
- Similarity search on non-indexed field (should work but be slow)
- Invalid vector dimensions (should throw validation error)
- Empty query vector list for batch search
- Extremely large limit values
- Index rebuild while queries are running

## Implementation Details

**Step 1: Define Core Types**
- Create DistanceMetric enum in lib/src/vector/distance_metric.dart
- Create IndexType enum in lib/src/vector/index_type.dart
- Create IndexDefinition class in lib/src/vector/index_definition.dart
- Create SimilarityResult class in lib/src/vector/similarity_result.dart

**Step 2: Extend Schema System**
- Add indexDefinitions field to TableStructure
- Create IndexDdlGenerator extending DDL generation pattern
- Add index DDL generation to migration workflow
- Update DdlGenerator.generateFromDiff to handle indexes

**Step 3: Implement Search Methods**
- Add searchSimilar() method to Database class
- Implement distance metric to SurrealQL function mapping
- Build SurrealQL similarity queries with proper parameter binding
- Parse results into SimilarityResult wrappers

**Step 4: Batch Search Implementation**
- Add batchSearchSimilar() method to Database class
- Execute multiple queries efficiently (potentially in parallel)
- Aggregate results into Map<int, List<SimilarityResult>>

**Step 5: Index Management**
- Add rebuildIndex() method
- Implement drop + recreate logic
- Add error handling for index operations

**Step 6: Testing and Validation**
- Write comprehensive unit tests for all new types
- Create integration tests covering all user stories
- Add edge case tests for error conditions
- Validate performance characteristics

## Out of Scope

**Performance Metrics and Monitoring:**
- Search latency tracking
- Index size reporting
- Number of distance calculations performed
- Query optimization statistics
- Deferred to future enhancement

**Automatic Index Rebuilding:**
- Real-time auto-rebuild on vector updates
- Incremental index updates
- Background index optimization
- Manual rebuild only in initial implementation

**Advanced Index Features:**
- Multiple index types per field
- Composite vector indexes
- Custom distance metric definitions
- Index partitioning or sharding

**UI Components:**
- Admin dashboard for index management
- Visual index performance monitoring
- Query result visualization
- Not applicable for backend-only feature

**Additional Distance Metrics:**
- Hamming distance
- Jaccard similarity
- Custom user-defined metrics
- Focus on four core metrics initially

## Success Criteria

**Functional Success:**
- Developers can define vector indexes using IndexDefinition class
- Similarity searches return results ordered by distance
- All four distance metrics (Euclidean, Cosine, Manhattan, Minkowski) work correctly
- Chained queries combining similarity and traditional filters execute successfully
- Batch searches process multiple vectors and return correctly mapped results
- Index rebuild operations complete without data loss

**Code Quality:**
- All new code follows existing SDK patterns and conventions
- API design is intuitive and consistent with ORM query() pattern
- Comprehensive test coverage for all new functionality
- Clear documentation for all public APIs

**Performance:**
- Similarity searches complete faster than full table scans on large datasets
- Index creation completes successfully on datasets with 10K+ vectors
- Batch searches show performance improvement over sequential searches

**Integration:**
- Vector indexes integrate seamlessly with existing schema migration workflow
- Similarity search works with existing where() and limit() query methods
- No breaking changes to existing vector storage functionality
