import Foundation
import SwiftData

@Model
final class DailySummary {
    @Attribute(.unique) var dateKey: String
    var totalReceived: Int64
    var totalSent: Int64
    var wifiReceived: Int64
    var wifiSent: Int64
    var hotspotReceived: Int64
    var hotspotSent: Int64
    var topAppsJSON: Data?

    init(
        dateKey: String,
        totalReceived: Int64 = 0,
        totalSent: Int64 = 0,
        wifiReceived: Int64 = 0,
        wifiSent: Int64 = 0,
        hotspotReceived: Int64 = 0,
        hotspotSent: Int64 = 0,
        topAppsJSON: Data? = nil
    ) {
        self.dateKey = dateKey
        self.totalReceived = totalReceived
        self.totalSent = totalSent
        self.wifiReceived = wifiReceived
        self.wifiSent = wifiSent
        self.hotspotReceived = hotspotReceived
        self.hotspotSent = hotspotSent
        self.topAppsJSON = topAppsJSON
    }

    static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct TopAppEntry: Codable {
    let name: String
    let bundleIdentifier: String?
    let bytesReceived: Int64
    let bytesSent: Int64
}
