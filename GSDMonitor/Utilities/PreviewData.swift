import Foundation

enum PreviewData {
    static let projects: [Project] = [
        // Full project with roadmap, state, config
        Project(
            name: "gsd-monitor",
            path: URL(fileURLWithPath: "/Users/username/Developer/gsd-monitor"),
            roadmap: Roadmap(
                projectName: "gsd-monitor",
                phases: [
                    Phase(
                        number: 1,
                        name: "Foundation & Models",
                        goal: "Establish Swift 6 patterns and create all models",
                        requirements: ["UI-01", "UI-02", "UI-03"],
                        status: .done
                    ),
                    Phase(
                        number: 2,
                        name: "File Discovery & Parsing",
                        goal: "Discover and parse GSD projects",
                        dependencies: ["Phase 1"],
                        requirements: ["NAV-01", "PARSE-01"],
                        status: .inProgress
                    ),
                    Phase(
                        number: 3,
                        name: "State Monitoring",
                        goal: "Live updates via FSEvents",
                        dependencies: ["Phase 2"],
                        requirements: ["LIVE-01"],
                        status: .notStarted
                    )
                ]
            ),
            state: State(
                currentPhase: 2,
                currentPlan: 3,
                status: "In Progress",
                lastActivity: "2026-02-13",
                decisions: [
                    "SwiftUI over Electron for native performance",
                    "FSEvents for live-opdatering"
                ],
                blockers: [],
                totalExecutionTime: "~1.8 hours",
                currentMilestone: "v1.1 Visual Overhaul"
            ),
            config: PlanningConfig(
                workflowVersion: "1.0",
                autoCommit: true,
                mode: "yolo",
                depth: "standard",
                parallelization: true
            ),
            requirements: [
                Requirement(
                    id: "UI-01",
                    category: "UI",
                    description: "Display project list in sidebar",
                    mappedToPhases: [1],
                    status: .validated
                ),
                Requirement(
                    id: "NAV-01",
                    category: "Navigation",
                    description: "Provide two-column layout with master-detail pattern",
                    mappedToPhases: [1],
                    status: .validated
                ),
                Requirement(
                    id: "PARSE-01",
                    category: "Parsing",
                    description: "Parse ROADMAP.md and STATE.md files from .planning/",
                    mappedToPhases: [2],
                    status: .active
                )
            ],
            plans: [
                Plan(
                    phaseNumber: 1,
                    planNumber: 1,
                    objective: "Setup Swift 6 project and establish concurrency patterns",
                    tasks: [
                        Task(name: "Create Xcode project with Swift 6", type: .auto, status: .done),
                        Task(name: "Add models with Sendable conformance", type: .auto, status: .done)
                    ],
                    status: .done
                ),
                Plan(
                    phaseNumber: 2,
                    planNumber: 3,
                    objective: "Parse REQUIREMENTS.md and PLAN.md files",
                    tasks: [
                        Task(name: "Implement RequirementsParser", type: .auto, status: .done),
                        Task(name: "Implement PlanParser", type: .auto, status: .inProgress),
                        Task(name: "Wire parsers to ProjectService", type: .auto, status: .pending)
                    ],
                    status: .inProgress
                )
            ],
            driftCommits: [
                DriftCommit(id: "a1b2c3d", message: "quick fix for layout bug", date: Date().addingTimeInterval(-3600), filesChanged: 2),
                DriftCommit(id: "e4f5g6h", message: "update readme", date: Date().addingTimeInterval(-86400), filesChanged: 1),
                DriftCommit(id: "f7a8b9c", message: "tweak colors manually", date: Date().addingTimeInterval(-172800), filesChanged: 3),
            ]
        ),
        // Minimal project
        Project(
            name: "another-project",
            path: URL(fileURLWithPath: "/Users/username/Developer/another-project")
        ),
        // Project with partial data
        Project(
            name: "web-scraper",
            path: URL(fileURLWithPath: "/Users/username/Developer/web-scraper"),
            roadmap: Roadmap(
                projectName: "web-scraper",
                phases: [
                    Phase(
                        number: 1,
                        name: "Core Scraper",
                        goal: "Build scraping engine",
                        status: .inProgress
                    )
                ]
            )
        )
    ]

    // Grouped projects by source (for sidebar preview)
    static let groupedProjects: [(source: String, projects: [Project])] = [
        ("~/Developer", [projects[0], projects[1]]),
        ("Manually Added", [projects[2]])
    ]
}
