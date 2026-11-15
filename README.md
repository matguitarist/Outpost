# Outpost

A native macOS menu bar monitor for your home server, built with fluid materials, live telemetry, and zero bloat.

[Download Outpost](https://github.com/matguitarist/Outpost/releases/latest/download/Outpost.dmg)

## Building

Building Outpost requires macOS and Xcode tools.

```bash
# Build, sign ad-hoc, and install to ~/Applications/Outpost.app:
./build.sh

# Run self-test:
tools/selftest.sh

# Run unit tests:
swift test
```

## Outpost Agent (Server)

The server daemon is written in Rust, listening on `127.0.0.1:7654` and providing real-time telemetry with sub-5MB memory footprint.

```bash
cd outpost-agent
cargo build --release
```

## License

MIT License. See [LICENSE](LICENSE) for details.
