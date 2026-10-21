import SwiftUI
import SwiftData
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct DolphinCatalogLayoutTests {
    private func image(_ species: FishSpecies, canvas: CGSize, viewport: CGSize, frame: Int? = nil) throws -> UIImage {
        let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: frame)
            .frame(width: canvas.width, height: canvas.height)
            .frame(width: viewport.width, height: viewport.height).clipped())
        renderer.scale = 3
        return try #require(renderer.uiImage)
    }

    private func alphaBounds(_ image: UIImage) throws -> CGRect {
        let cg = try #require(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        pixels.withUnsafeMutableBytes {
            let context = CGContext(data: $0.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        }
        var minX = cg.width, minY = cg.height, maxX = -1, maxY = -1
        for y in 0..<cg.height { for x in 0..<cg.width where pixels[(y * cg.width + x) * 4 + 3] > 16 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        try #require(maxX >= minX && maxY >= minY)
        let scale = image.scale
        let bounds = CGRect(x: CGFloat(minX) / scale, y: CGFloat(minY) / scale,
            width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
        #expect(bounds.minX > 0 && bounds.minY > 0 && bounds.maxX < image.size.width && bounds.maxY < image.size.height)
        return bounds
    }

    @Test func visibleLengthsMatchLargeFishAndKeepTheEntireArtworkInsideEachViewport() throws {
        var records: [[String: Any]] = []
        var comparisons: [UIImage] = []
        for placed in [false, true] {
            let viewport = placed ? CGSize(width: 60, height: 50) : AquariumEditorFishThumbnailLayout.viewport
            let factor: CGFloat = placed ? 0.52 : 1
            let oldCanvas = 46 / FishDetailImageLayout.visibleContentRatio(for: .dolphin).width * factor
            let before = try image(.dolphin, canvas: CGSize(width: oldCanvas, height: oldCanvas), viewport: viewport)
            let after = try image(.dolphin, canvas: AquariumEditorFishThumbnailLayout.imageSize(for: .dolphin, isPlacedList: placed), viewport: viewport)
            let tuna = try image(.manta, canvas: AquariumEditorFishThumbnailLayout.imageSize(for: .manta, isPlacedList: placed), viewport: viewport)
            let oldWidth = try alphaBounds(before).width, width = try alphaBounds(after).width, tunaWidth = try alphaBounds(tuna).width
            #expect(width > oldWidth * 1.5 && abs(width / tunaWidth - 1) < 0.02)
            records.append(["context": placed ? "editorPlaced" : "editorAdd", "before": oldWidth, "after": width, "tuna": tunaWidth])
            comparisons += [before, after, tuna]
        }
        let bookViewport = BookFishThumbnailLayout.frameSize
        let bookBefore = try image(.dolphin, canvas: bookViewport, viewport: bookViewport)
        let bookAfter = try image(.dolphin, canvas: BookFishThumbnailLayout.imageSize(for: .dolphin), viewport: bookViewport)
        let bookTuna = try image(.manta, canvas: BookFishThumbnailLayout.imageSize(for: .manta), viewport: bookViewport)
        let oldBookWidth = try alphaBounds(bookBefore).width, bookWidth = try alphaBounds(bookAfter).width, tunaBookWidth = try alphaBounds(bookTuna).width
        #expect(bookWidth > oldBookWidth && (0.9...1.25).contains(bookWidth / tunaBookWidth))
        records.append(["context": "bookList", "before": oldBookWidth, "after": bookWidth, "tuna": tunaBookWidth])
        comparisons += [bookBefore, bookAfter, bookTuna]
        for width: CGFloat in [320, 393, 768] {
            let viewport = CGSize(width: width, height: FishDetailImageLayout.cardHeight)
            let available = FishDetailImageLayout.availableSize(in: viewport)
            let oldSide = FishDetailImageLayout.displaySize(for: .dolphin, availableSize: available)
            let side = FishDetailImageLayout.catalogDisplaySize(for: .dolphin, availableSize: available)
            let tunaSide = FishDetailImageLayout.catalogDisplaySize(for: .manta, availableSize: available)
            let before = try image(.dolphin, canvas: CGSize(width: oldSide, height: oldSide), viewport: viewport)
            let after = try image(.dolphin, canvas: CGSize(width: side, height: side), viewport: viewport)
            let tuna = try image(.manta, canvas: CGSize(width: tunaSide, height: tunaSide), viewport: viewport)
            let oldWidth = try alphaBounds(before).width, newWidth = try alphaBounds(after).width, tunaWidth = try alphaBounds(tuna).width
            #expect(newWidth > oldWidth && abs(newWidth / tunaWidth - 1) < 0.02)
            for frame in 0..<9 {
                _ = try alphaBounds(image(.dolphin, canvas: CGSize(width: side, height: side), viewport: viewport, frame: frame))
            }
            records.append(["context": "detail\(Int(width))", "before": oldWidth, "after": newWidth, "tuna": tunaWidth])
            if width == 320 { comparisons += [before, after, tuna] }
        }
        try JSONSerialization.data(withJSONObject: records, options: .prettyPrinted)
            .write(to: URL(fileURLWithPath: "/private/tmp/DolphinCatalogVisibleLengths.json"))
        let titles = ["Editor add", "Editor placed", "Book list", "Book detail"]
        let renderer = ImageRenderer(content: VStack {
            Text("Before / After / Bluefin tuna (same viewport per row)")
            ForEach(0..<4) { row in
                HStack {
                    Text(titles[row]).frame(width: 105)
                    ForEach(0..<3) { col in
                        Image(uiImage: comparisons[row * 3 + col]).frame(width: 340, height: row == 3 ? 240 : 100)
                    }
                }
            }
        }.padding().background(.white))
        renderer.scale = 1
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/DolphinCatalogComparison.png"))
    }

    @Test func catalogOverridesDoNotChangeAquariumRewardsOrOtherSpecies() {
        #expect(FishSpecies.dolphin.displayScale == 0.80)
        #expect(abs(AquariumFishSizing.displaySize(for: .dolphin, isFavorite: false) - 186.9305134619731) < 0.000001)
        for width: CGFloat in [320, 393, 768] {
            let available = FishDetailImageLayout.availableSize(in: CGSize(width: width, height: 240))
            for species in FishSpecies.allCases where species != .dolphin {
                #expect(FishDetailImageLayout.catalogDisplaySize(for: species, availableSize: available)
                    == FishDetailImageLayout.displaySize(for: species, availableSize: available))
            }
        }
        let rewardSide = FishRewardImageLayout.detailDisplaySize(for: .dolphin, stageSize: CGSize(width: 320, height: 270))
        #expect(abs(rewardSide - 111.72) < 0.01)
        #expect(abs(FishRewardImageLayout.displaySize(from: rewardSide) - 98.31) < 0.01)
    }

    @Test func actualEditorListsBookListAndDetailFitOnSmallAndStandardScreens() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let fish = [FishSpecies.manta, .dolphin].map { PlayerFish(species: $0) }
        let reserves = [FishSpecies.manta, .dolphin].map { PlayerFish(species: $0) }
        let player = Player(ownedFish: fish + reserves, activeAquariumFishIDs: fish.map(\.id), hasInitializedActiveAquariumFish: true)
        container.mainContext.insert(player)
        try container.mainContext.save()
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
                    root = AnyView(NavigationStack { FishDetailView(species: .dolphin, player: player) })
                }
                let size = CGSize(width: width, height: 852)
                let host = UIHostingController(rootView: root)
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(origin: .zero, size: size)
                window.rootViewController = host
                window.makeKeyAndVisible()
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
                host.view.layoutIfNeeded()
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                var drawn = false
                let shot = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    drawn = host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
                }
                #expect(drawn)
                screenshots.append(shot)
                try #require(shot.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/DolphinCatalog-\(Int(width))-\(page).png"))
                window.isHidden = true
            }
        }
        let renderer = ImageRenderer(content: VStack {
            ForEach(0..<2) { row in
                HStack {
                    ForEach(0..<4) { col in
                        Image(uiImage: screenshots[row * 4 + col]).resizable().frame(width: 196.5, height: 426)
                    }
                }
            }
        }.padding().background(.white))
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/DolphinCatalogActualScreens.png"))
    }
}
