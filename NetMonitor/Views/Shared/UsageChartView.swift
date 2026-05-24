import SwiftUI
import Charts

struct UsageChartView: View {
    let data: [ChartDataPoint]
    let title: String
    var showDownload: Bool = true
    var showUpload: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Chart {
                if showDownload {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Downloaded", point.bytesReceived)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                    }
                }
                if showUpload {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Uploaded", point.bytesSent)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bytes = value.as(Int64.self) {
                            Text(ByteCountFormatter.formatBytes(bytes))
                        }
                    }
                }
            }
            .frame(minHeight: 200)
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let bytesReceived: Int64
    let bytesSent: Int64
}
