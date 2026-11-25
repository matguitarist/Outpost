import Foundation
import ProcessKit

public enum SSHError: LocalizedError, Equatable {
    case command(status: Int32, message: String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .command(let status, let message):
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if status == 255 {
                if text.contains("Permission denied") {
                    return "SSH Permission Denied. Check your SSH key path and ensure the server has your public key in ~/.ssh/authorized_keys."
                }
                return text.isEmpty ? "Couldn't connect over SSH." : text
            }
            return text.isEmpty ? "SSH command failed (exit code \(status))." : text
        case .timeout:
            return "SSH connection timed out."
        }
    }
}

public actor SSHClient {
    public nonisolated let target: String
    public nonisolated let identityFile: String?
    public nonisolated let port: Int

    private var masterReady = false

    public init(target: String, identityFile: String? = nil, port: Int = 22) {
        self.target = target
        let key = identityFile?.trimmingCharacters(in: .whitespaces) ?? ""
        self.identityFile = key.isEmpty ? nil : (key as NSString).expandingTildeInPath
        self.port = port
    }

    private nonisolated var controlPath: String {
        "/tmp/outpost-\(getuid())-%C"
    }

    nonisolated func sshArguments(_ remote: String? = nil, extra: [String] = []) -> [String] {
        var args = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=5",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "ControlPath=\(controlPath)",
            "-p", String(port)
        ]
        if let identityFile {
            args += ["-i", identityFile, "-o", "IdentitiesOnly=yes"]
        }
        args += extra
        args.append(target)
        if let remote {
            args.append(remote)
        }
        return args
    }

    public func ensureMaster() async throws {
        if masterReady, (try? await Self.run(sshArguments(extra: ["-O", "check"]))) != nil { return }
        masterReady = false
        if (try? await Self.run(sshArguments(extra: ["-O", "check"]))) == nil {
            _ = try await Self.run(
                sshArguments(extra: ["-f", "-N", "-o", "ControlMaster=yes", "-o", "ControlPersist=600"]),
                background: true
            )
        }
        masterReady = true
    }

    public func disconnect() async {
        _ = try? await Self.run(sshArguments(extra: ["-O", "exit"]))
        masterReady = false
    }

    public nonisolated func disconnectNow() {
        _ = try? Shell.runSync("/usr/bin/ssh", sshArguments(extra: ["-O", "exit"]), options: Self.options(stdout: .discard, stderr: .discard))
    }

    public func runRemote(_ command: String) async throws -> String {
        try await ensureMaster()
        do {
            return try await Self.run(sshArguments(command))
        } catch SSHError.command(status: 255, _) {
            masterReady = false
            try await ensureMaster()
            return try await Self.run(sshArguments(command))
        }
    }

    public func testConnection() async -> Result<String, Error> {
        do {
            let output = try await runRemote("uname -s -r")
            return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return .failure(error)
        }
    }

    /// Fetches system metrics directly from /proc without requiring any daemon installed.
    public func fetchDirectMetrics() async throws -> SystemMetrics {
        let script = #"""
        awk '/^cpu / {print "@cpu", $2+$3+$4, $2+$3+$4+$5}' /proc/stat
        awk '/MemTotal:/ {tot=$2} /MemAvailable:/ {avail=$2} END {print "@mem", tot, tot-avail}' /proc/meminfo
        awk '{print "@load", $1, $2, $3}' /proc/loadavg
        awk '{print "@uptime", int($1)}' /proc/uptime
        """#
        let output = try await runRemote(script)
        var cpuUsed: Double = 0
        var cpuTotal: Double = 0
        var memTotalKb: UInt64 = 0
        var memUsedKb: UInt64 = 0
        var load1: Double = 0, load5: Double = 0, load15: Double = 0
        var uptime: UInt64 = 0

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard let tag = parts.first else { continue }
            switch tag {
            case "@cpu" where parts.count >= 3:
                cpuUsed = Double(parts[1]) ?? 0
                cpuTotal = Double(parts[2]) ?? 1
            case "@mem" where parts.count >= 3:
                memTotalKb = UInt64(parts[1]) ?? 0
                memUsedKb = UInt64(parts[2]) ?? 0
            case "@load" where parts.count >= 4:
                load1 = Double(parts[1]) ?? 0
                load5 = Double(parts[2]) ?? 0
                load15 = Double(parts[3]) ?? 0
            case "@uptime" where parts.count >= 2:
                uptime = UInt64(parts[1]) ?? 0
            default:
                break
            }
        }

        let cpuPercent = cpuTotal > 0 ? (cpuUsed / cpuTotal) * 100.0 : 0.0

        return SystemMetrics(
            cpuPercent: cpuPercent,
            memoryUsedBytes: memUsedKb * 1024,
            memoryTotalBytes: memTotalKb * 1024,
            uptimeSeconds: uptime,
            loadAverage1m: load1,
            loadAverage5m: load5,
            loadAverage15m: load15,
            networkInBytesPerSecond: 0,
            networkOutBytesPerSecond: 0
        )
    }

    /// ssh starts the way Terminal starts it: it disclaims Outpost as its responsible process, so macOS
    /// judges its network access on its own and Local Network privacy (tied to each build) never blocks it.
    private static func options(stdout: Shell.Destination = .capture, stderr: Shell.Destination = .capture) -> Shell.Options {
        Shell.Options(stdout: stdout, stderr: stderr, disclaimsResponsibility: true)
    }

    /// `background` is for `ssh -f`: the master it leaves running keeps its stdout and stderr, so they go
    /// to nothing and to a file instead of pipes, and the result comes when the first ssh exits.
    private static func run(_ arguments: [String], background: Bool = false) async throws -> String {
        let errorFile = FileManager.default.temporaryDirectory.appending(path: "outpost-ssh-\(UUID().uuidString).txt")
        defer { if background { try? FileManager.default.removeItem(at: errorFile) } }
        let output = try await Shell.run(
            "/usr/bin/ssh", arguments,
            options: background ? options(stdout: .discard, stderr: .file(errorFile)) : options()
        )
        guard output.succeeded else {
            let errors = background ? ((try? Data(contentsOf: errorFile)) ?? Data()) : output.stderr
            throw SSHError.command(status: output.status, message: String(decoding: errors, as: UTF8.self))
        }
        return output.text
    }
}
