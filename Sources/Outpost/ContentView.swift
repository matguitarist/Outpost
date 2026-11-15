import AppKit
import Charts
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
            if !SelfTest.requested && ProcessInfo.processInfo.environment["APP_SNAPSHOT"] == nil {
                model.startPolling()
            }
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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                headerCard
                if let error = model.connectionError {
                    errorBanner(error)
                }
                metricsGrid
                chartSection
                quickActions
            }
            .padding(Space.lg)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { model.reconnect() }) {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: Space.md) {
            IconTile(symbol: "server.rack", size: 48)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.xs) {
                    Text(model.host)
                        .font(.title2.weight(.semibold))
                    Circle()
                        .fill(model.isConnected ? Color.green : (model.isConnecting ? Color.orange : Color.gray))
                        .frame(width: 10, height: 10)
                }
                HStack(spacing: Space.md) {
                    Text(model.isConnected ? "Authenticated via SSH Key" : (model.isConnecting ? "Connecting…" : "Disconnected"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if model.metrics.uptimeSeconds > 0 {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(uptimeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(Space.md)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.callout)
            Spacer()
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(Space.md)
        .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.control, style: .continuous).strokeBorder(.yellow.opacity(0.3), lineWidth: 1))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Space.md) {
            metricCard(
                title: "CPU Usage",
                symbol: "cpu",
                value: String(format: "%.1f%%", model.metrics.cpuPercent),
                fraction: model.metrics.cpuPercent / 100.0,
                color: model.metrics.cpuPercent > 80 ? .red : (model.metrics.cpuPercent > 50 ? .orange : Palette.accent)
            )
            metricCard(
                title: "Memory",
                symbol: "memorychip",
                value: String(format: "%.1f / %.1f GB", Double(model.metrics.memoryUsedBytes) / 1e9, Double(model.metrics.memoryTotalBytes) / 1e9),
                fraction: model.metrics.memoryFraction,
                color: model.metrics.memoryFraction > 0.85 ? .orange : Palette.accent
            )
            metricCard(
                title: "Load Average",
                symbol: "chart.line.uptrend.xyaxis",
                value: String(format: "%.2f", model.metrics.loadAverage1m),
                subvalue: String(format: "5m: %.2f  •  15m: %.2f", model.metrics.loadAverage5m, model.metrics.loadAverage15m),
                fraction: nil,
                color: Palette.accent
            )
        }
    }

    private func metricCard(title: String, symbol: String, value: String, subvalue: String? = nil, fraction: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
            if let subvalue {
                Text(subvalue)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            if let fraction {
                ProgressView(value: fraction, total: 1.0)
                    .tint(color)
                    .padding(.top, 2)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("CPU History (Recent)")
                .font(.headline)
            Chart {
                ForEach(Array(model.metricsHistory.enumerated()), id: \.offset) { index, sample in
                    AreaMark(
                        x: .value("Time", index),
                        y: .value("CPU", sample.cpuPercent)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Palette.accent.opacity(0.35), Palette.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Time", index),
                        y: .value("CPU", sample.cpuPercent)
                    )
                    .foregroundStyle(Palette.accent)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .frame(height: 140)
        }
        .padding(Space.md)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private var quickActions: some View {
        HStack(spacing: Space.md) {
            Button("Open Web Dashboard") {
                if let url = URL(string: "https://\(model.host)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)

            Button("Launch SSH Terminal") {
                let script = "tell application \"Terminal\" to do script \"ssh -i \(model.identityFile) \(model.targetString)\""
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var uptimeText: String {
        let secs = model.metrics.uptimeSeconds
        let days = secs / 86400
        let hours = (secs % 86400) / 3600
        let mins = (secs % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h uptime"
        } else {
            return "\(hours)h \(mins)m uptime"
        }
    }
}
