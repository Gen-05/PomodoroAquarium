import SwiftUI
import Combine
import SwiftData
import UIKit
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import PomodoroAquarium

@MainActor
struct WhaleSharkAnimationTests {
    private let frameDuration = AquariumFishMotion.whaleSharkSpriteFrameDuration

    private func alphaBounds(_ image: UIImage) throws -> CGRect {
        let cg = try #require(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        bytes.withUnsafeMutableBytes {
            let context = CGContext(data: $0.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        var x0 = cg.width, y0 = cg.height, x1 = -1, y1 = -1
        for y in 0..<cg.height { for x in 0..<cg.width where bytes[(y * cg.width + x) * 4 + 3] > 16 {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        } }
        try #require(x1 >= x0)
        return CGRect(x: CGFloat(x0) / image.scale, y: CGFloat(y0) / image.scale,
            width: CGFloat(x1 - x0 + 1) / image.scale, height: CGFloat(y1 - y0 + 1) / image.scale)
    }

    private func render(_ view: some View) throws -> UIImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return try #require(renderer.uiImage)
    }

    @Test func allTwelveTransparentFramesAndNeutralAssetsAreRegistered() throws {
        let species = FishSpecies.whaleShark
        #expect(species.rawValue == "whaleShark" && species.rarity == .legendary && species.displayScale == 6)
        #expect(species.swimmingImageNames == (1...12).map { "fish_whale_shark_side_\($0)" })
        #expect(species.imageName == "fish_whale_shark" && species.usesForwardSwimmingLoop)
        for name in species.swimmingImageNames + [species.imageName!] {
            let image = try #require(UIImage(named: name)?.cgImage)
            #expect(image.width == 1254 && image.height == 1254)
            #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        }
        #expect(UIImage(named: species.imageName!)?.pngData() == UIImage(named: species.swimmingImageNames[0])?.pngData())
        #expect(UIImage(named: species.swimmingImageNames[6])?.pngData() == UIImage(named: species.swimmingImageNames[0])?.pngData())
        for species in FishSpecies.allCases where species != .whaleShark {
            #expect(species.usesForwardSwimmingLoop == (species == .manta))
        }
    }

    @Test func actualSpriteAndDetailPlaybackUseEveryFrameForwardAtPointTwoFourSeconds() throws {
        let species = FishSpecies.whaleShark
        #expect(frameDuration == 0.24)
        for behavior in AquariumFishMotion.Behavior.allCases {
            for speed: CGFloat in [0, 0.03, 0.9] {
                #expect(AquariumFishMotion.spriteFrameDuration(for: species, behavior: behavior, currentSpeed: speed, baseSpeed: 0.03) == frameDuration)
            }
        }
        for step in 0..<36 {
            let time = (Double(step) + 0.5) * frameDuration
            let index = FishSpriteAnimation.loopFrameIndex(frameCount: 12, elapsedTime: time, frameDuration: frameDuration)
            #expect(index == step % 12)
            let image = FishImageView(species: species, animationTime: time, animationFrameDuration: frameDuration).interactionImage
            #expect(image?.pngData() == UIImage(named: species.swimmingImageNames[step % 12])?.pngData())
        }
        for time in [2.88, 5.76] {
            #expect(FishSpriteAnimation.loopFrameIndex(frameCount: 12, elapsedTime: time - 0.000001, frameDuration: frameDuration) == 11)
            #expect(FishSpriteAnimation.loopFrameIndex(frameCount: 12, elapsedTime: time + 0.000001, frameDuration: frameDuration) == 0)
        }
        var detail = FishDetailStrokeAnimationState(species: species)
        let started = detail.start()
        #expect(detail.frameDuration == frameDuration && started)
        var frames: [Int] = []
        while let frame = detail.currentFrameIndex { frames.append(frame); detail.advance() }
        #expect(frames == Array(0..<12) && !detail.isAnimating)
        #expect(FishRewardPresentationTiming.rewardFrameDuration(for: species) == frameDuration)
        #expect(abs(FishRewardPresentationTiming.oneStrokeDuration(for: species) - 2.88) < 0.000001)
    }

    @Test func aquariumPlaybackUsesStableIndividualTempoWithTheNewBaseInterval() {
        let ids = (1...5).map { UUID(uuidString: String(format: "A11E5A40-0000-4000-8000-%012d", $0))! }
        func duration(for id: UUID, species: FishSpecies = .whaleShark) -> TimeInterval {
            SwimmingFishView(fishID: id, species: species, backgroundTheme: .aquarium,
                isFavorite: false, aquariumSize: CGSize(width: 393, height: 852),
                updateDate: Date(timeIntervalSince1970: 100), isSimulationPaused: false,
                isSelectionEnabled: false, isSelected: false, neighborPositions: .empty,
                reportPosition: { _ in }, select: {}).spriteFrameDuration
        }
        let durations = ids.map { duration(for: $0) }
        #expect(Set(durations).count > 1)
        for (id, actual) in zip(ids, durations) {
            #expect(actual == 0.24 * AquariumFishMotion.spriteTempoMultiplier(for: id))
            #expect((0.216...0.264).contains(actual))
            #expect(duration(for: id) == actual)
            #expect(duration(for: id, species: .manta) == 0.11)
        }
    }

    @Test func neutralVisibleLengthIsPreservedAndCatalogFramesFitWithoutClipping() throws {
        let species = FishSpecies.whaleShark
        let side = AquariumFishSizing.displaySize(for: species, isFavorite: false)
        let neutral = try render(FishImageView(species: species).frame(width: side, height: side))
        let visible = try alphaBounds(neutral)
        let previousVisible: CGFloat = 468 * (1177.0 / 1254)
        #expect(abs(visible.width - previousVisible) < 1)
        #expect(abs(side - 550.2857142857143) < 0.000001)
        var records: [[String: Any]] = [["context": "aquariumNeutral", "canvas": side,
            "visibleWidth": visible.width, "previousVisibleWidth": previousVisible]]
        for placed in [false, true] {
            let canvas = AquariumEditorFishThumbnailLayout.imageSize(for: species, isPlacedList: placed)
            let viewport = placed ? CGSize(width: 60, height: 50) : AquariumEditorFishThumbnailLayout.viewport
            let image = try render(FishImageView(species: species).frame(width: canvas.width, height: canvas.height)
                .frame(width: viewport.width, height: viewport.height).clipped())
            let bounds = try alphaBounds(image)
            #expect(bounds.minX > 0 && bounds.maxX < viewport.width && bounds.minY > 0 && bounds.maxY < viewport.height)
            records.append(["context": placed ? "editorPlaced" : "editorAdd", "canvas": canvas.width, "visibleWidth": bounds.width])
        }
        let bookSize = BookFishThumbnailLayout.imageSize(for: species)
        let bookImage = try render(FishImageView(species: species).frame(width: bookSize.width, height: bookSize.height)
            .frame(width: 48, height: 38).clipped())
        let bookBounds = try alphaBounds(bookImage)
        #expect(bookBounds.minX > 0 && bookBounds.maxX < 48 && bookBounds.minY > 0 && bookBounds.maxY < 38)
        #expect(abs(bookBounds.width - 38 * 1.32 * 1168 / 1254) < 1)
        records.append(["context": "book", "visibleWidth": bookBounds.width])
        for width: CGFloat in [288, 361, 736] {
            let viewport = CGSize(width: width, height: FishDetailImageLayout.cardHeight)
            let available = FishDetailImageLayout.availableSize(in: viewport)
            let canvas = FishDetailImageLayout.catalogDisplaySize(for: species, availableSize: available)
            for frame in 0..<12 {
                let image = try render(FishImageView(species: species, fixedAnimationFrameIndex: frame)
                    .frame(width: canvas, height: canvas).frame(width: viewport.width, height: viewport.height).clipped())
                let bounds = try alphaBounds(image)
                #expect(bounds.minX > 0 && bounds.maxX < viewport.width && bounds.minY > 0 && bounds.maxY < viewport.height)
                if frame == 0 { records.append(["context": "detail\(width)", "canvas": canvas, "visibleWidth": bounds.width]) }
            }
        }
        try JSONSerialization.data(withJSONObject: records, options: .prettyPrinted)
            .write(to: URL(fileURLWithPath: "/private/tmp/WhaleSharkVisibleLengths.json"))
        if let old = UIImage(contentsOfFile: "/private/tmp/WhaleSharkOldSide1.png") {
            let comparison = try render(VStack {
                Text("Old / new neutral: same visible length, unchanged image aspect ratio")
                Image(uiImage: old).resizable().scaledToFit().frame(width: 468, height: 468).frame(width: 620, height: 260)
                FishImageView(species: species).frame(width: side, height: side).frame(width: 620, height: 260)
            }.padding().background(.white))
            try #require(comparison.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/WhaleSharkSizeComparison.png"))
        }
    }

    @Test func loopPreviewUsesTheSameCanvasAndMirrorsWithoutExtraDeformation() throws {
        let species = FishSpecies.whaleShark
        let side = AquariumFishSizing.displaySize(for: species, isFavorite: false)
        let url = URL(fileURLWithPath: "/private/tmp/WhaleSharkForwardLoop.gif")
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 24, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for step in 0..<24 {
            let time = (Double(step) + 0.5) * frameDuration
            let shot = try render(HStack(spacing: 0) {
                ForEach([1.0, -1.0], id: \.self) { sign in
                    FishImageView(species: species, facingHorizontalScale: sign, animationTime: time,
                        animationFrameDuration: frameDuration).frame(width: side, height: side)
                        .modifier(AquariumFishColorCorrection.correction(for: .aquarium, species: species))
                        .frame(width: 620, height: 300)
                }
            }.frame(height: 360).background(Color(red: 0.7, green: 0.9, blue: 0.95)))
            CGImageDestinationAddImage(destination, try #require(shot.cgImage),
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: frameDuration]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(destination))
        #expect(AquariumFishMotion.presentationAmplitude(for: species) == 0)
        for sign: CGFloat in [-1, 1] {
            #expect(FishImageView(species: species, facingHorizontalScale: sign).resolvedHorizontalScale == sign)
        }
    }

    @Test func actualSwimmingViewShowsTheNewLoopWithoutChangingTheMotionCalculation() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let id = UUID(uuidString: "A11E5A40-0000-4000-8000-000000000001")!
        let size = CGSize(width: 1024, height: 768)
        let session = AquariumFishViewingSession()
        let probe = WhaleSharkRenderProbe()
        let initial = AquariumFishMotion.initialState(for: id, profile: .whaleShark,
            initialPosition: CGPoint(x: 0.5, y: 0.4), aquariumSize: size,
            fishSize: AquariumFishSizing.displaySize(for: .whaleShark, isFavorite: false))
        let owner = UUID()
        var initialTempo = AquariumWhaleSharkAnimationTempo.State(id: id)
        initialTempo.advance(deltaTime: initialTempo.phaseDuration + 0.5)
        _ = session.claim(id, owner: owner, initial: .init(motion: initial,
            direction: .init(direction: initial.facingDirection), whaleSharkTempo: initialTempo), bounds: .legacy)
        session.release(id, owner: owner)
        let host = UIHostingController(rootView: WhaleSharkWaterHost(id: id, session: session, probe: probe, size: size))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        var reference = try #require(session.snapshot(for: id)).motion
        var tempoReference = try #require(session.snapshot(for: id)?.whaleSharkTempo)
        var lastTime = 0.0
        var frames: Set<Int> = []
        var tempoPhases: Set<String> = []
        let destination = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath:
            "/private/tmp/WhaleSharkActualSwimming.gif") as CFURL, UTType.gif.identifier as CFString, 60, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        for tick in 1...180 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) / 30)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(15))
            host.view.layoutIfNeeded()
            let saved = try #require(session.snapshot(for: id))
            let delta = saved.elapsedTime - lastTime
            if delta > 0 {
                reference.advance(deltaTime: delta, elapsedTime: saved.elapsedTime)
                tempoReference.advance(deltaTime: delta)
            }
            #expect(abs(saved.motion.position.x - reference.position.x) < 0.000000001)
            #expect(abs(saved.motion.position.y - reference.position.y) < 0.000000001)
            #expect(saved.motion.randomState == reference.randomState)
            let tempo = try #require(saved.whaleSharkTempo)
            tempoPhases.insert(String(describing: tempo.phase))
            #expect(abs(tempo.playbackTime - tempoReference.playbackTime) < 0.000000001)
            let rendering = SwimmingFishView(fishID: id, viewingSession: session, species: .whaleShark,
                backgroundTheme: .aquarium, isFavorite: false, aquariumSize: size, updateDate: probe.date,
                isSimulationPaused: false, isSelectionEnabled: false, isSelected: false,
                neighborPositions: .empty, reportPosition: { _ in }, select: {})
            #expect(rendering.spriteAnimationTime == tempo.playbackTime)
            lastTime = saved.elapsedTime
            frames.insert(FishSpriteAnimation.loopFrameIndex(frameCount: 12, elapsedTime: tempo.playbackTime,
                frameDuration: frameDuration * AquariumFishMotion.spriteTempoMultiplier(for: id),
                phase: AquariumFishMotion.spriteAnimationPhase(for: id)))
            if tick.isMultiple(of: 3) {
                let shot = renderer.image { _ in host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true) }
                CGImageDestinationAddImage(destination, try #require(shot.cgImage),
                    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.1]] as CFDictionary)
                if tick == 90 {
                    try #require(shot.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/WhaleSharkActualSwimming.png"))
                }
            }
        }
        #expect(frames == Set(0..<12))
        #expect(tempoPhases.contains("slowing") && tempoPhases.contains("slow"))
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test func actualEditorAndCatalogShowTheWholeNeutralFish() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let fish = [PlayerFish(species: .whaleShark), PlayerFish(species: .whaleShark)]
        let player = Player(ownedFish: fish, activeAquariumFishIDs: [fish[0].id], hasInitializedActiveAquariumFish: true)
        container.mainContext.insert(player); try container.mainContext.save()
        var screenshots: [UIImage] = []
        for width: CGFloat in [320, 393] {
            for page in 0..<4 {
                let root: AnyView
                if page < 2 {
                    root = AnyView(AquariumEditorSheet(placements: [], player: player, backgroundTheme: .aquarium,
                        editorCategory: .fish, selectedFishID: nil, showsActiveFish: .constant(page == 1), category: .constant(nil),
                        addDecoration: { _ in }, selectPlacement: { _ in }, addFish: { _ in }, storeFish: { _ in },
                        selectFish: { _ in }, close: {}, selectBackground: { _ in }))
                } else if page == 2 {
                    root = AnyView(NavigationStack { BookView() }.modelContainer(container))
                } else {
                    root = AnyView(NavigationStack { FishDetailView(species: .whaleShark, player: player) })
                }
                let size = CGSize(width: width, height: 852)
                let host = UIHostingController(rootView: root)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = host; window.makeKeyAndVisible()
                host.view.layoutIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                if page == 2 {
                    func scrollToBottom(_ view: UIView) {
                        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                        }
                        for child in view.subviews { scrollToBottom(child) }
                    }
                    scrollToBottom(host.view)
                    try await Task.sleep(for: .milliseconds(80))
                }
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let shot = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                screenshots.append(shot)
                window.isHidden = true
            }
        }
        let sheet = try render(VStack {
            ForEach(0..<2) { row in
                HStack {
                    ForEach(0..<4) { col in
                        Image(uiImage: screenshots[row * 4 + col]).resizable().frame(width: 196.5, height: 426)
                    }
                }
            }
        }.padding().background(.white))
        try #require(sheet.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/WhaleSharkActualCatalog.png"))
    }

    @Test func ownershipPlacementDiscoveryAndLegendaryCandidatesStayCompatible() throws {
        let restored = try JSONDecoder().decode(FishSpecies.self, from: Data("\"whaleShark\"".utf8))
        #expect(restored == .whaleShark && FishSpecies.allCases.count == 16)
        #expect(FishSpecies.allCases.filter { $0.rarity == .legendary } == [.whaleShark])
        let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let id = UUID(), fish = PlayerFish(id: id, species: restored)
        let player = Player(ownedFish: [fish], activeAquariumFishIDs: [id], hasInitializedActiveAquariumFish: true)
        container.mainContext.insert(player); try container.mainContext.save()
        let read = try #require(try container.mainContext.fetch(FetchDescriptor<Player>()).first)
        #expect(read.ownedFish.count == 1 && read.ownedFish.first?.id == id && read.activeAquariumFishIDs == [id])
        #expect(BookView.ownedCount(for: restored, in: read) == 1)
        for minutes in [0, 180] {
            #expect(FishRewardService.rarityProbabilities(for: minutes).legendary == (minutes == 0 ? 2 : 4))
        }
        #expect(FishMovementProfile.whaleShark.baseSpeedRange == 0.026...0.040)
        #expect(FishMovementProfile.whaleShark.directionHoldDurationRange == 10...15)
        #expect(FishMovementProfile.whaleShark.turnResponsivenessRange == 0.14...0.28)
    }
}

@MainActor
private final class WhaleSharkRenderProbe: ObservableObject {
    @Published var date = Date(timeIntervalSince1970: 100)
}
private struct WhaleSharkWaterHost: View {
    let id: UUID
    let session: AquariumFishViewingSession
    @ObservedObject var probe: WhaleSharkRenderProbe
    let size: CGSize
    var body: some View {
        ZStack {
            AquariumBackground(theme: .aquarium)
            SwimmingFishView(fishID: id, viewingSession: session, species: .whaleShark,
                backgroundTheme: .aquarium, isFavorite: false, aquariumSize: size,
                updateDate: probe.date, isSimulationPaused: false, isSelectionEnabled: false,
                isSelected: false, neighborPositions: .empty, reportPosition: { _ in }, select: {})
        }.frame(width: size.width, height: size.height).ignoresSafeArea().environment(\.scenePhase, .active)
    }
}
