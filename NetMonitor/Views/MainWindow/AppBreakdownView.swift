import SwiftUI
import SwiftData

struct AppBreakdownView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var apps: [AppUsageRow] = []
    @State private var selectedTimeRange: TimeRange = .today
    @State private var sortOrder: SortOrder = .totalDescending

    enum TimeRange: String, CaseIterable {
        case lastHour = "Last Hour"
        case today = "Today"
        case week = "This Week"
    }

    enum SortOrder {
        case totalDescending
        case downloadDescending
        case uploadDescending
        case nameAscending
    }

    struct AppUsageRow: Identifiable {
        let id = UUID()
        let name: String
        let bundleIdentifier: String?
        let bytesReceived: Int64
        let bytesSent: Int64
        var total: Int64 { bytesReceived + bytesSent }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                Text("\(apps.count) apps")
                    .foregroundStyle(.secondary)
            }

            Table(sortedApps) {
                TableColumn("Application") { row in
                    HStack(spacing: 8) {
                        AppIconView(bundleIdentifier: row.bundleIdentifier)
                        Text(row.name)
                            .lineLimit(1)
                    }
                }
                .width(min: 200)

                TableColumn("Downloaded") { row in
                    Text(ByteCountFormatter.formatBytes(row.bytesReceived))
                        .monospacedDigit()
                        .foregroundStyle(.blue)
                }
                .width(100)

                TableColumn("Uploaded") { row in
                    Text(ByteCountFormatter.formatBytes(row.bytesSent))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                }
                .width(100)

                TableColumn("Total") { row in
                    Text(ByteCountFormatter.formatBytes(row.total))
                        .monospacedDigit()
                        .bold()
                }
                .width(100)
            }
        }
        .padding(20)
        .onAppear { loadData() }
        .onChange(of: selectedTimeRange) { loadData() }
    }

    private var sortedApps: [AppUsageRow] {
        switch sortOrder {
        case .totalDescending: return apps.sorted { $0.total > $1.total }
        case .downloadDescending: return apps.sorted { $0.bytesReceived > $1.bytesReceived }
        case .uploadDescending: return apps.sorted { $0.bytesSent > $1.bytesSent }
        case .nameAscending: return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }

    private func loadData() {
        let since: Date
        switch selectedTimeRange {
        case .lastHour:
            since = Date().addingTimeInterval(-3600)
        case .today:
            since = Calendar.current.startOfDay(for: Date())
        case .week:
            since = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }

        let descriptor = FetchDescriptor<AppTrafficSample>(
            predicate: #Predicate { $0.timestamp >= since }
        )

        guard let samples = try? modelContext.fetch(descriptor) else { return }

        var aggregated: [String: (name: String, bundleId: String?, received: Int64, sent: Int64)] = [:]
        for sample in samples {
            let key = sample.bundleIdentifier ?? sample.processName
            var entry = aggregated[key] ?? (name: sample.processName, bundleId: sample.bundleIdentifier, received: 0, sent: 0)
            entry.received += sample.bytesReceived
            entry.sent += sample.bytesSent
            aggregated[key] = entry
        }

        apps = aggregated.values.map {
            AppUsageRow(
                name: $0.name,
                bundleIdentifier: $0.bundleId,
                bytesReceived: $0.received,
                bytesSent: $0.sent
            )
        }
    }
}

struct AppIconView: View {
    let bundleIdentifier: String?

    var body: some View {
        Group {
            if let bundleId = bundleIdentifier,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable()
            } else {
                Image(systemName: "app")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
    }
}
