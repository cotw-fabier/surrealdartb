# Requirements Summary

## User Responses to Clarifying Questions

### Core Deserialization Engine

1. **Comprehensive Type Support:** YES - Handle ALL SurrealDB v2.x type wrappers
2. **Investigation Approach:** YES - Logging may be required for debugging
3. **Nested Structures:** YES - Handle nested structures with semantic type preservation (e.g., Thing IDs as "table:id" strings)
4. **Number Types:** YES - Unwrap to simplest representation (Int → number, Float → number, Decimal → string for precision)
5. **Fix Strategy:** Focus on fixing what we have (not building fallback strategies)

### Testing & Verification

6. **Comprehensive Testing:** YES - Validate ALL CRUD operations across BOTH storage backends (mem:// and RocksDB)
7. **Performance Verification:** YES - Probably a good idea to verify performance hasn't regressed
8. **Test Approach:** Rely on existing example app with enhanced validation (not building new comprehensive test suite)

### Error Handling

9. **Error Propagation:** Errors must bubble up to Dart - use whatever is the best method for that
10. **Diagnostic Infrastructure:** Temporary scaffolding (will be removed after fixing)

### Architecture & Implementation

11. **PRIMARY APPROACH:** **Search Rust docs FIRST** to find the proper SurrealDB deserialization method before building custom layer
    - **Result:** Found the solution! Use `value.to_string()` instead of `serde_json::to_string(value)`
    - The Display trait implementation provides clean JSON automatically
    - No custom unwrapper needed!

12. **FFI Stack Audit:** YES - Full review to make sure everything is working correctly

### Scope

13. **Type of Effort:** Fix and stabilize (aside from dealing with deserialization issues)
14. **Future-Proofing:** Leave it open to new potential types
15. **Explicit Exclusions:** Out of scope - vector indexing, live queries, transactions, advanced SurrealQL features, remote connections
    - Focus: Just get the core CRUD working

## Key Insights from Rust SDK Documentation

### The Solution (from flexible-typing.mdx)

**Problem Identified:**
- Current code uses `serde_json::to_string(value)` which produces wrapped JSON
- Example: `{"Strand": "John Doe"}` instead of `"John Doe"`

**Solution:**
- Use `value.to_string()` which uses SurrealDB's Display trait
- This automatically unwraps all type tags
- Example output: `[{ class_id: 20, id: student:abc123, name: 'Another student' }]`

**Implementation:**
- Replace line 22 in `rust/src/query.rs`
- Remove the entire custom recursive unwrapper (no longer needed)
- Test all CRUD operations

## Scope Definition

### In Scope

1. **Fix Deserialization**
   - Replace serde serialization with Display trait (`.to_string()`)
   - Remove custom unwrapper code
   - Test with all SurrealDB types

2. **Comprehensive FFI Stack Audit**
   - Verify Rust FFI boundary safety
   - Check Dart isolate communication
   - Validate memory management with NativeFinalizer
   - Review async runtime (Tokio) behavior
   - Confirm error propagation works across all layers
   - Check thread safety

3. **Testing & Verification**
   - Test all CRUD operations (create, select, update, delete, query)
   - Test both storage backends (mem:// and RocksDB)
   - Verify no field values appear as null
   - Verify type wrappers are eliminated
   - Confirm memory management is leak-free
   - Check performance hasn't regressed

4. **Stabilization**
   - Fix any issues discovered during audit
   - Ensure error messages are clear
   - Verify examples work correctly
   - Update documentation as needed

### Out of Scope

- Vector indexing and similarity search
- Live queries and real-time subscriptions
- Transactions
- Advanced SurrealQL features
- Remote connections (WebSocket/HTTP)
- New features (unless discovered as necessary during audit)

## Success Criteria

### Functional
- [ ] All CRUD operations return clean JSON (no type wrappers)
- [ ] All field values appear correctly (no nulls)
- [ ] Both storage backends work correctly
- [ ] Example scenarios pass successfully
- [ ] Errors bubble up to Dart with clear messages

### Technical
- [ ] Deserialization uses SurrealDB's Display trait
- [ ] Custom unwrapper code removed (simplified)
- [ ] FFI boundary safety verified
- [ ] Memory management leak-free
- [ ] Isolate communication works correctly
- [ ] Async operations non-blocking

### Quality
- [ ] Performance hasn't regressed
- [ ] No compilation warnings
- [ ] Clean diagnostic output
- [ ] Documentation updated
- [ ] CHANGELOG.md updated

## Implementation Priorities

1. **P0 (Critical):** Fix deserialization using Display trait
2. **P0 (Critical):** Test all CRUD operations for correct data
3. **P1 (High):** Audit FFI stack for safety and correctness
4. **P1 (High):** Verify memory management
5. **P2 (Medium):** Performance verification
6. **P2 (Medium):** Documentation updates
7. **P3 (Low):** Code cleanup and optimization

## Timeline Estimate

Based on the simple fix identified:
- Deserialization fix: 1-2 hours (simple one-line change + testing)
- FFI stack audit: 4-6 hours (thorough review)
- Testing & verification: 3-4 hours (comprehensive testing)
- Documentation: 1-2 hours
- **Total:** ~2 days of focused work

Much faster than originally estimated because we found the proper SDK method instead of building a custom solution!
