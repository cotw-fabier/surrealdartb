# Product Mission

## Pitch
SurrealDartB is a Dart/Flutter wrapper library that brings embedded SurrealDB to mobile and desktop developers by providing full-featured local database capabilities with advanced AI workflows including vector indexing and similarity search.

## Users

### Primary Customers
- **Mobile App Developers**: Flutter developers building iOS and Android applications requiring robust local data storage with AI/ML capabilities
- **Desktop Application Developers**: Dart developers creating cross-platform desktop applications (macOS, Windows, Linux) needing powerful embedded database solutions
- **AI/ML-Focused Developers**: Developers building on-device AI applications requiring vector storage and similarity search for embeddings, semantic search, and RAG workflows

### User Personas

**Mobile AI Developer** (25-40 years)
- **Role:** Flutter developer building intelligent mobile applications
- **Context:** Creating apps with on-device AI features like semantic search, recommendation systems, or RAG (Retrieval-Augmented Generation) workflows
- **Pain Points:** Existing mobile databases lack vector indexing capabilities; cloud-based vector databases add latency and privacy concerns; limited options for sophisticated on-device data management
- **Goals:** Store embeddings locally, perform fast similarity searches, maintain user privacy with on-device processing, handle complex relational and document data alongside vectors

**Cross-Platform Desktop Developer** (28-45 years)
- **Role:** Desktop application developer using Flutter/Dart
- **Context:** Building data-intensive desktop applications requiring advanced querying and local-first architecture
- **Pain Points:** SQLite too limited for complex queries; no good Dart options for graph-like queries or vector operations; want single database solution for multiple data models
- **Goals:** Build sophisticated desktop apps with powerful local database, support complex queries without backend dependency, leverage SurrealQL for flexible data modeling

## The Problem

### Limited Database Options for Advanced Workflows in Dart/Flutter
While the Dart/Flutter ecosystem has several excellent local database solutions (Hive, SQLite, Drift, Mimir), none provide the complete package for modern AI-powered applications. Developers building applications with vector embeddings, semantic search, or complex relational-document hybrid data models must either compromise on features, add multiple dependencies, or rely on cloud services that introduce latency and privacy concerns.

**Our Solution:** SurrealDartB brings the full power of SurrealDB's Rust implementation to Dart/Flutter through FFI and native assets, providing an embedded database solution that supports traditional CRUD, advanced queries with SurrealQL, vector indexing for AI workflows, and real-time subscriptions - all running locally on-device with no external dependencies.

### On-Device AI Requires On-Device Vector Storage
As AI/ML capabilities move to edge devices for privacy and performance, developers need local vector storage for embeddings. Current options force developers to choose between cloud-based vector databases (privacy/latency issues) or building custom solutions (time-consuming and error-prone).

**Our Solution:** SurrealDartB provides first-class vector indexing and similarity search capabilities directly embedded in mobile and desktop applications, enabling developers to build sophisticated AI features that run entirely on-device while maintaining user privacy and delivering instant response times.

## Differentiators

### First SurrealDB Implementation for Dart/Flutter Ecosystem
Unlike existing Dart database solutions, we leverage SurrealDB's powerful Rust implementation to bring enterprise-grade database features to mobile and desktop applications. This gives Dart developers access to multi-model data support (documents, graphs, key-value), advanced query language (SurrealQL), and vector operations that simply don't exist in other Dart-native databases. This results in a single dependency that replaces multiple specialized libraries while providing superior functionality.

### Native Vector Indexing for AI-Powered Applications
Unlike SQLite, Hive, or other traditional local databases that require custom extensions or workarounds for vector operations, SurrealDartB provides built-in vector indexing and similarity search out of the box. This results in developers being able to build semantic search, recommendation engines, and RAG systems with simple, intuitive APIs rather than complex custom implementations.

### Embedded-First with Path to Parity
Unlike remote-only database wrappers, we prioritize embedded/local-first use cases, ensuring the database runs entirely on-device without external dependencies. Our architecture path to 1:1 parity with SurrealDB's Rust API means developers get comprehensive database functionality that grows with their needs, from simple CRUD to complex distributed scenarios, all through a consistent API.

### True Cross-Platform Native Performance
Unlike pure Dart solutions or platform channel implementations, SurrealDartB uses Rust FFI with native assets for optimal performance across all native platforms (iOS, Android, macOS, Windows, Linux). This results in native-speed database operations regardless of platform, with automatic native library compilation handled transparently through Dart's native asset system.

## Key Features

### Core Features
- **Embedded Database Operations:** Full CRUD (Create, Read, Update, Delete) operations running entirely on-device with no external dependencies, providing developers with reliable local data storage that works offline and respects user privacy
- **SurrealQL Query Support:** Advanced query capabilities using SurrealDB's powerful query language, enabling developers to express complex data relationships, graph traversals, and document queries in a single, intuitive syntax
- **Native Multi-Platform Support:** Seamless operation across iOS, Android, macOS, Windows, and Linux with automatic native library compilation, giving developers true write-once-run-anywhere database functionality

### AI/ML Features
- **Vector Indexing:** Built-in support for storing and indexing high-dimensional vector embeddings, enabling developers to persist ML model outputs directly in the database
- **Similarity Search:** Fast k-nearest neighbor (KNN) and approximate nearest neighbor (ANN) searches for semantic similarity operations, powering features like semantic search, recommendation systems, and duplicate detection
- **Multi-Model Data Support:** Store vectors alongside traditional relational data, documents, and graph structures in a single database, eliminating the need for multiple specialized databases

### Advanced Features
- **Real-Time Subscriptions:** Live queries that automatically update when underlying data changes, enabling reactive applications without manual polling or complex state management
- **Data Synchronization:** Capabilities for syncing local embedded database with remote instances, supporting offline-first architectures with eventual consistency
- **Flexible Data Modeling:** Support for documents, graphs, relational tables, and key-value stores in a single database, allowing developers to choose the best model for each feature without architectural constraints
