import Foundation
import SwiftData

enum AlertPeriod: String, Codable, CaseIterable {
    case daily
    case weekly
    case monthly
}

enum TrafficDirection: String, Codable, CaseIterable {
    case download
    case upload
    case both
}

@Model
final class UsageAlert {
    @Attribute(.unique) var id: UUID
    var name: String
    var thresholdBytes: Int64
    var period: AlertPeriod
    var direction: TrafficDirection
    var interfaceFilter: String?
    var appFilter: String?
    var isEnabled: Bool
    var lastTriggeredDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        thresholdBytes: Int64,
        period: AlertPeriod = .daily,
        direction: TrafficDirection = .both,
        interfaceFilter: String? = nil,
        appFilter: String? = nil,
        isEnabled: Bool = true,
        lastTriggeredDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.thresholdBytes = thresholdBytes
        self.period = period
        self.direction = direction
        self.interfaceFilter = interfaceFilter
        self.appFilter = appFilter
        self.isEnabled = isEnabled
        self.lastTriggeredDate = lastTriggeredDate
    }
}
