import Foundation
import SwiftData
import UserNotifications

final class AlertEngine {
    private let modelContainer: ModelContainer
    private var dataStore: DataStore?
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.netmonitor.alerts", qos: .utility)

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        Task {
            self.dataStore = DataStore(modelContainer: modelContainer)
        }
    }

    func start() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(
            deadline: .now() + Constants.aggregationInterval,
            repeating: Constants.aggregationInterval,
            leeway: .seconds(5)
        )
        timer?.setEventHandler { [weak self] in
            Task {
                await self?.evaluateAlerts()
            }
        }
        timer?.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func evaluateAlerts() async {
        guard let dataStore else { return }
        guard let alerts = try? await dataStore.fetchEnabledAlerts() else { return }

        for alert in alerts {
            if alreadyTriggeredThisPeriod(alert) { continue }

            let startDate = periodStartDate(for: alert.period)
            guard let usage = try? await dataStore.totalUsageForPeriod(
                since: startDate,
                direction: alert.direction,
                interfaceFilter: alert.interfaceFilter
            ) else { continue }

            if usage >= alert.thresholdBytes {
                await fireNotification(for: alert, currentUsage: usage)
                try? await dataStore.markAlertTriggered(alert.id)
            }
        }
    }

    private func alreadyTriggeredThisPeriod(_ alert: UsageAlert) -> Bool {
        guard let lastTriggered = alert.lastTriggeredDate else { return false }
        let periodStart = periodStartDate(for: alert.period)
        return lastTriggered >= periodStart
    }

    private func periodStartDate(for period: AlertPeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .daily:
            return calendar.startOfDay(for: now)
        case .weekly:
            let weekday = calendar.component(.weekday, from: now)
            return calendar.date(byAdding: .day, value: -(weekday - calendar.firstWeekday), to: calendar.startOfDay(for: now))!
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)!
        }
    }

    private func fireNotification(for alert: UsageAlert, currentUsage: Int64) async {
        let content = UNMutableNotificationContent()
        content.title = "Network Usage Alert"
        content.body = "\(alert.name): \(ByteCountFormatter.formatBytes(currentUsage)) used (limit: \(ByteCountFormatter.formatBytes(alert.thresholdBytes)))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "alert-\(alert.id.uuidString)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
