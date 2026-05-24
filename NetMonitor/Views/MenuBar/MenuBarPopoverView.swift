import SwiftUI

struct MenuBarPopoverView: View {
    var engine: SamplingEngine
    var topApps: [TopAppEntry] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Live speeds
            HStack(spacing: 20) {
                SpeedIndicator(
                    label: "Download",
                    speed: engine.currentDownloadSpeed,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                SpeedIndicator(
                    label: "Upload",
                    speed: engine.currentUploadSpeed,
                    icon: "arrow.up.circle.fill",
                    color: .orange
                )
            }
            .padding(.horizontal, 4)

            Divider()

            // Today's totals
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                UsageRow(
                    label: "Total",
                    received: engine.todayTotalReceived,
                    sent: engine.todayTotalSent
                )
                UsageRow(
                    label: "WiFi",
                    received: engine.todayWifiReceived,
                    sent: engine.todayWifiSent
                )
                UsageRow(
                    label: "Hotspot",
                    received: engine.todayHotspotReceived,
                    sent: engine.todayHotspotSent
                )
            }

            if !topApps.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Top Apps (last hour)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(topApps, id: \.name) { app in
                        HStack {
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.formatBytes(app.bytesReceived + app.bytesSent))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
            }

            Divider()

            HStack {
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.title == "NetMonitor" {
                        window.makeKeyAndOrderFront(nil)
                        return
                    }
                }
                .buttonStyle(.link)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.link)
                .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: Constants.popoverWidth)
    }
}

private struct SpeedIndicator: View {
    let label: String
    let speed: Double
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(ByteCountFormatter.formatSpeed(speed))
                .font(.system(.title3, design: .monospaced, weight: .medium))
        }
    }
}

private struct UsageRow: View {
    let label: String
    let received: Int64
    let sent: Int64

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text(ByteCountFormatter.formatBytes(received))
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(ByteCountFormatter.formatBytes(sent))
                    .monospacedDigit()
            }
        }
        .font(.caption)
    }
}
