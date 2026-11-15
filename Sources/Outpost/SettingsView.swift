import AppKit
import OutpostKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.settingsTab) {
            ForEach(SettingsTab.allCases) { tab in
                page(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func page(_ tab: SettingsTab) -> some View {
        Form {
            switch tab {
            case .general: GeneralSettings()
            case .appearance: AppearanceSettings()
            case .updates: UpdateSettings()
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: String(localized: "General")
        case .appearance: String(localized: "Appearance")
        case .updates: String(localized: "Updates")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }
}

struct GeneralSettings: View {
    @Environment(AppModel.self) private var model
    @State private var testingConnection = false
    @State private var testResult: String?

    var body: some View {
        @Bindable var model = model
        Section("Server Connection") {
            TextField("Host or IP", text: $model.host)
            TextField("User", text: $model.user)
            TextField("Port", value: $model.port, format: .number)
        }

        Section("Authentication (SSH Key)") {
            HStack {
                TextField("SSH Private Key", text: $model.identityFile)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.showsHiddenFiles = true
                    panel.directoryURL = URL(fileURLWithPath: ("~/.ssh" as NSString).expandingTildeInPath)
                    if panel.runModal() == .OK, let url = panel.url {
                        model.identityFile = url.path
                    }
                }
            }

            Text("Outpost authenticates directly using your SSH key pair. No password is sent or stored.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Test Connection") {
                    testingConnection = true
                    testResult = nil
                    Task {
                        let client = SSHClient(target: model.targetString, identityFile: model.identityFile, port: model.port)
                        let result = await client.testConnection()
                        testingConnection = false
                        switch result {
                        case .success(let kernel):
                            testResult = "Connected! (\(kernel))"
                        case .failure(let err):
                            testResult = "Failed: \(err.localizedDescription)"
                        }
                    }
                }
                .disabled(testingConnection)

                if testingConnection {
                    ProgressView().controlSize(.small)
                } else if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundStyle(testResult.hasPrefix("Connected") ? .green : .red)
                }
            }
        }
    }
}

struct UpdateSettings: View {
    @State private var autoChecks: Bool = Updater.shared.automaticallyChecks

    var body: some View {
        Section("Software Updates") {
            Toggle("Automatically check for updates", isOn: $autoChecks)
                .onChange(of: autoChecks) { _, newValue in
                    Updater.shared.automaticallyChecks = newValue
                }

            Button("Check Now…") {
                Updater.shared.checkForUpdates()
            }
            .disabled(!Updater.shared.isAvailable)
        }
    }
}
