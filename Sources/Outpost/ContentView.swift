import AppKit
import LogKitUI
import OutpostKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            sidebar
        } detail: {
            page(model.sidebar ?? .overview)
        }
        .task {
            SelfTest.runIfRequested(model: model)
            Snapshot.runIfRequested(model: model, openSettings: openSettings, openWindow: openWindow)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return List(selection: $model.sidebar) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    }

    @ViewBuilder
    private func page(_ item: SidebarItem) -> some View {
        switch item {
        case .overview:
            OverviewPage()
        case .log:
            LogViewer(
                model: model.logViewer,
                options: LogViewerOptions(
                    emptyTitle: String(localized: "No Log Messages"),
                    emptyMessage: String(localized: "What Outpost does with your server shows here.")
                )
            )
            .navigationTitle("Activity Log")
        }
    }
}

struct OverviewPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Outpost", systemImage: "server.rack")
        } description: {
            Text("A native macOS menu bar monitor for your home server, built with fluid materials, live telemetry, and zero bloat.")
        } actions: {
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .navigationTitle("Overview")
    }
}
