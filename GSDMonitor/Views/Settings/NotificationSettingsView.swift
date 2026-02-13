import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @SwiftUI.State private var notificationsEnabled: Bool = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    @SwiftUI.State private var permissionStatus: String = "Checking..."

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
                    }
                Text("Receive notifications when phase statuses change in your GSD projects.")
                    .foregroundStyle(Theme.textSecondary)
                    .font(.caption)
            }

            Section("Permission Status") {
                Text(permissionStatus)
                    .foregroundStyle(Theme.textSecondary)
                if permissionStatus == "Denied" {
                    Text("Notifications are blocked by macOS. Enable in System Settings > Notifications > GSD Monitor.")
                        .foregroundStyle(Theme.warning)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await checkPermissionStatus()
        }
    }

    private func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            permissionStatus = "Authorized"
        case .denied:
            permissionStatus = "Denied"
        case .notDetermined:
            permissionStatus = "Not Determined"
        case .provisional:
            permissionStatus = "Provisional"
        case .ephemeral:
            permissionStatus = "Ephemeral"
        @unknown default:
            permissionStatus = "Unknown"
        }
    }
}
