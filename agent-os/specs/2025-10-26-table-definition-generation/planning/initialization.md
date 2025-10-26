# Initial Spec Idea

## User's Initial Description
**Feature: TableDefinition Generation from Dart Classes/Objects**

The user wants to expand the TableDefinition setup to automatically establish tables from serializable Dart objects. The feature should support:

- `TableDefinition.fromClass(ClassName)` - Create table definition from a Dart class
- `TableDefinition.fromObject(instancedObject)` - Create table definition from an object instance

The goal is to eliminate the need for custom implementations by building the spec dynamically from the serialized object, providing type safety by mapping common Dart types to SurrealDB types automatically.

This is a schema generation/reflection feature that will improve developer experience by reducing boilerplate code for table definitions.

## Metadata
- Date Created: 2025-10-26
- Spec Name: table-definition-generation
- Spec Path: agent-os/specs/2025-10-26-table-definition-generation
