import SwiftUI
import SwiftData
import Testing
import UIKit
@testable import PomodoroAquarium

@MainActor
struct ShopLayoutTests {
    @Test func scrollViewportStaysAboveTheActualBottomBar() async throws {
        let container = try ModelContainer(for: Player.self, PlayerFish.self, AquariumDecorationPlacement.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        container.mainContext.insert(Player(coins: 2_000))
        try container.mainContext.save()
        let probe = ShopBarProbe()
        let host = UIHostingController(rootView: ShopLayoutHost(probe: probe).modelContainer(container))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        for _ in 0..<6 {
            host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        let scroll = try #require(findScroll(in: host.view))
        let frame = scroll.convert(scroll.bounds, to: window)
        let visibleBottom = frame.maxY - scroll.adjustedContentInset.bottom
        print("SHOP LAYOUT: scroll=\(frame) safe=\(scroll.safeAreaInsets) adjusted=\(scroll.adjustedContentInset) bar=\(probe.barFrame)")
        #expect(probe.barFrame.height > 0)
        #expect(visibleBottom <= probe.barFrame.minY + 1)
        let end = max(-scroll.adjustedContentInset.top,
            scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: 0, y: end), animated: false)
        host.view.layoutIfNeeded()
        #expect(abs(scroll.contentOffset.y - end) < 1)
    }

    @Test func contentHeightDoesNotReserveTheBottomBarTwice() {
        let frame = CGRect(x: 0, y: 100, width: 402, height: 774)
        #expect(ShopContentLayout.contentHeight(frame: frame, boundary: 786) == 686)
        #expect(ShopContentLayout.contentHeight(frame: CGRect(x: 0, y: 100, width: 402, height: 686),
            boundary: 786) == 686)
        #expect(ShopContentLayout.contentHeight(frame: frame, boundary: 900) == 774)
        #expect(ShopContentLayout.contentHeight(frame: frame, boundary: nil) == 774)
    }

    @Test func decorationThumbnailsKeepTheirBaseRatioAndGroundLineWithinTheCard() {
        for width in [CGFloat(100), 150, 300] {
            let size = CGSize(width: width, height: ShopDecorationThumbnailLayout.height)
            let small = ShopDecorationThumbnailLayout.frame(for: .smallRockA, in: size)
            let medium = ShopDecorationThumbnailLayout.frame(for: .mediumRockA, in: size)
            #expect(abs(small.width / medium.width - 96.0 / 176) < 0.000_001)
            #expect(abs(small.height / medium.height - 56.0 / 77) < 0.000_001)
            let ground = small.minY + small.height * (AquariumDecorationKind.smallRockA.groundAnchorY ?? 1)
            for kind in ShopDecorationThumbnailLayout.kinds {
                let frame = ShopDecorationThumbnailLayout.frame(for: kind, in: size)
                #expect(frame.minX >= 3.999 && frame.minY >= 3.999)
                #expect(frame.maxX <= size.width - 3.999 && frame.maxY <= size.height - 3.999)
                #expect(abs(frame.minY + frame.height * (kind.groundAnchorY ?? 1) - ground) < 0.000_001)
            }
        }
    }

    private func findScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { findScroll(in: $0) }.first
    }
}

@MainActor @Observable
private final class ShopBarProbe {
    var barFrame = CGRect.zero
}

private struct ShopLayoutHost: View {
    let probe: ShopBarProbe
    var body: some View {
        TabView {
            Tab("ショップ", systemImage: "storefront.fill") {
                NavigationStack {
                    ShopView(bottomContentBoundary: probe.barFrame.isEmpty ? nil : probe.barFrame.minY)
                }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.blue.frame(height: MainTabBarHitShieldLayout.tabBarHeight)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.barFrame = $0 }
        }
    }
}
