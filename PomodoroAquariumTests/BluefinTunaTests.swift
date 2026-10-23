import SwiftUI
import SwiftData
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct BluefinTunaTests {
    private let id = UUID(uuidString: "B10F17A0-6A60-4A60-8A60-000000000001")!

    @Test func legacyRawValueIsOneEpicSlotWithNewAssetsAndStaticArtwork() throws {
        let legacy = try JSONDecoder().decode(FishSpecies.self, from: Data("\"manta\"".utf8))
        #expect(legacy == .manta && legacy.rawValue == "manta" && legacy.name == "クロマグロ")
        #expect(try JSONEncoder().encode(legacy) == Data("\"manta\"".utf8))
        #expect(FishSpecies.allCases.count == 17)
        #expect(!FishSpecies.allCases.contains { $0.name == "マンタ" })
        #expect(FishSpecies.allCases.filter { $0.rarity == .epic } == [.manta, .seaTurtle, .dolphin])
        #expect(legacy.imageName == "fish_bluefin_tuna")
        #expect(legacy.swimmingImageNames == (1...8).map { "fish_bluefin_tuna_side_\($0)" })
        for name in legacy.swimmingImageNames + [legacy.imageName!] {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst)
        }
        for minutes in [0, 180, 300] {
            let p = FishRewardService.rarityProbabilities(for: minutes)
            #expect(p.total == 100 && p.epic == (minutes == 0 ? 8 : 13))
            #expect(p.epic / 3 == (minutes == 0 ? 8.0 / 3 : 13.0 / 3))
        }
    }

    @Test func legacyOwnedPlacedFavoriteDiscoveryAndHistorySurviveRepeatedStoreReads() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LegacyManta-\(UUID()).store")
        defer { for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: url.path + suffix) } }
        func container() throws -> ModelContainer {
            try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self,
                RewardHistoryEntry.self, configurations: ModelConfiguration(url: url))
        }
        let storedID = UUID(), historyID = UUID()
        // 旧アプリと同じmanta保存値・同じSwiftDataモデルで旧個体と履歴を用意する。
        do {
            let store = try container(), context = store.mainContext
            let oldSpecies = try JSONDecoder().decode(FishSpecies.self, from: Data("\"manta\"".utf8))
            let placed = PlayerFish(id: id, species: oldSpecies), stored = PlayerFish(id: storedID, species: oldSpecies)
            let player = Player(ownedFish: [placed, stored], favoriteFish: placed,
                activeAquariumFishIDs: [id], hasInitializedActiveAquariumFish: true, coins: 83)
            context.insert(player)
            context.insert(RewardHistoryEntry(id: historyID, fishID: id, fishSpecies: oldSpecies,
                fishName: "マンタ", rarity: .epic, fishCountDelta: 1, pointDelta: 8,
                wasNewFish: true, previousOwnedCount: 0, currentOwnedCount: 1))
            try context.save()
        }
        for _ in 0..<3 {
            let store = try container(), context = store.mainContext
            let player = try #require(try context.fetch(FetchDescriptor<Player>()).first)
            #expect(Set(player.ownedFish.map(\.id)) == [id, storedID] && player.ownedFish.count == 2)
            #expect(player.activeAquariumFishIDs == [id] && player.favoriteFish?.id == id)
            #expect(player.ownedFish.allSatisfy { $0.species.name == "クロマグロ" })
            #expect(BookView.ownedCount(for: .manta, in: player) == 2 && player.coins == 83)
            let history = try #require(try context.fetch(FetchDescriptor<RewardHistoryEntry>()).first)
            let shown = RewardHistorySnapshot(entry: history)
            #expect(history.id == historyID && history.fishID == id && history.fishSpeciesRawValue == "manta")
            #expect(history.fishName == "マンタ" && shown.fishName == "クロマグロ" && shown.fishSpecies == .manta)
            #expect(shown.pointDelta == 8 && shown.currentOwnedCount == 1 && shown.wasNewFish)
            #expect(try context.fetchCount(FetchDescriptor<PlayerFish>()) == 2)
            try context.save()
        }
    }

    @Test func fixedDebugSlotsDoNotDuplicateAnExistingLegacyIndividualOrRewards() throws {
        let store = try ModelContainer(for: Player.self, PlayerFish.self, FocusSessionRecord.self, StudyDailyRecord.self,
            RewardHistoryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let old = PlayerFish(id: id, species: .manta), regular = PlayerFish(species: .manta)
        let player = Player(ownedFish: [old, regular], activeAquariumFishIDs: [id],
            hasInitializedActiveAquariumFish: true, totalStudyMinutes: 30, todayStudyMinutes: 10, coins: 90)
        store.mainContext.insert(player)
        try store.mainContext.save()
        let seeded = try AquariumDeveloperFish.seedIfNeeded(for: player, in: store.mainContext)
#if DEBUG
        #expect(seeded && AquariumDeveloperFish.individualIDs(for: .manta).count == 5)
        #expect(player.ownedFish.filter { $0.species == .manta }.count == 6)
        #expect(player.ownedFish.filter { $0.id == id }.count == 1)
#else
        #expect(!seeded && AquariumDeveloperFish.individualIDs(for: .manta).isEmpty)
        #expect(player.ownedFish.count == 2)
#endif
        let ids = Set(player.ownedFish.map(\.id))
        #expect(try AquariumDeveloperFish.seedIfNeeded(for: player, in: store.mainContext) == false)
        #expect(Set(player.ownedFish.map(\.id)) == ids && player.activeAquariumFishIDs == [id])
        #expect(player.ownedFish.contains { $0.id == regular.id })
        #expect(player.totalStudyMinutes == 30 && player.todayStudyMinutes == 10 && player.coins == 90)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<RewardHistoryEntry>()) == 0)
    }

    @Test func eightFramesLoopForwardAtPointElevenWithIndependentPhase() throws {
        for step in 0..<32 {
            let time = Double(step) * 0.11 + 0.000001
            let index = FishSpriteAnimation.loopFrameIndex(frameCount: 8, elapsedTime: time, frameDuration: 0.11)
            #expect(index == step % 8)
            let sprite = FishImageView(species: .manta, animationTime: time, animationFrameDuration: 0.11)
            #expect(sprite.interactionImage?.pngData() == UIImage(named: "fish_bluefin_tuna_side_\(index + 1)")?.pngData())
        }
        #expect(AquariumFishMotion.spriteFrameDuration(for: .manta, behavior: .cruising, currentSpeed: 1, baseSpeed: 1) == 0.11)
        #expect(AquariumFishMotion.wingSwimmingProfile(for: .manta) == nil)
        #expect(AquariumFishMotion.presentationAmplitude(for: .manta) == 0)
        var preview = FishDetailStrokeAnimationState(species: .manta)
        let started = preview.start()
        #expect(started)
        for expected in 0..<8 {
            #expect(preview.currentFrameIndex == expected)
            _ = preview.advance()
        }
        #expect(!preview.isAnimating)
        let ids = (1...5).map { UUID(uuidString: String(format: "B10F17A0-6A60-4A60-8A60-%012d", $0))! }
        #expect(Set(ids.map { AquariumFishMotion.spriteAnimationPhase(for: $0) }).count == 5)
    }

    @Test func baseCruisingSpeedKeepsPreAdjustmentDolphinRatioWithoutStopping() {
        #expect(AquariumFishMotion.movementProfile(for: .manta).baseSpeedRange == FishMovementProfile.bluefinTuna.baseSpeedRange)
        var tuna = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna)
        var dolphin = AquariumFishMotion.initialState(for: id, profile: .dolphin)
        #expect(FishMovementProfile.bluefinTuna.hoverProbability == 0 && FishMovementProfile.bluefinTuna.burstProbability == 0)
        for tick in 1...900 {
            tuna.behavior = .cruising; dolphin.behavior = .cruising
            tuna.behaviorTimeRemaining = 100; dolphin.behaviorTimeRemaining = 100
            tuna.directionChangeTimeRemaining = 100; dolphin.directionChangeTimeRemaining = 100
            tuna.targetSpeed = tuna.baseSpeed; dolphin.targetSpeed = dolphin.baseSpeed
            tuna.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            dolphin.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30, speedMultiplier: AquariumDolphinSwimming.propulsionSpeed)
            #expect(tuna.currentSpeed > 0)
            if tick > 300 { #expect(abs(tuna.currentSpeed / dolphin.currentSpeed - 1.20) < 0.001) }
        }
    }

    @Test func continuousSwimmingDoesNotRemainPinnedToAnEdge() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let side = AquariumFishSizing.displaySize(for: .manta, isFavorite: false)
            let bounds = FishMovementProfile.bluefinTuna.roamingStyle.bounds(in: size, fishSize: side)
            for individual in 1...5 {
                let id = UUID(uuidString: String(format: "B10F17A0-6A60-4A60-8A60-%012d", individual))!
                var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna, roamingBounds: bounds, aquariumSize: size)
                var pinned = 0, longest = 0
                for tick in 1...900 {
                    state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
                    let p = state.position
                    let atEdge = abs(p.x - bounds.horizontal.lowerBound) < 0.000001
                        || abs(p.x - bounds.horizontal.upperBound) < 0.000001
                        || abs(p.y - bounds.vertical.lowerBound) < 0.000001
                        || abs(p.y - bounds.vertical.upperBound) < 0.000001
                    pinned = atEdge ? pinned + 1 : 0
                    longest = max(longest, pinned)
                    #expect(bounds.horizontal.contains(p.x) && bounds.vertical.contains(p.y))
                }
                #expect(longest < 45, "size=\(size), id=\(individual), pinned=\(longest) frames")
            }
        }
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    @Test func renderedSizeMatchesNinetyPercentOfDolphinAndAllFramesKeepAlphaAndHitArea() throws {
        let side = AquariumFishSizing.displaySize(for: .manta, isFavorite: false)
        let dolphin = AquariumFishSizing.displaySize(for: .dolphin, isFavorite: false)
        #expect(abs(side * 956 / 1254 - dolphin * 1203 / 1254 * 0.90) < 0.000001)
        for name in FishSpecies.manta.swimmingImageNames + ["fish_bluefin_tuna"] {
            let sprite = FishImageView(species: .manta, runtimeImageName: name)
            let source = ImageRenderer(content: sprite.frame(width: side, height: side))
            source.scale = 2
            let image = try #require(source.uiImage?.cgImage), bytes = pixels(image)
            let path = AquariumFishHitTesting.path(image: sprite.interactionImage, canvasSize: side + 20, fishSize: side)
            var minX = image.width, maxX = 0
            for y in 0..<image.height { for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 128 {
                minX = min(minX, x); maxX = max(maxX, x)
                #expect(x > 0 && x < image.width - 1 && y > 0 && y < image.height - 1)
                if x.isMultiple(of: 8) && y.isMultiple(of: 8) {
                    #expect(path.contains(CGPoint(x: 10 + CGFloat(x) / CGFloat(image.width) * side,
                        y: 10 + CGFloat(y) / CGFloat(image.height) * side)))
                }
            } }
            if name == "fish_bluefin_tuna" { #expect(abs(CGFloat(maxX - minX + 1) / 2 - dolphin * 1203 / 1254 * 0.90) < 1) }
            for theme in AquariumBackgroundTheme.allCases {
                let renderer = ImageRenderer(content: sprite.frame(width: side, height: side)
                    .modifier(AquariumFishColorCorrection.correction(for: theme, species: .manta)))
                renderer.scale = 2
                let corrected = try #require(renderer.uiImage?.cgImage), result = pixels(corrected)
                #expect(image.width == corrected.width && image.height == corrected.height)
                #expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { abs(Int(bytes[$0]) - Int(result[$0])) <= 1 })
            }
        }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = FishMovementProfile.bluefinTuna.roamingStyle.bounds(in: size, fishSize: side)
            #expect(bounds.horizontal.lowerBound * size.width >= side * 0.40 + 5.9)
            #expect(bounds.vertical.lowerBound * size.height >= side * 0.20 + 5.9)
        }
    }

    @Test func renderBackgroundComparisonsAtRaisedNeutralAndLoweredTail() throws {
        let side = AquariumFishSizing.displaySize(for: .manta, isFavorite: false)
        for theme in AquariumBackgroundTheme.allCases {
            let renderer = ImageRenderer(content: HStack(spacing: 0) {
                ForEach([false, true], id: \.self) { corrected in
                    ZStack {
                        AquariumBackground(theme: theme)
                        ForEach(Array([0, 3, 7].enumerated()), id: \.offset) { item in
                            FishImageView(species: .manta, fixedAnimationFrameIndex: item.element)
                                .frame(width: side, height: side)
                                .modifier(corrected ? AquariumFishColorCorrection.correction(for: theme, species: .manta)
                                    : .init(saturation: 1, brightness: 0, red: 1, green: 1, blue: 1))
                                .opacity(FishMovementProfile.bluefinTuna.depthOpacity(at: 0.5))
                                .position(x: 196.5, y: 746 * [0.18, 0.5, 0.82][item.offset])
                        }
                    }.frame(width: 393, height: 746).clipped()
                }
            })
            renderer.scale = 2
            try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/BluefinTuna-\(theme.rawValue).png"))
        }
    }
}
