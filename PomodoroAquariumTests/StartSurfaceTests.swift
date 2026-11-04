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
            let sharedMouth = layout.point(StartSurfaceLayout.fishMouth)
            #expect(abs(sharedMouth.x - mouthX) < 0.000001)
            #expect(abs(sharedMouth.y - mouthY) < 0.000001)
            let dot = layout.point(StartSurfaceLayout.iDotCenter)
            #expect(dot.x < sharedMouth.x && dot.y < sharedMouth.y)
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
        var bubbles = StartSurfaceClock(period: StartTitleBubblePresentation.duration, repeats: false)
        bubbles.setRunning(true)
        _ = bubbles.advance(at: 0)
        #expect(bubbles.advance(at: 1.9) == 1.9)
        bubbles.setRunning(false)
        #expect(bubbles.advance(at: 1000) == 1.9)
        bubbles.setRunning(true)
        #expect(bubbles.advance(at: 2000) == 1.9) // 復帰では最初から再生しない。
        #expect(bubbles.advance(at: 2100) == StartTitleBubblePresentation.duration)
        #expect(!bubbles.isRunning)
        bubbles.setRunning(true)
        #expect(!bubbles.isRunning) // 完成後も復帰で再演出しない。
        #expect(bubbles.advance(at: 3000) == StartTitleBubblePresentation.duration)
        let reopened = StartSurfaceClock(period: StartTitleBubblePresentation.duration, repeats: false)
        #expect(reopened.elapsed == 0) // 新しいPreviewのCoordinatorは新しい時計を持つ。
        var reducedMotion = reopened
        reducedMotion.finish()
        reducedMotion.setRunning(true)
        #expect(!reducedMotion.isRunning)
        #expect(reducedMotion.elapsed == StartTitleBubblePresentation.duration)
    }

    @Test func bubblePlaybackFinishesAndKeepsTheIndependentDot() {
        let start = StartTitleBubblePresentation.particle(0, at: 0.45)
        #expect(start.center == StartSurfaceLayout.fishMouth)
        #expect(start.opacity == 0)
        let moving = StartTitleBubblePresentation.particle(0, at: 1.9)
        #expect(moving.opacity > 0)
        #expect(moving.center.x < StartSurfaceLayout.fishMouth.x)
        #expect(moving.center.y < StartSurfaceLayout.fishMouth.y)
        let following = StartTitleBubblePresentation.particle(1, at: 1.9)
        #expect(following.center.x > moving.center.x)
        let formed = StartTitleBubblePresentation.particle(3, at: 4.5)
        #expect(formed.center == StartSurfaceLayout.iDotCenter)
        #expect(formed.radius == StartSurfaceLayout.iDotRadius)
        #expect(formed.opacity == 1)
        for time in [StartTitleBubblePresentation.duration, 6.5, 180, 10000] {
            let held = StartTitleBubblePresentation.particle(3, at: time)
            #expect(held.center == formed.center)
            #expect(held.opacity == 1 && held.radius == formed.radius)
            for index in 0..<3 {
                #expect(StartTitleBubblePresentation.particle(index, at: time).opacity == 0)
            }
        }
        for index in 0..<3 {
            #expect(StartTitleBubblePresentation.particle(index, at: 4.5).opacity == 0)
            #expect(StartTitleBubblePresentation.particle(index, at: 1.9, completed: true).opacity == 0)
        }
        let still = StartTitleBubblePresentation.particle(3, at: 0, completed: true)
        #expect(still.center == formed.center)
        #expect(still.radius == formed.radius && still.opacity == 1)
    }

}
