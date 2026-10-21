import SwiftUI
import Combine
import SwiftData
import UIKit
import Testing
@testable import PomodoroAquarium

@MainActor
struct MandarinfishStartupTests {
    @Test(arguments: [false, true]) func coldAquariumViewFirstHoverUsesRealGeometry(zeroFirst: Bool) async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let fish = (1...5).map { PlayerFish(id: UUID(uuidString: String(format: "A4DAF15A-6A60-4A60-8A60-%012d", $0))!, species: .mandarinfish) }
        let player = Player(ownedFish: fish, activeAquariumFishIDs: fish.map(\.id), hasInitializedActiveAquariumFish: true)
        container.mainContext.insert(player)
        let session = AquariumFishViewingSession(id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!)
        let size = CGSize(width: 393, height: 746)
        let probe = MandarinStartupProbe(size: zeroFirst ? .zero : size)
        let host = UIHostingController(rootView: MandarinStartupHost(player: player, session: session, probe: probe)
            .environment(\.scenePhase, .active).modelContainer(container))
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        host.view.layoutIfNeeded()
        if zeroFirst {
            probe.size = size
            host.view.setNeedsLayout(); host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
            host.view.layoutIfNeeded()
        }
        var records: [[String: Any]] = []
        for item in fish {
            let snapshot = try #require(session.snapshot(for: item.id))
            let action = try #require(snapshot.motion.stationKeeping)
            let actualSize = try #require(probe.canvasSize)
            let distance = hypot((action.target.x - action.start.x) * actualSize.width,
                (action.target.y - action.start.y) * actualSize.height)
            records.append(["id":item.id.uuidString,"size": "\(action.aquariumSize)","distance":distance])
            #expect(action.aquariumSize == probe.canvasSize)
            #expect(distance <= AquariumFishSizing.displaySize(for: .mandarinfish, isFavorite: false)
                * AquariumMandarinfishMotion.visibleLengthRatio * AquariumMandarinfishMotion.correctionBodyLengths.upperBound + 0.001)
        }
        try JSONSerialization.data(withJSONObject: records, options: .prettyPrinted)
            .write(to: URL(fileURLWithPath: "/private/tmp/MandarinColdViewGeometry-\(zeroFirst).json"))
    }
}

@MainActor
private final class MandarinStartupProbe: ObservableObject {
    @Published var size: CGSize
    var canvasSize: CGSize?
    init(size: CGSize) { self.size = size }
}
private struct MandarinStartupHost: View {
    let player: Player
    let session: AquariumFishViewingSession
    @ObservedObject var probe: MandarinStartupProbe
    var body: some View {
        AquariumView(player: player, fishViewingSessionOverride: session,
            onCanvasGeometryChanged: { probe.canvasSize = $0.size },
            isTreasureTapEnabled: false, editingPlacements: [])
            .frame(width: probe.size.width, height: probe.size.height)
    }
}
