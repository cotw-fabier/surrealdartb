# Spec Requirements: Type-Safe ORM Layer

## Initial Description
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

## Requirements Discussion

### First Round Questions

**Q1: CRUD Operations Signature**
I assume you want operations like `db.create(userObject)`, `db.update(userObject)`, `db.delete(userObject)`, and `db.select<User>()` where the type parameter drives the query. Is that correct?

**Answer:** Yes, exactly. The type parameter and object should drive everything. For create/update/delete, pass the object. For select/query, use the type parameter to know which table to query.

---

**Q2: Table Name Extraction**
I'm thinking we extract the table name from the `@SurrealTable('table_name')` annotation on the class. Should we also support automatic table name derivation (e.g., `User` class -> `user` table) if no annotation is present?

**Answer:** Extract from the annotation. No automatic derivation - require explicit annotation for clarity and to avoid confusion.

---

**Q3: Backward Compatibility with Maps**
I assume the existing Map-based methods (with the "QL" suffix) should remain unchanged and work exactly as they do now - this is purely additive functionality. Correct?

**Answer:** Correct. The existing methods should be renamed to append "QL" (e.g., `create` -> `createQL`, `select` -> `selectQL`). The new type-safe methods take the base names. Maps continue to work with the "QL" methods for schemaless/raw query scenarios.

---

**Q4: Query Builder Approach**
For query building, should we provide a fluent/chaining API like `db.query<User>().where(...).include(...).limit(10)`, or would you prefer direct method parameters like `db.query<User>(where: ..., include: ..., limit: 10)`?

**Answer:** Both. Start with a fluent API for complex queries, but also support direct parameters for simple cases. The fluent API should return a query builder that can be chained and then executed.

---

**Q5: Include System for Relationships**
When including relationships (like `db.query<User>().include('posts')`), should the returned object have those relationships populated in strongly-typed fields (e.g., `user.posts` as `List<Post>`), or do you want a more dynamic approach?

**Answer:** Strongly-typed fields. If a class has a `List<Post> posts` field with a relationship annotation, including 'posts' should populate that field with actual Post objects. The schema should define the relationship structure.

---

**Q6: Where Clause DSL**
For type-safe where clauses, I'm thinking of generating methods based on fields, like `queryBuilder.whereEmail(equals: 'user@example.com')` or `queryBuilder.whereAge(greaterThan: 18)`. Should we generate these as part of code generation, or use a more dynamic builder pattern?

**Answer:** This is interesting. Leaning towards generated methods for type safety, but we need to think about operators (equals, contains, greaterThan, lessThan, in, etc.). Can we generate a comprehensive set while keeping the API clean?

---

**Q7: Relationship and Edge Graph Annotations**
For defining relationships, should we introduce new annotations like `@SurrealRelation('posts', type: RelationType.oneToMany)` on fields? How explicit do you want the edge table definitions to be?

**Answer:** Yes, introduce relationship annotations. We need to support:
- One-to-one
- One-to-many
- Many-to-many (with edge tables)
Edge tables should be definable as separate classes with their own annotations that specify the relationship structure.

---

**Q8: Code Generation Scope**
Should the code generator create extension methods on the existing classes (like `extension UserORM on User {...}`) or generate completely separate model classes (like `class UserModel extends User {...}`)?

**Answer:** Extension methods on the existing classes. Keep a single source of truth - the annotated class definition. Generate helper methods and query builders as extensions or companion classes.

---

**Q9: Exclusions and Future Enhancements**
What should we explicitly NOT include in this first version? For example: migrations, schema validation at runtime, connection pooling, caching, transaction support beyond what SurrealDB provides natively?

