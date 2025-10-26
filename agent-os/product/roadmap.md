# Product Roadmap

## Current Status Summary

**Last Updated:** 2025-10-26

**Overall Progress:** Phase 1 Complete ✅ | Phase 2 Complete ✅ | Phase 3 Blocked ⚠️ | Phase 4 In Progress (72%)

**Production Readiness:**
- ✅ **Ready:** Core CRUD operations, SurrealQL queries, vector/AI workloads, offline-first applications
- ⚠️ **Blocked:** Applications requiring transaction rollback
- ❌ **Not Ready:** Real-time subscriptions, vector similarity search, data synchronization

### Critical Issues
1. **Transaction Rollback Broken** - CANCEL TRANSACTION executes but changes persist (affects both mem:// and rocksdb://)
   - Status: ⚠️ Blocking Phase 3 completion
   - Impact: 7/8 transaction tests pass, rollback test fails
   - Reference: agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md

2. **Live Queries Not Functional** - Infrastructure skeleton exists but not exposed to FFI
   - Status: 20% complete, not functional
   - Impact: No real-time data subscriptions available

### Key Metrics
- **Code Base:** 4,004 LOC Rust + 4,250 LOC Dart + 4,161 LOC Tests
- **Test Coverage:** 18 test files, 150+ tests, ~92% pass rate
- **Platforms:** macOS, iOS, Android, Windows, Linux (all supported)
- **Storage Backends:** In-memory (testing), RocksDB (persistent)

---

## Feature Status Overview

| Feature | Status | Priority | Effort | Target Phase |
|---------|--------|----------|--------|--------------|
| FFI Foundation & Native Asset Setup | ✅ Complete | P0 | M | Phase 1 |
| Basic Database Connection & Lifecycle | ✅ Complete | P0 | M | Phase 1 |
| Core CRUD Operations | ✅ Complete | P0 | L | Phase 1 |
| SurrealQL Query Execution | ✅ Complete | P0 | L | Phase 2 |
| Vector Data Types & Storage | ✅ Complete | P1 | M | Phase 2 |
| Vector Indexing & Similarity Search | Not Started | P1 | L | Phase 3 |
| Real-Time Live Queries | In Progress (20%) | P1 | L | Phase 3 |
| Transaction Support | ⚠️ Blocked | P2 | M | Phase 3 |
| Advanced Query Features | In Progress (70%) | P2 | M | Phase 4 |
| Data Synchronization | Not Started (N/A) | P2 | XL | Phase 4 |
| Multi-Platform Testing & Optimization | Working (85%) | P1 | L | Ongoing |
| API Documentation & Examples | Working (75%) | P0 | M | Ongoing |

**Status Legend:** Not Started | In Progress | Working | ✅ Complete | ⚠️ Blocked
**Priority:** P0 (Critical) | P1 (High) | P2 (Medium) | P3 (Low)
**Effort:** XS (1 day) | S (2-3 days) | M (1 week) | L (2 weeks) | XL (3+ weeks)

---

## Detailed Development Phases

### Phase 1: Foundation & Basic Operations (4-5 weeks)

**Goal:** Establish FFI infrastructure and implement basic embedded database functionality

#### Milestones
1. [x] ✅ **FFI Foundation & Native Asset Setup** - Set up Rust-to-Dart FFI bindings using native_toolchain_rs, create build hooks for automatic native library compilation, define opaque handle types for SurrealDB objects, and establish memory management patterns with NativeFinalizer. Includes configuring Cargo.toml for cdylib/staticlib output and rust-toolchain.toml for multi-platform targets. `M` **COMPLETE (100%)**

2. [x] ✅ **Basic Database Connection & Lifecycle** - Implement database initialization, connection management, and proper cleanup for embedded SurrealDB instances. Create high-level Dart API wrapping low-level FFI calls, handle database file paths across platforms, implement error propagation from Rust to Dart, and establish lifecycle management (create, open, close, destroy). `M` **COMPLETE (100%)**

3. [x] ✅ **Core CRUD Operations** - Implement complete create, read, update, and delete operations for SurrealDB tables. Build type-safe API for record manipulation, handle serialization/deserialization between Dart objects and SurrealDB data structures, implement query result parsing, and provide async API patterns for all operations. Includes support for namespaces, databases, and table operations. `L` **COMPLETE (100%)**

**Exit Criteria:** ✅ **ALL MET**
- ✅ Developers can create/open embedded SurrealDB database
- ✅ Basic CRUD operations work reliably across all target platforms
- ✅ Memory management prevents leaks (validated with testing)
- ✅ Example app demonstrates basic database usage

---

### Phase 2: Query Language & Vector Foundation (3-4 weeks)

**Goal:** Enable advanced queries and establish vector storage capabilities

#### Milestones
4. [x] ✅ **SurrealQL Query Execution** - Implement full SurrealQL query execution engine accessible from Dart. Support parameterized queries, handle complex query results with nested data structures, implement query builder helpers for common patterns, and provide clear error messages for query syntax issues. Includes support for relations, graph traversals, and conditional logic. `L` **COMPLETE (100%)**

5. [x] ✅ **Vector Data Types & Storage** - Complete support for AI/ML vector embeddings with all 6 SurrealDB vector formats (F32, F64, I8, I16, I32, I64). Implements intelligent hybrid serialization (JSON ≤100 dims, binary >100 dims with 2.92x performance improvement), comprehensive TableStructure type system for schema definition with dual validation strategy (Dart-side + SurrealDB fallback), and full vector math operations (dot product, normalize, magnitude, cosine/euclidean/manhattan distance). Includes 149 comprehensive tests (99.3% pass rate), batch operations support, and complete migration guide. Production-ready for semantic search, AI embeddings, and multi-modal applications. `M` **COMPLETE (100%)**

**Exit Criteria:** ✅ **ALL MET**
- ✅ Developers can execute arbitrary SurrealQL queries from Dart
- ✅ Vector data can be stored and retrieved reliably
- ✅ Query results properly handle nested/relational data
- ✅ Documentation includes SurrealQL usage examples

---

### Phase 3: AI Features & Real-Time (4-5 weeks)

**Goal:** Deliver core AI/ML capabilities and real-time data reactivity

#### Milestones
6. [ ] **Vector Indexing & Similarity Search** - Implement vector indexing configuration and k-nearest neighbor (KNN) / approximate nearest neighbor (ANN) similarity search. Expose SurrealDB's vector index creation, build intuitive API for similarity queries, support various distance metrics (cosine, euclidean, manhattan), and optimize for performance with large vector datasets. Includes batch similarity search and filtering combined with vector search. `L` **NOT STARTED (0%)**

7. [ ] **Real-Time Live Queries** - Implement SurrealDB's live query functionality for real-time data subscriptions. Create Stream-based API for live query results, handle subscription lifecycle (subscribe, unsubscribe), propagate data changes to Dart listeners, and ensure thread-safe callback handling across FFI boundary. Includes error handling for connection interruptions and subscription management. `L` **IN PROGRESS (20%)** - Infrastructure exists but not functional

8. [~] ⚠️ **Transaction Support** - Add support for database transactions with ACID guarantees. Implement transaction begin/commit/rollback operations, provide idiomatic Dart API (callback-based or explicit control), handle transaction isolation levels, and ensure proper error handling with automatic rollback on failures. Includes nested transaction support if available in SurrealDB. `M` **BLOCKED (85%)** - API complete but rollback broken (see agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md)

**Exit Criteria:** ⚠️ **BLOCKED**
- ❌ Vector similarity search performs efficiently on realistic datasets
- ❌ Live queries successfully stream updates to Dart applications
- ⚠️ Transactions provide reliable ACID semantics (ROLLBACK BROKEN - Critical bug blocking completion)
- ❌ AI-focused example app demonstrates vector search capabilities

---

### Phase 4: Advanced Features & Production Readiness (4-6 weeks)

**Goal:** Complete feature parity for production use cases and enable data synchronization

#### Milestones
9. [ ] **Advanced Query Features** - Implement remaining SurrealQL advanced features including graph queries, subqueries, aggregations, and computed fields. Add support for SurrealDB functions, custom function definitions, conditional expressions, and complex joins. Build query optimization helpers and provide debugging tools for query performance analysis. `M` **IN PROGRESS (70%)** - Parameters and functions work, graph/join patterns limited

10. [ ] **Data Synchronization** - Implement data sync capabilities between local embedded database and remote SurrealDB instances. Design sync protocol handling conflict resolution, implement incremental sync strategies, provide hooks for custom sync logic, and handle offline-first scenarios with eventual consistency. Includes connection state management and automatic retry logic. `XL` **NOT STARTED (N/A for embedded mode)**

11. [~] **Multi-Platform Testing & Optimization** - Comprehensive testing and optimization across all supported platforms (iOS, Android, macOS, Windows, Linux). Implement platform-specific performance tests, optimize memory usage for mobile devices, validate FFI boundary efficiency, and ensure consistent behavior across platforms. Includes automated CI/CD testing on all platforms and performance benchmarking suite. `L` **WORKING (85%)** - 18 test files, 150+ tests, ~92% pass rate

12. [~] **API Documentation & Examples** - Create comprehensive documentation covering all API surfaces, usage patterns, and best practices. Build extensive example applications demonstrating real-world use cases (mobile app with vector search, desktop app with live queries, offline-first sync app), write migration guides for developers coming from other databases, and document performance characteristics and limitations. `M` **WORKING (75%)** - Core features documented, advanced features lacking

**Exit Criteria:** 🔶 **PARTIALLY MET**
- ❌ Data sync works reliably between local and remote instances (N/A for embedded)
- 🔶 All advanced SurrealQL features accessible from Dart (70% complete)
- ✅ Performance validated across all platforms (85% complete)
- 🔶 Documentation complete with real-world examples (75% complete)

---

## Long-Term Vision (Post-MVP)

**Future Enhancements:**
- Full 1:1 API parity with SurrealDB Rust SDK
- Advanced sync strategies (CRDTs, operational transforms)
- Database encryption at rest
- Custom index types and optimization hints
- Database migration tools and versioning
- Advanced monitoring and observability features
- Performance profiling and query analysis tools
- Support for SurrealDB embedded ML models
- Integration with popular Dart state management solutions
- Cloud backup and restore capabilities

---

## Development Principles

**Embedded-First Architecture:**
All features prioritize embedded/local use cases. Remote capabilities are secondary and built on the same foundation.

**Platform Parity:**
Every feature must work consistently across all supported native platforms (iOS, Android, macOS, Windows, Linux).

**Type-Safe FFI:**
All FFI boundaries are type-safe with proper error handling. Never expose raw pointers in public API.

**Memory Safety:**
Leverage NativeFinalizer for automatic resource cleanup. No memory leaks in normal usage patterns.

**Performance Conscious:**
All operations optimized for mobile constraints. Minimize FFI boundary crossings and allocations.

**Documentation Driven:**
Every public API documented with examples. Complex features include dedicated guides.
