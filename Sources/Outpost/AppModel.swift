import AppKit
import LogKit
import LogKitUI
import Observation
import OutpostKit
import SwiftUI

public enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "overview"
    case log = "log"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .log: String(localized: "Activity Log")
        }
    }

    public var symbol: String {
        switch self {
        case .overview: "server.rack"
        case .log: "scroll"
        }
    }
}

@Observable
final class AppModel {
    var sidebar: SidebarItem? = .overview
    var settingsTab: SettingsTab = .general

    let log: LogStore
    let logViewer: LogViewerModel

    var metrics: SystemMetrics = SystemMetrics()
    var isConnected: Bool = false
    var host: String = "192.168.40.210"
    var port: Int = 22

    init(log: LogStore) {
        self.log = log
        self.logViewer = LogViewerModel(store: log)
        log.post(.info, "Outpost started", source: "App")
    }
}