**Answer:** Exclude for now:
- Advanced caching layers (let SurrealDB handle it)
- Connection pooling (handle in a future enhancement)
- Complex transaction DSLs (use SurrealDB's native transaction support)
Include:
- Schema validation where it makes sense
- Basic relationship traversal
- Type-safe query building

### Existing Code to Reference

**Similar Features Identified:**
- Feature: Existing Table Schema Generation (2025-10-26-table-definition-generation)
  - Path: `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-26-table-definition-generation`
  - This spec implemented the foundation: decorators, class annotations, and table schema generation
  - Components to potentially reuse:
    - `@SurrealTable()` annotations
    - `@SurrealField()` annotations
    - Code generation infrastructure in `lib/generator/`
    - Type mapping logic in `lib/generator/type_mapper.dart`
    - Schema introspection in `lib/src/schema/introspection.dart`
  - The ORM layer should extend and build upon this foundation

### Follow-up Questions

**Follow-up 1: Include System - Type Safety Strategy**
When a relationship is defined but not included in a query, should the field be null, an empty list, or should we use a special "unloaded" state that throws an error if accessed? How do we maintain type safety while indicating "not loaded"?

**Answer:** Use schema introspection. Returned objects should already know there's a relation. If included, it's populated with data. If not included, it's an empty list or null. If a relation isn't optional, it should probably always be included by default.

---

**Follow-up 2: Include System - SurrealQL Generation**
When generating SurrealQL for includes, should we use FETCH clauses or graph traversal syntax? What's your preference given SurrealDB's capabilities?

**Answer:** Use graph traversal or record links depending on annotations in the schema. `@SurrealRelation()` is different from `@SurrealRecord()`. Trust our judgment on the best way to handle this - think through the optimal approach.

---

**Follow-up 3: Where Clause DSL - Code Generation Strategy**
If we generate where clause methods, we'll need to regenerate them whenever the schema changes. Is that acceptable, or would you prefer a single unified builder that works dynamically?

**Answer:** Generate these with code gen. This keeps things type-safe and easy to manage with future updates - just rerun code gen to update functions.

---

**Follow-up 4: Phasing Strategy**
You mentioned "query function should be its own phase for advanced implementation" - do you mean we should break this spec into multiple implementation phases, or is this all part of one spec with dedicated tasks for the query builder?

**Answer:** By "phase" meant dedicated tasks specifically for handling the query function as this will be an advanced implementation. It's all part of this spec.

---

**Follow-up 5: Relationship Annotation Details**
For the many-to-many edge table example, would this be defined like:
```dart
@SurrealEdgeTable('user_posts')
class UserPostEdge {
  @SurrealRecord() User user;
  @SurrealRecord() Post post;
  DateTime createdAt;
}
```
And then referenced from the User class somehow?

**Answer:** The example would be an edge table. We should have different annotations in the table definition which handle each type of relation:
- Record links
- Edge tables
- Traditional foreign key patterns

---

**Follow-up 6: Existing Table Schema Generation Integration**
Should we modify the existing schema generation code, or keep the ORM layer as a separate module that depends on it?

**Answer:** Extend current implementation. Generate ORM model comparison code. Since we're annotating a class, no need to generate a second class. Instead, extend that class with additional functions. Single source of truth based on annotations.

## Visual Assets

### Files Provided:
No visual files found.

### Visual Insights:
No visual assets provided.

## Requirements Summary

### Functional Requirements

**Core CRUD Operations:**
- Type-safe create: `db.create(userObject)` - infers table from object type
- Type-safe update: `db.update(userObject)` - requires ID field to be set
- Type-safe delete: `db.delete(userObject)` - uses ID from object
- Type-safe select: `db.select<User>()` - returns query builder or direct results
- Automatic serialization from Dart objects to SurrealDB format
- Automatic deserialization from SurrealDB results to Dart objects

**Query Builder (Advanced):**
- Fluent/chaining API: `db.query<User>().where(...).include(...).limit(10)`
- Direct parameter API: `db.query<User>(where: ..., include: ..., limit: 10)`
- Type-safe where clause methods generated per field
- Support for operators: equals, contains, greaterThan, lessThan, in, etc.
- Include/exclude specific fields
- Limit, offset, ordering
- Query execution returns strongly-typed results

**Relationship Management:**
- Three relationship annotation types:
  - `@SurrealRecord()` - for record link relationships
  - `@SurrealRelation()` - for graph traversal relationships
  - `@SurrealEdge()` - for edge table relationships
- Support for one-to-one, one-to-many, many-to-many
- Include system populates related objects in strongly-typed fields
- Non-optional relations included by default
- Optional relations: null/empty list when not included
- Smart SurrealQL generation based on relationship type

**Backward Compatibility:**
- Rename existing methods: `create` -> `createQL`, `select` -> `selectQL`, etc.
- "QL" suffix methods continue to work with Maps for raw queries
- Schemaless table support maintained via "QL" methods
- No breaking changes to existing API

**Code Generation:**
- Generate extension methods on annotated classes
- Generate query builder classes per entity
- Generate where clause methods per field with type-safe operators
- Generate relationship traversal code
- Reusable with schema changes - rerun generator to update
- Single source of truth: the annotated class definition

### Reusability Opportunities

**Existing Infrastructure to Extend:**
- Table schema generation utility from previous spec
- `@SurrealTable()`, `@SurrealField()` annotations
- Code generator in `lib/generator/`
- Type mapping logic in `lib/generator/type_mapper.dart`
- Schema introspection in `lib/src/schema/introspection.dart`

**New Annotations to Create:**
- `@SurrealRecord()` - mark record link fields
- `@SurrealRelation()` - mark graph traversal relationships
- `@SurrealEdge()` - mark edge table relationships

**Code Generation Extensions:**
- Extend existing generator to create ORM methods
- Generate query builder classes
- Generate type-safe where clause methods
- Generate relationship loading code

### Scope Boundaries

**In Scope:**
- Type-safe CRUD operations with Dart objects
- Query builder with fluent and direct APIs
- Type-safe where clause DSL (generated)
- Relationship definitions and loading (one-to-one, one-to-many, many-to-many)
- Include/exclude system for relationships and fields
- Automatic serialization/deserialization
- Extension of existing table schema generation
- Code generation for ORM functionality
- Basic schema validation during code generation
- Method renaming for backward compatibility

**Out of Scope:**
- Advanced caching layers (rely on SurrealDB)
- Connection pooling (future enhancement)
- Complex transaction DSLs (use SurrealDB native support)
- Runtime schema migration (handled by existing schema generation spec)
- Query optimization beyond what SurrealDB provides
- Database connection management (already exists)

**Future Enhancements Mentioned:**
- Connection pooling strategies
- Advanced caching mechanisms
- Sophisticated transaction builders
- Query result caching
- Lazy loading strategies for relationships

### Technical Considerations

**Design Decisions for Spec Writer:**

1. **Query Builder Architecture:**
   - Design dual API: fluent chaining vs direct parameters
   - Ensure both paths produce identical SurrealQL
   - Consider immutability vs mutable builder pattern
   - Design for extensibility with new operators

2. **Relationship SurrealQL Generation:**
   - `@SurrealRecord()` -> generate FETCH or direct record link syntax
   - `@SurrealRelation()` -> generate graph traversal (->relates_to->)
   - `@SurrealEdge()` -> generate edge table queries
   - Document the decision rationale for each approach
   - Consider performance implications

3. **Type Safety for Unloaded Relations:**
   - Non-optional relations: auto-include by default
   - Optional relations: use nullable types or empty collections
   - Consider schema introspection to validate at compile-time
   - Clear error messages if required relation not included

4. **Where Clause Code Generation:**
   - Generate comprehensive operator methods per field type
   - String fields: equals, contains, startsWith, endsWith, in
   - Numeric fields: equals, greaterThan, lessThan, between, in
   - Boolean fields: equals, isTrue, isFalse
   - Date fields: equals, before, after, between
   - Collection fields: contains, isEmpty, isNotEmpty
   - Keep API ergonomic despite comprehensive coverage

5. **Extension Method Strategy:**
   - Generate extension methods on annotated classes for serialization
   - Generate separate query builder classes for type-safe queries
   - Avoid polluting class namespace with too many generated methods
   - Consider using companion classes where appropriate

6. **Integration with Existing Database Class:**
   - Extend `lib/src/database.dart` with new type-safe methods
   - Keep "QL" methods for raw query access
   - Ensure smooth interop between typed and raw methods
   - Maintain consistency with existing error handling patterns

7. **Code Generation Triggers:**
   - Integrate with existing build_runner workflow
   - Generate files alongside existing schema generation
   - Clear naming convention for generated files
   - Documentation for when to regenerate

8. **Serialization/Deserialization Strategy:**
   - Leverage existing type mapper where possible
   - Handle nested objects and relationships
   - Support for SurrealDB-specific types (Record IDs, Geometry, etc.)
   - Validate data types during deserialization
   - Clear error messages for type mismatches

9. **Task Breakdown Structure:**
   - Phase 1: Core CRUD with basic type safety
   - Phase 2: Query builder foundation (simple where, limit, offset)
   - Phase 3: Advanced where clause generation (all operators)
   - Phase 4: Relationship annotations and loading (dedicated focus)
   - Phase 5: Include/exclude system
   - Phase 6: Integration, testing, documentation

### Standards Compliance Notes

**From tech-stack.md:**
- Use Dart 3.x features (records, patterns, enhanced enums)
- Follow SurrealDB Rust SDK patterns where applicable
- Code generation via build_runner and source_gen

**From coding-style.md:**
- Follow Dart style guide
- Use meaningful variable names
- Keep methods focused and single-purpose
- Prefer composition over inheritance

**From error-handling.md:**
- Custom exception types for ORM-specific errors
- Clear error messages with context
- Propagate SurrealDB errors appropriately
- Validation errors should be descriptive

**From validation.md:**
- Validate object state before CRUD operations
- Type validation during deserialization
- Schema validation during code generation
- Relationship integrity checks where appropriate

**From conventions.md:**
- Consistent naming: query builders named `{Entity}QueryBuilder`
- Extension methods named `{Entity}ORM`
- Generated files follow existing patterns
- Documentation comments on all public APIs
