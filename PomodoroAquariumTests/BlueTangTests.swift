import Foundation
import SwiftData
import SwiftUI
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct BlueTangTests {
    @Test func registrationAssetsAndExistingSavedIdentifiers() throws {
        #expect(FishSpecies.blueTang.rawValue == "blueTang")
        #expect(FishSpecies.blueTang.name == "ナンヨウハギ")
        #expect(FishSpecies.blueTang.rarity == .common)
        #expect(FishSpecies.blueTang.imageName == "fish_blue_tang_side_2")
        #expect(FishSpecies.blueTang.swimmingImageNames == (1...3).map { "fish_blue_tang_side_\($0)" })
        let ids = ["clownfish", "jellyfish", "pufferfish", "seahorse", "manta", "whaleShark", "blueTang", "yellowTang", "blueGreenChromis", "orientalButterflyfish", "pennantCoralfish", "lionfish", "porcupinefish", "mandarinfish", "seaTurtle", "dolphin", "orca"]
        #expect(FishSpecies.allCases.map(\.rawValue) == ids)
        for id in ids {
            let data = Data("\"\(id)\"".utf8)
            let species = try JSONDecoder().decode(FishSpecies.self, from: data)
            #expect(try JSONEncoder().encode(species) == data)
        }
        for name in FishSpecies.blueTang.swimmingImageNames {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
    }

    @Test func commonPoolAndRarityProbabilitiesRemainUniform() {
        let common = FishSpecies.allCases.filter { $0.rarity == .common }
        #expect(Set(common) == [.clownfish, .jellyfish, .pufferfish, .blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish])
        for (minutes, expected) in [(0, [70.0, 20, 8, 2]), (180, [58.0, 25, 13, 4]), (300, [58.0, 25, 13, 4])] {
            let probabilities = FishRewardService.rarityProbabilities(for: minutes)
            #expect([probabilities.common, probabilities.rare, probabilities.epic, probabilities.legendary] == expected)
            #expect(probabilities.total == 100)
            for species in common {
                #expect(probabilities.probability(for: species.rarity) / Double(common.count) == (minutes == 0 ? 70.0 / 8 : 58.0 / 8))
            }
        }
        #expect(FishSpecies.allCases.filter { $0.rarity == .rare } == [.seahorse, .lionfish, .porcupinefish, .mandarinfish])
        #expect(FishSpecies.allCases.filter { $0.rarity == .epic } == [.manta, .seaTurtle, .dolphin])
        #expect(FishSpecies.allCases.filter { $0.rarity == .legendary } == [.whaleShark, .orca])
    }

    @Test func usesClownfishTemplateAndThreeFramePingPong() {
        let id = UUID()
        let blue = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .blueTang))
        let clown = AquariumFishMotion.initialState(for: id, profile: AquariumFishMotion.movementProfile(for: .clownfish))
        #expect(blue.position == clown.position && blue.velocity == clown.velocity)
        #expect(blue.baseSpeed == clown.baseSpeed && blue.facingDirection == clown.facingDirection)
        #expect(blue.movementProfile.roamingStyle == .small)
        for behavior in AquariumFishMotion.Behavior.allCases {
            #expect(AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .blueTang, behavior: behavior)
                == AquariumFishMotion.behaviorTargetSpeedMultiplier(for: .clownfish, behavior: behavior))
            #expect(AquariumFishMotion.spriteFrameDuration(for: .blueTang, behavior: behavior, currentSpeed: 1, baseSpeed: 1)
                == AquariumFishMotion.spriteFrameDuration(for: .clownfish, behavior: behavior, currentSpeed: 1, baseSpeed: 1))
        }
        for direction in FishFacingDirection.allCases {
            #expect(FishSpecies.blueTang.swimmingImageRotation(for: direction) == FishSpecies.clownfish.swimmingImageRotation(for: direction))
            #expect(FishSpecies.blueTang.swimmingImageNames(for: direction) == FishSpecies.blueTang.swimmingImageNames)
        }
        #expect(FishImageView(species: .blueTang, facingHorizontalScale: -1).resolvedHorizontalScale == -1)
        #expect((0..<8).map { FishSpriteAnimation.pingPongFrameIndex(frameCount: 3, elapsedTime: Double($0) * 0.25, frameDuration: 0.25) }
            == [0, 1, 2, 1, 0, 1, 2, 1])
    }

    @Test func renderedBlueTangIsTenPercentLargerThanItsPreviousAquariumWidth() throws {
        func visibleWidth(_ species: FishSpecies, frame: CGSize? = nil) throws -> Int {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let frame = frame ?? CGSize(width: size, height: size)
            let renderer = ImageRenderer(content: FishImageView(species: species).frame(width: frame.width, height: frame.height))
            renderer.scale = 3
            let image = try #require(renderer.uiImage?.cgImage)
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            bytes.withUnsafeMutableBytes {
                let context = CGContext(data: $0.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            var minX = image.width, maxX = -1
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 16 {
                minX = min(minX, x); maxX = max(maxX, x)
            } }
            return maxX - minX + 1
        }
        let blue = try visibleWidth(.blueTang), clown = try visibleWidth(.clownfish)
        #expect(FishSpecies.clownfish.displayScale == 0.40)
        #expect(FishSpecies.blueTang.displayScale == 0.64)
        #expect(abs(FishDetailImageLayout.preferredDisplaySize(for: .blueTang) - 82.82) < 0.01)
        #expect(Double(blue) / Double(clown) > 1.60 && Double(blue) / Double(clown) < 1.70)
        print("Neutral visible fish width at 3x: blueTang \(Double(blue) / 3)pt, clownfish \(Double(clown) / 3)pt")
        let bookBlue = try visibleWidth(.blueTang, frame: BookFishThumbnailLayout.imageSize(for: .blueTang))
        let bookClown = try visibleWidth(.clownfish, frame: BookFishThumbnailLayout.imageSize(for: .clownfish))
        #expect(Double(bookBlue) / Double(bookClown) > 0.9 && Double(bookBlue) / Double(bookClown) < 1.1)
        print("Book visible fish width at 3x: blueTang \(Double(bookBlue) / 3)pt, clownfish \(Double(bookClown) / 3)pt")
    }

    @Test(arguments: [FishSpecies.blueTang, .yellowTang, .blueGreenChromis, .orientalButterflyfish, .pennantCoralfish, .lionfish, .porcupinefish, .mandarinfish, .seaTurtle, .dolphin, .manta, .orca])
    func developerFiveAreDistinctIdempotentAndDoNotTouchRewards(regularSpecies: FishSpecies) throws {
        let container = try makeContainer()
        let context = container.mainContext
        let regular = PlayerFish(species: regularSpecies), placed = PlayerFish(species: .clownfish)
        let player = Player(ownedFish: [regular, placed], activeAquariumFishIDs: [placed.id],
            hasInitializedActiveAquariumFish: true, totalStudyMinutes: 90, todayStudyMinutes: 25, coins: 80)
        player.dailyEarnedFishCount = 3
        player.dailyClaimedFishCount = 1
        player.pendingFishEarnedCount = 2
        player.dailyGrantedFishCount = 1
        player.dailyFishProgressSeconds = 400
        context.insert(player)
        try context.save()
        #expect(try AquariumDeveloperFish.seedIfNeeded(for: player, in: context, enabled: false) == false)
        let changed = try AquariumDeveloperFish.seedIfNeeded(for: player, in: context)
#if DEBUG
        #expect(changed && AquariumDeveloperFish.individualIDs.count == 60)
        #expect(player.ownedFish.count == 62)
        #expect(Set(player.ownedFish.map(\.id)).count == 62)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .blueTang }.map(\.id)) == Set(AquariumDeveloperFish.individualIDs(for: .blueTang)))
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .yellowTang }.map(\.id))
            == Set(AquariumDeveloperFish.individualIDs(for: .yellowTang)))
        #expect(AquariumDeveloperFish.individualIDs(for: .yellowTang).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .blueGreenChromis }.map(\.id))
            == Set(AquariumDeveloperFish.individualIDs(for: .blueGreenChromis)))
        #expect(AquariumDeveloperFish.individualIDs(for: .blueGreenChromis).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .orientalButterflyfish }.map(\.id))
            == Set(AquariumDeveloperFish.individualIDs(for: .orientalButterflyfish)))
        #expect(AquariumDeveloperFish.individualIDs(for: .orientalButterflyfish).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .pennantCoralfish }.map(\.id))
            == Set(AquariumDeveloperFish.individualIDs(for: .pennantCoralfish)))
        #expect(AquariumDeveloperFish.individualIDs(for: .pennantCoralfish).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .lionfish }.map(\.id))
            == Set(AquariumDeveloperFish.individualIDs(for: .lionfish)))
        #expect(AquariumDeveloperFish.individualIDs(for: .lionfish).count == 5)
        #expect(AquariumDeveloperFish.individualIDs(for: .porcupinefish).count == 5)
        #expect(AquariumDeveloperFish.individualIDs(for: .mandarinfish).count == 5)
        #expect(AquariumDeveloperFish.individualIDs(for: .dolphin).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .dolphin }.map(\.id)) == Set(AquariumDeveloperFish.individualIDs(for: .dolphin)))
        #expect(AquariumDeveloperFish.individualIDs(for: .seaTurtle).count == 5)
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .seaTurtle }.map(\.id)) == Set(AquariumDeveloperFish.individualIDs(for: .seaTurtle)))
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .mandarinfish }.map(\.id)) == Set(AquariumDeveloperFish.individualIDs(for: .mandarinfish)))
        #expect(Set(player.ownedFish.filter { $0.id != regular.id && $0.species == .porcupinefish }.map(\.id)) == Set(AquariumDeveloperFish.individualIDs(for: .porcupinefish)))
        let testID = try #require(AquariumDeveloperFish.individualIDs(for: regularSpecies).first)
        #expect(player.addFishToAquarium(playerFishID: testID))
