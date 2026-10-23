import SwiftUI
import SwiftData
import UIKit
import Combine
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import PomodoroAquarium

@MainActor
struct OrcaPresentationTests {
    private func render(_ view: some View, scale: CGFloat = 3) throws -> UIImage {
        let renderer = ImageRenderer(content: view); renderer.scale = scale
        return try #require(renderer.uiImage)
    }

    private func pixels(_ image: CGImage) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        data.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    private func bounds(_ image: UIImage) throws -> CGRect {
        let cg = try #require(image.cgImage), data = pixels(cg)
        var x0 = cg.width, y0 = cg.height, x1 = -1, y1 = -1
        for y in 0..<cg.height { for x in 0..<cg.width where data[(y * cg.width + x) * 4 + 3] > 16 {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        } }
        try #require(x1 >= x0)
        return CGRect(x: CGFloat(x0) / image.scale, y: CGFloat(y0) / image.scale,
            width: CGFloat(x1 - x0 + 1) / image.scale, height: CGFloat(y1 - y0 + 1) / image.scale)
    }

    @Test func aquariumVisibleLengthIncreasesTenPercentAndAllFramesFitCatalogAndHitShapes() throws {
        let side = AquariumFishSizing.displaySize(for: .orca, isFavorite: false)
        let dolphinSide = AquariumFishSizing.displaySize(for: .dolphin, isFavorite: false)
        let dolphin = try render(FishImageView(species: .dolphin).frame(width: dolphinSide, height: dolphinSide))
        let orca = try render(FishImageView(species: .orca).frame(width: side, height: side))
        let dolphinWidth = try bounds(dolphin).width, orcaWidth = try bounds(orca).width
        let previousSide: CGFloat = 226.19688955046468
        let previous = try render(FishImageView(species: .orca).frame(width: previousSide, height: previousSide))
        let previousWidth = try bounds(previous).width
        try JSONSerialization.data(withJSONObject: ["dolphinCanvas": dolphinSide, "orcaCanvas": side,
            "dolphinVisibleWidth": dolphinWidth, "orcaVisibleWidth": orcaWidth,
            "visibleRatio": orcaWidth / dolphinWidth, "previousOrcaVisibleWidth": previousWidth,
            "sizeChangeRatio": orcaWidth / previousWidth], options: .prettyPrinted)
            .write(to: URL(fileURLWithPath: "/private/tmp/OrcaVisibleSizes.json"))
        #expect(abs(orcaWidth / dolphinWidth - 1.32) < 0.01)
        #expect(abs(orcaWidth / previousWidth - 1.10) < 0.005)
        #expect(abs(side - 248.81657850551115) < 0.000001)
        #expect(abs(dolphinSide - 186.9305134619731) < 0.000001)
        let comparison = try render(VStack {
            Text("Dolphin / Orca - same depth, visible length 1 : 1.32")
            HStack {
                FishImageView(species: .dolphin).frame(width: dolphinSide, height: dolphinSide).frame(width: 280, height: 180)
                FishImageView(species: .orca).frame(width: side, height: side).frame(width: 280, height: 180)
            }
        }.padding().background(.white), scale: 2)
        try #require(comparison.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/OrcaSizeComparison.png"))
        let sizes = [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)]
        for frame in 0..<16 {
            let source = try #require(UIImage(named: FishSpecies.orca.swimmingImageNames[frame]))
            let sourceBounds = try bounds(source)
            for size in sizes {
                let area = FishMovementProfile.orca.roamingStyle.bounds(in: size, fishSize: side)
                let oldArea = FishMovementProfile.orca.roamingStyle.bounds(in: size, fishSize: previousSide)
                #expect(area.horizontal.lowerBound > oldArea.horizontal.lowerBound)
                #expect(area.vertical.lowerBound > oldArea.vertical.lowerBound)
                for sign: CGFloat in [-1, 1] {
                    for x in [area.horizontal.lowerBound, area.horizontal.upperBound] {
                        for y in [area.vertical.lowerBound, area.vertical.upperBound] {
                            let minX = sign > 0 ? sourceBounds.minX / 1254 : 1 - sourceBounds.maxX / 1254
                            let maxX = sign > 0 ? sourceBounds.maxX / 1254 : 1 - sourceBounds.minX / 1254
                            #expect(x * size.width + (minX - 0.5) * side >= 0)
                            #expect(x * size.width + (maxX - 0.5) * side <= size.width)
                            #expect(y * size.height + (sourceBounds.minY / 1254 - 0.5) * side >= 0)
                            #expect(y * size.height + (sourceBounds.maxY / 1254 - 0.5) * side <= size.height)
                        }
                    }
                    let sprite = FishImageView(species: .orca, facingHorizontalScale: sign, fixedAnimationFrameIndex: frame)
                    #expect(sprite.resolvedHorizontalScale == sign)
                    let path = AquariumFishHitTesting.path(image: sprite.interactionImage, canvasSize: side + 20,
                        fishSize: side, horizontalScale: sign)
                    let cg = try #require(source.cgImage), data = pixels(cg)
                    for py in stride(from: 16, to: cg.height, by: 32) {
                        for px in stride(from: 16, to: cg.width, by: 32) where data[(py * cg.width + px) * 4 + 3] > 200 {
                            let localX = sign > 0 ? CGFloat(px) / 1254 : 1 - CGFloat(px) / 1254
                            #expect(path.contains(CGPoint(x: 10 + localX * side, y: 10 + CGFloat(py) / 1254 * side)))
                        }
                    }
                }
            }
            var contexts: [(CGSize, CGSize)] = []
            for placed in [false, true] {
                contexts.append((AquariumEditorFishThumbnailLayout.imageSize(for: .orca, isPlacedList: placed),
                    placed ? CGSize(width: 60, height: 50) : AquariumEditorFishThumbnailLayout.viewport))
            }
            for width: CGFloat in [288, 361, 736] {
                let viewport = CGSize(width: width, height: 240)
                let canvas = FishDetailImageLayout.catalogDisplaySize(for: .orca,
                    availableSize: FishDetailImageLayout.availableSize(in: viewport))
                contexts.append((CGSize(width: canvas, height: canvas), viewport))
            }
            let rewardCanvas = FishRewardImageLayout.displaySize(from: FishRewardImageLayout.detailDisplaySize(
                for: .orca, stageSize: CGSize(width: 320, height: 270)))
            contexts.append((CGSize(width: rewardCanvas, height: rewardCanvas), CGSize(width: 320, height: 270)))
            for (canvas, viewport) in contexts {
                let image = try render(FishImageView(species: .orca, fixedAnimationFrameIndex: frame)
                    .frame(width: canvas.width, height: canvas.height).frame(width: viewport.width, height: viewport.height).clipped())
                let rect = try bounds(image)
                #expect(rect.minX > 0 && rect.minY > 0 && rect.maxX < viewport.width && rect.maxY < viewport.height)
            }
        }
        let book = BookFishThumbnailLayout.imageSize(for: .orca)
        let bookImage = try render(FishImageView(species: .orca).frame(width: book.width, height: book.height)
            .frame(width: 48, height: 38).clipped())
        let bookRect = try bounds(bookImage)
        #expect(bookRect.minX > 0 && bookRect.maxX < 48 && bookRect.minY > 0 && bookRect.maxY < 38)
        print("Visible neutral lengths at 3x: dolphin \(dolphinWidth)pt, orca \(orcaWidth)pt")
    }

    @Test func backgroundCorrectionKeepsAlphaAndTheWholeFishReadable() throws {
        let side = AquariumFishSizing.displaySize(for: .orca, isFavorite: false)
        for frame in 0..<16 {
            let source = FishImageView(species: .orca, fixedAnimationFrameIndex: frame).frame(width: side, height: side)
            let original = try #require(try render(source, scale: 1).cgImage), alpha = pixels(original)
            for theme in AquariumBackgroundTheme.allCases {
                let corrected = try #require(try render(source.modifier(
                    AquariumFishColorCorrection.correction(for: theme, species: .orca)), scale: 1).cgImage)
                let result = pixels(corrected)
                #expect(original.width == corrected.width && original.height == corrected.height)
                #expect(stride(from: 3, to: alpha.count, by: 4).allSatisfy { abs(Int(alpha[$0]) - Int(result[$0])) <= 1 })
            }
        }
        let sheet = try render(HStack(spacing: 0) {
            ForEach(AquariumBackgroundTheme.allCases, id: \.self) { theme in
                ZStack {
                    AquariumBackground(theme: theme)
                    ForEach([0.22, 0.50, 0.78], id: \.self) { y in
                        FishImageView(species: .orca, fixedAnimationFrameIndex: y == 0.5 ? 11 : 0)
                            .frame(width: side, height: side)
                            .modifier(AquariumFishColorCorrection.correction(for: theme, species: .orca))
                            .position(x: 196.5, y: 746 * y)
                    }
                }.frame(width: 393, height: 746).clipped()
            }
        }, scale: 2)
        try #require(sheet.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/OrcaBackgrounds.png"))
    }

    @Test func actualSwimmingViewConnectsTwoStrokesAndGlideWithSharedState() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let id = UUID(uuidString: "0ACA1150-6A60-4A60-8A60-000000000001")!
        let size = CGSize(width: 393, height: 852), session = AquariumFishViewingSession()
        let probe = OrcaRenderProbe(), owner = UUID()
        let side = AquariumFishSizing.displaySize(for: .orca, isFavorite: false)
        let area = FishMovementProfile.orca.roamingStyle.bounds(in: size, fishSize: side)
        let motion = AquariumFishMotion.initialState(for: id, profile: .orca, roamingBounds: area,
            initialPosition: CGPoint(x: 0.5, y: 0.5), aquariumSize: size, fishSize: side)
        let cycle = AquariumOrcaSwimming.State(id: id, staggered: false)
        _ = session.claim(id, owner: owner, initial: .init(motion: motion,
            direction: .init(direction: motion.facingDirection), orca: cycle), bounds: area)
        session.release(id, owner: owner)
        let host = UIHostingController(rootView: OrcaRenderHost(id: id, session: session, probe: probe, size: size))
        let window = UIWindow(windowScene: scene); window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(60))
        var reference = cycle, lastTime = 0.0, previous = motion.position
        var frames: Set<Int> = [], phases: Set<String> = []
        let dest = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: "/private/tmp/OrcaActualSwimming.gif") as CFURL,
            UTType.gif.identifier as CFString, 100, nil))
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        for tick in 1...600 {
            probe.date = Date(timeIntervalSince1970: 100 + Double(tick) / 30)
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(8)); host.view.layoutIfNeeded()
            let saved = try #require(session.snapshot(for: id)), current = try #require(saved.orca)
            reference.advance(deltaTime: saved.elapsedTime - lastTime)
            #expect(reference.imageName == current.imageName && reference.phase == current.phase)
            #expect(abs(reference.phaseElapsed - current.phaseElapsed) < 0.000001)
            #expect(abs(reference.speedMultiplier - current.speedMultiplier) < 0.000001)
            #expect(area.horizontal.contains(saved.motion.position.x) && area.vertical.contains(saved.motion.position.y))
            #expect(hypot((previous.x - saved.motion.position.x) * size.width,
                (previous.y - saved.motion.position.y) * size.height) < 4)
            frames.insert(current.frameNumber); phases.insert(String(describing: current.phase))
            previous = saved.motion.position; lastTime = saved.elapsedTime
            if tick.isMultiple(of: 6) {
                let shot = renderer.image { _ in host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true) }
                CGImageDestinationAddImage(dest, try #require(shot.cgImage),
                    [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.2]] as CFDictionary)
            }
        }
        #expect(frames == Set(1...16) && phases.count == 2)
        #expect(CGImageDestinationFinalize(dest))
    }

    @Test func actualEditorBookDetailAndRewardShowTheNewSpecies() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let fish = [PlayerFish(species: .orca), PlayerFish(species: .orca)]
        let player = Player(ownedFish: fish, activeAquariumFishIDs: [fish[0].id], hasInitializedActiveAquariumFish: true)
        container.mainContext.insert(player); try container.mainContext.save()
        var shots: [UIImage] = []
        for width: CGFloat in [320, 393] {
            for page in 0..<5 {
                let root: AnyView
                let rewardCompletion = OrcaRewardCompletion()
                if page < 2 {
                    root = AnyView(AquariumEditorSheet(placements: [], player: player, backgroundTheme: .aquarium,
                        editorCategory: .fish, selectedFishID: nil, showsActiveFish: .constant(page == 1), category: .constant(nil),
                        addDecoration: { _ in }, selectPlacement: { _ in }, addFish: { _ in }, storeFish: { _ in },
                        selectFish: { _ in }, close: {}, selectBackground: { _ in }))
                } else if page == 2 {
                    root = AnyView(NavigationStack { BookView() }.modelContainer(container))
                } else if page == 3 {
                    root = AnyView(NavigationStack { FishDetailView(species: .orca, player: player) })
                } else {
                    root = AnyView(FishRewardView(result: .init(fish: fish[0], previousOwnedCount: 0, currentOwnedCount: 1),
                        sequence: .init(startsAutomatically: true, onPresentationFinished: { rewardCompletion.finished = true }, onAdvance: {})))
                }
                let size = CGSize(width: width, height: 852), host = UIHostingController(rootView: root)
                let window = UIWindow(windowScene: scene); window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = host; window.makeKeyAndVisible()
                host.view.layoutIfNeeded(); try await Task.sleep(for: .milliseconds(100))
                if page == 4 {
                    for _ in 0..<160 where !rewardCompletion.finished { try await Task.sleep(for: .milliseconds(50)) }
                    #expect(rewardCompletion.finished)
                }
                if page == 2 {
                    func bottom(_ view: UIView) {
                        if let scroll = view as? UIScrollView, scroll.contentSize.height > scroll.bounds.height {
                            scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height
                                + scroll.adjustedContentInset.bottom)), animated: false)
                        }
                        for child in view.subviews { bottom(child) }
                    }
                    bottom(host.view); try await Task.sleep(for: .milliseconds(80))
                }
                host.view.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                shots.append(UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                })
                window.isHidden = true
            }
        }
        let sheet = try render(VStack {
            ForEach(0..<2) { row in HStack {
                ForEach(0..<5) { col in Image(uiImage: shots[row * 5 + col]).resizable().frame(width: 196.5, height: 426) }
            } }
        }.padding().background(.white), scale: 1)
        try #require(sheet.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/OrcaActualCatalog.png"))
    }
}

@MainActor
private final class OrcaRewardCompletion { var finished = false }
@MainActor
private final class OrcaRenderProbe: ObservableObject {
    @Published var date = Date(timeIntervalSince1970: 100)
}
private struct OrcaRenderHost: View {
    let id: UUID
    let session: AquariumFishViewingSession
    @ObservedObject var probe: OrcaRenderProbe
    let size: CGSize
    var body: some View {
        ZStack {
            AquariumBackground(theme: .aquarium)
            SwimmingFishView(fishID: id, viewingSession: session, species: .orca, backgroundTheme: .aquarium,
                isFavorite: false, aquariumSize: size, updateDate: probe.date, isSimulationPaused: false,
                isSelectionEnabled: false, isSelected: false, neighborPositions: .empty, reportPosition: { _ in }, select: {})
        }.frame(width: size.width, height: size.height).ignoresSafeArea().environment(\.scenePhase, .active)
    }
}
