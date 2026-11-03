import Foundation
import CoreGraphics
import Testing
@testable import PomodoroAquarium

@MainActor
struct StartSurfaceTests {
    @Test func adoptedLayoutKeepsTheMouthAlignedAndTheButtonInsideTheCanvas() {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 768, height: 1024), CGSize(width: 1366, height: 1024)] {
            let layout = StartSurfaceLayout(size: size)
            let fish = layout.rect(StartSurfaceLayout.fishRect)
            let mouthY = fish.minY + 204 * (146.0 / 629) * layout.scale
            let lastMCenterY = layout.origin.y + 956.5 * layout.scale
            #expect(abs(mouthY - lastMCenterY) < 0.000001)
            let mouthX = fish.minX + (629 - 622.5) * (146.0 / 629) * layout.scale
            #expect(abs(mouthX - (layout.origin.x + 654 * layout.scale)) < 0.000001)
            let button = layout.rect(StartSurfaceLayout.buttonRect)
            #expect(button.minX > 0 && button.maxX < size.width)
            #expect(button.minY > 44 && button.maxY < size.height - 34)
            #expect(fish.maxX < size.width)
        }
    }

    @Test func clockDoesNotAdvanceWhileHiddenOrAddTheBackgroundInterval() {
        var clock = StartSurfaceClock()
        #expect(clock.advance(at: 10) == 0)
        clock.setRunning(true)
        #expect(clock.advance(at: 20) == 0)
        #expect(clock.advance(at: 23) == 3)
        clock.setRunning(false)
        #expect(clock.advance(at: 1000) == 3)
        clock.setRunning(true)
        #expect(clock.advance(at: 2000) == 3)
        #expect(clock.advance(at: 2001) == 4)
        #expect(clock.advance(at: 2177) == 0)
    }
}