#else
        #expect(!changed && AquariumDeveloperFish.individualIDs.isEmpty)
        #expect(player.ownedFish.count == 2 && Set(player.ownedFish.map(\.id)) == Set([regular.id, placed.id]))
#endif
        try context.save()
        let active = player.activeAquariumFishIDs
        let owned = Set(player.ownedFish.map(\.id))
        let reopened = ModelContext(container)
        let restored = try #require(try reopened.fetch(FetchDescriptor<Player>()).first)
        #expect(try AquariumDeveloperFish.seedIfNeeded(for: restored, in: reopened) == false)
        #expect(Set(restored.ownedFish.map(\.id)) == owned)
        #expect(restored.activeAquariumFishIDs == active)
        #expect(restored.ownedFish.contains { $0.id == regular.id })
        #expect(restored.coins == 80 && restored.totalStudyMinutes == 90 && restored.todayStudyMinutes == 25)
        #expect(restored.dailyEarnedFishCount == 3 && restored.dailyClaimedFishCount == 1)
        #expect(restored.pendingFishEarnedCount == 2 && restored.dailyGrantedFishCount == 1 && restored.dailyFishProgressSeconds == 400)
        #expect(try reopened.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<FocusSessionRecord>()) == 0)
        #expect(try reopened.fetchCount(FetchDescriptor<StudyDailyRecord>()) == 0)
