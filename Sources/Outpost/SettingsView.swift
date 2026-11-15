import AppKit
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
        .frame(width: 480)
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

    var body: some View {
        @Bindable var model = model
        Section("Server Connection") {
            TextField("Host or IP", text: $model.host)
            TextField("Port", value: $model.port, format: .number)
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
