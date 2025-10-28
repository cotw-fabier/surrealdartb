# Spec Requirements: Vector Indexing & Similarity Search

## Initial Description
Vector Indexing & Similarity Search

This is a Phase 3, Priority P1 feature from the roadmap. The Vector Data Types & Storage feature is already complete, and this is the next logical step to add indexing and similarity search capabilities for vectors.

## Requirements Discussion

### First Round Questions

**Q1: Index Types and Auto-Selection Strategy**
What vector index types should we support (HNSW, M-Tree, FLAT, etc.), and should we auto-select the optimal index type based on dataset characteristics (size, dimensions, distance metric)?

**Answer:** Dataset size should drive the auto-selection logic.

**Q2: Distance Metrics**
Which distance metrics should be prioritized for similarity search - Euclidean, Cosine, Manhattan? Should we support all three or focus on specific ones?

**Answer:** Support all three distance metrics (Euclidean, Cosine, Manhattan). The VectorValue class already has implementations for all three.

**Q3: Batch Search Results Structure**
For batch similarity searches (multiple query vectors), should results be structured as:
- Option A: `List<List<SimilarityResult>>` (ordered list of result lists)
- Option B: `Map<int, List<SimilarityResult>>` (mapping input index to results)
- Option C: Custom class with metadata

**Answer:** Option B looks best - `Map<int, List<SimilarityResult>>` (mapping input index to results)

**Q4: Index Configuration Parameters**
Should index creation support:
- Manual parameter tuning (M, efConstruction for HNSW)
- Auto-tuning based on dataset analysis
- Hybrid approach with smart defaults + optional overrides

**Answer:** Hybrid approach with smart defaults + optional overrides.

**Q5: Integration with Existing ORM**
Should similarity search integrate with the existing query() builder pattern, or should it be a separate API? For example:
- `db.query('users').searchSimilar('embedding', vector).limit(10)`
- OR separate: `db.searchSimilar('users', 'embedding', vector, limit: 10)`

**Answer:** Integrate with existing ORM and query() methods. The user wants to add onto their existing ORM pattern.

**Q6: Index Rebuild/Update Behavior**
When vectors are updated or new vectors are added, should indexes:
- Auto-rebuild (performance impact)
- Manual rebuild function
- Incremental updates (if supported by index type)

**Answer:** Just do a drop and rebuild at this point (destructive approach is fine).

**Q7: Result Filtering and Combined Queries**
Should similarity search support combining with traditional filters? For example:
- Find similar products WHERE category = 'electronics' AND price < 1000
- Should this be a chained builder pattern or separate parameters?

**Answer:** Option A looks best - Chained/Builder Pattern where searchSimilar returns a builder that can chain `.where()` calls.

**Q8: Performance Metrics and Monitoring**
Should the similarity search API expose performance metrics like:
- Search latency
- Index size
- Number of distance calculations performed
- Or keep it simple initially and add monitoring later?

**Answer:** Keep it simple initially. Focus on core functionality first.

**Q9: Scope Boundaries**
Are there any specific features or edge cases we should explicitly exclude from this implementation to keep the scope manageable?

**Answer:** No specific exclusions mentioned. Focus on the core vector indexing and similarity search capabilities.

### Existing Code to Reference

**Similar Features Identified:**
- Feature: VectorValue class - Path: `lib/src/types/vector_value.dart`
  - Contains VectorFormat enum with f32, f64, i8, i16, i32, i64
  - Distance calculation methods already implemented: euclidean, manhattan, cosine
  - Vector operations: magnitude, dotProduct, normalize
  - Serialization methods for FFI transport

**Integration Points:**
- This feature will integrate with existing ORM and query() methods
- No existing examples of index definition or similarity search in the app yet (this is new functionality)

### Follow-up Questions

None required - all clarifying questions have been answered comprehensively.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
Not applicable - this is a backend/API feature without UI components.

## Requirements Summary

### Functional Requirements

**Core Functionality:**
- Vector index creation with multiple index types (HNSW, M-Tree, FLAT, etc.)
- Auto-selection of optimal index type based on dataset size
- Similarity search supporting three distance metrics:
  - Euclidean distance (already implemented in VectorValue)
  - Cosine similarity (already implemented in VectorValue)
  - Manhattan distance (already implemented in VectorValue)
- Integration with existing ORM query() builder pattern
- Chained builder pattern for combining similarity search with traditional filters

**Batch Search:**
- Support for multiple query vectors in a single operation
- Results structured as `Map<int, List<SimilarityResult>>` (input index to results mapping)

**Index Management:**
- Hybrid configuration approach: smart defaults + optional manual parameter overrides
- Manual index rebuild function (destructive drop and rebuild)
- Support for HNSW parameters (M, efConstruction) when manually tuning

**Query Integration:**
- Pattern: `db.query('table').searchSimilar('field', vector).where(...).limit(10)`
- Builder returns chainable object supporting `.where()` calls
- Maintains consistency with existing ORM patterns

### Reusability Opportunities

**Existing VectorValue Class (`lib/src/types/vector_value.dart`):**
- VectorFormat enum can be reused for index type detection
- Distance calculation methods (euclidean, manhattan, cosine) should be leveraged
- Vector validation and dimension checking already implemented
- Serialization methods available for FFI transport

**Integration Patterns:**
- Follow existing ORM and query() builder patterns
- Maintain consistency with current codebase architecture
- Leverage existing FFI bindings and type system

### Scope Boundaries

**In Scope:**
- Vector index creation and management (create, drop, rebuild)
- Auto-selection of index types based on dataset size
- Support for HNSW, M-Tree, FLAT index types
- Similarity search with Euclidean, Cosine, Manhattan metrics
- Integration with ORM query() builder pattern
- Batch search capabilities with indexed result mapping
- Chained filtering (similarity search + traditional WHERE clauses)
- Manual index rebuild functionality
- Hybrid configuration (smart defaults + optional overrides)

**Out of Scope:**
- Performance metrics and monitoring (deferred to later phase)
- Real-time auto-rebuild on vector updates (manual rebuild only)
- Incremental index updates (destructive rebuild approach)
- Advanced monitoring dashboards or analytics
- UI components (backend/API feature only)

**Future Enhancements:**
- Performance metrics exposure (search latency, index size, calculation counts)
- Incremental index updates instead of full rebuilds
- Auto-rebuild triggers on data changes
- Advanced index optimization algorithms
- Additional index types beyond HNSW, M-Tree, FLAT

### Technical Considerations

**Existing System Integration:**
- Must integrate seamlessly with existing ORM and query() methods
- Follow established builder pattern conventions
- Leverage VectorValue class for all vector operations
- Maintain FFI binding patterns used elsewhere in codebase

**Technology Stack:**
- Dart language (consistent with existing codebase)
- SurrealDB backend (vector indexing capabilities)
- FFI bindings for native performance
- Existing VectorValue implementation for type safety

**Distance Metrics Implementation:**
- All three required metrics (Euclidean, Cosine, Manhattan) already exist in VectorValue
- Should reuse existing implementations rather than duplicating logic
- Ensure consistency between VectorValue distance calculations and search operations

**Index Type Auto-Selection Logic:**
- Primary driver: dataset size
- Consider: number of records, vector dimensions, expected query patterns
- Defaults should favor HNSW for larger datasets, simpler indexes for smaller ones
- Allow manual override when auto-selection is not optimal

**Configuration Philosophy:**
- Smart defaults minimize configuration burden
- Optional parameters available for advanced tuning
- HNSW parameters (M, efConstruction) exposed when needed
- Balance between simplicity and power-user flexibility
