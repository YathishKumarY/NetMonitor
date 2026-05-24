import Foundation
import SwiftData

@Observable
final class AlertsViewModel {
    var alerts: [UsageAlert] = []
    var showingAddAlert = false

    func loadAlerts(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UsageAlert>(
            sortBy: [SortDescriptor(\.name)]
        )
        alerts = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addAlert(
        name: String,
        thresholdBytes: Int64,
        period: AlertPeriod,
        direction: TrafficDirection,
        interfaceFilter: String?,
        appFilter: String?,
        modelContext: ModelContext
    ) {
        let alert = UsageAlert(
            name: name,
            thresholdBytes: thresholdBytes,
            period: period,
            direction: direction,
            interfaceFilter: interfaceFilter,
            appFilter: appFilter
        )
        modelContext.insert(alert)
        try? modelContext.save()
        loadAlerts(modelContext: modelContext)
    }

    func deleteAlert(_ alert: UsageAlert, modelContext: ModelContext) {
        modelContext.delete(alert)
        try? modelContext.save()
        loadAlerts(modelContext: modelContext)
    }

    func toggleAlert(_ alert: UsageAlert, modelContext: ModelContext) {
        alert.isEnabled.toggle()
        try? modelContext.save()
    }
}
