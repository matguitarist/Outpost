import Foundation

/// Real-time metrics snapshot from an Outpost server.
public struct SystemMetrics: Sendable, Codable, Equatable {
    public var cpuPercent: Double
    public var memoryUsedBytes: UInt64
    public var memoryTotalBytes: UInt64
    public var uptimeSeconds: UInt64
    public var loadAverage1m: Double
    public var loadAverage5m: Double
    public var loadAverage15m: Double
    public var networkInBytesPerSecond: UInt64
    public var networkOutBytesPerSecond: UInt64

    public init(
        cpuPercent: Double = 0.0,
        memoryUsedBytes: UInt64 = 0,
        memoryTotalBytes: UInt64 = 0,
        uptimeSeconds: UInt64 = 0,
        loadAverage1m: Double = 0.0,
        loadAverage5m: Double = 0.0,
        loadAverage15m: Double = 0.0,
        networkInBytesPerSecond: UInt64 = 0,
        networkOutBytesPerSecond: UInt64 = 0
    ) {
        self.cpuPercent = cpuPercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.uptimeSeconds = uptimeSeconds
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
        self.networkInBytesPerSecond = networkInBytesPerSecond
        self.networkOutBytesPerSecond = networkOutBytesPerSecond
    }

    public var memoryFraction: Double {
        guard memoryTotalBytes > 0 else { return 0.0 }
        return Double(memoryUsedBytes) / Double(memoryTotalBytes)
    }
}

/// A container running on the remote host.
public struct ContainerInfo: Sendable, Codable, Identifiable, Equatable {
    public var id: String
    public var name: String
    public var image: String
    public var state: String
    public var status: String

    public init(id: String, name: String, image: String, state: String, status: String) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.status = status
    }
}
