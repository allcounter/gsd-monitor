import Foundation
import Markdown

struct StateParser: Sendable {
    func parse(_ content: String) throws -> State {
        let document = Document(parsing: content)
        var walker = StateWalker()
        walker.visit(document)

        return State(
            currentPhase: walker.currentPhase,
            currentPlan: walker.currentPlan,
            status: walker.status ?? "",
            lastActivity: walker.lastActivity,
            decisions: walker.decisions,
            blockers: walker.blockers,
            totalExecutionTime: walker.totalExecutionTime,
            currentMilestone: walker.currentMilestone
        )
    }
}

private struct StateWalker: MarkupWalker {
    var currentPhase: Int?
    var currentPlan: Int?
    var status: String?
    var lastActivity: String?
    var decisions: [String] = []
    var blockers: [String] = []
    var totalExecutionTime: String?
    var currentMilestone: String?

    private var inDecisionsSection = false
    private var inBlockersSection = false
    private var inVelocitySection = false

    mutating func visitHeading(_ heading: Heading) {
        let text = heading.plainText.trimmingCharacters(in: .whitespaces)

        if text.lowercased().contains("decisions") {
            inDecisionsSection = true
            inBlockersSection = false
            inVelocitySection = false
        } else if text.lowercased().contains("blockers") || text.lowercased().contains("concerns") {
            inBlockersSection = true
            inDecisionsSection = false
            inVelocitySection = false
        } else if heading.level <= 2 {
            inDecisionsSection = false
            inBlockersSection = false
            inVelocitySection = false
        }

        descendInto(heading)
    }

    mutating func visitParagraph(_ paragraph: Paragraph) {
        let text = paragraph.plainText.trimmingCharacters(in: .whitespaces)

        if text.starts(with: "Phase:") {
            if let regex = try? NSRegularExpression(pattern: #"Phase:\s*(\d+)"#),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let numberRange = Range(match.range(at: 1), in: text),
               let number = Int(String(text[numberRange])) {
                currentPhase = number
            }
        }

        if text.starts(with: "Plan:") {
            if let regex = try? NSRegularExpression(pattern: #"Plan:\s*(\d+)"#),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let numberRange = Range(match.range(at: 1), in: text),
               let number = Int(String(text[numberRange])) {
                currentPlan = number
            }
        }

        if text.starts(with: "Status:") {
            status = text.replacingOccurrences(of: "Status:", with: "").trimmingCharacters(in: .whitespaces)
        }

        if text.starts(with: "Last activity:") {
            lastActivity = text.replacingOccurrences(of: "Last activity:", with: "").trimmingCharacters(in: .whitespaces)
        }

        if text.starts(with: "Current focus:") {
            // Extract milestone name from parentheses, e.g. "v1.1 Visual Overhaul"
            if let match = text.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
                var captured = String(text[match])
                // Strip surrounding parentheses
                captured = captured.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
                currentMilestone = captured
            }
        }

        if text.contains("Velocity:") {
            inVelocitySection = true
        }

        descendInto(paragraph)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        let formattedText = listItem.format()
        // Strip leading bullet marker ("- " or "* ") and trim for plain text extraction
        let stripped = formattedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let text: String
        if stripped.hasPrefix("- ") {
            text = String(stripped.dropFirst(2))
        } else if stripped.hasPrefix("* ") {
            text = String(stripped.dropFirst(2))
        } else {
            text = stripped
        }

        if inVelocitySection && text.contains("Total execution time:") {
            let parts = text.components(separatedBy: "Total execution time:")
            if parts.count > 1 {
                totalExecutionTime = parts[1].trimmingCharacters(in: CharacterSet.whitespaces)
            }
            descendInto(listItem)
            return
        }

        if formattedText.lowercased() == "none yet." {
            descendInto(listItem)
            return
        }

        if inDecisionsSection {
            decisions.append(formattedText)
        } else if inBlockersSection {
            blockers.append(formattedText)
        }

        descendInto(listItem)
    }
}
