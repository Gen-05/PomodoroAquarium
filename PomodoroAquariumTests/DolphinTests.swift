import SwiftUI
import SwiftData
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct DolphinTests {
    private let id = UUID(uuidString: "D01F1150-6A60-4A60-8A60-000000000001")!
    private var images: [String] { FishSpecies.dolphin.swimmingImageNames + AquariumDolphinSwimming.glideImageNames }

    @Test func registrationImagesAndIdenticalNeutralConnection() throws {
        #expect(FishSpecies.dolphin.rawValue == "dolphin" && FishSpecies.dolphin.name == "イルカ")
        #expect(FishSpecies.dolphin.rarity == .epic && FishSpecies.dolphin.imageName == "fish_dolphin_side_5")
        #expect(try JSONDecoder().decode(FishSpecies.self, from: JSONEncoder().encode(FishSpecies.dolphin)) == .dolphin)
        #expect(images.count == 14)
        for name in images {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipLast && image.alphaInfo != .noneSkipFirst)
        }
        #expect(UIImage(named: "fish_dolphin_side_5")?.pngData() == UIImage(named: "fish_dolphin_glide_3")?.pngData())
        #expect(!FishSpecies.dolphin.usesDirectionalSwimmingSprites && FishSpecies.dolphin.usesHorizontalSwimmingFlip)
    }

    @Test func exactCyclesJoinAtNeutralWithoutDuplicateEndpointFrames() {
        var state = AquariumDolphinSwimming.State(id: id, staggered: false)
        let sequence = (0..<32).map { _ in
            let frame = state.imageName
            state.advance(deltaTime: 0.12)
            return frame
        }
        #expect(sequence == (AquariumDolphinSwimming.propulsionFrames + AquariumDolphinSwimming.propulsionFrames).map { "fish_dolphin_side_\($0)" })
        #expect(state.phase == .gliding && state.imageName == "fish_dolphin_glide_3")
        #expect((3...5).contains(state.plannedGlideDuration))
        var observed: [Int] = []
        var prior = state
        while state.phase == .gliding {
            observed.append(state.frameNumber)
            prior = state
            state.advance(deltaTime: 0.30)
        }
        #expect(observed.prefix(8) == AquariumDolphinSwimming.glideFrames[...])
        #expect(prior.frameNumber == 4 || prior.frameNumber == 2)
        #expect(state.imageName == "fish_dolphin_side_5")
        #expect(prior.phaseElapsed < prior.plannedGlideDuration + 1.2)
        #expect(abs(prior.phaseElapsed + 0.3 - prior.plannedGlideDuration) < 0.000001)
        #expect(abs(state.phaseElapsed) < 0.000001)
    }

    @Test func speedIsContinuousPositiveAndIndependentOfFrameTempo() {
        var state = AquariumDolphinSwimming.State(id: id, staggered: false)
        var previous = state.speedMultiplier
        var phases: Set<String> = []
        var motion = AquariumFishMotion.initialState(for: id, profile: .dolphin)
        let start = motion.position
        for tick in 1...1800 {
            state.advance(deltaTime: 1.0 / 60)
            #expect(state.speedMultiplier >= AquariumDolphinSwimming.glideSpeed)
            #expect(state.speedMultiplier <= AquariumDolphinSwimming.propulsionSpeed)
            #expect(abs(state.speedMultiplier - previous) < 0.008)
            motion.advance(deltaTime: 1.0 / 60, elapsedTime: Double(tick) / 60, speedMultiplier: state.speedMultiplier)
            #expect(motion.currentSpeed > 0)
            phases.insert(String(describing: state.phase))
            previous = state.speedMultiplier
        }
        #expect(phases.count == 2 && motion.position != start)
        #expect(FishMovementProfile.dolphin.baseSpeedRange.lowerBound == FishMovementProfile.seaTurtle.baseSpeedRange.lowerBound * 1.10)
        #expect(FishMovementProfile.dolphin.turnResponsivenessRange == FishMovementProfile.seaTurtle.turnResponsivenessRange)
    }

    @Test func fixedIDsHaveIndependentReproducibleCyclesAndMotion() {
        let ids = (1...5).map { UUID(uuidString: String(format: "D01F1150-6A60-4A60-8A60-%012d", $0))! }
        let states = ids.map { AquariumDolphinSwimming.State(id: $0) }
        #expect(states == ids.map { AquariumDolphinSwimming.State(id: $0) })
        #expect(Set(states.map { "\($0.phase)-\($0.frameStep)-\($0.frameElapsed)" }).count == 5)
        #expect(Set(states.map { String(describing: $0.phase) }).count == 2)
        #expect(Set(ids.map { AquariumFishMotion.initialState(for: $0, profile: .dolphin).position.x }).count == 5)
        var oneStep = states[0], split = states[0]
        oneStep.advance(deltaTime: 30)
        for _ in 0..<1800 { split.advance(deltaTime: 1.0 / 60) }
        #expect(oneStep.imageName == split.imageName && oneStep.phase == split.phase)
        #expect(abs(oneStep.phaseElapsed - split.phaseElapsed) < 0.000001)
        #expect(abs(oneStep.speedMultiplier - split.speedMultiplier) < 0.000001)
    }

    @Test func sharedSnapshotKeepsCycleOwnershipAndEditingIsolation() throws {
        let session = AquariumFishViewingSession(), owner = UUID(), next = UUID()
        var cycle = AquariumDolphinSwimming.State(id: id, staggered: false)
        cycle.advance(deltaTime: 4.6)
        let motion = AquariumFishMotion.initialState(for: id, profile: .dolphin)
        var value = AquariumFishViewingSession.Snapshot(motion: motion,
            direction: .init(direction: motion.facingDirection), wing: nil, dolphin: cycle)
        _ = session.claim(id, owner: owner, initial: value, bounds: .legacy)
        let resumed = session.claim(id, owner: next, initial: value, bounds: .legacy)
        #expect(resumed.dolphin == cycle)
        value.dolphin?.advance(deltaTime: 0.2)
        #expect(!session.update(id, owner: owner, snapshot: value))
        #expect(session.snapshot(for: id)?.dolphin == cycle)
        session.beginEditing()
        let editing = try #require(session.editingSession)
        _ = editing.claim(id, owner: owner, initial: value, bounds: .legacy)
        #expect(editing.update(id, owner: owner, snapshot: value))
        session.finishEditing()
        #expect(session.snapshot(for: id)?.dolphin == cycle)
        session.beginEditing()
        let committed = try #require(session.editingSession)
        _ = committed.claim(id, owner: owner, initial: value, bounds: .legacy)
        #expect(committed.update(id, owner: owner, snapshot: value))
        session.finishEditing(commit: [id])
        #expect(session.snapshot(for: id)?.dolphin == value.dolphin)
        session.stopInflation(except: [])
        #expect(session.snapshot(for: id) == nil)
    }

    @Test func savedPlayerFishRestoresNewAndOldIDs() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let schema = Schema([PlayerFish.self])
        let config = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("fish.store"))
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            context.insert(PlayerFish(id: id, species: .dolphin))
            context.insert(PlayerFish(species: .clownfish))
            try context.save()
        }
        let restored = try ModelContainer(for: schema, configurations: config)
        let fish = try ModelContext(restored).fetch(FetchDescriptor<PlayerFish>())
        #expect(fish.count == 2 && fish.first { $0.id == id }?.species == .dolphin)
        #expect(fish.contains { $0.species == .clownfish })
    }

    @Test func epicCandidatesRemainUniformAndRarityWeightsUnchanged() {
        let pool = FishSpecies.allCases.filter { $0.rarity == .epic }
        #expect(pool == [.manta, .seaTurtle, .dolphin])
        for (minutes, epic) in [(0, 8.0), (180, 13.0), (300, 13.0)] {
            let p = FishRewardService.rarityProbabilities(for: minutes)
            #expect(p.epic == epic && p.total == 100)
            #expect(p.epic / Double(pool.count) == epic / 3)
        }
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.draw(image,
                    in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    @Test func allFramesKeepSameSizeAlphaAndSelectableTailWithinSafeBounds() throws {
        let side = AquariumFishSizing.displaySize(for: .dolphin, isFavorite: false)
        let turtle = AquariumFishSizing.displaySize(for: .seaTurtle, isFavorite: false)
        #expect(abs(side * 1203 / 1254 - turtle * 867 / 1254 * 1.5) < 0.000001)
        for name in images {
            let sprite = FishImageView(species: .dolphin, runtimeImageName: name)
            let source = ImageRenderer(content: sprite.frame(width: side, height: side))
            source.scale = 4
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
            if name == FishSpecies.dolphin.imageName {
                #expect(abs(CGFloat(maxX - minX + 1) / 4 - turtle * 867 / 1254 * 1.5) < 1)
            }
            for theme in AquariumBackgroundTheme.allCases {
                let renderer = ImageRenderer(content: sprite.frame(width: side, height: side)
                    .modifier(AquariumFishColorCorrection.correction(for: theme, species: .dolphin)))
                renderer.scale = 4
                let result = try #require(renderer.uiImage?.cgImage), corrected = pixels(result)
                #expect(result.width == image.width && result.height == image.height)
                #expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { abs(Int(bytes[$0]) - Int(corrected[$0])) <= 1 })
            }
        }
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = FishMovementProfile.dolphin.roamingStyle.bounds(in: size, fishSize: side)
            #expect(bounds.horizontal.lowerBound * size.width >= side * 0.72 + 5.9)
            #expect(bounds.vertical.lowerBound * size.height >= side * 0.72 + 5.9)
        }
    }

    @Test func renderThreeBackgroundComparisons() throws {
        let size = AquariumFishSizing.displaySize(for: .dolphin, isFavorite: false)
        let frames = ["fish_dolphin_side_5", "fish_dolphin_side_9", "fish_dolphin_glide_5"]
        for theme in AquariumBackgroundTheme.allCases {
            let renderer = ImageRenderer(content: HStack(spacing: 0) {
                ForEach([false, true], id: \.self) { corrected in
                    ZStack {
                        AquariumBackground(theme: theme)
                        ForEach(Array(frames.enumerated()), id: \.offset) { frame in
                            FishImageView(species: .dolphin, runtimeImageName: frame.element)
                                .frame(width: size, height: size)
                                .modifier(corrected ? AquariumFishColorCorrection.correction(for: theme, species: .dolphin)
                                    : .init(saturation: 1, brightness: 0, red: 1, green: 1, blue: 1))
                                .opacity(FishMovementProfile.dolphin.depthOpacity(at: 0.5))
                                .position(x: 196.5, y: 746 * [0.18, 0.5, 0.82][frame.offset])
                        }
                    }.frame(width: 393, height: 746).clipped()
                }
            })
            renderer.scale = 2
            try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/Dolphin-\(theme.rawValue).png"))
        }
    }
}
