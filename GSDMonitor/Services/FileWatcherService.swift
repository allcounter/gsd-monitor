import Foundation
import CoreServices

@MainActor
final class FileWatcherService {
    private nonisolated(unsafe) var stream: FSEventStreamRef?
    private var continuation: AsyncStream<[URL]>.Continuation?
    private nonisolated(unsafe) var continuationPointer: UnsafeMutablePointer<AsyncStream<[URL]>.Continuation>?

    // MARK: - Public API

    /// Watch the given paths for file system changes
    /// - Parameter paths: Array of URLs to watch (typically .planning/ directories)
    /// - Returns: AsyncStream that yields arrays of changed URLs
    func watch(paths: [URL]) -> AsyncStream<[URL]> {
        // Create AsyncStream with continuation
        let stream = AsyncStream<[URL]> { continuation in
            self.continuation = continuation

            // Allocate pointer to pass continuation to C callback
            let pointer = UnsafeMutablePointer<AsyncStream<[URL]>.Continuation>.allocate(capacity: 1)
            pointer.initialize(to: continuation)
            self.continuationPointer = pointer

            // Convert Swift URLs to CFArray of CFStrings
            let pathsToWatch = paths.map { $0.path as CFString } as CFArray

            // Configure callback context to pass continuation pointer
            var context = FSEventStreamContext(
                version: 0,
                info: UnsafeMutableRawPointer(pointer),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            // Create FSEventStream
            guard let eventStream = FSEventStreamCreate(
                kCFAllocatorDefault,
                fsEventsCallback,
                &context,
                pathsToWatch,
                FSEventsGetCurrentEventId(),
                1.0, // 1 second latency (research recommendation)
                UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer)
            ) else {
                // Clean up allocated pointer on failure
                pointer.deinitialize(count: 1)
                pointer.deallocate()
                self.continuationPointer = nil
                continuation.finish()
                return
            }

            // Schedule on main dispatch queue (service is @MainActor)
            FSEventStreamSetDispatchQueue(eventStream, DispatchQueue.main)

            // Start receiving events
            guard FSEventStreamStart(eventStream) else {
                FSEventStreamInvalidate(eventStream)
                FSEventStreamRelease(eventStream)
                continuation.finish()
                return
            }

            // Store stream reference for cleanup
            self.stream = eventStream
        }

        return stream
    }

    /// Stop watching for file system changes
    func stopWatching() {
        guard let stream = stream else { return }

        // CRITICAL: Execute cleanup sequence in correct order
        // 1. Stop receiving events
        FSEventStreamStop(stream)

        // 2. Unschedule from run loop
        FSEventStreamInvalidate(stream)

        // 3. Release memory
        FSEventStreamRelease(stream)

        // Finish AsyncStream
        continuation?.finish()

        // Deallocate continuation pointer
        continuationPointer?.deinitialize(count: 1)
        continuationPointer?.deallocate()

        // Clear references
        self.stream = nil
        self.continuation = nil
        self.continuationPointer = nil
    }

    /// Update watched paths by stopping current stream and creating new one
    /// - Parameter paths: New array of URLs to watch
    func updatePaths(_ paths: [URL]) -> AsyncStream<[URL]> {
        stopWatching()
        return watch(paths: paths)
    }

    deinit {
        // Ensure cleanup on deinitialization
        // Note: deinit is nonisolated, so we must perform cleanup directly
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            continuation?.finish()
        }
        // Always clean up pointer — it may be allocated even if stream creation failed
        if let pointer = continuationPointer {
            pointer.deinitialize(count: 1)
            pointer.deallocate()
        }
    }
}

// MARK: - FSEvents Callback

/// FSEvents callback function (C function pointer)
/// This is nonisolated and runs on FSEvents internal thread
private func fsEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    // Retrieve continuation from context
    guard let info = clientCallBackInfo else { return }
    let continuationPointer = info.assumingMemoryBound(to: AsyncStream<[URL]>.Continuation.self)
    let continuation = continuationPointer.pointee

    // Extract paths from C array (cast to NSArray since we used kFSEventStreamCreateFlagUseCFTypes)
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]

    var changedURLs: [URL] = []

    for i in 0..<numEvents {
        let path = paths[i]

        // Filter out .git/ paths to prevent event storms during Git operations
        if path.contains("/.git/") {
            continue
        }

        changedURLs.append(URL(fileURLWithPath: path))
    }

    // Yield non-empty arrays to AsyncStream
    if !changedURLs.isEmpty {
        continuation.yield(changedURLs)
    }
}
