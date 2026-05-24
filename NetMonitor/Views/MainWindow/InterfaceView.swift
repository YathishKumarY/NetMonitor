import SwiftUI
import SwiftData
import Charts

struct InterfaceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedInterface: InterfaceFilter = .all
    @State private var dailyData: [InterfaceDayData] = []

    enum InterfaceFilter: String, CaseIterable {
        case all = "All"
        case wifi = "WiFi"
        case hotspot = "Hotspot"
    }

    struct InterfaceDayData: Identifiable {
        let id = UUID()
        let date: Date
        let dateLabel: String
        let wifiReceived: Int64
        let wifiSent: Int64
        let hotspotReceived: Int64
        let hotspotSent: Int64
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Interface", selection: $selectedInterface) {
                    ForEach(InterfaceFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                // Bar chart comparing interfaces
                Chart(dailyData) { day in
                    if selectedInterface != .hotspot {
                        BarMark(
                            x: .value("Day", day.dateLabel),
                            y: .value("Bytes", day.wifiReceived + day.wifiSent)
                        )
                        .foregroundStyle(.blue)
                        .position(by: .value("Interface", "WiFi"))
                    }

                    if selectedInterface != .wifi {
                        BarMark(
                            x: .value("Day", day.dateLabel),
                            y: .value("Bytes", day.hotspotReceived + day.hotspotSent)
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Interface", "Hotspot"))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteCountFormatter.formatBytes(bytes))
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "WiFi": Color.blue,
                    "Hotspot": Color.green
                ])
                .frame(minHeight: 300)

                // Interface details table
                if !dailyData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daily Breakdown")
                            .font(.headline)

                        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                            GridRow {
                                Text("Date").bold()
                                Text("WiFi Down").bold()
                                Text("WiFi Up").bold()
                                Text("Hotspot Down").bold()
                                Text("Hotspot Up").bold()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            ForEach(dailyData.suffix(7)) { day in
                                GridRow {
                                    Text(day.dateLabel)
                                    Text(ByteCountFormatter.formatBytes(day.wifiReceived))
                                        .foregroundStyle(.blue)
                                    Text(ByteCountFormatter.formatBytes(day.wifiSent))
                                        .foregroundStyle(.blue.opacity(0.7))
                                    Text(ByteCountFormatter.formatBytes(day.hotspotReceived))
                                        .foregroundStyle(.green)
                                    Text(ByteCountFormatter.formatBytes(day.hotspotSent))
                                        .foregroundStyle(.green.opacity(0.7))
                                }
                                .font(.caption)
                                .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .onAppear { loadData() }
        .onChange(of: selectedInterface) { loadData() }
    }

    private func loadData() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"

        let endDate = formatter.string(from: Date())
        let startDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: -14, to: Date())!)

        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey >= startDate && $0.dateKey <= endDate },
            sortBy: [SortDescriptor(\.dateKey)]
        )

        guard let summaries = try? modelContext.fetch(descriptor) else { return }

        dailyData = summaries.compactMap { summary in
            guard let date = formatter.date(from: summary.dateKey) else { return nil }
            return InterfaceDayData(
                date: date,
                dateLabel: displayFormatter.string(from: date),
                wifiReceived: summary.wifiReceived,
                wifiSent: summary.wifiSent,
                hotspotReceived: summary.hotspotReceived,
                hotspotSent: summary.hotspotSent
            )
        }
    }
}
