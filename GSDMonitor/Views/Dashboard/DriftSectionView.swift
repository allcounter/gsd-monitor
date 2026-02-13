import SwiftUI

struct DriftSectionView: View {
    let driftCommits: [DriftCommit]

    @SwiftUI.State private var isSectionExpanded: Bool = false

    var body: some View {
        if driftCommits.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Section header — tappable to collapse/expand
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSectionExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSectionExpanded ? "chevron.down" : "chevron.right")
                            .foregroundStyle(Theme.brightOrange)
                            .font(.caption)
                            .frame(width: 12)

                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(Theme.brightOrange)
                            .font(.headline)

                        Text("Drift")
                            .font(.headline)
                            .foregroundStyle(Theme.fg1)

                        // Count badge
                        Text("\(driftCommits.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.bg0)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.brightOrange)
                            .clipShape(Capsule())

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isSectionExpanded {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(driftCommits) { commit in
                                DriftCommitRow(commit: commit)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }
}

// MARK: - DriftCommitRow

private struct DriftCommitRow: View {
    let commit: DriftCommit

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Left: hash + message
            VStack(alignment: .leading, spacing: 2) {
                Text(commit.id)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.brightOrange)

                Text(commit.message)
                    .font(.callout)
                    .foregroundStyle(Theme.fg1)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Right: files changed + date
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "doc")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                    Text("\(commit.filesChanged)")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }

                Text(commit.relativeDate)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(10)
        .background(Theme.bg1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        DriftSectionView(driftCommits: [
            DriftCommit(id: "a1b2c3d", message: "quick fix for layout bug", date: Date().addingTimeInterval(-3600), filesChanged: 2),
            DriftCommit(id: "e4f5g6h", message: "update readme", date: Date().addingTimeInterval(-86400), filesChanged: 1),
            DriftCommit(id: "f7a8b9c", message: "tweak colors manually outside GSD workflow", date: Date().addingTimeInterval(-172800), filesChanged: 3),
        ])

        DriftSectionView(driftCommits: [])
    }
    .padding(14)
    .background(Theme.bg0)
}
