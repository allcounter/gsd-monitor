import Foundation
import Markdown

struct RoadmapParser: Sendable {
    func parse(_ content: String) throws -> Roadmap {
        // Extract phases from HTML details blocks (pre-pass)
        let detailsPhases = extractPhasesFromDetailsBlocks(content)

        // Extract phases from Markdown AST (standard ### Phase N: headings)
        let document = Document(parsing: content)
        var walker = RoadmapWalker()
        walker.visit(document)

        // Merge: details phases provide accurate completion status from <details> blocks.
        // AST phases provide richer metadata (goal, deps) but may miss completion status.
        // Strategy: start with details phases, then merge AST phases but preserve done status.
        var phasesByNumber: [Int: Phase] = [:]
        for phase in detailsPhases {
            phasesByNumber[phase.number] = phase
        }
        for phase in walker.phases {
            if let existing = phasesByNumber[phase.number] {
                // AST has richer metadata — use it, but keep resolved status from details extraction
                let mergedStatus = existing.isResolved ? existing.status : phase.status
                phasesByNumber[phase.number] = Phase(
                    number: phase.number,
                    name: phase.name,
                    goal: phase.goal,
                    dependencies: phase.dependencies,
                    requirements: phase.requirements,
                    milestones: phase.milestones,
                    status: mergedStatus
                )
            } else {
                phasesByNumber[phase.number] = phase
            }
        }

        let mergedPhases = phasesByNumber.values.sorted { $0.number < $1.number }
        let milestones = parseMilestones(from: content, phases: mergedPhases)

        return Roadmap(
            projectName: walker.projectName,
            phases: mergedPhases,
            milestones: milestones
        )
    }

    private func parseMilestones(from content: String, phases: [Phase]) -> [Milestone] {
        var milestones: [Milestone] = []

        // Only parse if ## Milestones section exists
        guard content.contains("## Milestones") else { return milestones }

        // Pattern matches lines like:
        // - ✅ **v1.0 MVP** - Phases 1-5 (shipped 2026-02-14) - [archive](...)
        // - 🚧 **v1.1 Visual Overhaul** - Phases 6-12 (in progress)
        let pattern = #"- (?:✅|🚧) \*\*(.+?)\*\* - Phases? (\d+)(?:[-–](\d+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return milestones
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let nameRange = Range(match.range(at: 1), in: content),
                  let startRange = Range(match.range(at: 2), in: content),
                  let startNum = Int(String(content[startRange])) else { continue }

            let name = String(content[nameRange])
            let endNum: Int
            if match.numberOfRanges >= 4,
               let endRange = Range(match.range(at: 3), in: content) {
                endNum = Int(String(content[endRange])) ?? startNum
            } else {
                endNum = startNum
            }
            let phaseNumbers = Array(startNum...endNum)

            // Derive isComplete: all phases in range must be resolved (done, cancelled, or deferred)
            let relevantPhases = phases.filter { phaseNumbers.contains($0.number) }
            let isComplete = !relevantPhases.isEmpty && relevantPhases.allSatisfy { $0.isResolved }

            milestones.append(Milestone(name: name, phaseNumbers: phaseNumbers, isComplete: isComplete))
        }

