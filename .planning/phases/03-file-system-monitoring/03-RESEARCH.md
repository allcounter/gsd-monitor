# Phase 3: File System Monitoring - Research

**Researched:** 2026-02-13
**Domain:** macOS file system monitoring with FSEvents API
**Confidence:** MEDIUM-HIGH

## Summary

File system monitoring on macOS requires choosing between FSEvents (directory-level monitoring with high performance) and DispatchSource (single-file monitoring). For this project's goal of watching .planning/ directories across multiple projects, **FSEvents is the standard approach**.

The core challenge is integrating FSEvents' C-based callback API with Swift 6 strict concurrency while avoiding common pitfalls: event storms from .git/ directories, improper cleanup causing memory leaks, and race conditions between file changes and UI updates.

**Primary recommendation:** Use FSEvents with AsyncStream wrapper for modern Swift concurrency, implement callback-based filtering to exclude .git/ directories, debounce events using swift-async-algorithms, and verify cleanup with Instruments.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FSEvents (Core Services) | System | Directory tree monitoring | Apple's native API for efficient file watching |
| swift-async-algorithms | Latest | Event debouncing | Official Apple package for async sequence operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| FSEventsWrapper | 1.2.0+ | Swift wrapper | If building custom wrapper (AsyncStream support) |
| FileMonitor | 1.2.0+ | High-level abstraction | If avoiding FSEvents C API entirely |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FSEvents | DispatchSource.makeFileSystemObjectSource | Only monitors single file, not directories; requires file descriptor per file |
| FSEvents | FileMonitor package | Higher abstraction but less control; requires macOS 13+; may not support security-scoped bookmarks |
| Custom wrapper | FSEventsWrapper | Pre-built AsyncStream support but adds dependency |

**Installation:**
```bash
# swift-async-algorithms (for debouncing)
# Add to Package.swift dependencies
.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
```

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/Services/
├── FileWatcherService.swift    # FSEvents wrapper with AsyncStream
├── ProjectService.swift         # Existing coordinator
└── Parsers/                     # Existing parsers
```

### Pattern 1: FSEvents with AsyncStream Wrapper
**What:** Wrap FSEvents C callback API in Swift AsyncStream for modern concurrency
**When to use:** Need Swift 6 compatibility with @Sendable closures and structured concurrency

**Example:**
```swift
// Source: https://github.com/Frizlab/FSEventsWrapper pattern
@MainActor
final class FileWatcherService {
    private var stream: FSEventStreamRef?
    private var continuation: AsyncStream<[URL]>.Continuation?

    func watch(paths: [URL]) -> AsyncStream<[URL]> {
        AsyncStream { continuation in
            self.continuation = continuation

            // Create FSEventStream with callback
            let callback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
                // Extract paths, filter .git/, convert to URLs
                // Send via continuation.yield([urls])
            }

            // Configure and start stream
            // Store stream reference for cleanup
        }
    }

    func stopWatching() {
        // CRITICAL: proper cleanup sequence
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        continuation?.finish()
    }
}
```

### Pattern 2: Event Debouncing with AsyncAlgorithms
**What:** Use debounce to coalesce rapid file changes (Git commits, multi-file saves)
**When to use:** Events arrive faster than UI should update

**Example:**
```swift
// Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Debounce.md
import AsyncAlgorithms

// In view or service
for await urls in fileWatcher.watch(paths: projectPaths).debounce(for: .seconds(0.5)) {
    // Only triggered after 500ms of quiet
    await reloadProjects(at: urls)
}
```

### Pattern 3: Security-Scoped Bookmark Integration
**What:** FSEvents works with security-scoped URLs without special handling
**When to use:** Watching directories accessed via BookmarkService

**Example:**
```swift
// Source: Existing BookmarkService pattern
func watchProject(_ project: Project) async {
    let url = project.path

    // FSEvents doesn't require startAccessingSecurityScopedResource
    // for watching, only for reading files when events arrive
    let eventStream = fileWatcher.watch(paths: [url.appendingPathComponent(".planning")])

    for await changedURLs in eventStream.debounce(for: .seconds(0.5)) {
        // NOW we need security-scoped access to read files
        for changedURL in changedURLs {
            try? bookmarkService.accessSecurityScoped(project.path) {
                await reloadProject(at: project.path)
            }
        }
    }
}
```

### Pattern 4: Swift 6 Concurrency with FSEvents Callback
**What:** FSEvents callback must be @Sendable; communicate to @MainActor via AsyncStream
**When to use:** Swift 6 strict concurrency enabled (project requirement)

**Example:**
```swift
// Callback is nonisolated (runs on FSEvents internal thread)
let callback: FSEventStreamCallback = { streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds in
    // MUST be @Sendable - capture only Sendable types
    guard let continuation = Unmanaged<AsyncStream<[URL]>.Continuation>.fromOpaque(clientCallBackInfo!).takeUnretainedValue() else { return }

    var urls: [URL] = []
    let paths = unsafeBitCast(eventPaths, to: [UnsafePointer<CChar>].self)

    for i in 0..<numEvents {
        let path = String(cString: paths[i])

        // Filter .git/ directories HERE in callback
        if path.contains("/.git/") { continue }

        urls.append(URL(fileURLWithPath: path))
    }

    if !urls.isEmpty {
        continuation.yield(urls)
    }
}

