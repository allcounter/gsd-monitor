# Phase 5: Notifications & Editor Integration - Research

**Researched:** 2026-02-14
**Domain:** macOS User Notifications & External Editor Integration
**Confidence:** HIGH

## Summary

Phase 5 adds native macOS notifications for phase status changes and task completions, plus the ability to open files in user-selected code editors (Cursor, VS Code, Zed). This requires integrating UNUserNotificationCenter with the existing FSEvents-based file monitoring system in ProjectService, implementing an editor detection/selection system, and creating a Settings scene for user preferences.

The implementation builds on the existing @Observable ProjectService architecture with Swift 6 strict concurrency. Since the app sandbox is already disabled, file system operations and launching external editors are straightforward. The main technical challenges are: (1) properly timing notification permission requests, (2) handling UNUserNotificationCenterDelegate with Swift 6 concurrency, and (3) detecting status changes in @Observable properties to trigger notifications.

**Primary recommendation:** Use NSApplicationDelegateAdaptor to set up UNUserNotificationCenterDelegate, implement change tracking via withObservationTracking on ProjectService.projects array, use NSWorkspace.shared.open(_:withApplicationAt:configuration:completionHandler:) for opening files in editors, and create a Settings scene with @AppStorage for editor preferences.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| UserNotifications | macOS 10.14+ | Local notifications via UNUserNotificationCenter | Native framework, Focus mode integration, modern async API |
| AppKit (NSWorkspace) | macOS 10.0+ | Launching apps and opening files | Standard macOS framework for inter-app operations |
| SwiftUI Settings | macOS 11.0+ | Settings scene for preferences window | Native SwiftUI scene type, automatic menu integration |
| @AppStorage | SwiftUI | Persisting user preferences | SwiftUI property wrapper, automatic UserDefaults sync |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Observation framework | Swift 5.9+ | Change tracking with withObservationTracking | Monitoring @Observable properties outside SwiftUI views |
| NSApplicationDelegateAdaptor | SwiftUI | Integrating AppDelegate into SwiftUI app | Required for UNUserNotificationCenterDelegate setup |
| FileManager | Foundation | Detecting installed editors in /Applications | Enumerating .app bundles for editor discovery |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UNUserNotificationCenter | NSUserNotificationCenter | Deprecated in macOS 11.0, no Focus mode support |
| Settings scene | Custom preferences window | More work, loses automatic Cmd+, shortcut |
| @AppStorage | Manual UserDefaults | More boilerplate, no automatic UI updates |
| NSWorkspace | URL schemes (e.g., vscode://) | Less reliable, requires knowing each editor's scheme |

**Installation:**
```swift
// No external dependencies - all native frameworks
import UserNotifications
import AppKit
import SwiftUI
```

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── App/
│   ├── GSDMonitorApp.swift          # Add Settings scene here
│   └── AppDelegate.swift             # NEW: UNUserNotificationCenterDelegate
├── Services/
│   ├── ProjectService.swift          # Add notification triggering logic
│   ├── NotificationService.swift     # NEW: Manage notification scheduling
│   └── EditorService.swift           # NEW: Editor detection & opening files
├── Models/
│   └── EditorPreference.swift        # NEW: Editor choice model
└── Views/
    └── Settings/
        └── SettingsView.swift        # NEW: Settings scene with TabView
```

### Pattern 1: AppDelegate with NSApplicationDelegateAdaptor
**What:** SwiftUI apps use NSApplicationDelegateAdaptor to integrate traditional AppDelegate for notification handling
**When to use:** Required for UNUserNotificationCenterDelegate setup
**Example:**
```swift
// Source: https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor
// Modified for macOS + Swift 6 concurrency

@main
struct GSDMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // Handle foreground notifications
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
```

**Swift 6 Concurrency Note:** Use `@preconcurrency` on UNUserNotificationCenterDelegate protocol conformance to avoid nonisolated errors. The framework hasn't fully adopted strict concurrency yet.

### Pattern 2: Requesting Notification Permission (Context-Based)
**What:** Request authorization when user experiences value, not on app launch
**When to use:** First time a notification-worthy event occurs (phase status change)
**Example:**
```swift
// Source: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications

func requestNotificationPermission() async -> Bool {
    let center = UNUserNotificationCenter.current()

    do {
        let granted = try await center.requestAuthorization(options: [.alert, .sound])
        return granted
    } catch {
        print("Notification permission error: \(error)")
        return false
    }
}

// In NotificationService - check before scheduling
func schedulePhaseChangeNotification(phase: Phase) async {
    let center = UNUserNotificationCenter.current()
    let settings = await center.notificationSettings()

    if settings.authorizationStatus == .notDetermined {
        // First notification - request permission with context
        let granted = await requestNotificationPermission()
        guard granted else { return }
    }

    guard settings.authorizationStatus == .authorized else { return }

    // Schedule notification
    let content = UNMutableNotificationContent()
    content.title = "Phase Complete"
    content.body = "Phase \(phase.number): \(phase.name)"
    content.interruptionLevel = .timeSensitive

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil // Deliver immediately
    )

    try? await center.add(request)
}
```

### Pattern 3: Change Detection in @Observable Properties
**What:** Use withObservationTracking to monitor changes in @Observable ProjectService
**When to use:** Detecting phase status changes to trigger notifications
**Example:**
```swift
// Source: https://www.polpiella.dev/observable-outside-of-a-view
// Adapted for ProjectService monitoring