        return milestones
    }

    private func extractPhasesFromDetailsBlocks(_ content: String) -> [Phase] {
        var phases: [Phase] = []

        // Find all <details>...</details> blocks
        let detailsPattern = "(?s)<details>.*?</details>"
        guard let detailsRegex = try? NSRegularExpression(pattern: detailsPattern, options: []) else {
            return phases
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let detailsMatches = detailsRegex.matches(in: content, options: [], range: nsRange)

        // Phase patterns inside details blocks:
        // 1. Checkbox: "- [x] Phase 1: Name (3/3 plans) - date" or "- [x] **Phase 1: Name**"
        // 2. Heading: "### Phase 1: Name" or "#### Phase 1: Name"
        let checkboxPattern = #"^- \[([ x~])\] \*{0,2}Phase (\d+):\s*([^\n*]+?)\*{0,2}(?:\s*\(\d+/\d+ plans?\))?(?:\s*[-—].+)?$"#
        let headingPattern = #"^#{2,4} Phase (\d+):\s*(.+)$"#

        guard let checkboxRegex = try? NSRegularExpression(pattern: checkboxPattern, options: [.anchorsMatchLines]),
              let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: [.anchorsMatchLines]) else {
            return phases
        }

        for detailsMatch in detailsMatches {
            guard let detailsRange = Range(detailsMatch.range, in: content) else { continue }
            let detailsBlock = String(content[detailsRange])
            let blockNSRange = NSRange(detailsBlock.startIndex..<detailsBlock.endIndex, in: detailsBlock)

            // Check if summary indicates completion, cancellation, or deferral
            let blockLower = detailsBlock.lowercased()
            let summaryDone = blockLower.contains("shipped") || blockLower.contains("complete") || detailsBlock.contains("✅")
            let summaryCancelled = blockLower.contains("cancelled") || blockLower.contains("canceled")
            let summaryDeferred = blockLower.contains("deferred")

            // 1. Checkbox matches
            let checkboxMatches = checkboxRegex.matches(in: detailsBlock, options: [], range: blockNSRange)
            for match in checkboxMatches {
                guard match.numberOfRanges >= 4,
                      let checkStateRange = Range(match.range(at: 1), in: detailsBlock),
                      let numberRange = Range(match.range(at: 2), in: detailsBlock),
                      let nameRange = Range(match.range(at: 3), in: detailsBlock),
                      let number = Int(String(detailsBlock[numberRange])) else { continue }

                let checkState = String(detailsBlock[checkStateRange])
                let status: PhaseStatus
                if summaryCancelled {
                    status = .cancelled
                } else if summaryDeferred {
                    status = .deferred
                } else if checkState == "x" || summaryDone {
                    status = .done
                } else if checkState == "~" {
                    // [~] without explicit keyword — check phase content for hints
                    status = .cancelled
                } else {
                    status = .notStarted
                }
                let cleanName = String(detailsBlock[nameRange]).trimmingCharacters(in: .whitespaces)

                phases.append(Phase(number: number, name: cleanName, goal: "", status: status))
            }

            // 2. Heading matches (only if no checkbox matches found for this block)
            let foundNumbers = Set(phases.suffix(checkboxMatches.count).map { $0.number })
            let headingMatches = headingRegex.matches(in: detailsBlock, options: [], range: blockNSRange)
            for match in headingMatches {
                guard match.numberOfRanges >= 3,
                      let numberRange = Range(match.range(at: 1), in: detailsBlock),
                      let nameRange = Range(match.range(at: 2), in: detailsBlock),
                      let number = Int(String(detailsBlock[numberRange])) else { continue }

                // Skip if already found via checkbox
                guard !foundNumbers.contains(number) else { continue }

                let status: PhaseStatus = summaryDone ? .done : .notStarted
                let cleanName = String(detailsBlock[nameRange])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespaces)

                phases.append(Phase(number: number, name: cleanName, goal: "", status: status))
            }
        }

        return phases
    }
}

private struct RoadmapWalker: MarkupWalker {
    var projectName: String?
    var phases: [Phase] = []

    private var phaseCompletionStatus: [Int: Bool] = [:]
    private var currentPhaseBuilder: PhaseBuilder?
    private var inPhasesSection = false

