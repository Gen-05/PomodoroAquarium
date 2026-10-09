import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

struct AquariumEditorPresentationTests {
    @Test func appearanceIsOneSecondAndNeverReplaysAfterCompletion() {
        let start = Date(timeIntervalSince1970: 100)
        let appearance = AquariumFishAppearance(startedAt: start)
        #expect(appearance.progress(at: start) == 0)
        #expect(appearance.fishProgress(at: start) == 0)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(0.5)) > 0)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(0.5)) < 1)
        #expect(appearance.progress(at: start.addingTimeInterval(1)) == 1)
        #expect(appearance.fishProgress(at: start.addingTimeInterval(60)) == 1)
    }

    @Test func initialDecorationStaysGroundedAndAvoidsTheFixedMenuAndNeighbors() {
        let size = CGSize(width: 393, height: 808)
        for kind in AquariumDecorationKind.allCases where kind.groundAnchorY != nil {
            let first = AquariumEditorInitialPlacement.decoration(kind: kind, scale: 1, size: size, existing: [])
            let existing = AquariumDecoration(id: "existing", kind: kind, relativeX: first.x, relativeY: first.y, scale: 1)
            let next = AquariumEditorInitialPlacement.decoration(kind: kind, scale: 1, size: size, existing: [existing])
            #expect(kind.movementBounds.y.contains(first.y))
            #expect(kind.movementBounds.y.contains(next.y))
            #expect(first != next)
            #expect(first.y * size.height < size.height - 95 || abs(first.x * size.width - size.width / 2) > 130)
            #expect(existing.relativeX == first.x && existing.relativeY == first.y)
        }
    }

    @Test func initialFishRespectsExistingMovementBoundsAndAvoidsNeighbors() {
        let size = CGSize(width: 393, height: 808)
        for species in FishSpecies.allCases {
            let first = AquariumEditorInitialPlacement.fish(species: species, size: size, neighbors: [])
            let next = AquariumEditorInitialPlacement.fish(species: species, size: size, neighbors: [first])
            let bounds = AquariumFishMotion.movementProfile(for: species).roamingStyle.bounds(
                in: size, fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
            #expect(AquariumFishMotion.clampedPoint(next, bounds: bounds) == next)
            #expect(first != next)
        }
    }
}
