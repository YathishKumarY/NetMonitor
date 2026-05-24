import Foundation
import SwiftData

@Model
final class InterfaceSample {
    var timestamp: Date
    var interfaceName: String
    var interfaceType: String
    var bytesReceived: Int64
    var bytesSent: Int64

    init(
        timestamp: Date = .now,
        interfaceName: String,
        interfaceType: String,
        bytesReceived: Int64,
        bytesSent: Int64
    ) {
        self.timestamp = timestamp
        self.interfaceName = interfaceName
        self.interfaceType = interfaceType
        self.bytesReceived = bytesReceived
        self.bytesSent = bytesSent
    }
}
