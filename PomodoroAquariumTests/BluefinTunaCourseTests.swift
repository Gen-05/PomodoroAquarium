import SwiftUI
import CoreGraphics
import Foundation
import Testing
@testable import PomodoroAquarium

@MainActor
struct BluefinTunaCourseTests {
    private let id = UUID(uuidString: "B10F17A0-6A60-4A60-8A60-000000000001")!
    private let openBounds = FishRoamingBounds(horizontal: -10...10, vertical: -10...10,
                                              horizontalWallMargin: 0.3, verticalWallMargin: 0.3)

    @Test func levelCruisingKeepsExactHeightAndCurrentHorizontalSpeed() {
        var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
            roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.5))
        state.bluefinCruise?.direction = 1
        state.bluefinCruise?.levelTimeRemaining = 100
        for tick in 1...180 {
            let start = state.position
            state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            #expect(state.position.y == start.y)
            let expected = state.currentSpeed * state.depthSpeedMultiplier * 6.76 * AquariumFishMotion.largeFishMovementSpeedMultiplier / 30
            #expect(abs(state.position.x - start.x - expected) < 0.00000001)
        }
        for profile in [FishMovementProfile.clownfish, .seaTurtle, .dolphin] {
            let other = AquariumFishMotion.initialState(for: id, profile: profile)
            #expect(other.bluefinCruise == nil)
            #expect(other.translationVelocity == CGVector(dx: other.velocity.dx * other.movementProfile.movementSpeedMultiplier,
                                                         dy: other.velocity.dy * other.movementProfile.movementSpeedMultiplier))
        }
    }

    @Test func actualCoordinatesShowLevelSlowHeightChangeThenLevelAcrossSizesAndTurns() throws {
        var records: [[String: Any]] = []
        var plot: [CGPoint] = []
        var maximumSpeed: CGFloat = 0
        var turnMaximumSpeed: CGFloat = 0
        var changingDuringTurn = 0
        var maximumTurningSpeed: CGFloat = 0
        var longestStoppedTime = 0.0
        var turnDurations: [Double] = []
        var switches = 0
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let side = AquariumFishSizing.displaySize(for: .manta, isFavorite: false)
            let bounds = FishMovementProfile.bluefinTuna.roamingStyle.bounds(in: size, fishSize: side)
            for individual in 1...5 {
                let fishID = UUID(uuidString: String(format: "B10F17A0-6A60-4A60-8A60-%012d", individual))!
                var state = AquariumFishMotion.initialState(for: fishID, profile: .bluefinTuna,
                    roamingBounds: bounds, initialPosition: CGPoint(x: 0.5, y: 0.5), aquariumSize: size)
                var began: (time: Double, y: CGFloat)?
                var completed = 0, turnTicks = 0
                var levelPasses = 0
                var expectedPasses = try #require(state.bluefinCruise?.levelCrossingsRemaining)
                var directions: Set<Int> = []
                var turnBegan: Double?
                var turnBeganWhileLevel = false
                var lastHeightEnd: Double?
                var measuredLevel = 0.0
                var stoppedTime = 0.0
                var turningBeganAt: Double?
                for tick in 1...1350 {
                    let time = Double(tick) / 30
                    let previous = state.position
                    let wasChanging = state.bluefinCruise?.heightTarget != nil
                    let wasTurning = state.bluefinCruise?.turnElapsed != nil
                    let oldPhase = state.bluefinCruise?.turnPhase
                    let previousSign = state.facingSign
                    state.advance(deltaTime: 1.0 / 30, elapsedTime: time)
                    let changing = state.bluefinCruise?.heightTarget != nil
                    let turning = state.bluefinCruise?.turnElapsed != nil
                    if !wasTurning && turning {
                        turnBegan = time - 1.0 / 30
                        turnBeganWhileLevel = !wasChanging
                    }
                    if wasTurning && !turning {
                        let start = try #require(turnBegan)
                        #expect(time - start >= AquariumFishMotion.BluefinTunaCruise.turnDuration)
                        #expect(time - start <= AquariumFishMotion.BluefinTunaCruise.turnDuration
                            + AquariumFishMotion.BluefinTunaCruise.brakingDuration
                            + AquariumFishMotion.BluefinTunaCruise.accelerationDuration + 0.15)
                        if !wasChanging && turnBeganWhileLevel { levelPasses += 1 }
                    }
                    let displacement = state.position.x - previous.x
                    let xSpeed = abs(displacement) * size.width * 30
                    #expect(abs(state.facingHorizontalScale) == 1 && state.facingWidth == 1)
                    #expect(state.visualTurnTargetSign == nil)
                    if state.facingSign != previousSign {
                        switches += 1
                        #expect(oldPhase == .turning && xSpeed < 0.00001)
                    }
                    if oldPhase != .turning && state.bluefinCruise?.turnPhase == .turning {
                        turningBeganAt = time
                    }
                    if oldPhase == .turning {
                        maximumTurningSpeed = max(maximumTurningSpeed, xSpeed)
                        #expect(xSpeed <= AquariumFishMotion.BluefinTunaCruise.turningSpeed * AquariumFishMotion.largeFishMovementSpeedMultiplier + 0.00001)
                        if xSpeed < 0.00001 { stoppedTime += 1.0 / 30 } else { stoppedTime = 0 }
                        longestStoppedTime = max(longestStoppedTime, stoppedTime)
                        #expect(stoppedTime <= 2.0 / 30 + 0.00001)
                    }
                    if oldPhase == .turning && state.bluefinCruise?.turnPhase == .accelerating {
                        turnDurations.append(time - (try #require(turningBeganAt)))
                        #expect(previousSign == state.facingSign)
                        #expect((state.bluefinCruise!.direction > 0 ? -1.0 : 1.0) == previousSign)
                    }
                    if abs(displacement) > 0.00000001 {
                        #expect((displacement > 0 ? 1.0 : -1.0) * state.facingHorizontalScale > 0)
                    }
                    let verticalSpeed = abs(state.position.y - previous.y) * size.height * 30
                    maximumSpeed = max(maximumSpeed, verticalSpeed)
                    #expect(verticalSpeed <= 10 * AquariumFishMotion.largeFishMovementSpeedMultiplier + 0.00001)
                    #expect(bounds.horizontal.contains(state.position.x) && bounds.vertical.contains(state.position.y))
                    if !wasChanging && !changing { #expect(state.position.y == previous.y) }
                    #expect(abs(state.position.x - previous.x - state.translationVelocity.dx * state.depthSpeedMultiplier / 30) < 0.00000001)
                    if state.bluefinCruise?.turnElapsed != nil {
                        turnTicks += 1
                        turnMaximumSpeed = max(turnMaximumSpeed, verticalSpeed)
                        if changing { changingDuringTurn += 1 }
                    }
                    if !wasChanging && changing {
                        began = (time - 1.0 / 30, previous.y)
                        #expect(levelPasses == expectedPasses && (1...2).contains(levelPasses))
                        if let end = lastHeightEnd {
                            measuredLevel = time - 1.0 / 30 - end
                            #expect(measuredLevel >= 0.95)
                        }
                    }
                    if wasChanging && !changing {
                        let start = try #require(began)
                        let distance = abs(state.position.y - start.y) * size.height
                        let duration = time - start.time
                        #expect(distance >= 39.99 && distance <= 60.01)
                        #expect(duration >= 5 / Double(AquariumFishMotion.largeFishMovementSpeedMultiplier) - 0.01
                            && duration <= 8 / Double(AquariumFishMotion.largeFishMovementSpeedMultiplier) + 0.05)
                        directions.insert(state.position.y > start.y ? 1 : -1)
                        records.append(["width": size.width, "height": size.height, "individual": individual,
                            "distancePoints": distance, "signedDistancePoints": (state.position.y - start.y) * size.height,
                            "durationSeconds": duration, "levelBeforeSeconds": measuredLevel, "levelPasses": levelPasses])
                        completed += 1; lastHeightEnd = time
                        levelPasses = 0
                        expectedPasses = try #require(state.bluefinCruise?.levelCrossingsRemaining)
                    }
                    if size.width == 393 && individual == 1 { plot.append(state.position) }
                }
                #expect(completed >= 2 && turnTicks > 0 && lastHeightEnd != nil && directions.count == 2)
            }
        }
        #expect(changingDuringTurn > 0)
        try JSONSerialization.data(withJSONObject: ["heightChanges": records, "maximumVerticalPointsPerSecond": maximumSpeed,
            "maximumVerticalPointsPerSecondDuringTurns": turnMaximumSpeed, "heightChangeDuringTurnFrames": changingDuringTurn,
            "maximumTurningPointsPerSecond": maximumTurningSpeed, "longestStoppedSeconds": longestStoppedTime,
            "turnDurations": turnDurations, "facingSwitches": switches],
            options: .prettyPrinted).write(to: URL(fileURLWithPath: "/private/tmp/TunaHeightMeasurements.json"))
        let renderer = ImageRenderer(content: VStack {
            Text("Bluefin tuna / 45 seconds / actual position")
            Canvas { context, canvas in
                var path = Path()
                for (i, p) in plot.enumerated() {
                    let point = CGPoint(x: p.x * canvas.width, y: p.y * canvas.height)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(.cyan), lineWidth: 1.5)
            }.frame(width: 393, height: 852).background(.black)
            Canvas { context, canvas in
                var path = Path()
                for (i, p) in plot.enumerated() {
                    let point = CGPoint(x: CGFloat(i) / CGFloat(plot.count - 1) * canvas.width,
                        y: (p.y - 0.4) * canvas.height * 5)
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(.blue), lineWidth: 1.5)
            }.frame(width: 393, height: 160)
            Text("Height over time (vertical scale magnified 5x)")
        }.padding().background(.white))
        renderer.scale = 2
        try #require(renderer.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/TunaLevelHeightPaths.png"))
    }

    @Test func heightChangeUsesOldHorizontalPaceAndIndependentClockThenRecoversStraightSpeed() throws {
        var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
            roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.5), aquariumSize: CGSize(width: 393, height: 852))
        state.bluefinCruise?.direction = 1
        state.bluefinCruise?.heightStart = 0.5
        state.bluefinCruise?.heightTarget = 0.5 + 50.0 / 852
        state.bluefinCruise?.heightTime = 7
        state.behaviorTimeRemaining = 100; state.directionChangeTimeRemaining = 100
        state.currentSpeed = state.baseSpeed; state.targetSpeed = state.baseSpeed
        for tick in 1...330 {
            let before = state.position
            state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            #expect(abs(state.position.y - before.y) * 852 * 30 <= 10 * AquariumFishMotion.largeFishMovementSpeedMultiplier + 0.00001)
            if tick == 90 {
                let cruise = try #require(state.bluefinCruise)
                #expect(abs(cruise.heightElapsed - 3) < 0.000001)
                #expect(abs(cruise.horizontalSpeedMultiplier - 2.60) < 0.001)
            }
            if tick == 210 {
                #expect(abs(state.position.y - (0.5 + 50.0 / 852)) < 0.000001)
            }
        }
        #expect(abs(state.bluefinCruise!.horizontalSpeedMultiplier - 6.76) < 0.001)
        #expect(state.bluefinCruise?.heightTarget == nil)
        #expect(abs(state.position.y - (0.5 + 50.0 / 852)) < 0.000001)
    }

    @Test func correctionsAndResidualSteeringCannotExceedVerticalLimit() {
        var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
            roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.8), aquariumSize: CGSize(width: 393, height: 852))
        let tightened = FishRoamingBounds(horizontal: 0.25...0.75, vertical: 0.3...0.7,
            horizontalWallMargin: 0.04, verticalWallMargin: 0.06)
        state.updateRoamingBounds(tightened)
        #expect(state.position.y == 0.8) // 補正の必要があっても、その場で上下へワープさせない。
        for tick in 1...600 {
            let before = state.position
            state.velocity.dy = tick.isMultiple(of: 2) ? 10 : -10
            state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            if tick == 30 {
                let elapsed = state.bluefinCruise?.heightElapsed
                state.updateRoamingBounds(tightened)
                #expect(state.bluefinCruise?.heightElapsed == elapsed)
            }
            #expect(abs(state.position.y - before.y) * 852 * 30 <= 10 * AquariumFishMotion.largeFishMovementSpeedMultiplier + 0.00001)
        }
        #expect(tightened.vertical.contains(state.position.y))
    }

    @Test func heightAndTurnStateResumeWithoutRestartAndCancelDoesNotLeak() throws {
        let session = AquariumFishViewingSession()
        var initial = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
            roamingBounds: .legacy, initialPosition: CGPoint(x: 0.5, y: 0.5))
        initial.bluefinCruise?.levelTimeRemaining = 0
        initial.bluefinCruise?.levelCrossingsRemaining = 0
        for tick in 1...30 { initial.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30) }
        #expect(initial.bluefinCruise?.heightTarget != nil)
        let owner = UUID(), nextOwner = UUID()
        let snapshot = AquariumFishViewingSession.Snapshot(motion: initial, direction: .init(direction: initial.facingDirection))
        _ = session.claim(id, owner: owner, initial: snapshot, bounds: .legacy)
        var resumed = session.claim(id, owner: nextOwner, initial: snapshot, bounds: .legacy)
        #expect(resumed.motion.position == initial.position)
        #expect(resumed.motion.bluefinCruise?.heightElapsed == initial.bluefinCruise?.heightElapsed)
        for tick in 31...180 {
            initial.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            resumed.motion.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
            #expect(resumed.motion.position == initial.position)
            #expect(resumed.motion.bluefinCruise?.turnElapsed == initial.bluefinCruise?.turnElapsed)
        }
        #expect(!session.update(id, owner: owner, snapshot: resumed))
        session.beginEditing()
        let editing = try #require(session.editingSession)
        let editOwner = UUID()
        var edited = editing.claim(id, owner: editOwner, initial: snapshot, bounds: .legacy)
        edited.motion.bluefinCruise?.heightTarget = 0.75
        #expect(editing.update(id, owner: editOwner, snapshot: edited))
        session.finishEditing()
        #expect(session.snapshot(for: id)?.motion.bluefinCruise?.heightTarget == snapshot.motion.bluefinCruise?.heightTarget)
    }

    @Test func measureOneScreenWidthAtFixedDepthAndHorizontalCruisingSpeed() throws {
        let profile = FishMovementProfile.bluefinTuna
        let multiplier = FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier
        let width: CGFloat = 393
        var state = AquariumFishMotion.initialState(for: id, profile: profile,
            roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.5))
        state.velocity = CGVector(dx: state.baseSpeed, dy: 0)
        state.desiredDirection = CGVector(dx: 1, dy: 0)
        state.currentSpeed = state.baseSpeed
        state.targetSpeed = state.baseSpeed
        state.currentDepth = 0.5; state.targetDepth = 0.5
        state.depthChangeTimeRemaining = 100
        state.behavior = .cruising; state.behaviorTimeRemaining = 100
        state.directionChangeTimeRemaining = 100
        state.roamingDestination = CGPoint(x: 5, y: 0.5)
        state.bluefinCruise?.direction = 1
        state.bluefinCruise?.levelTimeRemaining = 100
        let pointsPerSecond = state.baseSpeed * multiplier * profile.depthSpeedMultiplier(at: 0.5) * width
        let calculated = Double(width / pointsPerSecond)
        var measured: Double?
        for tick in 1...4800 {
            let before = state.position.x
            state.advance(deltaTime: 1.0 / 240, elapsedTime: Double(tick) / 240)
            #expect(abs(state.position.y - 0.5) < 0.00000001)
            if state.position.x >= 1.5 {
                measured = (Double(tick - 1) + Double((1.5 - before) / (state.position.x - before))) / 240
                break
            }
        }
        let elapsed = try #require(measured)
        #expect(abs(elapsed - calculated) < 0.00000001)
        let result: [String: Any] = ["widthPoints": width, "depth": 0.5, "baseSpeed": state.baseSpeed,
            "horizontalMultiplier": multiplier, "pointsPerSecond": pointsPerSecond,
            "calculatedSeconds": calculated, "simulatedSeconds": elapsed]
        try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted).write(to:
            URL(fileURLWithPath: "/private/tmp/TunaWidthTiming-\(Int((multiplier * 100).rounded())).json"))
    }


    @Test func edgeStartsAndDifferentFrameRatesDoNotEscapeOrRemainStopped() throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 1024, height: 768)] {
            let bounds = FishMovementProfile.bluefinTuna.roamingStyle.bounds(in: size,
                fishSize: AquariumFishSizing.displaySize(for: .manta, isFavorite: false))
            for fps in [15, 30, 60] {
                for direction: CGFloat in [-1, 1] {
                    var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
                        roamingBounds: bounds, initialPosition: CGPoint(
                            x: direction > 0 ? bounds.horizontal.upperBound : bounds.horizontal.lowerBound, y: 0.5),
                        aquariumSize: size)
                    state.bluefinCruise?.direction = direction
                    state.bluefinCruise?.levelTimeRemaining = 100
                    state.bluefinCruise?.levelCrossingsRemaining = 100
                    state.facingSign = -direction
                    state.facingDirection = direction > 0 ? .right : .left
                    var stoppedTime = 0.0
                    var accelerated = false
                    for tick in 1...(fps * 8) {
                        let before = state.position
                        state.advance(deltaTime: 1.0 / Double(fps), elapsedTime: Double(tick) / Double(fps))
                        #expect(bounds.horizontal.contains(state.position.x) && state.position.y == before.y)
                        #expect(abs(state.position.x - before.x - state.translationVelocity.dx
                            * state.depthSpeedMultiplier / CGFloat(fps)) < 0.00000001)
                        if abs(state.position.x - before.x) < 0.00000001 { stoppedTime += 1.0 / Double(fps) }
                        else { stoppedTime = 0 }
                        // 初期位置が端ちょうどなら前進できないが、反転の時点から内側へ動き出す。
                        #expect(stoppedTime <= AquariumFishMotion.BluefinTunaCruise.facingSwitchTime + 2.0 / Double(fps))
                        if state.bluefinCruise?.turnPhase == .accelerating { accelerated = true }
                    }
                    #expect(accelerated)
                }
            }
        }
    }

    @Test func turningWaitsForDisplayedFacingAndResumesAcrossOwners() throws {
        for direction: CGFloat in [-1, 1] {
            var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
                roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.5),
                aquariumSize: CGSize(width: 393, height: 852))
            state.bluefinCruise?.direction = direction
            state.bluefinCruise?.levelTimeRemaining = 100
            state.bluefinCruise?.turnPhase = .turning
            state.bluefinCruise?.turnElapsed = 0
            state.bluefinCruise?.turnSpeed = 18.0 / 393
            // 時間だけ満了しても、直前に描画した方向が逆なら再加速を許可しない。
            state.bluefinCruise?.phaseElapsed = AquariumFishMotion.BluefinTunaCruise.turnDuration
            state.facingSign = -direction
            state.facingDirection = direction > 0 ? .right : .left
            state.advance(deltaTime: 1.0 / 30, elapsedTime: 1.0 / 30)
            #expect(state.position.x == 0.5 && state.bluefinCruise?.turnPhase == .turning)
            #expect(state.facingSign == direction && abs(state.facingHorizontalScale) == 1)
            let session = AquariumFishViewingSession(), owner = UUID(), next = UUID()
            let snapshot = AquariumFishViewingSession.Snapshot(motion: state, direction: .init(direction: state.facingDirection))
            _ = session.claim(id, owner: owner, initial: snapshot, bounds: openBounds)
            var resumed = session.claim(id, owner: next, initial: snapshot, bounds: openBounds)
            var moved = false
            for tick in 2...30 {
                let before = state.position
                state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
                resumed.motion.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30)
                #expect(resumed.motion.position == state.position)
                #expect(resumed.motion.facingHorizontalScale == state.facingHorizontalScale)
                #expect(resumed.motion.bluefinCruise?.turnPhase == state.bluefinCruise?.turnPhase)
                if state.position.x != before.x {
                    #expect((state.position.x - before.x) * direction < 0)
                    moved = true
                }
            }
            #expect(moved && !session.update(id, owner: owner, snapshot: resumed))
        }
    }

    @Test func actualFishRendererPreservesBodyShapeThroughoutBothTurns() throws {
        func render(_ scale: CGFloat) throws -> UIImage {
            let renderer = ImageRenderer(content: FishImageView(species: .manta,
                spritePose: .facing(scale > 0 ? .right : .left), facingHorizontalScale: scale,
                fixedAnimationFrameIndex: 0).frame(width: 240, height: 240))
            renderer.scale = 1
            return try #require(renderer.uiImage)
        }
        func visibleWidth(_ image: UIImage) throws -> Int {
            let cg = try #require(image.cgImage)
            var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
            let context = try #require(CGContext(data: &pixels, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            var columns: [Int] = []
            for x in 0..<cg.width {
                if (0..<cg.height).contains(where: { pixels[($0 * cg.width + x) * 4 + 3] > 20 }) { columns.append(x) }
            }
            return try #require(columns.last) - #require(columns.first) + 1
        }
        let reference = try render(1)
        let referenceWidth = try visibleWidth(reference)
        var images: [UIImage] = []
        for direction: CGFloat in [-1, 1] {
            var state = AquariumFishMotion.initialState(for: id, profile: .bluefinTuna,
                roamingBounds: openBounds, initialPosition: CGPoint(x: 0.5, y: 0.5),
                aquariumSize: CGSize(width: 393, height: 852))
            state.bluefinCruise?.direction = direction
            state.bluefinCruise?.turnPhase = .turning
            state.bluefinCruise?.turnElapsed = 0
            state.bluefinCruise?.turnSpeed = 18.0 / 393
            state.bluefinCruise?.levelTimeRemaining = 100
            state.facingSign = -direction
            state.facingDirection = direction > 0 ? .right : .left
            for tick in 0...48 {
                if tick > 0 { state.advance(deltaTime: 1.0 / 30, elapsedTime: Double(tick) / 30) }
                let image = try render(state.facingHorizontalScale)
                #expect(abs(state.facingHorizontalScale) == 1)
                #expect(try visibleWidth(image) == referenceWidth)
                if tick.isMultiple(of: 12) { images.append(image) }
            }
        }
        let comparison = ImageRenderer(content: VStack {
            Text("Rigid side sprites / no width deformation / both directions")
            ForEach(0..<2) { row in
                HStack(spacing: 0) {
                    ForEach(0..<5) { column in
                        Image(uiImage: images[row * 5 + column]).resizable().frame(width: 160, height: 160)
                    }
                }
            }
        }.padding().background(.white))
        comparison.scale = 2
        try #require(comparison.uiImage?.pngData()).write(to: URL(fileURLWithPath: "/private/tmp/TunaRigidFacingComparison.png"))
    }

    @Test func courseSettingsDoNotChangeSpeedOrOtherSpeciesProfiles() {
        let tuna = FishMovementProfile.bluefinTuna
        #expect(FishMovementProfile.bluefinTunaHorizontalSpeedMultiplier == 6.76)
        #expect(AquariumFishMotion.BluefinTunaCruise.maximumVerticalSpeed == 10)
        #expect(AquariumFishMotion.BluefinTunaCruise.turnDuration >= 1)
        #expect(AquariumFishMotion.BluefinTunaCruise.facingSwitchTime > 0
            && AquariumFishMotion.BluefinTunaCruise.facingSwitchTime < AquariumFishMotion.BluefinTunaCruise.turnDuration)
        #expect(AquariumFishMotion.BluefinTunaCruise.accelerationDuration > 0)
        #expect(tuna.directionHoldDurationRange == 16...24 && tuna.steeringNoiseMultiplier == 0)
        #expect(tuna.baseSpeedRange.lowerBound == FishMovementProfile.dolphin.baseSpeedRange.lowerBound * 2.30 * 1.20)
        #expect(tuna.baseSpeedRange.upperBound == FishMovementProfile.dolphin.baseSpeedRange.upperBound * 2.30 * 1.20)
        #expect(tuna.wallAvoidanceStrength == 5 && tuna.turnResponsivenessRange == 1.20...1.50)
        #expect(FishMovementProfile.seaTurtle.directionHoldDurationRange == 9...14)
        #expect(FishMovementProfile.dolphin.directionHoldDurationRange == 9...14)
        #expect(FishMovementProfile.seaTurtle.steeringNoiseMultiplier == 0.16)
        #expect(FishMovementProfile.dolphin.steeringNoiseMultiplier == 0.16)
    }
}
