import Foundation
import AppKit

@MainActor
@Observable
final class EditorService {
    var installedEditors: [Editor] = []

    var preferredEditorID: String {
        get { UserDefaults.standard.string(forKey: "preferredEditorID") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "preferredEditorID") }
    }

    var preferredEditor: Editor? {
        installedEditors.first { $0.id == preferredEditorID }
    }

    private static let knownEditors: [String: String] = [
        "com.microsoft.VSCode": "Visual Studio Code",
        "com.todesktop.230313mzl4w4u92": "Cursor",
        "dev.zed.Zed": "Zed"
    ]

    private let customEditorsKey = "customEditors"

    private var customEditors: [Editor] {
        get {
            guard let data = UserDefaults.standard.data(forKey: customEditorsKey),
                  let editors = try? JSONDecoder().decode([Editor].self, from: data) else {
                return []
            }
            return editors
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: customEditorsKey)
            }
        }
    }

    init() {
        detectInstalledEditors()
    }

    func detectInstalledEditors() {
        let knownEditors = Self.knownEditors
        let storedCustom = customEditors

        _Concurrency.Task { @MainActor [weak self] in
            let found = await Self.scanEditors(knownEditors: knownEditors, customEditors: storedCustom)
            self?.installedEditors = found
        }
    }

    private static func scanEditors(knownEditors: [String: String], customEditors: [Editor]) async -> [Editor] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var found: [Editor] = []
                let searchPaths = [
                    URL(fileURLWithPath: "/Applications"),
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
                ]

                for searchPath in searchPaths {
                    guard let enumerator = FileManager.default.enumerator(
                        at: searchPath,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsPackageDescendants, .skipsHiddenFiles]
                    ) else { continue }

                    for case let appURL as URL in enumerator {
                        guard appURL.pathExtension == "app" else { continue }
                        guard let bundle = Bundle(url: appURL),
                              let bundleID = bundle.bundleIdentifier,
                              let editorName = knownEditors[bundleID] else { continue }

                        if !found.contains(where: { $0.id == bundleID }) {
                            found.append(Editor(id: bundleID, name: editorName, path: appURL))
                        }
                    }
                }

                // Append custom editors whose path still exists on disk
                for custom in customEditors {
                    if FileManager.default.fileExists(atPath: custom.path.path) {
                        if !found.contains(where: { $0.id == custom.id }) {
                            found.append(custom)
                        }
                    }
                }

                continuation.resume(returning: found)
            }
        }
    }

    func addCustomEditor(name: String, path: URL) {
        let newEditor = Editor(
            id: path.path,
            name: name,
            path: path,
            isCustom: true
        )
        var current = customEditors
        // Avoid duplicates by path
        if !current.contains(where: { $0.id == newEditor.id }) {
            current.append(newEditor)
            customEditors = current
        }
        detectInstalledEditors()
    }

    func removeCustomEditor(id: String) {
        var current = customEditors
        current.removeAll { $0.id == id }
        customEditors = current
        if preferredEditorID == id {
            preferredEditorID = ""
        }
        detectInstalledEditors()
    }

    func openFile(_ fileURL: URL) {
        guard let editor = preferredEditor ?? installedEditors.first else { return }
        openFile(fileURL, with: editor)
    }

    func openFile(_ fileURL: URL, with editor: Editor) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(
            [fileURL],
            withApplicationAt: editor.path,
            configuration: configuration
        ) { _, error in
            if let error {
                print("Failed to open \(fileURL.path) with \(editor.name): \(error.localizedDescription)")
            }
        }
    }
}
