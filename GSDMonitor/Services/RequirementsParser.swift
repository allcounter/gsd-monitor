import Foundation
import Markdown

struct RequirementsParser {
    func parse(_ content: String) -> [Requirement] {
        guard !content.isEmpty else { return [] }

        let document = Document(parsing: content)
        var walker = RequirementsWalker()
        walker.visit(document)

        // Extract traceability mappings
        let traceabilityMap = extractTraceability(from: content)

        // Merge traceability data with requirements
        return walker.requirements.map { requirement in
            let phases = traceabilityMap[requirement.id] ?? []
            return Requirement(
                id: requirement.id,
                category: requirement.category,
                description: requirement.description,
                mappedToPhases: phases,
                status: requirement.status
            )
        }
    }

    private func extractTraceability(from content: String) -> [String: [Int]] {
        var map: [String: [Int]] = [:]

        // Find the Traceability section
        guard content.contains("## Traceability") else {
            return map
        }

        let lines = content.components(separatedBy: .newlines)
        var inTraceability = false

        for line in lines {
            if line.contains("## Traceability") {
                inTraceability = true
                continue
            }

            if inTraceability && line.starts(with: "##") {
                // Next section started
                break
            }

            if inTraceability && line.contains("|") && !line.contains("---") && !line.contains("Requirement") {
                // Parse table row: | REQ-ID | Phase N | Status |
                let columns = line.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                if columns.count >= 2 {
                    let reqId = columns[0]
                    let phaseText = columns[1]

                    // Extract all phase numbers from "Phase N, Phase M" format
                    let phasePattern = #"Phase\s+(\d+)"#
                    if let regex = try? NSRegularExpression(pattern: phasePattern) {
                        let matches = regex.matches(in: phaseText, range: NSRange(phaseText.startIndex..., in: phaseText))
                        let phaseNumbers = matches.compactMap { match -> Int? in
                            guard let numberRange = Range(match.range(at: 1), in: phaseText) else { return nil }
                            return Int(String(phaseText[numberRange]))
                        }
                        if !phaseNumbers.isEmpty {
                            map[reqId] = phaseNumbers
                        }
                    }
                }
            }
        }

        return map
    }
}

// MARK: - MarkupWalker for Requirements

private struct RequirementsWalker: MarkupWalker {
    var requirements: [Requirement] = []
    var currentCategory: String = ""

    mutating func visitHeading(_ heading: Heading) {
        if heading.level == 3 {
            // Collect text from heading
            currentCategory = heading.plainText
        }
        descendInto(heading)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        // Check if item has a checkbox
        if let checkbox = listItem.checkbox {
            let isChecked = (checkbox == .checked)

            // Get the text from the list item
            let text = listItem.format()

            // Parse requirement from text
            let pattern = #"\*\*([A-Z]+-\d+)\*\*:\s*(.+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let idRange = Range(match.range(at: 1), in: text),
               let descRange = Range(match.range(at: 2), in: text) {

                let id = String(text[idRange])
                let description = String(text[descRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let status: RequirementStatus = isChecked ? .validated : .active

                let requirement = Requirement(
                    id: id,
                    category: currentCategory,
                    description: description,
                    mappedToPhases: [],
                    status: status
                )
                requirements.append(requirement)
            }
        }

        descendInto(listItem)
    }
}