    mutating func visitHeading(_ heading: Heading) {
        let text = heading.plainText.trimmingCharacters(in: .whitespaces)

        if heading.level == 1 {
            if text.starts(with: "Roadmap:") {
                projectName = text.replacingOccurrences(of: "Roadmap:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }

        if heading.level == 2 {
            if text.lowercased() == "phases" {
                inPhasesSection = true
            } else {
                inPhasesSection = false
            }

            if text.lowercased().contains("phase details") {
                if let builder = currentPhaseBuilder {
                    phases.append(builder.build())
                    currentPhaseBuilder = nil
                }
            }
        }

        if heading.level == 3 {
            if let builder = currentPhaseBuilder {
                phases.append(builder.build())
            }

            if let (number, name) = extractPhaseInfo(from: text) {
                let status: PhaseStatus
                let textLower = text.lowercased()
                if textLower.contains("cancelled") || textLower.contains("canceled") {
                    status = .cancelled
                } else if textLower.contains("deferred") {
                    status = .deferred
                } else if phaseCompletionStatus[number] == true {
                    status = .done
                } else {
                    status = .notStarted
                }
                currentPhaseBuilder = PhaseBuilder(number: number, name: name, status: status)
            } else {
                currentPhaseBuilder = nil
            }
        }

        descendInto(heading)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        // Use format() to preserve markdown markers like **
        let rawText = paragraph.format().trimmingCharacters(in: .whitespaces)
        // Also get plain text for fallback matching
        let plainText = paragraph.plainText.trimmingCharacters(in: .whitespaces)

        if rawText.starts(with: "**Goal**:") || rawText.starts(with: "**Goal:**") ||
           plainText.starts(with: "Goal:") || plainText.starts(with: "Goal :") {
            let goal = plainText
                .replacingOccurrences(of: "Goal:", with: "")
                .replacingOccurrences(of: "Goal :", with: "")
                .trimmingCharacters(in: .whitespaces)
            currentPhaseBuilder?.goal = goal
        } else if rawText.starts(with: "**Depends on**:") || rawText.starts(with: "**Depends on:**") ||
                  plainText.starts(with: "Depends on:") || plainText.starts(with: "Depends on :") {
            let deps = plainText
                .replacingOccurrences(of: "Depends on:", with: "")
                .replacingOccurrences(of: "Depends on :", with: "")
                .trimmingCharacters(in: .whitespaces)
            currentPhaseBuilder?.dependencies = [deps]
        } else if rawText.starts(with: "**Requirements**:") || rawText.starts(with: "**Requirements:**") ||
                  plainText.starts(with: "Requirements:") || plainText.starts(with: "Requirements :") {
            let reqs = plainText
                .replacingOccurrences(of: "Requirements:", with: "")
                .replacingOccurrences(of: "Requirements :", with: "")
                .trimmingCharacters(in: .whitespaces)
            currentPhaseBuilder?.requirements = reqs.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        }

        descendInto(paragraph)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let text = listItem.format()

        if inPhasesSection {
            let isComplete = listItem.checkbox == .checked

            if let (number, _) = extractPhaseInfo(from: text) {
                phaseCompletionStatus[number] = isComplete
            }
        }

        descendInto(listItem)
    }

    mutating func visitDocument(_ document: Document) {
        descendInto(document)

        if let builder = currentPhaseBuilder {
            phases.append(builder.build())
            currentPhaseBuilder = nil
        }
    }

    private func extractPhaseInfo(from text: String) -> (number: Int, name: String)? {
        let pattern = #"(?:\*\*)?Phase\s+(\d+):\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else {
            return nil
        }

        guard match.numberOfRanges >= 3 else { return nil }

        let numberRange = Range(match.range(at: 1), in: text)
        let nameRange = Range(match.range(at: 2), in: text)

        guard let numberRange = numberRange, let nameRange = nameRange else {
            return nil
        }

        let numberText = String(text[numberRange])
        let nameText = String(text[nameRange])

        guard let number = Int(numberText) else {
            return nil
        }

        let cleanName = nameText
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " - ").first?
            .trimmingCharacters(in: .whitespaces) ?? nameText

        return (number, cleanName)
    }
}

private class PhaseBuilder {
    let number: Int
    let name: String
    var goal: String = ""
    var dependencies: [String] = []
    var requirements: [String] = []
    var milestones: [String] = []
    let status: PhaseStatus

    init(number: Int, name: String, status: PhaseStatus) {
        self.number = number
        self.name = name
        self.status = status
    }

    func build() -> Phase {
        Phase(
            number: number,
            name: name,
            goal: goal,
            dependencies: dependencies,
            requirements: requirements,
            milestones: milestones,
            status: status
        )
    }
}