@MainActor
final class NotificationService {
    private let projectService: ProjectService
    private var monitoringTask: Task<Void, Never>?
    private var previousStates: [UUID: PhaseStatus] = [:]

    init(projectService: ProjectService) {
        self.projectService = projectService
    }

    func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                await withObservationTracking {
                    // Access properties to track
                    _ = projectService.projects
                } onChange: {
                    await self.checkForStatusChanges()
                }
            }
        }
    }

    private func checkForStatusChanges() async {
        for project in projectService.projects {
            guard let roadmap = project.roadmap else { continue }

            for phase in roadmap.phases {
                let previousStatus = previousStates[phase.id]

                if previousStatus != phase.status && previousStatus != nil {
                    // Status changed - send notification
                    await schedulePhaseChangeNotification(phase: phase)
                }

                previousStates[phase.id] = phase.status
            }
        }
    }
}
```

### Pattern 4: Editor Detection & Opening Files
**What:** Enumerate /Applications for known editors, open files with NSWorkspace
**When to use:** Settings view to detect editors, file path clicks to open
**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/filemanager
// Source: https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:)

struct Editor: Identifiable, Codable {
    let id: String  // Bundle identifier
    let name: String
    let path: URL
}

@MainActor
final class EditorService {
    private let knownEditors = [
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "dev.zed.Zed": "Zed"
    ]

    func detectInstalledEditors() -> [Editor] {
        var editors: [Editor] = []
        let appDir = URL(fileURLWithPath: "/Applications")

        guard let enumerator = FileManager.default.enumerator(
            at: appDir,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return [] }

        for case let appURL as URL in enumerator where appURL.pathExtension == "app" {
            guard let bundle = Bundle(url: appURL),
                  let bundleID = bundle.bundleIdentifier,
                  let editorName = knownEditors[bundleID] else { continue }

            editors.append(Editor(id: bundleID, name: editorName, path: appURL))
        }

        return editors
    }

    func openFile(_ fileURL: URL, with editor: Editor) async {
        let config = NSWorkspace.OpenConfiguration()

        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: editor.path,
            configuration: config
        ) { _, error in
            if let error = error {
                print("Failed to open file: \(error)")
            }
        }
    }
}
```

### Pattern 5: Settings Scene with TabView
**What:** SwiftUI Settings scene with TabView for preferences organization
**When to use:** Creating macOS preferences window
**Example:**
```swift
// Source: https://serialcoder.dev/text-tutorials/macos-tutorials/presenting-the-preferences-window-on-macos-using-swiftui/

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
        .frame(width: 500, height: 300)  // CRITICAL: Must set frame size
    }
}

struct EditorSettingsView: View {
    @StateObject private var editorService = EditorService()
    @AppStorage("preferredEditor") private var preferredEditorID: String = ""

    var body: some View {
        Form {
            Section {
                Picker("Preferred Editor:", selection: $preferredEditorID) {
                    Text("None").tag("")
                    ForEach(editorService.installedEditors) { editor in
                        Text(editor.name).tag(editor.id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            editorService.refreshEditors()
        }
    }
}
```

