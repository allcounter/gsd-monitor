import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "chevron.left.forwardslash.chevron.right")
                }

            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
        }
        .frame(width: 450, height: 300)
    }
}
