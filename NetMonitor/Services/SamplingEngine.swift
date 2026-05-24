import Foundation
import SwiftData
import Combine

@Observable
final class SamplingEngine {
    var currentDownloadSpeed: Double = 0
    var currentUploadSpeed: Double = 0
    var todayTotalReceived: Int64 = 0
    var todayTotalSent: Int64 = 0
    var todayWifiReceived: Int64 = 0
    var todayWifiSent: Int64 = 0
    var todayHotspotReceived: Int64 = 0
    var todayHotspotSent: Int64 = 0

    private let collector = InterfaceStatsCollector()
    private let processCollector = ProcessTrafficCollector()
    private let modelContainer: ModelContainer
    private var dataStore: DataStore?

    private var interfaceTimer: DispatchSourceTimer?
    private var persistTimer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var pruneTimer: DispatchSourceTimer?

    private var previousStats: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var pendingSamples: [InterfaceSample] = []
    private var isPaused = false

    private let queue = DispatchQueue(label: "com.netmonitor.sampling", qos: .utility)

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func start() {
        Task {
            self.dataStore = DataStore(modelContainer: modelContainer)
            await loadTodayTotals()
        }

        startInterfaceTimer()
        startPersistTimer()
        startProcessTimer()
        startPruneTimer()
    }

    func pause() {
        isPaused = true
        interfaceTimer?.suspend()
        persistTimer?.suspend()
        processTimer?.suspend()
    }

    func resume() {
        isPaused = false
        previousStats.removeAll()
        interfaceTimer?.resume()
        persistTimer?.resume()
        processTimer?.resume()
    }

    private func startInterfaceTimer() {
        interfaceTimer = DispatchSource.makeTimerSource(queue: queue)
        interfaceTimer?.schedule(
            deadline: .now(),
            repeating: Constants.interfacePollInterval,
            leeway: Constants.timerLeeway
        )
        interfaceTimer?.setEventHandler { [weak self] in
            self?.sampleInterfaces()
        }
        interfaceTimer?.resume()
    }

    private func startPersistTimer() {
        persistTimer = DispatchSource.makeTimerSource(queue: queue)
        persistTimer?.schedule(
            deadline: .now() + Constants.persistInterval,
            repeating: Constants.persistInterval,
            leeway: Constants.timerLeeway
        )
        persistTimer?.setEventHandler { [weak self] in
            self?.persistPendingSamples()
        }
        persistTimer?.resume()
    }

    private func startProcessTimer() {
        processTimer = DispatchSource.makeTimerSource(queue: queue)
        processTimer?.schedule(
            deadline: .now() + Constants.nettopInterval,
            repeating: Constants.nettopInterval,
            leeway: Constants.timerLeeway
        )
        processTimer?.setEventHandler { [weak self] in
            self?.sampleProcesses()
        }
        processTimer?.resume()
    }

    private func startPruneTimer() {
        pruneTimer = DispatchSource.makeTimerSource(queue: queue)
        pruneTimer?.schedule(
            deadline: .now() + Constants.pruneInterval,
            repeating: Constants.pruneInterval,
            leeway: .seconds(60)
        )
        pruneTimer?.setEventHandler { [weak self] in
            self?.pruneOldData()
        }
        pruneTimer?.resume()
    }

    private func sampleInterfaces() {
        let stats = collector.collectStats()
        var totalBytesInDelta: UInt64 = 0
        var totalBytesOutDelta: UInt64 = 0

        for stat in stats {
            if let previous = previousStats[stat.name] {
                // Counter reset detection
                let bytesInDelta: UInt64
                let bytesOutDelta: UInt64

                if stat.bytesIn >= previous.bytesIn {
                    bytesInDelta = stat.bytesIn - previous.bytesIn
                } else {
                    bytesInDelta = 0
                }

                if stat.bytesOut >= previous.bytesOut {
                    bytesOutDelta = stat.bytesOut - previous.bytesOut
                } else {
                    bytesOutDelta = 0
                }

                if bytesInDelta > 0 || bytesOutDelta > 0 {
                    let sample = InterfaceSample(
                        interfaceName: stat.name,
                        interfaceType: stat.type,
                        bytesReceived: Int64(bytesInDelta),
                        bytesSent: Int64(bytesOutDelta)
                    )
                    pendingSamples.append(sample)

                    totalBytesInDelta += bytesInDelta
                    totalBytesOutDelta += bytesOutDelta

                    // Update today's totals
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.todayTotalReceived += Int64(bytesInDelta)
                        self.todayTotalSent += Int64(bytesOutDelta)
                        if stat.type == "wifi" {
                            self.todayWifiReceived += Int64(bytesInDelta)
                            self.todayWifiSent += Int64(bytesOutDelta)
                        } else if stat.type == "hotspot" {
                            self.todayHotspotReceived += Int64(bytesInDelta)
                            self.todayHotspotSent += Int64(bytesOutDelta)
                        }
                    }
                }
            }

            previousStats[stat.name] = (bytesIn: stat.bytesIn, bytesOut: stat.bytesOut)
        }

        // Update live speed (bytes per second)
        let downloadSpeed = Double(totalBytesInDelta) / Constants.interfacePollInterval
        let uploadSpeed = Double(totalBytesOutDelta) / Constants.interfacePollInterval

        DispatchQueue.main.async { [weak self] in
            self?.currentDownloadSpeed = downloadSpeed
            self?.currentUploadSpeed = uploadSpeed
        }
    }

    private func persistPendingSamples() {
        guard !pendingSamples.isEmpty else { return }
        let samples = pendingSamples
        pendingSamples.removeAll()

        Task { [weak self] in
            guard let dataStore = self?.dataStore else { return }
            try? await dataStore.insertInterfaceSamples(samples)

            // Update daily summary
            let dateKey = DailySummary.todayKey()
            for sample in samples {
                try? await dataStore.updateDailySummary(
                    dateKey: dateKey,
                    receivedDelta: sample.bytesReceived,
                    sentDelta: sample.bytesSent,
                    interfaceType: sample.interfaceType
                )
            }
        }
    }

    private func sampleProcesses() {
        Task { [weak self] in
            guard let self else { return }
            guard let entries = try? await self.processCollector.collectSample() else { return }

            let samples = entries.map { entry in
                let bundleId = self.processCollector.resolveBundleIdentifier(pid: entry.pid)
                return AppTrafficSample(
                    processName: entry.processName,
                    bundleIdentifier: bundleId,
                    pid: entry.pid,
                    bytesReceived: entry.bytesIn,
                    bytesSent: entry.bytesOut
                )
            }

            guard !samples.isEmpty else { return }
            try? await self.dataStore?.insertAppTrafficSamples(samples)
        }
    }

    private func pruneOldData() {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Constants.retentionDays,
            to: Date()
        )!
        Task { [weak self] in
            try? await self?.dataStore?.pruneOldData(olderThan: cutoff)
        }
    }

    private func loadTodayTotals() async {
        let dateKey = DailySummary.todayKey()
        guard let summary = try? await dataStore?.fetchDailySummary(for: dateKey) else { return }
        await MainActor.run {
            self.todayTotalReceived = summary.totalReceived
            self.todayTotalSent = summary.totalSent
            self.todayWifiReceived = summary.wifiReceived
            self.todayWifiSent = summary.wifiSent
            self.todayHotspotReceived = summary.hotspotReceived
            self.todayHotspotSent = summary.hotspotSent
        }
    }
}
