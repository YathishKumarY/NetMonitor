import Foundation
import SwiftData

@Observable
final class DashboardViewModel {
    var totalReceived: Int64 = 0
    var totalSent: Int64 = 0
    var recentSamples: [ChartDataPoint] = []
    var selectedTimeRange: TimeRange = .today
    var isLoading = false

    enum TimeRange: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
    }

    func loadData(modelContext: ModelContext) {
        isLoading = true
        let calendar = Calendar.current

        switch selectedTimeRange {
        case .today:
            loadTodayData(modelContext: modelContext, calendar: calendar)
        case .week:
            loadRangeData(modelContext: modelContext, days: 7)
        case .month:
            loadRangeData(modelContext: modelContext, days: 30)
        }

        isLoading = false
    }

    private func loadTodayData(modelContext: ModelContext, calendar: Calendar) {
        let startOfDay = calendar.startOfDay(for: Date())
        let descriptor = FetchDescriptor<InterfaceSample>(
            predicate: #Predicate { $0.timestamp >= startOfDay },
            sortBy: [SortDescriptor(\.timestamp)]
        )

        guard let samples = try? modelContext.fetch(descriptor) else { return }

        // Compute totals for summary cards
        var rx: Int64 = 0
        var tx: Int64 = 0
        for sample in samples {
            rx += sample.bytesReceived
            tx += sample.bytesSent
        }
        totalReceived = rx
        totalSent = tx

        // Group by 5-minute intervals
        var grouped: [Date: (received: Int64, sent: Int64)] = [:]
        for sample in samples {
            let minute = calendar.component(.minute, from: sample.timestamp)
            let roundedMinute = (minute / 5) * 5
            var components = calendar.dateComponents([.year, .month, .day, .hour], from: sample.timestamp)
            components.minute = roundedMinute
            components.second = 0
            guard let interval = calendar.date(from: components) else { continue }

            var entry = grouped[interval] ?? (received: 0, sent: 0)
            entry.received += sample.bytesReceived
            entry.sent += sample.bytesSent
            grouped[interval] = entry
        }

        recentSamples = grouped.sorted { $0.key < $1.key }.map {
            ChartDataPoint(date: $0.key, bytesReceived: $0.value.received, bytesSent: $0.value.sent)
        }
    }

    private func loadRangeData(modelContext: ModelContext, days: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let endDate = formatter.string(from: Date())
        let startDate = formatter.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)

        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey >= startDate && $0.dateKey <= endDate },
            sortBy: [SortDescriptor(\.dateKey)]
        )

        guard let summaries = try? modelContext.fetch(descriptor) else { return }

        // Compute totals for summary cards
        var rx: Int64 = 0
        var tx: Int64 = 0
        for s in summaries {
            rx += s.totalReceived
            tx += s.totalSent
        }
        totalReceived = rx
        totalSent = tx

        recentSamples = summaries.compactMap { summary in
            guard let date = formatter.date(from: summary.dateKey) else { return nil }
            return ChartDataPoint(
                date: date,
                bytesReceived: summary.totalReceived,
                bytesSent: summary.totalSent
            )
        }
    }
}
