import AppKit
import Foundation
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

    // Server Configuration
    var host: String = "192.168.40.210"
    var user: String = "root"
    var port: Int = 22
    var identityFile: String = "~/.ssh/id_ed25519_homeserver"

    // Live State
    var metrics: SystemMetrics = SystemMetrics()
    var metricsHistory: [SystemMetrics] = []
    var isConnected: Bool = false
    var isConnecting: Bool = false
    var connectionError: String? = nil
    var lastUpdated: Date? = nil

    @ObservationIgnored
    private var pollTask: Task<Void, Never>?
    @ObservationIgnored
    private var sshClient: SSHClient?

    init(log: LogStore) {
        self.log = log
        self.logViewer = LogViewerModel(store: log)
        log.post(.info, "Outpost initialized with SSH key support", source: "App")

        // Pre-fill identity file if homeserver key exists, else default id_ed25519
        let homeserverKey = ("~/.ssh/id_ed25519_homeserver" as NSString).expandingTildeInPath
        let defaultEdKey = ("~/.ssh/id_ed25519" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: homeserverKey) {
            self.identityFile = "~/.ssh/id_ed25519_homeserver"
        } else if FileManager.default.fileExists(atPath: defaultEdKey) {
            self.identityFile = "~/.ssh/id_ed25519"
        }
    }

    var targetString: String {
        "\(user)@\(host)"
    }

    func startPolling() {
        guard pollTask == nil else { return }
        let client = SSHClient(target: targetString, identityFile: identityFile, port: port)
        self.sshClient = client
        isConnecting = true
        connectionError = nil

        pollTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.log.post(.info, "Connecting to \(self.targetString) via SSH key (\(self.identityFile))", source: "SSH")
            let test = await client.testConnection()
            switch test {
            case .success(let kernel):
                self.isConnected = true
                self.isConnecting = false
                self.connectionError = nil
                self.log.post(.info, "SSH Key Authentication successful: \(kernel)", source: "SSH")
            case .failure(let error):
                self.isConnected = false
                self.isConnecting = false
                self.connectionError = error.localizedDescription
                self.log.post(.error, "SSH Connection failed: \(error.localizedDescription)", source: "SSH")
                return
            }

            while !Task.isCancelled {
                do {
                    let sample = try await client.fetchDirectMetrics()
                    self.metrics = sample
                    self.lastUpdated = Date()
                    self.metricsHistory.append(sample)
                    if self.metricsHistory.count > 30 {
                        self.metricsHistory.removeFirst()
                    }
                    self.isConnected = true
                    self.connectionError = nil
                } catch {
                    self.connectionError = error.localizedDescription
                    self.log.post(.error, "Failed to read telemetry: \(error.localizedDescription)", source: "Telemetry")
                }

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        isConnecting = false
        isConnected = false
        Task { [sshClient] in
            await sshClient?.disconnect()
        }
    }

    func reconnect() {
        stopPolling()
        startPolling()
    }
}
