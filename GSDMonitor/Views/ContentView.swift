import SwiftUI

struct ContentView: View {
    private static let selectedProjectKey = "selectedProjectID"

    @SwiftUI.State private var projectService = ProjectService()
    @SwiftUI.State private var selectedProjectID: UUID?
    @SwiftUI.State private var notificationService: NotificationService?
    @SwiftUI.State private var showCommandPalette = false
    @SwiftUI.State private var selectedPhase: Phase? = nil
    @SwiftUI.State private var scrollToPhaseNumber: Int? = nil
    @Environment(\.scenePhase) private var scenePhase

    private func handleCommandPaletteSelection(_ result: SearchResult) {
        // Always navigate to the project first
        selectedProjectID = result.projectID

        // Reset deep navigation state
        selectedPhase = nil
        scrollToPhaseNumber = nil

        // Deep navigate based on result type
        switch result.type {
        case .project:
            break // Just navigate to project
        case .phase(let phase):
            // Open PhaseDetailView sheet after project selection propagates
            _Concurrency.Task { @MainActor in
                try? await _Concurrency.Task.sleep(for: .milliseconds(100))
                selectedPhase = phase
            }
        case .plan(let plan):
            // Scroll to the parent phase
            _Concurrency.Task { @MainActor in
                try? await _Concurrency.Task.sleep(for: .milliseconds(100))
                scrollToPhaseNumber = plan.phaseNumber
            }
        case .requirement:
            break // Just navigate to project
        }

        withAnimation(.easeOut(duration: 0.15)) {
            showCommandPalette = false
        }
    }

    private func globalColorIndex(for projectID: UUID?) -> Int {
        guard let id = projectID else { return 0 }
        let sorted = projectService.projects.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        return sorted.firstIndex(where: { $0.id == id }) ?? 0
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(
                projectService: projectService,
                selectedProjectID: $selectedProjectID
            )
        } detail: {
            // Detail
            DetailView(
                selectedProject: projectService.projects.first { $0.id == selectedProjectID },
                projectName: projectService.projects.first { $0.id == selectedProjectID }?.name ?? "",
                projectColorIndex: globalColorIndex(for: selectedProjectID),
                selectedPhase: $selectedPhase,
                scrollToPhaseNumber: $scrollToPhaseNumber
            )
        }
        .overlay {
            if showCommandPalette {
                CommandPaletteView(
                    projects: projectService.projects,
                    isPresented: $showCommandPalette,
                    onSelect: { result in
                        handleCommandPaletteSelection(result)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background {
            Button("") {
                withAnimation(.easeOut(duration: 0.15)) {
                    showCommandPalette.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .hidden()
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        .navigationSplitViewStyle(.balanced)
        .background(Theme.bg0)
        .task {
            await projectService.loadProjects()

            // Restore last selected project
            if let savedID = UserDefaults.standard.string(forKey: ContentView.selectedProjectKey),
               let uuid = UUID(uuidString: savedID),
               projectService.projects.contains(where: { $0.id == uuid }) {
                selectedProjectID = uuid
            }

            if selectedProjectID == nil, !projectService.projects.isEmpty {
                selectedProjectID = projectService.groupedProjects.first?.projects.first?.id
                print("Auto-selected: \(selectedProjectID?.uuidString ?? "nil"), projects count: \(projectService.projects.count), groups: \(projectService.groupedProjects.count)")
            }

            let ns = NotificationService(projectService: projectService)
            notificationService = ns
            ns.startMonitoring()
        }
        .onDisappear {
            notificationService?.stopMonitoring()
        }
        .onChange(of: selectedProjectID) { _, newValue in
            if let id = newValue {
                UserDefaults.standard.set(id.uuidString, forKey: ContentView.selectedProjectKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ContentView.selectedProjectKey)
            }
            // Reset deep navigation state when project changes (sidebar navigation clears stale state;
            // command palette sets them via asyncAfter after this onChange fires)
            selectedPhase = nil
            scrollToPhaseNumber = nil
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                // Resuming from background -- reload in case files changed while inactive
                _Concurrency.Task {
                    await projectService.loadProjects()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
