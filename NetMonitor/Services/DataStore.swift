import Foundation
import SwiftData

@ModelActor
actor DataStore {

    func insertInterfaceSamples(_ samples: [InterfaceSample]) throws {
        for sample in samples {
            modelContext.insert(sample)
        }
        try modelContext.save()
    }

    func insertAppTrafficSamples(_ samples: [AppTrafficSample]) throws {
        for sample in samples {
            modelContext.insert(sample)
        }
        try modelContext.save()
    }

    func updateDailySummary(
        dateKey: String,
        receivedDelta: Int64,
        sentDelta: Int64,
        interfaceType: String
    ) throws {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        let existing = try modelContext.fetch(descriptor).first

        let summary: DailySummary
        if let existing {
            summary = existing
        } else {
            summary = DailySummary(dateKey: dateKey)
            modelContext.insert(summary)
        }

        summary.totalReceived += receivedDelta
        summary.totalSent += sentDelta

        switch interfaceType {
        case "wifi":
            summary.wifiReceived += receivedDelta
            summary.wifiSent += sentDelta
        case "hotspot":
            summary.hotspotReceived += receivedDelta
            summary.hotspotSent += sentDelta
        default:
            break
        }

        try modelContext.save()
    }

    func updateTopApps(dateKey: String, apps: [TopAppEntry]) throws {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        guard let summary = try modelContext.fetch(descriptor).first else { return }
        summary.topAppsJSON = try JSONEncoder().encode(apps)
        try modelContext.save()
    }

    func fetchEnabledAlerts() throws -> [UsageAlert] {
        let descriptor = FetchDescriptor<UsageAlert>(
            predicate: #Predicate { $0.isEnabled == true }
        )
        return try modelContext.fetch(descriptor)
    }

    func markAlertTriggered(_ alertId: UUID) throws {
        let descriptor = FetchDescriptor<UsageAlert>(
            predicate: #Predicate { $0.id == alertId }
        )
        guard let alert = try modelContext.fetch(descriptor).first else { return }
        alert.lastTriggeredDate = Date()
        try modelContext.save()
    }

    func fetchDailySummary(for dateKey: String) throws -> DailySummary? {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchDailySummaries(from startDate: String, to endDate: String) throws -> [DailySummary] {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.dateKey >= startDate && $0.dateKey <= endDate },
            sortBy: [SortDescriptor(\.dateKey)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchInterfaceSamples(since date: Date) throws -> [InterfaceSample] {
        let descriptor = FetchDescriptor<InterfaceSample>(
            predicate: #Predicate { $0.timestamp >= date },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTopApps(since date: Date, limit: Int) throws -> [TopAppEntry] {
        let descriptor = FetchDescriptor<AppTrafficSample>(
            predicate: #Predicate { $0.timestamp >= date }
        )
        let samples = try modelContext.fetch(descriptor)

        var appTotals: [String: (name: String, bundleId: String?, received: Int64, sent: Int64)] = [:]
        for sample in samples {
            let key = sample.bundleIdentifier ?? sample.processName
            var entry = appTotals[key] ?? (name: sample.processName, bundleId: sample.bundleIdentifier, received: 0, sent: 0)
            entry.received += sample.bytesReceived
            entry.sent += sample.bytesSent
            appTotals[key] = entry
        }

        return appTotals.values
            .sorted { ($0.received + $0.sent) > ($1.received + $1.sent) }
            .prefix(limit)
            .map { TopAppEntry(name: $0.name, bundleIdentifier: $0.bundleId, bytesReceived: $0.received, bytesSent: $0.sent) }
    }

    func pruneOldData(olderThan date: Date) throws {
        let interfaceDescriptor = FetchDescriptor<InterfaceSample>(
            predicate: #Predicate { $0.timestamp < date }
        )
        let oldSamples = try modelContext.fetch(interfaceDescriptor)
        for sample in oldSamples {
            modelContext.delete(sample)
        }

        let appDescriptor = FetchDescriptor<AppTrafficSample>(
            predicate: #Predicate { $0.timestamp < date }
        )
        let oldAppSamples = try modelContext.fetch(appDescriptor)
        for sample in oldAppSamples {
            modelContext.delete(sample)
        }

        try modelContext.save()
    }

    func totalUsageForPeriod(
        since startDate: Date,
        direction: TrafficDirection,
        interfaceFilter: String?
    ) throws -> Int64 {
        var total: Int64 = 0

        if let interfaceFilter {
            let descriptor = FetchDescriptor<InterfaceSample>(
                predicate: #Predicate { $0.timestamp >= startDate && $0.interfaceType == interfaceFilter }
            )
            let samples = try modelContext.fetch(descriptor)
            for sample in samples {
                switch direction {
                case .download: total += sample.bytesReceived
                case .upload: total += sample.bytesSent
                case .both: total += sample.bytesReceived + sample.bytesSent
                }
            }
        } else {
            let descriptor = FetchDescriptor<InterfaceSample>(
                predicate: #Predicate { $0.timestamp >= startDate }
            )
            let samples = try modelContext.fetch(descriptor)
            for sample in samples {
                switch direction {
                case .download: total += sample.bytesReceived
                case .upload: total += sample.bytesSent
                case .both: total += sample.bytesReceived + sample.bytesSent
                }
            }
        }

        return total
    }
}
