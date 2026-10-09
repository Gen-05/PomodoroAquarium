import CoreGraphics
import Foundation

struct AquariumFishInventoryCount: Equatable {
    let owned: Int
    let active: Int
    var available: Int { max(0, owned - active) }
}

@MainActor
enum AquariumFishEditing {
    static func counts(_ species: FishSpecies, player: Player) -> AquariumFishInventoryCount {
        AquariumFishInventoryCount(owned: player.ownedFish.count { $0.species == species },
            active: player.aquariumCount(for: species))
    }

    static func drop(species: FishSpecies, location: CGPoint, canvas: CGRect, player: Player,
                     preferredFishID: UUID? = nil) -> (id: UUID, position: CGPoint)? {
        guard canvas.width > 0, canvas.height > 0, canvas.contains(location) else { return nil }
        let previous = Set(player.activeAquariumFish.map(\.id))
        guard AquariumEditorDropCoordinator.addFish(from: .fish(species), preferredFishID: preferredFishID, to: player) == .placed,
              let added = player.activeAquariumFish.first(where: { !previous.contains($0.id) }) else { return nil }
        let relative = CGPoint(x: (location.x - canvas.minX) / canvas.width,
                               y: (location.y - canvas.minY) / canvas.height)
        let bounds = AquariumFishMotion.movementProfile(for: species).roamingStyle.bounds(
            in: canvas.size, fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
        return (added.id, AquariumFishMotion.clampedPoint(relative, bounds: bounds))
    }

    @discardableResult
    static func store(id: UUID, player: Player) -> Bool {
        player.removeFishFromAquarium(playerFishID: id)
    }
}
