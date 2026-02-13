import Foundation

// MARK: - Search Result Type

enum SearchResultType {
    case project
    case phase(Phase)
    case requirement(Requirement)
    case plan(Plan)
}

// MARK: - Search Result

struct SearchResult: Identifiable {
    let id: UUID
    let projectID: UUID
    let projectName: String
    let title: String
    let subtitle: String
    let type: SearchResultType
    let score: Int

    init(
        id: UUID = UUID(),
        projectID: UUID,
        projectName: String,
        title: String,
        subtitle: String,
        type: SearchResultType,
        score: Int
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.score = score
    }
}

// MARK: - Search Service

final class SearchService {

    // MARK: - Public API

    /// Search across all projects, returning results grouped by type label.
    /// Groups: "Projects", "Phases", "Requirements", "Plans"
    func search(query: String, in projects: [Project]) -> [String: [SearchResult]] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [:] }

        var projectResults: [SearchResult] = []
        var phaseResults: [SearchResult] = []
        var requirementResults: [SearchResult] = []
        var planResults: [SearchResult] = []

        for project in projects {
            // Search project itself
            if let result = searchProject(project, query: trimmed) {
                projectResults.append(result)
            }

            // Search phases
            if let phases = project.roadmap?.phases {
                for phase in phases {
                    if let result = searchPhase(phase, in: project, query: trimmed) {
                        phaseResults.append(result)
                    }
                }
            }

            // Search requirements
            if let requirements = project.requirements {
                for req in requirements {
                    if let result = searchRequirement(req, in: project, query: trimmed) {
                        requirementResults.append(result)
                    }
                }
            }

            // Search plans
            if let plans = project.plans {
                for plan in plans {
                    if let result = searchPlan(plan, in: project, query: trimmed) {
                        planResults.append(result)
                    }
                }
            }
        }

        var grouped: [String: [SearchResult]] = [:]

        let sortedProjects = sorted(projectResults)
        let sortedPhases = sorted(phaseResults)
        let sortedRequirements = sorted(requirementResults)
        let sortedPlans = sorted(planResults)

        if !sortedProjects.isEmpty { grouped["Projects"] = sortedProjects }
        if !sortedPhases.isEmpty { grouped["Phases"] = sortedPhases }
        if !sortedRequirements.isEmpty { grouped["Requirements"] = sortedRequirements }
        if !sortedPlans.isEmpty { grouped["Plans"] = sortedPlans }

        return grouped
    }

    // MARK: - Scoring

    /// Score a text field against the query. Returns 0 if no match.
    private func score(query: String, title: String, content: String) -> Int {
        let lowerQuery = query.lowercased()
        let lowerTitle = title.lowercased()
        let lowerContent = content.lowercased()

        var points = 0

        // Title exact match (case-insensitive contains)
        if lowerTitle.contains(lowerQuery) {
            points += 10

            // Word boundary bonus: query matches at start of a word
            let words = lowerTitle.components(separatedBy: .init(charactersIn: " -_./"))
            if words.contains(where: { $0.hasPrefix(lowerQuery) }) {
                points += 5
            }
        }

        // Content match
        if lowerContent.contains(lowerQuery) {
            points += 1
        }

        return points
    }

    // MARK: - Per-type Search

    private func searchProject(_ project: Project, query: String) -> SearchResult? {
        let title = project.name
        let content = project.state?.status ?? ""
        let s = score(query: query, title: title, content: content)
        guard s > 0 else { return nil }

        return SearchResult(
            projectID: project.id,
            projectName: project.name,
            title: title,
            subtitle: project.path.lastPathComponent,
            type: .project,
            score: s
        )
    }

    private func searchPhase(_ phase: Phase, in project: Project, query: String) -> SearchResult? {
        let title = phase.name
        let content = [phase.goal, phase.requirements.joined(separator: " ")].joined(separator: " ")
        let s = score(query: query, title: title, content: content)
        guard s > 0 else { return nil }

        let subtitle = "Phase \(phase.number) — \(project.name)"
        return SearchResult(
            projectID: project.id,
            projectName: project.name,
            title: title,
            subtitle: subtitle,
            type: .phase(phase),
            score: s
        )
    }

    private func searchRequirement(_ req: Requirement, in project: Project, query: String) -> SearchResult? {
        let title = "\(req.id) — \(req.description)"
        let content = req.category
        let s = score(query: query, title: title, content: content)
        guard s > 0 else { return nil }

        let subtitle = "\(req.category) — \(project.name)"
        return SearchResult(
            projectID: project.id,
            projectName: project.name,
            title: "\(req.id) \(req.description)",
            subtitle: subtitle,
            type: .requirement(req),
            score: s
        )
    }

    private func searchPlan(_ plan: Plan, in project: Project, query: String) -> SearchResult? {
        let title = plan.objective
        let content = plan.tasks.map(\.name).joined(separator: " ")
        let s = score(query: query, title: title, content: content)
        guard s > 0 else { return nil }

        let subtitle = "Phase \(plan.phaseNumber) Plan \(plan.planNumber) — \(project.name)"
        return SearchResult(
            projectID: project.id,
            projectName: project.name,
            title: plan.objective,
            subtitle: subtitle,
            type: .plan(plan),
            score: s
        )
    }

    // MARK: - Sorting

    private func sorted(_ results: [SearchResult]) -> [SearchResult] {
        results.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
