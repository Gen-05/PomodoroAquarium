import Foundation
import SwiftData

@Model
final class RewardHistoryEntry {
    @Attribute(.unique) var id: UUID
    var fishID: UUID
    var fishSpeciesRawValue: String
    var fishName: String
    var rarityRawValue: String
    var fishCountDelta: Int
    var pointDelta: Int
    var acquiredAt: Date
    var isAcknowledged: Bool
    var wasNewFish: Bool
    var previousOwnedCount: Int
    var currentOwnedCount: Int

    init(
        id: UUID = UUID(),
        fishID: UUID,
        fishSpecies: FishSpecies,
        fishName: String,
        rarity: FishRarity,
        fishCountDelta: Int,
        pointDelta: Int,
        acquiredAt: Date = Date(),
        isAcknowledged: Bool = false,
        wasNewFish: Bool,
        previousOwnedCount: Int,
        currentOwnedCount: Int
    ) {
        self.id = id
        self.fishID = fishID
        self.fishSpeciesRawValue = fishSpecies.rawValue
        self.fishName = fishName
        self.rarityRawValue = rarity.rawValue
        self.fishCountDelta = fishCountDelta
        self.pointDelta = pointDelta
        self.acquiredAt = acquiredAt
        self.isAcknowledged = isAcknowledged
        self.wasNewFish = wasNewFish
        self.previousOwnedCount = previousOwnedCount
        self.currentOwnedCount = currentOwnedCount
    }
}

struct RewardHistorySnapshot: Identifiable, Equatable {
    let id: UUID
    let fishID: UUID
    let fishSpecies: FishSpecies
    let fishName: String
    let rarity: FishRarity
    let fishCountDelta: Int
    let pointDelta: Int
    let acquiredAt: Date
    var isAcknowledged: Bool
    let wasNewFish: Bool
    let previousOwnedCount: Int
    let currentOwnedCount: Int

    init(entry: RewardHistoryEntry) {
        id = entry.id
        fishID = entry.fishID
        fishSpecies = FishSpecies(rawValue: entry.fishSpeciesRawValue) ?? .clownfish
        fishName = entry.fishName
        rarity = FishRarity(rawValue: entry.rarityRawValue) ?? .common
        fishCountDelta = entry.fishCountDelta
        pointDelta = entry.pointDelta
        acquiredAt = entry.acquiredAt
        isAcknowledged = entry.isAcknowledged
        wasNewFish = entry.wasNewFish
        previousOwnedCount = entry.previousOwnedCount
        currentOwnedCount = entry.currentOwnedCount
    }

    init(
        id: UUID = UUID(),
        fishID: UUID = UUID(),
        fishSpecies: FishSpecies,
        fishName: String? = nil,
        rarity: FishRarity? = nil,
        fishCountDelta: Int = 1,
        pointDelta: Int,
        acquiredAt: Date = Date(),
        isAcknowledged: Bool,
        wasNewFish: Bool,
        previousOwnedCount: Int,
        currentOwnedCount: Int
    ) {
        self.id = id
        self.fishID = fishID
        self.fishSpecies = fishSpecies
        self.fishName = fishName ?? fishSpecies.name
        self.rarity = rarity ?? fishSpecies.rarity
        self.fishCountDelta = fishCountDelta
        self.pointDelta = pointDelta
        self.acquiredAt = acquiredAt
        self.isAcknowledged = isAcknowledged
        self.wasNewFish = wasNewFish
        self.previousOwnedCount = previousOwnedCount
        self.currentOwnedCount = currentOwnedCount
    }

    @MainActor
    func replayResult() -> FishAcquisitionResult {
        FishAcquisitionResult(
            fish: PlayerFish(id: fishID, species: fishSpecies),
            previousOwnedCount: previousOwnedCount,
            currentOwnedCount: currentOwnedCount,
            fishName: fishName,
            rarity: rarity,
            wasNewFish: wasNewFish
        )
    }
}

enum RewardHistoryService {
    static let maximumEntryCount = 10

    @discardableResult
    @MainActor
    static func record(
        result: FishAcquisitionResult,
        pointDelta: Int,
        acquiredAt: Date = Date(),
        in context: ModelContext
    ) throws -> RewardHistoryEntry {
        let entry = RewardHistoryEntry(
            fishID: result.fish.id,
            fishSpecies: result.species,
            fishName: result.fishName,
            rarity: result.rarity,
            fishCountDelta: max(result.currentOwnedCount - result.previousOwnedCount, 0),
            pointDelta: max(pointDelta, 0),
            acquiredAt: acquiredAt,
            isAcknowledged: false,
            wasNewFish: result.isNewFish,
            previousOwnedCount: result.previousOwnedCount,
            currentOwnedCount: result.currentOwnedCount
        )
        context.insert(entry)
        try pruneIfNeeded(in: context)
        try context.save()
        return entry
    }

    @MainActor
    static func latestUnacknowledged(in context: ModelContext) throws -> RewardHistoryEntry? {
        var descriptor = FetchDescriptor<RewardHistoryEntry>(
            predicate: #Predicate { !$0.isAcknowledged },
            sortBy: [SortDescriptor(\RewardHistoryEntry.acquiredAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    static func recent(in context: ModelContext) throws -> [RewardHistoryEntry] {
        var descriptor = FetchDescriptor<RewardHistoryEntry>(
            sortBy: [SortDescriptor(\RewardHistoryEntry.acquiredAt, order: .reverse)]
        )
        descriptor.fetchLimit = maximumEntryCount
        return try context.fetch(descriptor)
    }

    @MainActor
    static func acknowledge(id: UUID, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<RewardHistoryEntry>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entry = try context.fetch(descriptor).first else { return }
        entry.isAcknowledged = true
        try context.save()
    }

    @MainActor
    private static func pruneIfNeeded(in context: ModelContext) throws {
        let descriptor = FetchDescriptor<RewardHistoryEntry>(
            sortBy: [SortDescriptor(\RewardHistoryEntry.acquiredAt, order: .reverse)]
        )
        let entries = try context.fetch(descriptor)
        guard entries.count > maximumEntryCount else { return }
        for entry in entries.dropFirst(maximumEntryCount) {
            context.delete(entry)
        }
    }
}
