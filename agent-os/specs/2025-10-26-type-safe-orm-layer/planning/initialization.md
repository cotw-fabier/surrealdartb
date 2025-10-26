# Initial Spec Idea

## User's Initial Description
Build a type-safe ORM layer on top of the existing table schema generation utility. This will allow developers to use Dart objects for CRUD operations instead of raw Maps and SurrealQL.

**Key Requirements:**
1. Type-safe CRUD operations using Dart objects (e.g., `db.create(<object>)`)
2. Automatic table and field identification from object types
3. Rename existing CRUD methods to append "QL" suffix (e.g., `db.create` -> `db.createQL`) to indicate raw SurrealQL usage
4. Maintain backward compatibility - Maps should still work for non-schemaful tables
5. Support for relationships and edge graphs definition
6. Query result resolution back into Dart objects
7. Leverage code generation and decorators for the ORM layer
8. Maximize SurrealDB's power while providing type-safe Dart interfaces

**Context:**
This builds on the previous spec (2025-10-26-table-definition-generation) which created a complex table schema generation utility using class definitions and decorators.

## Metadata
- Date Created: 2025-10-26
- Spec Name: type-safe-orm-layer
- Spec Path: agent-os/specs/2025-10-26-type-safe-orm-layer