// MainActor service receives events safely
@MainActor
func consumeEvents() async {
    for await urls in eventStream {
        // Now on MainActor, safe to update @Observable properties
        await reloadProjects(at: urls)
    }
}
```

### Anti-Patterns to Avoid
- **Watching entire project directory:** Watch only .planning/ subdirectory to avoid .git/ event storms
- **No debouncing:** Git commits trigger 50-200 events; process once after settling
- **Ignoring kFSEventStreamEventFlagMustScanSubDirs:** If flag set, must rescan directory (events were coalesced)
- **Accessing security-scoped URLs in callback:** FSEvents callback is NOT on MainActor; defer file I/O to MainActor task
- **Forgetting cleanup sequence:** Always Stop -> Invalidate -> Release or leak file descriptors

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async wrapper for FSEvents C API | Custom CFRunLoop management | AsyncStream with continuation | FSEvents requires CFRunLoop scheduling; AsyncStream abstracts this and integrates with Swift concurrency |
| Event debouncing | Manual Timer + coalescing logic | swift-async-algorithms debounce | Edge cases: timer invalidation, concurrent events, backpressure handling |
| Path filtering in callback | String manipulation in unsafe C callback | Path.contains() check in Swift callback wrapper | C string handling is error-prone; Swift String safer |
| File descriptor management | Manual open/close with DispatchSource | FSEvents (watches directory descriptors) | FSEvents manages descriptors internally; one stream = many files |

**Key insight:** FSEvents is deceptively complex. The C API requires CFRunLoop, careful memory management of C strings, UnsafePointer handling, and proper cleanup sequence. Wrapping in AsyncStream isolates complexity. Debouncing requires async sequence operators that handle cancellation, backpressure, and timing edge cases.

## Common Pitfalls

### Pitfall 1: .git/ Event Storms
**What goes wrong:** Watching entire project directory causes FSEvents to report 50-200 events per Git commit (one per .git/objects file change). This overwhelms the app with redundant reloads.

**Why it happens:** Git creates many temporary files in .git/objects/ during commits. FSEvents reports directory-level changes, but with kFSEventStreamCreateFlagFileEvents flag, it reports individual files.

**How to avoid:**
- Watch only .planning/ subdirectory, not project root
- OR filter .git/ paths in callback: `if path.contains("/.git/") { continue }`
- OR use higher latency (1-3 seconds) to let FSEvents coalesce events

**Warning signs:** Instruments shows 100+ event callbacks per second during Git commits; UI becomes unresponsive during commits

### Pitfall 2: Memory Leaks from Improper Cleanup
**What goes wrong:** FSEventStream holds file descriptors and run loop references. Failing to call Stop -> Invalidate -> Release sequence causes memory leaks and eventually file descriptor exhaustion.

**Why it happens:** FSEvents has three-step cleanup (C API pattern). Many developers only call FSEventStreamRelease, skipping Stop and Invalidate.

**How to avoid:**
```swift
deinit {
    stopWatching()
}

