import SwiftUI

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color

    @SwiftUI.State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
                .font(.system(size: 18))

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.fg0)

            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg1)
        .cornerRadius(10)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }
}

#Preview {
    HStack {
        StatCardView(icon: "chart.bar.fill", value: "12", label: "Total Phases", accentColor: Theme.brightBlue)
        StatCardView(icon: "percent", value: "84%", label: "Complete", accentColor: Theme.brightGreen)
        StatCardView(icon: "bolt.fill", value: "1", label: "Active", accentColor: Theme.brightYellow)
        StatCardView(icon: "clock.fill", value: "~1.8 hours", label: "Time Spent", accentColor: Theme.brightOrange)
    }
    .padding()
    .background(Theme.bg0)
}
