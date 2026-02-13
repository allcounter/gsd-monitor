import Foundation

enum BookmarkError: Error, Sendable {
    case accessDenied
    case staleAndUnrefreshable
    case creationFailed(Error)
}

final class BookmarkService: @unchecked Sendable {
    private let defaults: UserDefaults
    private let suiteName = "com.gsdmonitor.bookmarks"

    nonisolated init() {
        // UserDefaults suite for isolated bookmark storage
        // UserDefaults is thread-safe for reads/writes, so @unchecked Sendable is safe here
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    // MARK: - Bookmark Lifecycle

    /// Creates a security-scoped bookmark for the given URL
    nonisolated func saveBookmark(for url: URL, identifier: String) throws {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(bookmarkData, forKey: "bookmark_\(identifier)")
        } catch {
            throw BookmarkError.creationFailed(error)
        }
    }

    /// Resolves a stored bookmark, refreshing if stale
    nonisolated func resolveBookmark(for identifier: String) throws -> URL? {
        guard let bookmarkData = defaults.data(forKey: "bookmark_\(identifier)") else {
            return nil
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // If stale, attempt to refresh
            if isStale {
                do {
                    try saveBookmark(for: url, identifier: identifier)
                } catch {
                    throw BookmarkError.staleAndUnrefreshable
                }
            }

            return url
        } catch {
            throw BookmarkError.accessDenied
        }
    }

    /// Removes a stored bookmark
    nonisolated func removeBookmark(for identifier: String) {
        defaults.removeObject(forKey: "bookmark_\(identifier)")
    }

    /// Returns all stored bookmark identifiers
    nonisolated func allBookmarkIdentifiers() -> [String] {
        let allKeys = defaults.dictionaryRepresentation().keys
        return allKeys
            .filter { $0.hasPrefix("bookmark_") }
            .map { String($0.dropFirst("bookmark_".count)) }
    }

    // MARK: - Security-Scoped Access

    /// Wraps an operation with security-scoped resource access
    nonisolated func accessSecurityScoped<T>(_ url: URL, operation: () throws -> T) throws -> T {
        guard url.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        return try operation()
    }
}
