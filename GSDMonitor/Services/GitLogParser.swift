import Foundation

// MARK: - GitLogParser

final class GitLogParser: Sendable {

    // GSD commit patterns — commits matching any of these are NOT drift
    private static let gsdPatterns: [String] = [
        #"^(feat|fix|docs|refactor|chore|test|style)\(\d+-\d+\):"#,   // phase plans: feat(16-01):
        #"^(feat|fix|docs|refactor|chore|test|style)\(quick-\d+\):"#, // quick tasks: docs(quick-32):
        #"^(feat|fix|docs|refactor|chore|test|style)\(phase-\d+\):"#, // phase-level: docs(phase-16):
        #"^wip:"#,                                                      // work in progress
        #"^docs\(\d+\):"#,                                             // docs(16): style
        #"^docs\(roadmap\):"#,                                         // roadmap updates
        #"^docs: (create|define|start) milestone"#,                    // milestone setup
        #"^docs: complete milestone"#,                                 // milestone completion
        #"^chore: (complete|archive|cleanup)"#,                        // milestone lifecycle
        #"^Merge"#,                                                    // merge commits
    ]

    private static let compiledPatterns: [NSRegularExpression] = {
        gsdPatterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        }
    }()

    // MARK: - Public API

    func parseDriftCommits(at projectPath: URL) async -> [DriftCommit] {
        // Step 1: Get git log with hash, subject, author-date, and numstat in one pass
        // Format: "%h|%s|%ai" followed by numstat lines, separated by blank lines
        let logOutput = await runGit(
            args: ["log", "--format=%h%x1E%s%x1E%ai", "--numstat", "-50"],
            at: projectPath
        )
        guard !logOutput.isEmpty else { return [] }

        let commits = parseLogOutput(logOutput)
        return commits
            .filter { !isGSDCommit($0.message) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Parsing

    private struct RawCommit {
        let hash: String
        let message: String
        let date: Date
        var filesChanged: Int
    }

    /// Parse interleaved git log output:
    /// "%h|%s|%ai" lines followed by numstat lines (added\tdeleted\tfile), separated by blank lines.
    private func parseLogOutput(_ output: String) -> [DriftCommit] {
        var results: [DriftCommit] = []
        let lines = output.components(separatedBy: "\n")

        var currentCommit: RawCommit? = nil
        var fileCount = 0

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

        // Fallback formatter for git's default "%ai" format: "2026-02-18 14:30:00 +0100"
        let gitDateFormatter = DateFormatter()
        gitDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        gitDateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                // Blank line — flush current commit
                if let commit = currentCommit {
                    results.append(DriftCommit(
                        id: commit.hash,
                        message: commit.message,
                        date: commit.date,
                        filesChanged: fileCount
                    ))
                }
                currentCommit = nil
                fileCount = 0
                continue
            }

            // Check if this is a commit header line: "hash<RS>subject<RS>date"
            let parts = trimmed.split(separator: "\u{1E}", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count == 3 {
                let hashPart = String(parts[0])
                let messagePart = String(parts[1])
                let datePart = String(parts[2])

                // A commit header hash is 7 hex chars
                let isHash = hashPart.count <= 12 && hashPart.allSatisfy({ $0.isHexDigit })

                if isHash {
                    // Flush previous commit first
                    if let commit = currentCommit {
                        results.append(DriftCommit(
                            id: commit.hash,
                            message: commit.message,
                            date: commit.date,
                            filesChanged: fileCount
                        ))
                    }
                    fileCount = 0

                    // Parse date — try ISO first, then git format
                    let parsedDate = isoFormatter.date(from: datePart) ?? gitDateFormatter.date(from: datePart) ?? Date()
                    currentCommit = RawCommit(hash: hashPart, message: messagePart, date: parsedDate, filesChanged: 0)
                    continue
                }
            }

            // Otherwise it's a numstat line: "added\tdeleted\tfilename" or "-\t-\tfilename" (binary)
            if currentCommit != nil {
                let tabParts = trimmed.components(separatedBy: "\t")
                if tabParts.count >= 3 {
                    fileCount += 1
                }
            }
        }

        // Flush last commit if no trailing blank line
        if let commit = currentCommit {
            results.append(DriftCommit(
                id: commit.hash,
                message: commit.message,
                date: commit.date,
                filesChanged: fileCount
            ))
        }

        return results
    }

    // MARK: - GSD Pattern Matching

    private func isGSDCommit(_ message: String) -> Bool {
        let range = NSRange(message.startIndex..., in: message)
        return Self.compiledPatterns.contains { regex in
            regex.firstMatch(in: message, options: [], range: range) != nil
        }
    }

    // MARK: - Git Process Helper

    private func runGit(args: [String], at directory: URL) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["git"] + args
                process.currentDirectoryURL = directory

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: "")
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
        }
    }
}
