import SwiftUI
import UniformTypeIdentifiers

struct EditorSettingsView: View {
    @SwiftUI.State private var editorService = EditorService()
    @AppStorage("preferredEditorID") private var preferredEditorID: String = ""

    @SwiftUI.State private var showingFileImporter: Bool = false
    @SwiftUI.State private var customEditorName: String = ""
    @SwiftUI.State private var showingNamePrompt: Bool = false
    @SwiftUI.State private var pendingAppURL: URL? = nil

    var body: some View {
        Form {
            Section {
                Picker("Preferred Editor:", selection: $preferredEditorID) {
                    Text("System Default").tag("")
                    ForEach(editorService.installedEditors) { editor in
                        Text(editor.name).tag(editor.id)
                    }
                }
            }

            Section("Detected Editors") {
                if editorService.installedEditors.isEmpty {
                    Text("No supported editors found in /Applications")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(editorService.installedEditors) { editor in
                        HStack {
                            Text(editor.name)
                            Spacer()
                            Text(editor.path.path)
                                .foregroundStyle(Theme.textSecondary)
                                .font(.caption)
                            if editor.isCustom {
                                Button {
                                    editorService.removeCustomEditor(id: editor.id)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Section("Custom Editors") {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Add Custom Editor...", systemImage: "plus")
                }
            }

            Section {
                Button("Refresh") {
                    editorService.detectInstalledEditors()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            editorService.detectInstalledEditors()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.application]
        ) { result in
            switch result {
            case .success(let url):
                let appName: String
                if let bundle = Bundle(url: url),
                   let cfName = bundle.infoDictionary?["CFBundleName"] as? String {
                    appName = cfName
                } else {
                    appName = url.deletingPathExtension().lastPathComponent
                }
                pendingAppURL = url
                customEditorName = appName
                showingNamePrompt = true
            case .failure:
                // User cancelled or error — ignore
                break
            }
        }
        .alert("Editor Name", isPresented: $showingNamePrompt) {
            TextField("Name", text: $customEditorName)
            Button("Add") {
                if let url = pendingAppURL {
                    editorService.addCustomEditor(name: customEditorName, path: url)
                }
                pendingAppURL = nil
                customEditorName = ""
            }
            Button("Cancel", role: .cancel) {
                pendingAppURL = nil
                customEditorName = ""
            }
        }
    }
}
