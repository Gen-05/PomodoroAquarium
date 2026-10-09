import CoreGraphics
import SwiftUI
import UIKit
import SwiftData
import Testing
@testable import PomodoroAquarium

@MainActor
struct AquariumFishEditingTests {
    private func player() -> Player {
        Player(ownedFish: (0..<5).map { _ in PlayerFish(species: .clownfish) }, activeAquariumFishIDs: [], hasInitializedActiveAquariumFish: true)
    }

    @Test func aquariumSizesRemainIndependentOfCardsAndOrdered() {
        let small = AquariumFishSizing.displaySize(for: .clownfish, isFavorite: false)
        let manta = AquariumFishSizing.displaySize(for: .manta, isFavorite: false)
        let whale = AquariumFishSizing.displaySize(for: .whaleShark, isFavorite: false)
        #expect(small < manta && manta < whale && whale == 468)
        for species in FishSpecies.allCases {
            #expect(AquariumFishSizing.displaySize(for: species, isFavorite: true) == AquariumFishSizing.displaySize(for: species, isFavorite: false))
        }
    }

    @Test func renderedFishHaveTheExpectedVisibleSizes() throws {
        var visibleLengths: [FishSpecies: CGFloat] = [:]
        for species in FishSpecies.allCases {
            let size = AquariumFishSizing.displaySize(for: species, isFavorite: false)
            let renderer = ImageRenderer(content: FishImageView(species: species, fixedAnimationFrameIndex: 0)
                .frame(width: size, height: size))
            renderer.scale = 1
            let image = try #require(renderer.uiImage?.cgImage)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            pixels.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            var minX = image.width, minY = image.height, maxX = -1, maxY = -1
            for y in 0..<image.height { for x in 0..<image.width where pixels[(y * image.width + x) * 4 + 3] > 16 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            } }
            let length = CGFloat(max(maxX - minX + 1, maxY - minY + 1))
            visibleLengths[species] = length
            #expect(length > 0 && length <= ceil(size) + 1)
            #expect(size == 78 * species.displayScale)
            print("Fish rendered size", species.rawValue, "canvas", size, "visible", length)
        }
        let sizes = Dictionary(uniqueKeysWithValues: FishSpecies.allCases.map { species in
            (species.rawValue, ["canvas": Double(AquariumFishSizing.displaySize(for: species, isFavorite: false)),
                                "visible": Double(visibleLengths[species]!)])
        })
        try JSONSerialization.data(withJSONObject: sizes, options: [.prettyPrinted, .sortedKeys])
            .write(to: URL(fileURLWithPath: "/private/tmp/PomodoroFishSizes.json"))
        #expect(visibleLengths[.whaleShark]! > visibleLengths[.manta]!)
        #expect(visibleLengths[.manta]! > visibleLengths[.clownfish]!)
        let comparison = ImageRenderer(content: VStack(spacing: 0) {
            ForEach([FishSpecies.clownfish, .manta, .whaleShark], id: \.self) { species in
                HStack {
                    Text(species.name).font(.caption).foregroundStyle(.white).frame(width: 80)
                    FishImageView(species: species, fixedAnimationFrameIndex: 0)
                        .frame(width: AquariumFishSizing.displaySize(for: species, isFavorite: false),
                               height: AquariumFishSizing.displaySize(for: species, isFavorite: false))
                        .modifier(AquariumFishColorCorrection.correction(for: .aquarium, species: species))
                    Spacer(minLength: 0)
                }.frame(width: 640, height: 160)
            }
        }.background { Image("basic_ocean_00").resizable().scaledToFill().frame(width: 640, height: 480).clipped() })
        comparison.scale = 2
        try #require(comparison.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/PomodoroFishSizeComparison.png"))
    }

    @Test func editorThumbnailsKeepSpeciesOrderWithoutChangingAquariumSizes() {
        for species in FishSpecies.allCases {
            let card = AquariumEditorFishThumbnailLayout.imageSize(for: species)
            let row = AquariumEditorFishThumbnailLayout.imageSize(for: species, isPlacedList: true)
            #expect(card.width <= 112 && card.height <= 112)
            #expect(row.width <= 60)
            #expect(abs(row.width / card.width - 0.52) < 0.0001)
            #expect(AquariumFishSizing.displaySize(for: species, isFavorite: false) == 78 * species.displayScale)
        }
        #expect(AquariumEditorFishThumbnailLayout.imageSize(for: .whaleShark).width > AquariumEditorFishThumbnailLayout.imageSize(for: .manta).width)
        #expect(AquariumEditorFishThumbnailLayout.imageSize(for: .manta).width > AquariumEditorFishThumbnailLayout.imageSize(for: .clownfish).width)
    }

    @Test func thumbnailComparisonUsesRealCardImages() throws {
        let renderer = ImageRenderer(content: HStack(spacing: 12) {
            ForEach([FishSpecies.clownfish, .manta, .whaleShark], id: \.self) { species in
                VStack {
                    let size = AquariumEditorFishThumbnailLayout.imageSize(for: species)
                    FishImageView(species: species).frame(width: size.width, height: size.height)
                        .frame(width: 112, height: 86)
                    Text(species.name).font(.caption)
                }.padding(12).background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 16))
            }
        }.padding(12).background(Color.cyan.opacity(0.2)))
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/PomodoroFishCardComparison.png"))
    }

    @Test func alphaHitShapePreservesVerticalOrientationAndTransparentHoles() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 60, y: 10, width: 25, height: 20))
        }
        let path = AquariumFishHitTesting.path(image: image, canvasSize: 100, fishSize: 100)
        #expect(path.contains(CGPoint(x: 70, y: 20)))
        #expect(!path.contains(CGPoint(x: 70, y: 80)))
        #expect(!path.contains(CGPoint(x: 20, y: 20)))
    }

    @Test func whaleHitShapeExcludesTransparentSpaceAndFollowsFlip() throws {
        let image = try #require(UIImage(named: "fish_whale_shark_side_1"))
        let path = AquariumFishHitTesting.path(image: image, canvasSize: 488, fishSize: 468)
        #expect(path.contains(CGPoint(x: 244, y: 244)))
        #expect(!path.contains(CGPoint(x: 244, y: 40)))
        #expect(!path.contains(CGPoint(x: 10, y: 10)))
        let flipped = AquariumFishHitTesting.path(image: image, canvasSize: 488, fishSize: 468, horizontalScale: -1)
        for point in [CGPoint(x: 90, y: 244), CGPoint(x: 150, y: 220), CGPoint(x: 420, y: 244)] {
            #expect(path.contains(point) == flipped.contains(CGPoint(x: 488 - point.x, y: point.y)))
        }
    }

    @Test(arguments: FishSpecies.allCases)
    func allSpeciesDropUsesTheExistingRoamingBounds(species: FishSpecies) {
        let player = Player(ownedFish: [PlayerFish(species: species)], activeAquariumFishIDs: [], hasInitializedActiveAquariumFish: true)
        let canvas = CGRect(x: 0, y: 0, width: 393, height: 852)
        let dropped = AquariumFishEditing.drop(species: species, location: CGPoint(x: 1, y: 851), canvas: canvas, player: player)
        #expect(dropped != nil)
        let bounds = AquariumFishMotion.movementProfile(for: species).roamingStyle.bounds(in: canvas.size,
            fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: false))
        if let dropped {
            #expect(bounds.horizontal.contains(dropped.position.x) && bounds.vertical.contains(dropped.position.y))
            #expect(player.activeAquariumFishIDs == [dropped.id])
        }
    }

    @Test func dragCoordinatesCancelAndDuplicateLimit() {
        let player = player()
        let canvas = CGRect(x: 10, y: -20, width: 393, height: 852)
        #expect(AquariumFishEditing.drop(species: .clownfish, location: CGPoint(x: -10, y: 200), canvas: canvas, player: player) == nil)
        #expect(player.activeAquariumFish.isEmpty)
        let location = CGPoint(x: canvas.midX, y: canvas.minY + canvas.height * 0.4)
        for _ in 0..<5 {
            let dropped = AquariumFishEditing.drop(species: .clownfish, location: location, canvas: canvas, player: player)
            #expect(dropped != nil)
            #expect(abs((dropped?.position.x ?? 0) - 0.5) < 0.000_001)
            #expect(abs((dropped?.position.y ?? 0) - 0.4) < 0.000_001)
        }
        #expect(AquariumFishEditing.drop(species: .clownfish, location: location, canvas: canvas, player: player) == nil)
        #expect(AquariumFishEditing.counts(.clownfish, player: player) == AquariumFishInventoryCount(owned: 5, active: 5))
        #expect(Set(player.activeAquariumFishIDs).count == 5)
    }

    @Test func directAndListStorageShareIDsCountsAndPersistentOwnership() throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let player = player()
        context.insert(player)
        for fish in player.ownedFish.prefix(3) { #expect(player.addFishToAquarium(playerFishID: fish.id)) }
        let ids = player.activeAquariumFishIDs
        #expect(AquariumFishEditing.store(id: ids[0], player: player))
        #expect(!AquariumFishEditing.store(id: ids[0], player: player))
        #expect(AquariumFishEditing.counts(.clownfish, player: player).available == 3)
        #expect(AquariumFishEditing.store(id: ids[1], player: player))
        #expect(player.activeAquariumFishIDs == [ids[2]])
        #expect(player.ownedFish.count == 5)
        try context.save()
        let restored = try #require(ModelContext(container).fetch(FetchDescriptor<Player>()).first)
        #expect(restored.ownedFish.count == 5)
        #expect(restored.activeAquariumFishIDs == [ids[2]])
        #expect(AquariumFishEditing.counts(.clownfish, player: restored).available == 4)
    }
}
