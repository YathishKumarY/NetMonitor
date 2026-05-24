import Foundation

enum ByteCountFormatter {
    static func formatBytes(_ bytes: Int64) -> String {
        let absBytes = abs(bytes)
        let units: [(String, Int64)] = [
            ("TB", 1_099_511_627_776),
            ("GB", 1_073_741_824),
            ("MB", 1_048_576),
            ("KB", 1_024)
        ]

        for (unit, threshold) in units {
            if absBytes >= threshold {
                let value = Double(bytes) / Double(threshold)
                if value >= 100 {
                    return String(format: "%.0f %@", value, unit)
                } else if value >= 10 {
                    return String(format: "%.1f %@", value, unit)
                } else {
                    return String(format: "%.2f %@", value, unit)
                }
            }
        }

        return "\(bytes) B"
    }

    static func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units: [(String, Double)] = [
            ("GB/s", 1_073_741_824),
            ("MB/s", 1_048_576),
            ("KB/s", 1_024)
        ]

        for (unit, threshold) in units {
            if bytesPerSecond >= threshold {
                let value = bytesPerSecond / threshold
                if value >= 100 {
                    return String(format: "%.0f %@", value, unit)
                } else if value >= 10 {
                    return String(format: "%.1f %@", value, unit)
                } else {
                    return String(format: "%.2f %@", value, unit)
                }
            }
        }

        if bytesPerSecond > 0 {
            return String(format: "%.0f B/s", bytesPerSecond)
        }
        return "0 B/s"
    }
}
