import Foundation
import SwiftData

/// 開発用所持は通常報酬と分離し、固定個体IDで不足分だけ追加する。
@MainActor
enum AquariumDeveloperFish {
    private static let grants: [(species: FishSpecies, ids: [UUID])] = {
#if DEBUG
        return [
            (.blueTang, (1...5).map {
                UUID(uuidString: String(format: "B10E7A60-6A60-4A60-8A60-%012d", $0))!
            }),
            (.yellowTang, (1...5).map {
                UUID(uuidString: String(format: "E1107A60-6A60-4A60-8A60-%012d", $0))!
            }),
            (.blueGreenChromis, (1...5).map {
                UUID(uuidString: String(format: "C470A115-6A60-4A60-8A60-%012d", $0))!
            }),
            (.orientalButterflyfish, (1...5).map {
                UUID(uuidString: String(format: "B077E2F1-6A60-4A60-8A60-%012d", $0))!
            }),
            (.pennantCoralfish, (1...5).map {
                UUID(uuidString: String(format: "F1A77A7E-6A60-4A60-8A60-%012d", $0))!
            }),
            (.lionfish, (1...5).map {
                UUID(uuidString: String(format: "110F15A0-6A60-4A60-8A60-%012d", $0))!
            })
        ]
#else
        return []
#endif
    }()

    static var individualIDs: [UUID] { grants.flatMap(\.ids) }

    static func individualIDs(for species: FishSpecies) -> [UUID] {
        grants.first { $0.species == species }?.ids ?? []
    }

    @discardableResult
    static func seedIfNeeded(for player: Player, in context: ModelContext,
                             enabled: Bool = true) throws -> Bool {
        guard enabled, !individualIDs.isEmpty else { return false }
        let original = player.ownedFish
        let stored = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PlayerFish>()).map { ($0.id, $0) })
        let ownedIDs = Set(original.map(\.id))
        var inserted: [PlayerFish] = []
        for grant in grants {
            for id in grant.ids where !ownedIDs.contains(id) {
                // 保存済み個体が関係から外れていても、同じIDの個体を重複生成しない。
                if let existing = stored[id] {
                    guard existing.species == grant.species else { continue }
                    player.ownedFish.append(existing)
                } else {
                    let fish = PlayerFish(id: id, species: grant.species)
                    context.insert(fish)
                    player.ownedFish.append(fish)
                    inserted.append(fish)
                }
            }
        }
        guard player.ownedFish.count != original.count else { return false }
        do { try context.save() }
        catch {
            player.ownedFish = original
            for fish in inserted { context.delete(fish) }
            throw error
        }
        return true
    }
}