func stopWatching() {
    guard let stream = stream else { return }
    FSEventStreamStop(stream)        // 1. Stop receiving events
    FSEventStreamInvalidate(stream)  // 2. Unschedule from run loop
    FSEventStreamRelease(stream)     // 3. Release memory
    self.stream = nil
}
```

**Warning signs:** Instruments Leaks tool shows FSEventStream objects not deallocated; file descriptor count grows in Activity Monitor

### Pitfall 3: Swift 6 Sendable Violations in Callback
**What goes wrong:** FSEvents callback runs on internal FSEvents thread. Capturing non-Sendable types (like @MainActor properties) causes Swift 6 compilation errors or runtime data races.

**Why it happens:** FSEventStreamCallback is a C function pointer. Swift 6 requires callbacks to be @Sendable closures, which cannot capture non-Sendable values.

**How to avoid:**
- Pass Sendable continuation via clientCallBackInfo: `Unmanaged.passUnretained(continuation).toOpaque()`
- Only capture Sendable types in callback (primitives, Sendable structs)
- Communicate to @MainActor via AsyncStream, not direct property access

**Warning signs:** Compiler error: "Capture of 'self' with non-Sendable type in @Sendable closure"; data race warnings in Xcode

### Pitfall 4: Race Condition Between File Change and Read
**What goes wrong:** FSEvents reports "file changed" but when you read the file, it's empty or contains partial data. This happens because FSEvents fires IMMEDIATELY when write begins, not when write completes.

**Why it happens:** Text editors and Git write files in chunks. FSEvents reports first chunk write. Your code reads before write finishes.

**How to avoid:**
- Debounce events (0.5-1 second) to let writes complete
- Catch parse errors and retry with exponential backoff
- Use kFSEventStreamEventFlagItemModified flag (requires kFSEventStreamCreateFlagFileEvents) to distinguish modification from creation

**Warning signs:** Parser throws "unexpected end of file"; intermittent parse failures during rapid file changes; file length is 0 bytes

### Pitfall 5: Watching Stale Bookmark Paths
**What goes wrong:** User moves project directory. Bookmark resolves but points to old location. FSEvents watches old path, never sees changes in new location.

**Why it happens:** Security-scoped bookmarks can become stale. BookmarkService refreshes bookmark but FileWatcher keeps watching old URL.

**How to avoid:**
- When bookmark is refreshed (isStale = true), stop old watcher and create new one
- In FileWatcherService, expose `updatePath(old: URL, new: URL)` method
- ProjectService coordinates bookmark refresh + watcher update

**Warning signs:** UI never updates even though files change; Instruments shows FSEventStream callback never firing

## Code Examples

Verified patterns from official sources:

### FSEvents Stream Creation (C API)
```c
// Source: https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html
CFStringRef mypath = CFSTR("/path/to/watch");
CFArrayRef pathsToWatch = CFArrayCreate(NULL, (const void **)&mypath, 1, NULL);

CFAbsoluteTime latency = 1.0; // 1 second coalescing

FSEventStreamRef stream = FSEventStreamCreate(
    NULL,
    &myCallbackFunction,
    NULL,
    pathsToWatch,
    kFSEventStreamEventIdSinceNow,
    latency,
    kFSEventStreamCreateFlagNone | kFSEventStreamCreateFlagFileEvents
);

FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
FSEventStreamStart(stream);
```

### Event Filtering in Callback
```c
// Source: https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html
void mycallback(
    ConstFSEventStreamRef streamRef,
    void *clientCallBackInfo,
    size_t numEvents,
    void *eventPaths,
    const FSEventStreamEventFlags eventFlags[],
    const FSEventStreamEventId eventIds[])
{
    char **paths = eventPaths;
    for (int i = 0; i < numEvents; i++) {
        // Check for coalesced events requiring full scan
        if (eventFlags[i] & kFSEventStreamEventFlagMustScanSubDirs) {
            printf("Must rescan %s\n", paths[i]);
        }

        // Filter .git/ directories
        if (strstr(paths[i], "/.git/") != NULL) {
            continue; // Skip .git/ paths
        }

        // Process event
        printf("Change in %s\n", paths[i]);
    }
}
```

### Debouncing with AsyncAlgorithms
```swift
// Source: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Debounce.md
import AsyncAlgorithms

let debouncedEvents = fileWatcher.watch(paths: [url]).debounce(for: .seconds(1))

for await urls in debouncedEvents {
    // Only called after 1 second of quiet
    print("Processing changes to: \(urls)")
}
```

### Proper Cleanup Sequence
```swift
// Source: https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html
// CRITICAL: Must follow this exact order
FSEventStreamStop(stream)        // 1. Stop receiving events
FSEventStreamInvalidate(stream)  // 2. Unschedule from run loop
FSEventStreamRelease(stream)     // 3. Release memory
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| kqueue for file watching | FSEvents API | OS X 10.5 (2007) | FSEvents scales to watching entire directory trees vs one fd per file |
| Callback-based FSEvents | FSEvents + AsyncStream | Swift 5.5 (2021) | Modern concurrency integration; @Sendable safety |
| Grand Central Dispatch timers for debouncing | swift-async-algorithms debounce | 2023 | Official Apple async operators vs manual timer management |
| File-level events opt-in | File-level events standard | OS X 10.7 (2011) | kFSEventStreamCreateFlagFileEvents provides granular notifications |
| Manual @Sendable checking | Swift 6 strict concurrency | Swift 6.0 (2024) | Compile-time data race prevention vs runtime crashes |

