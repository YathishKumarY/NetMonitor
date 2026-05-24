import Foundation

enum Constants {
    // Polling intervals
    static let interfacePollInterval: TimeInterval = 2.0
    static let persistInterval: TimeInterval = 10.0
    static let nettopInterval: TimeInterval = 10.0
    static let aggregationInterval: TimeInterval = 60.0
    static let pruneInterval: TimeInterval = 3600.0

    // Timer leeway for battery efficiency
    static let timerLeeway: DispatchTimeInterval = .milliseconds(500)

    // Data retention
    static let retentionDays: Int = 30

    // UI
    static let popoverWidth: CGFloat = 300
    static let popoverHeight: CGFloat = 360
    static let topAppsCount: Int = 5
}
