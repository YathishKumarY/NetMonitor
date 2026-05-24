import Foundation
import SwiftData

@Observable
final class MenuBarViewModel {
    var downloadSpeed: Double = 0
    var uploadSpeed: Double = 0
    var todayReceived: Int64 = 0
    var todaySent: Int64 = 0
    var todayWifiReceived: Int64 = 0
    var todayWifiSent: Int64 = 0
    var todayHotspotReceived: Int64 = 0
    var todayHotspotSent: Int64 = 0
    var topApps: [TopAppEntry] = []

    private var refreshTimer: Timer?

    func startUpdating(from engine: SamplingEngine, dataStore: DataStore?) {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.downloadSpeed = engine.currentDownloadSpeed
            self.uploadSpeed = engine.currentUploadSpeed
            self.todayReceived = engine.todayTotalReceived
            self.todaySent = engine.todayTotalSent
            self.todayWifiReceived = engine.todayWifiReceived
            self.todayWifiSent = engine.todayWifiSent
            self.todayHotspotReceived = engine.todayHotspotReceived
            self.todayHotspotSent = engine.todayHotspotSent
        }

        // Refresh top apps less frequently
        Task {
            while !Task.isCancelled {
                if let store = dataStore {
                    let oneHourAgo = Date().addingTimeInterval(-3600)
                    if let apps = try? await store.fetchTopApps(since: oneHourAgo, limit: Constants.topAppsCount) {
                        await MainActor.run {
                            self.topApps = apps
                        }
                    }
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopUpdating() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