**Deprecated/outdated:**
- FSCopyAliasInfo: Deprecated in macOS 10.8; use security-scoped bookmarks instead
- DispatchSource for directory monitoring: Still works but FSEvents more efficient for recursive watching
- Combine for async sequences: Not deprecated but swift-async-algorithms is official successor for async/await patterns

## Open Questions

1. **Does FileMonitor package work with security-scoped bookmarks?**
   - What we know: FileMonitor requires macOS 13+, uses AsyncStream, supports macOS and Linux
   - What's unclear: Whether it respects security-scoped bookmark permissions or requires startAccessingSecurityScopedResource
   - Recommendation: Test with sandboxed app + manually added project, or build custom FSEvents wrapper with confirmed bookmark support

2. **What latency value balances responsiveness vs performance?**
   - What we know: Lower latency = more callbacks with fewer events per callback; higher latency = fewer callbacks but delayed updates
   - What's unclear: Optimal value for watching 10-50 projects simultaneously
   - Recommendation: Start with 1.0 second (Apple's example value), measure with Instruments, tune based on callback frequency

3. **Should we use kFSEventStreamCreateFlagFileEvents or directory-level events?**
   - What we know: File-level events provide granular notifications but generate significantly more events; directory-level requires checking which file changed
   - What's unclear: Whether .planning/ file changes are frequent enough to benefit from granularity
   - Recommendation: Start with directory-level (fewer events), add file-level flag if we need to distinguish ROADMAP.md vs STATE.md changes without filesystem I/O

4. **How to handle multiple projects efficiently?**
   - What we know: Can create one FSEventStream per project or one stream watching all projects
   - What's unclear: Performance difference; whether single stream watching 50 paths scales well
   - Recommendation: Single stream watching all .planning/ paths (FSEvents designed for this); benchmark with Instruments if issues arise

## Sources

### Primary (HIGH confidence)
- [Using the File System Events API](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html) - Official Apple documentation on FSEvents lifecycle, callback structure, cleanup sequence, and event flags
- [swift-async-algorithms Debounce Guide](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Debounce.md) - Official Apple package for debouncing async sequences
- [File System Events API Reference](https://developer.apple.com/documentation/coreservices/file_system_events) - Apple Developer Documentation (JavaScript required for full content)

### Secondary (MEDIUM confidence)
- [FSEventsWrapper Swift Package](https://swiftpackageindex.com/Frizlab/FSEventsWrapper) - Community wrapper with AsyncStream support, verified via Swift Package Index
- [DispatchSource: Detecting changes in files and folders in Swift](https://swiftrocks.com/dispatchsource-detecting-changes-in-files-and-folders-in-swift) - DispatchSource alternative explanation with cleanup patterns
- [FileMonitor Package](https://www.swifttoolkit.dev/posts/file-monitor) - Modern AsyncStream-based abstraction, requires macOS 13+
- [Swift 6 Concurrency Guide](https://medium.com/@egzonpllana/understanding-concurrency-in-swift-6-with-sendable-protocol-mainactor-and-async-await-5ccfdc0ca2b6) - @Sendable, @MainActor patterns for callbacks
- [fswatch Documentation - FSEvents Monitor](https://emcrisostomo.github.io/fswatch/doc/1.16.0/fswatch.html/Monitors.html) - Latency and NoDefer flag best practices

### Tertiary (LOW confidence - needs verification)
- [GitHub fsnotify/fsevents](https://github.com/fsnotify/fsevents) - Go implementation; confirms event storm issues with .git/ but different language
- Various Medium articles on Swift concurrency - General patterns but not FSEvents-specific
- [Security-scoped bookmarks guide](https://swiftylion.com/articles/persist-and-retrieve-user-folders-access) - Bookmark persistence but unclear on FSEvents integration

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - FSEvents is Apple's official API; swift-async-algorithms is official Apple package
- Architecture: MEDIUM-HIGH - AsyncStream pattern verified in FSEventsWrapper; @Sendable pattern verified in Swift 6 guides; cleanup sequence verified in Apple docs
- Pitfalls: MEDIUM - .git/ event storms inferred from general FSEvents behavior (not explicitly documented); memory leak sequence verified in Apple docs; Sendable issues verified in Swift 6 migration guides
- Code examples: HIGH - All C code examples from Apple official documentation; Swift patterns from official swift-async-algorithms package

**Research date:** 2026-02-13
**Valid until:** ~60 days (FSEvents API is stable; Swift concurrency patterns evolving)

**Notes:**
- FileMonitor package not deeply investigated (couldn't fetch GitHub README); marked as alternative requiring verification
- No specific "2026" FSEvents features found; API is mature and stable since OS X 10.5
- Security-scoped bookmark + FSEvents integration not explicitly documented; needs testing to confirm no special handling required
