import Foundation
import SwiftData

/// Receipts for UI only. Does not write focus records, coins, draw odds or ownership.
enum FishProbabilityPresentationStore {
    private static let key = "fishProbabilityPresentationReceipts.v1"
    private static let maximumReceipts = 128

    static func containsSession(_ id: UUID, in context: ModelContext) throws -> Bool {
        let query = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == id })
        return try context.fetch(query).isEmpty == false
    }

    static func snapshot(for sessionID: UUID, wasAlreadyRecorded: Bool, on date: Date = Date(),
                         calendar: Calendar = .current, defaults: UserDefaults, in context: ModelContext) throws -> FishProbabilityChange? {
        var receipts = load(defaults)
        if let existing = receipts.first(where: { $0.sessionIDs == [sessionID] }) { return existing }
        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>())
        guard records.contains(where: { $0.id == sessionID }) else { return nil }
        let after = StudyHistoryService.focusSeconds(on: date, from: records, calendar: calendar)
        // If an old record has no receipt, do not invent an earlier baseline on replay.
        let before = wasAlreadyRecorded ? after : StudyHistoryService.focusSeconds(
            on: date, from: records.filter { $0.id != sessionID }, calendar: calendar)
        let change = FishProbabilityChange(sessionIDs: [sessionID], referenceDay: calendar.startOfDay(for: date),
                                           beforeSeconds: before, afterSeconds: after)
        receipts.append(change)
        if let data = try? JSONEncoder().encode(Array(receipts.suffix(maximumReceipts))) {
            defaults.set(data, forKey: key)
        }
        return change
    }

    private static func load(_ defaults: UserDefaults) -> [FishProbabilityChange] {
        guard let data = defaults.data(forKey: key),
              let receipts = try? JSONDecoder().decode([FishProbabilityChange].self, from: data) else { return [] }
        return receipts
    }
}
