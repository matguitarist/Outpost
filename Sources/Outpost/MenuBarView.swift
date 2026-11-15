import AppKit
import Charts
import OutpostKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: Space.md) {
                    statusRow
                    cpuCard
                    memoryCard
                    loadCard
                }
                .padding(Space.md)
            }
            Divider()
            footer
        }
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: "server.rack")
                .foregroundStyle(Palette.accent)
            Text(model.host)
                .font(.headline)
            Spacer()
            Circle()
                .fill(model.isConnected ? Color.green : (model.isConnecting ? Color.orange : Color.gray))
                .frame(width: 8, height: 8)
            Text(model.isConnected ? "Connected" : (model.isConnecting ? "Connecting…" : "Offline"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }

    private var statusRow: some View {
        HStack {
            Label(uptimeText, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let last = model.lastUpdated {
                Text(last, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f%%", model.metrics.cpuPercent))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(cpuColor)
            }
            ProgressView(value: model.metrics.cpuPercent, total: 100.0)
                .tint(cpuColor)
        }
        .padding(Space.sm)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private var memoryCard: some View {
        let usedGb = Double(model.metrics.memoryUsedBytes) / 1_073_741_824.0
        let totalGb = Double(model.metrics.memoryTotalBytes) / 1_073_741_824.0
        let fraction = model.metrics.memoryFraction

        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Label("Memory", systemImage: "memorychip")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(String(format: "%.1f / %.1f GB", usedGb, totalGb))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: fraction, total: 1.0)
                .tint(fraction > 0.85 ? .orange : Palette.accent)
        }
        .padding(Space.sm)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
    }

    private var loadCard: some View {
        HStack {
            Label("Load Average", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.2f  %.2f  %.2f", model.metrics.loadAverage1m, model.metrics.loadAverage5m, model.metrics.loadAverage15m))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Space.xs)
    }

    private var footer: some View {
        HStack {
            Button("Open Window") {
                openWindow(id: "main")
                NSApp.activate()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Spacer()

            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
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

    private var cpuColor: Color {
        let val = model.metrics.cpuPercent
        if val > 80 { return .red }
        if val > 50 { return .orange }
        return Palette.accent
    }
}
