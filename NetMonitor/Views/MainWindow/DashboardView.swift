import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case apps = "Apps"
        case interfaces = "Interfaces"
        case alerts = "Alerts"
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: iconForTab(tab))
            }
            .listStyle(.sidebar)
            .frame(minWidth: 150)
        } detail: {
            switch selectedTab {
            case .overview:
                OverviewTabView()
            case .apps:
                AppBreakdownView()
            case .interfaces:
                InterfaceView()
            case .alerts:
                AlertsConfigView()
            }
        }
        .navigationTitle("NetMonitor")
    }

    private func iconForTab(_ tab: Tab) -> String {
        switch tab {
        case .overview: return "chart.line.uptrend.xyaxis"
        case .apps: return "square.grid.2x2"
        case .interfaces: return "wifi"
        case .alerts: return "bell"
        }
    }
}

struct OverviewTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()
    let refreshTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Time range picker
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(DashboardViewModel.TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                // Summary cards - always visible
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Downloaded",
                        value: ByteCountFormatter.formatBytes(viewModel.totalReceived),
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    SummaryCard(
                        title: "Uploaded",
                        value: ByteCountFormatter.formatBytes(viewModel.totalSent),
                        icon: "arrow.up.circle.fill",
                        color: .orange
                    )
                    SummaryCard(
                        title: "Total",
                        value: ByteCountFormatter.formatBytes(viewModel.totalReceived + viewModel.totalSent),
                        icon: "arrow.up.arrow.down.circle.fill",
                        color: .green
                    )
                }

                // Chart
                NetworkUsageChart(data: viewModel.recentSamples)
                    .frame(minHeight: 300)
            }
            .padding(20)
        }
        .onAppear {
            viewModel.loadData(modelContext: modelContext)
        }
        .onReceive(refreshTimer) { _ in
            viewModel.loadData(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedTimeRange) {
            viewModel.loadData(modelContext: modelContext)
        }
    }
}

struct NetworkUsageChart: View {
    let data: [ChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Usage")
                .font(.headline)

            if data.isEmpty {
                ContentUnavailableView(
                    "No Data Yet",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Usage data will appear here as network activity is recorded.")
                )
                .frame(height: 250)
            } else {
                Chart {
                    ForEach(data) { point in
                        BarMark(
                            x: .value("Time", point.date, unit: .minute),
                            y: .value("Downloaded", point.bytesReceived)
                        )
                        .foregroundStyle(.blue.opacity(0.7))
                        .position(by: .value("Direction", "Download"))

                        BarMark(
                            x: .value("Time", point.date, unit: .minute),
                            y: .value("Uploaded", point.bytesSent)
                        )
                        .foregroundStyle(.orange.opacity(0.7))
                        .position(by: .value("Direction", "Upload"))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let bytes = value.as(Int64.self) {
                                Text(ByteCountFormatter.formatBytes(bytes))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartForegroundStyleScale([
                    "Download": Color.blue.opacity(0.7),
                    "Upload": Color.orange.opacity(0.7)
                ])
                .chartLegend(position: .top, alignment: .leading) {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(.blue.opacity(0.7)).frame(width: 12, height: 12)
                            Text("Download").font(.caption)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(.orange.opacity(0.7)).frame(width: 12, height: 12)
                            Text("Upload").font(.caption)
                        }
                    }
                }
                .frame(minHeight: 250)
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
