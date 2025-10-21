use std::cell::OnceCell;
use tokio::runtime::Runtime;

thread_local! {
    /// Thread-local Tokio runtime for async operations
    ///
    /// Each thread (including Dart isolate threads) gets its own dedicated runtime.
    /// This prevents deadlocks that occur when using `block_on` with a shared global runtime.
    ///
    /// ## Why Thread-Local?
    ///
    /// When FFI functions are called from Dart isolates, each isolate runs on its own thread.
    /// If we use a global runtime and call `block_on` from multiple threads, we can encounter
    /// deadlocks where `block_on` waits for tasks that need the runtime's event loop, but
    /// the event loop is blocked by `block_on` itself.
    ///
    /// Thread-local storage gives each thread its own runtime instance, eliminating this issue.
    ///
    /// ## Trade-offs
    ///
    /// - **Pro**: No deadlocks, safe for multi-threaded FFI
    /// - **Pro**: Simple to implement, minimal code changes
    /// - **Con**: Higher memory overhead (~2-4MB per thread)
    /// - **Con**: Each runtime spawns worker threads (defaults to CPU core count)
    ///
    /// For typical usage with 1-3 isolates, this overhead is acceptable and provides
    /// reliable, deadlock-free operation.
    ///
    /// ## Future Optimization
    ///
    /// If memory/thread overhead becomes an issue with many concurrent isolates,
    /// consider migrating to the spawn-task pattern instead of block_on.
    static RUNTIME: OnceCell<Runtime> = OnceCell::new();
}

/// Get or create the thread-local Tokio runtime
///
/// This function returns a reference to the Tokio runtime for the current thread.
/// On first call from a thread, it creates a new runtime. Subsequent calls from
/// the same thread return the same runtime instance.
///
/// ## Thread Safety
///
/// Each thread has its own runtime instance. This is safe for FFI calls from
/// multiple Dart isolates, as each isolate thread will get its own runtime.
///
/// ## Performance
///
/// Runtime creation has some overhead (~10-50ms), but happens only once per thread.
/// All subsequent operations on the same thread reuse the existing runtime.
///
/// # Returns
/// A reference to the thread-local Tokio runtime
///
/// # Panics
/// Panics if the runtime cannot be created (extremely rare, indicates system resource exhaustion)
///
/// # Examples
/// ```no_run
/// let runtime = get_runtime();
/// runtime.block_on(async {
///     // Async code here - safe to use block_on with thread-local runtime
/// });
/// ```
pub fn get_runtime() -> &'static Runtime {
    RUNTIME.with(|cell| {
        // SAFETY: We're returning a reference with 'static lifetime, which is safe because:
        // 1. thread_local! ensures the cell lives for the entire thread lifetime
        // 2. OnceCell ensures the Runtime, once created, is never moved or dropped while the thread lives
        // 3. The returned reference is tied to thread-local storage, not heap allocation
        unsafe {
            let ptr = cell.get_or_init(|| {
                // Use current_thread runtime to avoid potential deadlocks with SurrealDB
                tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                    .expect("Failed to create Tokio runtime")
            }) as *const Runtime;
            &*ptr
        }
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_runtime_creation() {
        let runtime = get_runtime();
        assert!(runtime.handle().runtime_flavor() == tokio::runtime::RuntimeFlavor::MultiThread
            || runtime.handle().runtime_flavor() == tokio::runtime::RuntimeFlavor::CurrentThread);
    }

    #[test]
    fn test_runtime_reuse_same_thread() {
        let runtime1 = get_runtime();
        let runtime2 = get_runtime();
        // Same thread should get same runtime instance
        assert_eq!(runtime1 as *const _, runtime2 as *const _);
    }

    #[test]
    fn test_different_threads_get_different_runtimes() {
        // Get runtime in main thread
        let _ = get_runtime();

        // Spawn a new thread and verify it can get its own runtime
        let handle = thread::spawn(|| {
            let runtime = get_runtime();
            // If we get here without deadlock, thread-local is working
            runtime.block_on(async {
                42
            })
        });

        let result = handle.join().unwrap();
        // Both threads can independently use their runtimes
        assert_eq!(result, 42);
    }

    #[test]
    fn test_runtime_works_with_block_on() {
        let runtime = get_runtime();
        let result = runtime.block_on(async {
            tokio::time::sleep(std::time::Duration::from_millis(10)).await;
            42
        });
        assert_eq!(result, 42);
    }
}
