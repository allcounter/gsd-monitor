import Foundation

struct DiscoveredProject: Sendable, Equatable {
    let name: String       // directory name (last path component of parent)
    let path: URL          // project root (parent of .planning/)
    let scanSource: URL    // which root directory found this project
}

struct ProjectDiscoveryService: Sendable {
    private let excludedDirectories: Set<String> = [
        "node_modules",
        ".git",
        "build",
        "DerivedData",
        ".build",
        "Pods",
        "Carthage"
    ]

    private let maxDepth = 6

    /// Discovers projects in a single root directory (runs on background thread)
    func discoverProjects(in rootURL: URL) async -> [DiscoveredProject] {
        let excludedDirs = excludedDirectories
        let maxDepthLimit = maxDepth

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var discovered: [DiscoveredProject] = []

                guard let enumerator = FileManager.default.enumerator(
                    at: rootURL,
                    includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
                    options: [.skipsPackageDescendants]
                ) else {
                    continuation.resume(returning: [])
                    return
                }

                while let url = enumerator.nextObject() as? URL {
                    if enumerator.level > maxDepthLimit {
                        enumerator.skipDescendants()
                        continue
                    }

                    if let isSymlink = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink,
                       isSymlink {
                        enumerator.skipDescendants()
                        continue
                    }

                    let lastComponent = url.lastPathComponent

                    if excludedDirs.contains(lastComponent) {
                        enumerator.skipDescendants()
                        continue
                    }

                    if lastComponent == ".planning" {
                        let roadmapURL = url.appendingPathComponent("ROADMAP.md")
                        if FileManager.default.fileExists(atPath: roadmapURL.path) {
                            let projectRoot = url.deletingLastPathComponent()
                            let projectName = projectRoot.lastPathComponent

                            discovered.append(DiscoveredProject(
                                name: projectName,
                                path: projectRoot,
                                scanSource: rootURL
                            ))
                        }
                        enumerator.skipDescendants()
                    }
                }

                continuation.resume(returning: discovered)
            }
        }
    }

    /// Discovers projects in multiple root directories
    func discoverProjects(in rootURLs: [URL]) async -> [DiscoveredProject] {
        var allProjects: [DiscoveredProject] = []
        var seenPaths: Set<String> = []

        for rootURL in rootURLs {
            let projects = await discoverProjects(in: rootURL)

            for project in projects {
                // Remove duplicates by path
                if !seenPaths.contains(project.path.path) {
                    allProjects.append(project)
                    seenPaths.insert(project.path.path)
                }
            }
        }

        return allProjects
    }
}
