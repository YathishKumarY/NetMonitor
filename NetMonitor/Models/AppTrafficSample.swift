import Foundation
import SwiftData

@Model
final class AppTrafficSample {
    var timestamp: Date
    var processName: String
    var bundleIdentifier: String?
    var pid: Int32
    var bytesReceived: Int64
    var bytesSent: Int64
    var interfaceName: String?

    init(
        timestamp: Date = .now,
        processName: String,
        bundleIdentifier: String? = nil,
        pid: Int32,
        bytesReceived: Int64,
        bytesSent: Int64,
        interfaceName: String? = nil
    ) {
        self.timestamp = timestamp
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.pid = pid
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
        self.interfaceName = interfaceName
    }
}