#if DEBUG
        #expect(AquariumFishEditing.store(id: testID, player: restored))
        #expect(try AquariumDeveloperFish.seedIfNeeded(for: restored, in: reopened) == false)
        #expect(Set(restored.ownedFish.map(\.id)) == owned)
#endif
    }

    @Test func blueTangAndExistingFishPersistInTheSameStore() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("BlueTang-\(UUID()).store")
        defer { for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        let ids = (0..<10).map { _ in UUID() }
        do {
            let container = try makeContainer(url: url)
            let player = Player(ownedFish: [PlayerFish(id: ids[0], species: .blueTang), PlayerFish(id: ids[1], species: .clownfish), PlayerFish(id: ids[2], species: .yellowTang), PlayerFish(id: ids[3], species: .blueGreenChromis), PlayerFish(id: ids[4], species: .orientalButterflyfish), PlayerFish(id: ids[5], species: .pennantCoralfish), PlayerFish(id: ids[6], species: .lionfish), PlayerFish(id: ids[7], species: .porcupinefish), PlayerFish(id: ids[8], species: .mandarinfish), PlayerFish(id: ids[9], species: .seaTurtle)],
                activeAquariumFishIDs: [ids[0], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8], ids[9]], hasInitializedActiveAquariumFish: true)
            container.mainContext.insert(player)
            try container.mainContext.save()
            _ = try AquariumDeveloperFish.seedIfNeeded(for: player, in: container.mainContext)
        }
        let reopened = try makeContainer(url: url)
        let restored = try #require(try reopened.mainContext.fetch(FetchDescriptor<Player>()).first)
        #expect(try AquariumDeveloperFish.seedIfNeeded(for: restored, in: reopened.mainContext) == false)
        #expect(Set(restored.ownedFish.map(\.id)) == Set(ids + AquariumDeveloperFish.individualIDs))
        #expect(restored.ownedFish.first { $0.id == ids[0] }?.species == .blueTang)
        #expect(restored.ownedFish.first { $0.id == ids[2] }?.species == .yellowTang)
        #expect(restored.ownedFish.first { $0.id == ids[3] }?.species == .blueGreenChromis)
        #expect(restored.ownedFish.first { $0.id == ids[4] }?.species == .orientalButterflyfish)
        #expect(restored.ownedFish.first { $0.id == ids[5] }?.species == .pennantCoralfish)
        #expect(restored.ownedFish.first { $0.id == ids[6] }?.species == .lionfish)
        #expect(restored.ownedFish.first { $0.id == ids[7] }?.species == .porcupinefish)
        #expect(restored.ownedFish.first { $0.id == ids[8] }?.species == .mandarinfish)
        #expect(restored.ownedFish.first { $0.id == ids[9] }?.species == .seaTurtle)
        #expect(restored.ownedFish.first { $0.id == ids[1] }?.species == .clownfish)
        #expect(restored.activeAquariumFishIDs == [ids[0], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8], ids[9]])
    }

    private func makeContainer(url: URL? = nil) throws -> ModelContainer {
        let configuration = url.map { ModelConfiguration(url: $0) } ?? ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self,
            RewardHistoryEntry.self, configurations: configuration)
    }
}
