import Foundation

struct PlanParser {
    func parse(_ content: String) -> Plan? {
        guard !content.isEmpty else { return nil }

        // Extract frontmatter
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }

        // Extract phase number from "phase: XX-name" or "phase: XX"
        guard let phaseNumber = extractPhaseNumber(from: frontmatter) else {
            return nil
        }

        // Extract plan number from "plan: NN"
        guard let planNumber = extractPlanNumber(from: frontmatter) else {
            return nil
        }

        // Extract objective
        let objective = extractObjective(from: content)

        // Extract tasks
        let tasks = extractTasks(from: content)

        return Plan(
            phaseNumber: phaseNumber,
            planNumber: planNumber,
            objective: objective,
            tasks: tasks,
            status: .pending
        )
    }

    private func extractFrontmatter(from content: String) -> String? {
        // Frontmatter is between first two "---" delimiters
        let lines = content.components(separatedBy: .newlines)
        var frontmatterLines: [String] = []
        var inFrontmatter = false
        var frontmatterCount = 0

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                frontmatterCount += 1
                if frontmatterCount == 1 {
                    inFrontmatter = true
                    continue
                } else if frontmatterCount == 2 {
                    break
                }
            }

            if inFrontmatter {
                frontmatterLines.append(line)
            }
        }

        return frontmatterCount >= 2 ? frontmatterLines.joined(separator: "\n") : nil
    }

    private func extractPhaseNumber(from frontmatter: String) -> Int? {
        // Pattern: "phase: NN-name" or "phase: NN"
        let pattern = #"phase:\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: frontmatter, range: NSRange(frontmatter.startIndex..., in: frontmatter)),
              let numberRange = Range(match.range(at: 1), in: frontmatter) else {
            return nil
        }

        return Int(String(frontmatter[numberRange]))
    }

    private func extractPlanNumber(from frontmatter: String) -> Int? {
        // Pattern: "plan: NN"
        let pattern = #"plan:\s*(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: frontmatter, range: NSRange(frontmatter.startIndex..., in: frontmatter)),
              let numberRange = Range(match.range(at: 1), in: frontmatter) else {
            return nil
        }

        return Int(String(frontmatter[numberRange]))
    }

    private func extractObjective(from content: String) -> String {
        // Extract content between <objective> and </objective>
        let pattern = #"<objective>\s*([\s\S]*?)\s*</objective>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let objectiveRange = Range(match.range(at: 1), in: content) else {
            return ""
        }

        return String(content[objectiveRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTasks(from content: String) -> [Task] {
        var tasks: [Task] = []

        // Find all <task type="..."> blocks
        let pattern = #"<task\s+type="([^"]+)">\s*<name>(?:Task\s+\d+:\s*)?([^<]+)</name>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return tasks
        }

        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))

        for match in matches {
            guard let typeRange = Range(match.range(at: 1), in: content),
                  let nameRange = Range(match.range(at: 2), in: content) else {
                continue
            }

            let typeString = String(content[typeRange])
            let name = String(content[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse task type
            let taskType: TaskType
            if typeString == "auto" {
                taskType = .auto
            } else if typeString.starts(with: "checkpoint") {
                taskType = .checkpoint
            } else {
                taskType = .auto // Default
            }

            let task = Task(
                name: name,
                type: taskType,
                status: .pending
            )
            tasks.append(task)
        }

        return tasks
    }
}
