# Rust SDK Research Findings

## Critical Discovery: SurrealDB Value Display Trait

**Source:** `docs/doc-sdk-rust/concepts/flexible-typing.mdx`

### The Root Cause

The deserialization issue is caused by using the wrong serialization method for `surrealdb::Value`.

**Current Code (WRONG):**
```rust
// rust/src/query.rs:22
let json_str = serde_json::to_string(value)
```

This uses serde serialization which produces the Debug representation with type wrappers:
```json
{"Strand": "John Doe"}
{"Number": {"Int": 30}}
{"Thing": {"tb": "person", "id": {"String": "abc123"}}}
```

**Correct Approach:**
```rust
let json_str = value.to_string()
```

This uses the `Display` trait implementation which produces clean output:
```json
"John Doe"
30
"person:abc123"
```

### Documentation Evidence

From `flexible-typing.mdx` lines 150-151:
> "A `Value` implements `Display`, making the output similar to that in the CLI."

Example output (line 193):
```
[{ class_id: 20, id: student:7bhlb23ti1vedykpsnzd, name: 'Another student' }, { class_id: 10, id: student:rpi0qmsqc7rwaxddfxpb, name: 'Student 1' }, { class_id: 40, id: student:xl5rzvlkghtn01nh5tw2, metadata: { favourite_classes: ['Music', 'Industrial arts'], teacher: teacher:mr_gundry_white }, name: 'Third student' }]
```

Compare to Debug output (line 191):
```
Array(Array([Object(Object({"class_id": Number(Int(20)), "id": RecordId(RecordId { table: "student", key: String("7bhlb23ti1vedykpsnzd") }), "name": Strand(Strand("Another student"))})), ...
```

### Implementation Strategy

**Simple Fix (Recommended):**
1. Replace `serde_json::to_string(value)` with `value.to_string()` in `surreal_value_to_json()`
2. Remove the entire recursive unwrapper (lines 42-163 in query.rs) - no longer needed
3. Test all CRUD operations to verify clean data

**Alternative Approach (if needed):**
1. Check if `surrealdb::Value` has `.into_json()` or similar methods for direct conversion
2. Explore `surrealdb::sql::Value` methods for serialization options

### Why the Unwrapper Wasn't Executing

The unwrapper IS being called (status.md assumption was wrong), but:
1. The serialization produces wrapped JSON
2. The unwrapper tries to process it
3. BUT the real issue is that we shouldn't need an unwrapper at all - we should use Display!

### Next Steps

1. Update `rust/src/query.rs` to use `.to_string()` instead of `serde_json::to_string()`
2. Remove the custom unwrapper logic (it's solving the wrong problem)
3. Test with all CRUD operations
4. Verify nested structures, arrays, and complex types work correctly
5. Remove all diagnostic logging once confirmed working

## Additional SDK Insights

### Query Response Handling

From `methods/query.mdx`:
- `.take(index)` deserializes a specific statement result
- Use `.take_errors()` to extract errors from Response
- Response can contain multiple statement results

### Create Method

From `methods/create.mdx`:
- Can return typed structs: `let person: Option<Person> = db.create("person").await?`
- Can return Values when using `Resource::from()`
- Both approaches are valid depending on use case

### Resource vs String

Using `Resource::from("table")` instead of just `"table"` returns `surrealdb::Value` instead of deserializing to a type. This is useful for dynamic/flexible schemas.

For our FFI layer, we should always use the Value approach since we're crossing the FFI boundary to Dart and need maximum flexibility.
