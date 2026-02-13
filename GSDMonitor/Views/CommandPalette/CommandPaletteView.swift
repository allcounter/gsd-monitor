import SwiftUI

// MARK: - Ordered Group

private struct GroupedResults {
    let key: String
    let results: [SearchResult]
}

// MARK: - Command Palette View

struct CommandPaletteView: View {
    let projects: [Project]
    @Binding var isPresented: Bool
    let onSelect: (SearchResult) -> Void

    @SwiftUI.State private var searchText: String = ""
    @SwiftUI.State private var selectedIndex: Int = 0
    @SwiftUI.State private var flatResults: [SearchResult] = []
    @SwiftUI.State private var groupedResults: [GroupedResults] = []
    @FocusState private var isTextFieldFocused: Bool

    private let searchService = SearchService()

    // Fixed display order for groups
    private let groupOrder = ["Projects", "Phases", "Requirements", "Plans"]

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Palette card
            VStack(spacing: 0) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.fg4)
                        .font(.system(size: 16))

                    TextField("Search projects, phases, requirements...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.fg1)
                        .focused($isTextFieldFocused)
                        .onKeyPress(.upArrow) {
                            moveSelection(by: -1)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            moveSelection(by: 1)
                            return .handled
                        }
                        .onKeyPress(.return) {
                            confirmSelection()
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            dismiss()
                            return .handled
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()
                    .background(Theme.bg2)

                // Results list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if searchText.isEmpty {
                                emptyPromptView
                            } else if groupedResults.isEmpty {
                                noResultsView
                            } else {
                                ForEach(groupedResults, id: \.key) { group in
                                    // Section header
                                    Text(group.key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Theme.fg4)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 10)
                                        .padding(.bottom, 4)

                                    // Results
                                    ForEach(Array(group.results.enumerated()), id: \.element.id) { _, result in
                                        let flatIdx = flatIndex(for: result)
                                        ResultRowView(
                                            result: result,
                                            isSelected: flatIdx == selectedIndex
                                        )
                                        .id(result.id)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSelect(result)
                                            dismiss()
                                        }
                                        .onHover { hovering in
                                            if hovering, let idx = flatIdx {
                                                selectedIndex = idx
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex < flatResults.count {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo(flatResults[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }

                // Footer hint
                if !flatResults.isEmpty {
                    Divider()
                        .background(Theme.bg2)

                    HStack(spacing: 12) {
                        hintItem(icon: "arrow.up", label: "")
                        hintItem(icon: "arrow.down", label: "navigate")
                        hintItem(icon: "return", label: "select")
                        hintItem(icon: "escape", label: "close")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: 560)
            .background(Theme.bg0Hard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 40)
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: searchText) { _, _ in
            runSearch()
        }
    }

    // MARK: - Helper Views

    private var emptyPromptView: some View {
        HStack {
            Spacer()
            Text("Start typing to search...")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
                .padding(.vertical, 24)
            Spacer()
        }
    }

    private var noResultsView: some View {
        HStack {
            Spacer()
            Text("No results")
                .font(.system(size: 13))
                .foregroundColor(Theme.fg4)
                .padding(.vertical, 24)
            Spacer()
        }
    }

    private func hintItem(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Theme.textMuted)
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(Theme.textMuted)
            }
        }
    }

    // MARK: - Logic

    private func runSearch() {
        let raw = searchService.search(query: searchText, in: projects)

        // Build ordered groups
        var ordered: [GroupedResults] = []
        for key in groupOrder {
            if let results = raw[key], !results.isEmpty {
                ordered.append(GroupedResults(key: key, results: results))
            }
        }
        groupedResults = ordered
        flatResults = ordered.flatMap(\.results)
        selectedIndex = 0
    }

    private func flatIndex(for result: SearchResult) -> Int? {
        flatResults.firstIndex(where: { $0.id == result.id })
    }

    private func moveSelection(by delta: Int) {
        guard !flatResults.isEmpty else { return }
        let newIndex = (selectedIndex + delta).clamped(to: 0...(flatResults.count - 1))
        selectedIndex = newIndex
    }

    private func confirmSelection() {
        guard !flatResults.isEmpty, selectedIndex < flatResults.count else { return }
        onSelect(flatResults[selectedIndex])
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            isPresented = false
        }
    }
}

// MARK: - Result Row View

private struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: typeIcon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.fg1)
                    .lineLimit(1)

                Text(result.subtitle)
                    .font(.caption)
                    .foregroundColor(Theme.fg4)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Theme.bg2 : Color.clear)
    }

    private var typeIcon: String {
        switch result.type {
        case .project: return "folder"
        case .phase: return "arrow.right.square"
        case .requirement: return "checkmark.circle"
        case .plan: return "doc.text"
        }
    }

    private var iconColor: Color {
        switch result.type {
        case .project: return Theme.brightYellow
        case .phase: return Theme.brightBlue
        case .requirement: return Theme.brightGreen
        case .plan: return Theme.brightAqua
        }
    }
}

// MARK: - Comparable Extension

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
