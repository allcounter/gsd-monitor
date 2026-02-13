import SwiftUI
import UniformTypeIdentifiers

struct ScanDirectoriesPopoverView: View {
    let projectService: ProjectService

    @SwiftUI.State private var isDropTargeted = false

    private var defaultSource: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer")
    }

    private var additionalSources: [URL] {
        projectService.scanSources.filter { $0.path != defaultSource.path }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Scan Directories")
                    .font(.headline)
                    .foregroundStyle(Theme.fg1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Directory list
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Default section
                    sectionLabel("Default")

                    TimelineView(.periodic(from: .now, by: 60)) { _ in
                        ScanDirectoryRow(
                            url: defaultSource,
                            projectService: projectService,
                            isRemovable: false,
                            onRemove: {}
                        )
                    }

                    Divider()
                        .padding(.vertical, 6)

                    // Additional section
                    sectionLabel("Additional")

                    if additionalSources.isEmpty {
                        Text("No additional directories")
                            .font(.body)
                            .italic()
                            .foregroundStyle(Theme.fg4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(additionalSources, id: \.path) { source in
                            TimelineView(.periodic(from: .now, by: 60)) { _ in
                                ScanDirectoryRow(
                                    url: source,
                                    projectService: projectService,
                                    isRemovable: true,
                                    onRemove: {
                                        projectService.removeScanDirectory(source)
                                    }
                                )
                            }
                        }
                    }

                    // Duplicate warning removed — shown inline on matching row
                }
                .padding(.vertical, 6)
            }

            Divider()

            // Bottom bar — Add button
            HStack {
                Button {
                    _Concurrency.Task {
                        await projectService.addScanDirectoryViaPanel()
                    }
                } label: {
                    Label("Add Directory...", systemImage: "plus")
                        .font(.body)
                        .foregroundStyle(Theme.brightAqua)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 340)
        .background(Theme.bg0)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url, url.hasDirectoryPath else { return }
                    _Concurrency.Task { @MainActor in
                        projectService.addScanDirectory(url)
                    }
                }
            }
            return true
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Theme.brightBlue.opacity(isDropTargeted ? 0.6 : 0), lineWidth: 2)
        )
    }

    @ViewBuilder
    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }
}

// MARK: - Scan Directory Row

private struct ScanDirectoryRow: View {
    let url: URL
    let projectService: ProjectService
    let isRemovable: Bool
    let onRemove: () -> Void

    private var isDuplicate: Bool {
        projectService.duplicateWarningPath == url.standardizedFileURL.path
    }

    private var homePath: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    private var displayPath: String {
        url.path.replacingOccurrences(of: homePath, with: "~")
    }

    private var projectCount: Int {
        let manualPaths = Set(UserDefaults.standard.stringArray(forKey: "manualProjectPaths") ?? [])
        return projectService.projects.filter { project in
            project.path.path.hasPrefix(url.path) && !manualPaths.contains(project.path.path)
        }.count
    }

    private var scanState: ScanSourceState {
        projectService.scanSourceStates[url.path] ?? ScanSourceState()
    }

    private var lastScannedText: String? {
        guard let lastScanned = scanState.lastScannedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "scanned \(formatter.localizedString(for: lastScanned, relativeTo: Date()))"
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(displayPath)
                        .font(.body)
                        .foregroundStyle(scanState.isAccessible ? Theme.fg1 : Theme.fg4)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if !scanState.isAccessible {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.brightYellow)
                    }

                    if scanState.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    }
                }

                HStack(spacing: 4) {
                    if isDuplicate {
                        Text("Already added")
                            .font(.caption)
                            .foregroundStyle(Theme.brightYellow)
                    } else {
                        let count = projectCount
                        Text(count == 1 ? "1 project" : "\(count) projects")
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)

                        if let timeText = lastScannedText {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                            Text(timeText)
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }

            Spacer()

            if isRemovable {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.fg4)
                }
                .buttonStyle(.plain)
                .help("Remove \(displayPath)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isDuplicate ? Theme.brightYellow.opacity(0.1) : Theme.bg0)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isDuplicate ? Theme.brightYellow.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isDuplicate)
    }
}

#Preview("Scan Directories Popover") {
    let service = ProjectService()
    return ScanDirectoriesPopoverView(projectService: service)
        .frame(width: 340)
}