**CRITICAL:** Settings scene TabView MUST have explicit `.frame(width:height:)` or window will be tiny and non-resizable.

### Anti-Patterns to Avoid
- **Asking for notification permission on app launch:** Request permission when first notification-worthy event occurs, providing context
- **Using deprecated NSUserNotificationCenter:** Use UNUserNotificationCenter (available macOS 10.14+)
- **Polling for changes:** Use Observation framework's withObservationTracking instead of timers
- **Hardcoded editor paths:** Detect installed editors dynamically from /Applications
- **Forgetting @preconcurrency on UNUserNotificationCenterDelegate:** Causes Swift 6 concurrency errors

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notification scheduling | Custom notification queue system | UNUserNotificationCenter | Handles Focus mode, Do Not Disturb, deduplication, delivery timing automatically |
| Settings persistence | Custom JSON/Plist writer | @AppStorage + UserDefaults | Automatic UI updates, type-safe, built-in defaults |
| App launching | URL schemes or AppleScript | NSWorkspace.shared.open | Handles missing apps, security permissions, error cases |
| Change detection | Timer polling or didSet observers | withObservationTracking | Built for @Observable, efficient, cancellable |
| Preferences window | Custom NSWindow | Settings scene | Automatic Cmd+, shortcut, menu integration, SwiftUI-native |

**Key insight:** macOS provides mature frameworks for all these requirements. Custom implementations miss edge cases like Focus mode scheduling rules, sandboxing permissions, bundle identifier resolution, and concurrency safety.

## Common Pitfalls

### Pitfall 1: Not Setting UNUserNotificationCenter Delegate
**What goes wrong:** Notifications don't appear when app is in foreground
**Why it happens:** By default, notifications are suppressed for foreground apps
**How to avoid:** Set `UNUserNotificationCenter.current().delegate = self` in AppDelegate and implement `willPresent` method returning `[.banner, .sound]`
**Warning signs:** Notifications only appear when app is hidden/minimized

### Pitfall 2: Swift 6 Concurrency Errors with UNUserNotificationCenterDelegate
**What goes wrong:** Compiler errors about nonisolated requirements or main actor isolation
**Why it happens:** UNUserNotificationCenterDelegate hasn't fully adopted strict concurrency
**How to avoid:** Use `@preconcurrency` on protocol conformance: `final class AppDelegate: NSObject, NSApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate`
**Warning signs:** Build errors mentioning "nonisolated" or "main actor-isolated instance method"

### Pitfall 3: Forgetting Settings Scene Frame Size
**What goes wrong:** Settings window appears tiny (often 200x100 or smaller) and is non-resizable
**Why it happens:** SwiftUI doesn't infer window size for Settings scene
**How to avoid:** Always add `.frame(width:height:)` to TabView in Settings scene (typical: 450-500 width, 250-400 height)
**Warning signs:** Settings window too small to display content, users can't resize

### Pitfall 4: Opening Files in Sandboxed Context
**What goes wrong:** NSWorkspace.shared.open fails silently or with permission errors
**Why it happens:** Sandboxed apps need security-scoped URLs for file access
**How to avoid:** This app has sandbox disabled (entitlements show `com.apple.security.app-sandbox = false`), so no issue. If re-enabling sandbox, use security-scoped bookmarks
**Warning signs:** Files don't open, console shows "kLSAppDoesNotClaimTypeErr" or permission errors

### Pitfall 5: Assuming All Editors Are Installed in /Applications
**What goes wrong:** Missing editors installed in ~/Applications or custom locations
**Why it happens:** Only checking /Applications directory
**How to avoid:** Also check `~/Applications` and optionally `/System/Applications` (though code editors unlikely there)
**Warning signs:** Users report "my editor isn't detected" when it's in non-standard location

