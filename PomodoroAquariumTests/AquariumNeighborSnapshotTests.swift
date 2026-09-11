import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumNeighborSnapshotTests {
    @Test func snapshotMatchesLegacyNeighborSetsForExpectedFishCounts() {
        for fishCount in [1, 5, 10, 15] {
            var positions: [UUID: CGPoint] = [:]
            for index in 0..<fishCount {
                positions[UUID()] = CGPoint(
                    x: CGFloat(index + 1) / CGFloat(fishCount + 1),
                    y: CGFloat(index % 4) / 4
                )
            }

            let snapshot = AquariumFishPositionSnapshot(positions)
            for fishID in positions.keys {
                let legacyNeighbors = positions
                    .filter { $0.key != fishID }
                    .map { $0.value }
                let optimizedNeighbors = Array(
                    snapshot.neighborPositions(excluding: fishID)
                )

                #expect(optimizedNeighbors.count == max(fishCount - 1, 0))
                #expect(legacyNeighbors.allSatisfy(optimizedNeighbors.contains))
                #expect(optimizedNeighbors.allSatisfy(legacyNeighbors.contains))
            }
        }
    }

    @Test func optimizedCollectionPreservesGatheringSelectionSemantics() throws {
        let fishID = try #require(UUID(uuidString: "21C21E1B-E525-44F6-A4F3-02DD301A6967"))
        var materializedMotion = AquariumFishMotion.initialState(for: fishID)
        var optimizedMotion = materializedMotion
        var positions: [UUID: CGPoint] = [fishID: materializedMotion.position]

        for index in 0..<14 {
            positions[UUID()] = CGPoint(
                x: 0.2 + CGFloat(index) * 0.04,
                y: 0.2 + CGFloat(index % 5) * 0.07
            )
        }

        let optimizedNeighbors = AquariumFishPositionSnapshot(positions)
            .neighborPositions(excluding: fishID)
        let materializedNeighbors = Array(optimizedNeighbors)

        for _ in 0..<100 {
            materializedMotion.chooseLocalTarget(
                neighborPositions: materializedNeighbors,
                permitsGathering: true
            )
            optimizedMotion.chooseLocalTarget(
                neighborPositions: optimizedNeighbors,
                permitsGathering: true
            )

            #expect(optimizedMotion.localTarget == materializedMotion.localTarget)
            #expect(optimizedMotion.desiredDirection == materializedMotion.desiredDirection)
            #expect(optimizedMotion.randomState == materializedMotion.randomState)
        }
    }
}
