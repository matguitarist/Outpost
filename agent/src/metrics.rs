use serde::Serialize;
use sysinfo::{CpuRefreshKind, Disks, Networks, RefreshKind, System};
use std::sync::{Arc, Mutex};
use std::time::Instant;

#[derive(Debug, Clone, Serialize)]
pub struct SystemMetrics {
    #[serde(rename = "cpuPercent")]
    pub cpu_percent: f64,
    #[serde(rename = "memoryUsedBytes")]
    pub memory_used_bytes: u64,
    #[serde(rename = "memoryTotalBytes")]
    pub memory_total_bytes: u64,
    #[serde(rename = "uptimeSeconds")]
    pub uptime_seconds: u64,
    #[serde(rename = "loadAverage1m")]
    pub load_average_1m: f64,
    #[serde(rename = "loadAverage5m")]
    pub load_average_5m: f64,
    #[serde(rename = "loadAverage15m")]
    pub load_average_15m: f64,
    #[serde(rename = "networkInBytesPerSecond")]
    pub network_in_bytes_per_second: u64,
    #[serde(rename = "networkOutBytesPerSecond")]
    pub network_out_bytes_per_second: u64,
}

pub struct MetricsCollector {
    sys: System,
    networks: Networks,
    disks: Disks,
    last_tick: Instant,
}

impl MetricsCollector {
    pub fn new() -> Self {
        let mut sys = System::new_with_specifics(
            RefreshKind::nothing()
                .with_cpu(CpuRefreshKind::everything())
                .with_memory(sysinfo::MemoryRefreshKind::everything()),
        );
        sys.refresh_all();
        let networks = Networks::new_with_refreshed_list();
        let disks = Disks::new_with_refreshed_list();

        Self {
            sys,
            networks,
            disks,
            last_tick: Instant::now(),
        }
    }

    pub fn collect(&mut self) -> SystemMetrics {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_tick).as_secs_f64().max(0.001);
        self.last_tick = now;

        self.sys.refresh_cpu_usage();
        self.sys.refresh_memory();
        self.networks.refresh(true);
        self.disks.refresh(true);

        let cpu_percent = self.sys.global_cpu_usage() as f64;
        let memory_used_bytes = self.sys.used_memory();
        let memory_total_bytes = self.sys.total_memory();
        let uptime_seconds = System::uptime();
        let load_avg = System::load_average();

        let mut rx_total = 0u64;
        let mut tx_total = 0u64;
        for (_iface, data) in &self.networks {
            rx_total = rx_total.saturating_add(data.received());
            tx_total = tx_total.saturating_add(data.transmitted());
        }

        let network_in_bytes_per_second = (rx_total as f64 / elapsed) as u64;
        let network_out_bytes_per_second = (tx_total as f64 / elapsed) as u64;

        SystemMetrics {
            cpu_percent,
            memory_used_bytes,
            memory_total_bytes,
            uptime_seconds,
            load_average_1m: load_avg.one,
            load_average_5m: load_avg.five,
            load_average_15m: load_avg.fifteen,
            network_in_bytes_per_second,
            network_out_bytes_per_second,
        }
    }
}

pub type SharedCollector = Arc<Mutex<MetricsCollector>>;