### Pitfall 6: Not Handling Editor Launch Failures
**What goes wrong:** Silent failures when editor no longer exists or file path invalid
**Why it happens:** NSWorkspace.shared.open completion handler not checked
**How to avoid:** Handle completionHandler error parameter, show user-facing error dialog
**Warning signs:** File clicks do nothing, no user feedback

### Pitfall 7: Race Conditions in Change Detection
**What goes wrong:** Duplicate notifications or missed changes
**Why it happens:** ProjectService updates rapidly (FSEvents debounced at 1 second), multiple changes in quick succession
**How to avoid:** Store previous state snapshot, debounce notification scheduling, use unique identifiers to prevent duplicates
**Warning signs:** Multiple identical notifications appear, or status changes don't trigger notifications

### Pitfall 8: Notification Interruption Level Confusion
**What goes wrong:** Notifications don't break through Focus mode when expected
**Why it happens:** `.timeSensitive` requires special entitlement for remote notifications (not local), `.critical` requires extra permissions
**How to avoid:** Use `.timeSensitive` for local notifications (no entitlement needed), avoid `.critical` unless life-safety scenario
**Warning signs:** Users in Focus mode never see notifications despite authorization

## Code Examples

Verified patterns from official sources:

### Basic Notification Scheduling
```swift
// Source: https://www.hackingwithswift.com/example-code/system/how-to-set-local-alerts-using-unnotificationcenter

func scheduleNotification(title: String, body: String) async throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.interruptionLevel = .timeSensitive

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil  // Immediate delivery
    )

    try await UNUserNotificationCenter.current().add(request)
}
```

### Checking Authorization Status
```swift
// Source: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications

func checkNotificationPermission() async -> UNAuthorizationStatus {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    return settings.authorizationStatus
}
```

### Opening File with Preferred Editor
```swift
// Source: https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:)

func openInPreferredEditor(_ fileURL: URL, editorPath: URL) {
    let config = NSWorkspace.OpenConfiguration()

    NSWorkspace.shared.open(
        [fileURL],
        withApplicationAt: editorPath,
        configuration: config
    ) { app, error in
        if let error = error {
            print("Failed to open: \(error.localizedDescription)")
        } else if let app = app {
            print("Opened in: \(app)")
        }
    }
}
```

