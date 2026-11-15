import Foundation
import Testing
@testable import OutpostKit

@Suite struct SystemMetricsTests {
    @Test func calculatesMemoryFractionCorrectly() {
        let metrics = SystemMetrics(
            cpuPercent: 42.5,
            memoryUsedBytes: 8_000_000_000,
            memoryTotalBytes: 16_000_000_000
        )
        #expect(abs(metrics.memoryFraction - 0.5) < 0.001)
    }

    @Test func handlesZeroMemorySafely() {
        let metrics = SystemMetrics()
        #expect(metrics.memoryFraction == 0.0)
    }
}
