import Foundation
import SwiftData

final class DataRetentionService {
    private let modelContainer: ModelContainer
    private var dataStore: DataStore?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        Task {
            self.dataStore = DataStore(modelContainer: modelContainer)
        }
    }

    func pruneIfNeeded() async {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -Constants.retentionDays,
            to: Date()
        )!
        try? await dataStore?.pruneOldData(olderThan: cutoff)
    }
}