### Detecting Bundle Identifier
```swift
// Source: https://developer.apple.com/documentation/foundation/bundle

func getBundleIdentifier(for appURL: URL) -> String? {
    guard let bundle = Bundle(url: appURL) else { return nil }
    return bundle.bundleIdentifier
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSUserNotificationCenter | UNUserNotificationCenter | macOS 10.14 (2018) | Deprecated API, no Focus mode support |
| openFile(_:withApplication:) | open(_:withApplicationAt:configuration:completionHandler:) | macOS 10.15 (2019) | Async completion, better error handling |
| UIApplicationDelegateAdaptor | NSApplicationDelegateAdaptor | SwiftUI 1.0 (2019) | macOS-specific adaptor for AppDelegate |
| @Published + Combine | @Observable + Observation | Swift 5.9 (2023) | Simpler syntax, better performance |
| Manual UserDefaults sync | @AppStorage | SwiftUI 1.0 (2019) | Automatic UI updates on preference changes |

**Deprecated/outdated:**
- **NSUserNotificationCenter:** Deprecated in macOS 11.0, replaced by UNUserNotificationCenter
- **NSWorkspace.openFile(_:withApplication:):** Not formally deprecated but old style, prefer async version with configuration
- **Notification interruption level omission:** Pre-macOS 12 didn't support `.interruptionLevel`, now essential for Focus mode behavior

## Open Questions

1. **Should notification permission be requested proactively or lazily?**
   - What we know: Best practice is contextual request (when first notification occurs)
   - What's unclear: If user denies, should we retry or just disable notifications?
   - Recommendation: Request on first status change event, respect denial permanently, add "Re-enable Notifications" button in Settings

2. **How to handle multiple projects changing status simultaneously?**
   - What we know: FSEvents debounce is 1 second, could cause batch of changes
   - What's unclear: Send one notification per phase or batch into "Multiple phases completed"?
   - Recommendation: Send individual notifications (max 3-5), then batch if more, use UNNotificationCenter's deduplication

3. **Should we support other editors beyond Cursor/VS Code/Zed?**
   - What we know: Can detect any app in /Applications via bundle identifier
   - What's unclear: How to identify which apps are "code editors"?
   - Recommendation: Start with hardcoded list of known editors (Cursor, VS Code, Zed, Xcode, Nova, BBEdit), add "Custom..." option for manual selection

4. **Editor detection for Homebrew-installed editors?**
   - What we know: Homebrew installs to /Applications (casks) or /usr/local/bin (formulae)
   - What's unclear: Should we check /usr/local/bin or /opt/homebrew/bin?
   - Recommendation: Start with /Applications only (most GUI editors installed there), add ~/Applications in v1.1

## Sources

### Primary (HIGH confidence)
- [Apple Developer Documentation: UNNotificationInterruptionLevel](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel) - Interruption levels for Focus mode
- [Apple Developer Documentation: NSWorkspace.open(_:withApplicationAt:configuration:completionHandler:)](https://developer.apple.com/documentation/appkit/nsworkspace/open(_:withapplicationat:configuration:completionhandler:)) - Current API for opening files
- [Apple Developer Documentation: Settings Scene](https://developer.apple.com/documentation/swiftui/settings) - SwiftUI Settings scene
- [Apple Developer Documentation: NSApplicationDelegateAdaptor](https://developer.apple.com/documentation/swiftui/nsapplicationdelegateadaptor) - AppDelegate integration
- [Apple Developer Documentation: @AppStorage](https://developer.apple.com/documentation/swiftui/appstorage) - SwiftUI property wrapper

### Secondary (MEDIUM confidence)
- [Hacking with Swift: UNNotificationCenter tutorial](https://www.hackingwithswift.com/example-code/system/how-to-set-local-alerts-using-unnotificationcenter) - Notification scheduling patterns
- [SerialCoder.dev: Presenting Preferences Window on macOS](https://serialcoder.dev/text-tutorials/macos-tutorials/presenting-the-preferences-window-on-macos-using-swiftui/) - Settings scene implementation with code examples
- [Swift with Majid: Deep Linking for Local Notifications](https://swiftwithmajid.com/2024/04/09/deep-linking-for-local-notifications-in-swiftui/) - Notification response handling
- [Pol Piella: Observable Property Changes](https://www.polpiella.dev/observable-property-changes) - withObservationTracking usage
- [Donny Wals: Observing Properties Outside SwiftUI](https://www.donnywals.com/observing-properties-on-an-observable-class-outside-of-swiftui-views/) - @Observable monitoring patterns
- [Hacking with Swift: Swift 6 Concurrency](https://www.hackingwithswift.com/swift/6.0/concurrency) - @preconcurrency and Sendable
- [iOS framework UserNotifications and strict concurrency - GitHub Issue #78833](https://github.com/swiftlang/swift/issues/78833) - UNUserNotificationCenterDelegate concurrency issues
- [Apple Support: Get Bundle ID for Mac App](https://support.apple.com/guide/deployment/get-the-bundle-id-for-a-mac-app-dep0af2cd611/web) - Bundle identifier verification
- [GitHub Issue: VS Code Bundle Identifier](https://github.com/microsoft/vscode/issues/22366) - Verified com.microsoft.VSCode
- Zed documentation and Homebrew formulae - Verified dev.zed.Zed
- Web search results - Verified com.todesktop.230313mzl4w4u92 for Cursor

### Tertiary (LOW confidence - marked for validation)
- Specific bundle identifiers for Cursor (com.todesktop.230313mzl4w4u92) - should verify in installed app before hardcoding
- Editor detection best practices for Homebrew-installed apps - community patterns, not official guidance

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All native frameworks, official Apple APIs, well-documented
- Architecture: HIGH - Patterns verified from official docs and community best practices
- Pitfalls: MEDIUM-HIGH - Swift 6 concurrency issues well-documented, Settings scene gotchas confirmed, some pitfalls from practical experience
- Bundle identifiers: MEDIUM - VS Code confirmed, Zed confirmed, Cursor needs verification

**Research date:** 2026-02-14
**Valid until:** 2026-03-14 (30 days - stable APIs, but Swift concurrency evolving)
