//
//  AquariumView.swift
//  PomodoroAquarium
//

import SwiftUI
import SwiftData
import UIKit

private struct AquariumFishSelectionRevision: Equatable {
    let ownedFishIDs: [UUID]
    let activeFishIDs: [UUID]
    let isInitialized: Bool
}

struct AquariumView: View {
    let player: Player?
    var backgroundTheme: AquariumBackgroundTheme = .aquarium
    var fishSpawnPositions: [UUID: CGPoint] = [:]
    var fishAppearances: [UUID: AquariumFishAppearance] = [:]
    var onFishPositionsChanged: ([UUID: CGPoint]) -> Void = { _ in }
    var onCanvasGeometryChanged: (CGRect) -> Void = { _ in }
    var isSimulationPaused = false
    var isEditing = false
    var defersDecorationPersistence = false
    var isFishSelectionEnabled = false
    var selectedFishID: UUID?
    var onFishSelected: (UUID) -> Void = { _ in }
    var onCanvasTapped: () -> Void = {}
    var onDecorationChanged: () -> Void = {}
    var onDecorationEditingChanged: (Bool) -> Void = { _ in }
    var selectionResetRequestID: UUID?
    var decorationRestoreRequestID: String?
    var onDecorationRestoreRequestHandled: () -> Void = {}
    var decorationDragPreview: AquariumDecoration?

    @Environment(\.modelContext) private var modelContext
    @Query private var officialDecorationPlacements: [AquariumDecorationPlacement]
    var editingPlacements: [AquariumDecorationPlacement]?
    private var decorationPlacements: [AquariumDecorationPlacement] { editingPlacements ?? officialDecorationPlacements }
    @State private var editingDecorationID: String?
    @State private var showsDecorationNudge = false
    @State private var draggingDecorationID: String?
    @State private var canvasDragStart: CGPoint?
    @State private var canvasGestureStarted = false
    @State private var originalPosition: CGPoint?
    @State private var previewPosition: CGPoint?
    @State private var fishPositions: [UUID: CGPoint] = [:]
    @State private var displayedFish: [PlayerFish] = []

    private var displayedFishIDs: [UUID] {
        displayedFish.map(\.id)
    }

    private var fishSelectionRevision: AquariumFishSelectionRevision {
        AquariumFishSelectionRevision(
            ownedFishIDs: player?.ownedFish.map(\.id) ?? [],
            activeFishIDs: player?.activeAquariumFishIDs ?? [],
            isInitialized: player?.hasInitializedActiveAquariumFish ?? false
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AquariumBackground(theme: backgroundTheme)
                if backgroundTheme.usesFallbackSandLayer {
                    AquariumFloor()
                }
                selectionClearingLayer
                decorationLayer(in: geometry.size)
                if isEditing { decorationInteractionLayer(in: geometry.size) }
                fishLayer(in: geometry.size)
                if isEditing { decorationOperationMenu(in: geometry.size) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear { onCanvasGeometryChanged(geometry.frame(in: .named(AquariumEditorCoordinateSpace.name))) }
            .onChange(of: geometry.size) { _, _ in onCanvasGeometryChanged(geometry.frame(in: .named(AquariumEditorCoordinateSpace.name))) }
        }
        .ignoresSafeArea()
        .onAppear {
            updateDisplayedFish()
        }
        .task {
            await initializePersistentAquariumDataAfterAppearance()
        }
        .onChange(of: fishSelectionRevision, initial: true) { _, _ in
            updateDisplayedFish()
        }
        .onChange(of: displayedFishIDs, initial: true) { _, displayedFishIDs in
            let displayedIDSet = Set(displayedFishIDs)
            let retainedPositions = fishPositions.filter { displayedIDSet.contains($0.key) }
            if retainedPositions.count != fishPositions.count {
                fishPositions = retainedPositions
            }
        }
        .onChange(of: isEditing) { _, newValue in
            if !newValue {
                cancelDecorationEditing()
            }
        }
        .onChange(of: decorationRestoreRequestID) { _, decorationID in
            guard let decorationID,
                  let placement = decorationPlacements.first(where: {
                      $0.decorationID == decorationID
                  }) else { return }
            beginEditing(placement, at: placement.isPlaced
                ? CGPoint(x: placement.relativeX, y: placement.relativeY)
                : placement.kind.restorationPosition)
            onDecorationRestoreRequestHandled()
        }
        .onChange(of: selectionResetRequestID) { _, requestID in
            guard requestID != nil else { return }
            cancelDecorationEditing()
        }
        .onChange(of: fishPositions) { _, positions in
            if isEditing || isFishSelectionEnabled { onFishPositionsChanged(positions) }
        }
    }

    @ViewBuilder
    private var selectionClearingLayer: some View {
        if isEditing || isFishSelectionEnabled {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    cancelDecorationEditing()
                    onCanvasTapped()
                }
                .accessibilityElement()
                .accessibilityLabel("水槽の空いている場所")
                .accessibilityIdentifier("aquariumEditor.emptyCanvas")
        }
    }

    private func updateDisplayedFish() {
        guard let player else {
            displayedFish = []
            return
        }

        let activeFish = player.activeAquariumFish
        if activeFish.map(\.id) != displayedFishIDs {
            displayedFish = activeFish
        }
    }

    @MainActor
    private func initializePersistentAquariumDataAfterAppearance() async {
        // SwiftDataのQuery observer構築中に同期saveしないよう、次のMainActorターンで初期化する。
        await Task.yield()
        guard !Task.isCancelled else { return }
        if editingPlacements != nil { updateDisplayedFish(); return }

        do {
            _ = try AquariumDecorationService.createDefaultsIfNeeded(in: modelContext)
            _ = try AquariumDeveloperDecorations.seedIfNeeded(in: modelContext)
            guard !Task.isCancelled else { return }

            if let player,
               AquariumFishSelection.initializeIfNeeded(for: player) {
                try modelContext.save()
            }
            updateDisplayedFish()
        } catch {
#if DEBUG
            let nsError = error as NSError
            print(
                "[AQUARIUM INIT] failed error=\(String(reflecting: error)) " +
                "domain=\(nsError.domain) code=\(nsError.code)"
            )
#endif
        }
    }

    // AquariumDecorationを画面上の座標へ変換して描画する装飾レイヤー。
    private func decorationLayer(in size: CGSize) -> some View {
        ZStack {
            ForEach(decorationPlacements.filter {
                $0.isPlaced || $0.decorationID == editingDecorationID
            }) { placement in
                AquariumPlacedDecorationView(
                    placement: placement, backgroundTheme: backgroundTheme, aquariumSize: size,
                    isSelected: editingDecorationID == placement.decorationID,
                    position: position(for: placement)
                )
                .allowsHitTesting(false)
                .zIndex(AquariumDecorationDepthPresentation(
                    kind: placement.kind, relativeY: position(for: placement).y
                ).renderZIndex(isDragging: isEditing && draggingDecorationID == placement.decorationID))
            }
            if let decorationDragPreview {
                AquariumDecorationDragPreview(
                    decoration: decorationDragPreview,
                    backgroundTheme: backgroundTheme,
                    relativeY: decorationDragPreview.relativeY
                )
                .position(
                    x: decorationDragPreview.relativeX * size.width,
                    y: decorationDragPreview.relativeY * size.height
                )
                .zIndex(AquariumDecorationDepthPresentation(
                    kind: decorationDragPreview.kind, relativeY: decorationDragPreview.relativeY
                ).renderZIndex(isDragging: true))
            }
        }
        .allowsHitTesting(isEditing)
    }

    private func decoration(at point: CGPoint, in size: CGSize) -> AquariumDecorationPlacement? {
        let candidates = decorationPlacements.filter { $0.isPlaced }.map { placement in
            let root = position(for: placement)
            return AquariumDecoration(id: placement.decorationID, kind: placement.kind,
                relativeX: root.x, relativeY: root.y, scale: CGFloat(placement.scale))
        }
        let id = AquariumDecorationHitTesting.selectedID(at: point, decorations: candidates,
            aquariumSize: size, theme: backgroundTheme)
        return decorationPlacements.first { $0.decorationID == id }

    }

    private func decorationInteractionLayer(in size: CGSize) -> some View {
        Color.clear.contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !canvasGestureStarted {
                        canvasGestureStarted = true
                        if let placement = decoration(at: value.startLocation, in: size) {
                            beginEditing(placement)
                            canvasDragStart = position(for: placement)
                        } else {
                            cancelDecorationEditing()
                            onCanvasTapped()
                        }
                    }
                    guard let start = canvasDragStart, let id = editingDecorationID,
                          let placement = decorationPlacements.first(where: { $0.decorationID == id }),
                          hypot(value.translation.width, value.translation.height) >= 6 else { return }
                    draggingDecorationID = id
                    previewPosition = AquariumDecorationEditor.relativePosition(
                        originalX: start.x, originalY: start.y, translation: value.translation,
                        aquariumSize: size, kind: placement.kind, isEditing: true, scale: CGFloat(placement.scale))
                }
                .onEnded { _ in
                    if draggingDecorationID != nil, let id = editingDecorationID,
                       let position = previewPosition,
                       let placement = decorationPlacements.first(where: { $0.decorationID == id }) {
                        moveDecoration(placement, to: position)
                    }
                    canvasDragStart = nil
                    canvasGestureStarted = false
                    draggingDecorationID = nil
                })
            .accessibilityLabel("水槽の装飾キャンバス")
            .accessibilityIdentifier("aquariumEditor.decorationCanvas")
    }

    @ViewBuilder
    private func decorationOperationMenu(in size: CGSize) -> some View {
        if draggingDecorationID == nil, let id = editingDecorationID,
           let placement = decorationPlacements.first(where: { $0.decorationID == id }) {
            VStack {
                Spacer()
                HStack(spacing: 4) {
                    if showsDecorationNudge {
                        nudgeButton("arrow.left", label: "左へ", delta: CGSize(width: -8, height: 0), placement: placement, size: size)
                        nudgeButton("arrow.up", label: "奥へ", delta: CGSize(width: 0, height: -8), placement: placement, size: size)
                        nudgeButton("arrow.down", label: "手前へ", delta: CGSize(width: 0, height: 8), placement: placement, size: size)
                        nudgeButton("arrow.right", label: "右へ", delta: CGSize(width: 8, height: 0), placement: placement, size: size)
                        Button { showsDecorationNudge = false } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                            .accessibilityLabel("微調整を閉じる")
                            .accessibilityIdentifier("aquariumEditor.closeNudge")
                    } else {
                        Button { showsDecorationNudge = true } label: {
                            Label("微調整", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.caption.bold()).frame(minWidth: 88, minHeight: 44)
                        }
                        .accessibilityIdentifier("aquariumEditor.openNudge")
                        Button { storeDecoration(placement) } label: {
                            Label("水槽からしまう", systemImage: "tray.and.arrow.down")
                                .font(.caption.bold()).frame(minWidth: 132, minHeight: 44)
                        }
                            .accessibilityLabel("水槽からしまう")
                            .accessibilityIdentifier("aquariumEditor.removeSelectedDecoration")
                    }
                }
                .padding(8)
                .foregroundStyle(.white)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .buttonStyle(.plain)
                .frame(width: 260, height: 60)
                .padding(.bottom, 35)
            }
        }
    }

    private func nudgeButton(_ icon: String, label: String, delta: CGSize,
                             placement: AquariumDecorationPlacement, size: CGSize) -> some View {
        Button {
            let root = position(for: placement)
            let moved = AquariumDecorationEditor.relativePosition(originalX: root.x, originalY: root.y,
                translation: delta, aquariumSize: size, kind: placement.kind, isEditing: true, scale: CGFloat(placement.scale))
            moveDecoration(placement, to: moved)
        } label: { Image(systemName: icon).frame(width: 44, height: 44) }
        .accessibilityLabel(label)
        .accessibilityIdentifier("aquariumEditor.nudge.\(icon)")
    }

    private func position(for placement: AquariumDecorationPlacement) -> CGPoint {
        if editingDecorationID == placement.decorationID, let previewPosition {
            return previewPosition
        }
        return CGPoint(x: placement.relativeX, y: placement.relativeY)
    }

    private func beginEditing(_ placement: AquariumDecorationPlacement) {
        beginEditing(
            placement,
            at: CGPoint(x: placement.relativeX, y: placement.relativeY)
        )
    }

    private func beginEditing(
        _ placement: AquariumDecorationPlacement,
        at initialPreviewPosition: CGPoint
    ) {
        guard isEditing else { return }
        let position = CGPoint(x: placement.relativeX, y: placement.relativeY)
        let wasEditing = editingDecorationID != nil
        if editingDecorationID != placement.decorationID { showsDecorationNudge = false }
        editingDecorationID = placement.decorationID
        originalPosition = position
        previewPosition = initialPreviewPosition
        if !wasEditing {
            onDecorationEditingChanged(true)
        }
    }

    private func cancelDecorationEditing() {
        guard editingDecorationID != nil else { return }
        previewPosition = originalPosition
        finishDecorationEditing()
    }

    private func storeDecoration(_ placement: AquariumDecorationPlacement) {
        do {
            try AquariumDecorationService.store(
                placement,
                in: modelContext,
                persistChanges: !defersDecorationPersistence
            )
            onDecorationChanged()
        } catch {}
        finishDecorationEditing()
    }

    private func moveDecoration(
        _ placement: AquariumDecorationPlacement,
        to position: CGPoint
    ) {
        guard isEditing else { return }
        editingDecorationID = placement.decorationID
        do {
            try AquariumDecorationService.confirmPlacement(
                placement,
                at: position,
                in: modelContext,
                persistChanges: !defersDecorationPersistence
            )
            originalPosition = position
            previewPosition = nil
            onDecorationChanged()
        } catch {}
    }

    private func finishDecorationEditing() {
        showsDecorationNudge = false
        draggingDecorationID = nil
        editingDecorationID = nil
        originalPosition = nil
        previewPosition = nil
        onDecorationEditingChanged(false)
    }

    // 魚の配置と泳ぎは、背景装飾とは独立したレイヤーで管理する。
    private func fishLayer(in size: CGSize) -> some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30.0,
            paused: isSimulationPaused
        )) { timeline in
            let positionSnapshot = isSimulationPaused
                ? AquariumFishPositionSnapshot.empty
                : AquariumFishPositionSnapshot(fishPositions)

            ZStack {
                ForEach(displayedFish) { playerFish in
                    SwimmingFishView(
                        fishID: playerFish.id,
                        initialPosition: fishSpawnPositions[playerFish.id],
                        appearance: fishAppearances[playerFish.id],
                        species: playerFish.species,
                        backgroundTheme: backgroundTheme,
                        isFavorite: false,
                        aquariumSize: size,
                        updateDate: timeline.date,
                        isSimulationPaused: isSimulationPaused,
                        isSelectionEnabled: isFishSelectionEnabled,
                        isSelected: selectedFishID == playerFish.id,
                        neighborPositions: isSimulationPaused
                            ? .empty
                            : positionSnapshot.neighborPositions(excluding: playerFish.id),
                        reportPosition: { fishPositions[playerFish.id] = $0 },
                        select: { onFishSelected(playerFish.id) }
                    )
                }
            }
        }
    }

}

private struct AquariumPlacedDecorationView: View {
    let placement: AquariumDecorationPlacement
    let backgroundTheme: AquariumBackgroundTheme
    let aquariumSize: CGSize
    let isSelected: Bool
    let position: CGPoint

    var body: some View {
        let decoration = placement.decoration
        let depth = AquariumDecorationDepthPresentation(kind: decoration.kind, relativeY: position.y)
        let scale = decoration.scale * depth.scale
        AquariumDecorationView(decoration: decoration, backgroundTheme: backgroundTheme)
            .modifier(AquariumSelectionGlow(isSelected: isSelected))
            .scaleEffect(scale)
            .opacity(depth.opacity)
            .offset(y: decoration.kind.groundAnchorOffset(scale: scale))
            .position(x: aquariumSize.width * position.x, y: aquariumSize.height * position.y)
            .accessibilityLabel(decoration.kind.displayName)
            .accessibilityIdentifier("aquariumEditor.placedDecoration.\(placement.decorationID)")
    }
}

struct AquariumDecorationView: View {
    let decoration: AquariumDecoration
    var backgroundTheme: AquariumBackgroundTheme = .aquarium

    @ViewBuilder
    var body: some View {
        if !decoration.kind.animationFrameNames.isEmpty {
            AquariumDecorationFrameView(kind: decoration.kind, placementID: decoration.id)
                .modifier(AquariumSeaweedColorCorrection.correction(for: backgroundTheme))
        } else if let imageName = decoration.kind.assetImageName(for: backgroundTheme),
           let image = UIImage(named: imageName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: decoration.kind.displaySize.width, height: decoration.kind.displaySize.height)
                .modifier(AquariumCoralColorCorrection.correction(for: backgroundTheme, kind: decoration.kind))
        } else {
            switch decoration.kind {
            case .coralAPink, .coralAOrange, .coralAPurple, .coralBPink, .coralBOrange, .coralBPurple, .coralCPink, .coralCOrange, .coralCPurple:
                EmptyView()
            case .seaweed, .seaweedA, .seaweedB, .seaweedC:
                HStack(alignment: .bottom, spacing: -8) {
                    seaweedStem(height: 88, rotation: -8)
                    seaweedStem(height: 120, rotation: 3)
                    seaweedStem(height: 76, rotation: 10)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.mint, .green.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            case .rock, .smallRockA, .smallRockB, .smallRockC, .mediumRockA, .mediumRockB, .mediumRockC:
                ZStack(alignment: .bottom) {
                    Ellipse()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 112, height: 30)

                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [.gray.opacity(0.9), .black.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 94, height: 64)
                        .offset(y: -8)
                }
            }
        }
    }

    private func seaweedStem(height: CGFloat, rotation: Double) -> some View {
        Capsule()
            .fill(.green)
            .frame(width: 18, height: height)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
    }
}

enum AquariumFishSizing {
    // 3ae83d8の正常な水槽サイズを復元。一覧・drag previewのサイズとは独立。
    static let baseSize: CGFloat = 78
    static func displaySize(for species: FishSpecies, isFavorite _: Bool) -> CGFloat {
        baseSize * species.displayScale
    }
}

/// アニメーション中の画像alphaに沿う発光層。元画像はそのまま前面に保持する。
struct AquariumSelectionGlow: ViewModifier {
    let isSelected: Bool
    var edgeOpacity: Double = 1
    var outlineWidth: CGFloat = 0.8
    func body(content: Content) -> some View {
        content
            .background {
                if isSelected {
                    ZStack {
                        ForEach(0..<4, id: \.self) { index in
                            let offsets = [CGSize(width: -outlineWidth, height: 0), CGSize(width: outlineWidth, height: 0),
                                           CGSize(width: 0, height: -outlineWidth), CGSize(width: 0, height: outlineWidth)]
                            content.brightness(1).colorMultiply(Color(red: 0.65, green: 1, blue: 1))
                                .offset(offsets[index])
                        }
                    }
                        .blur(radius: 0.25)
                        .shadow(color: .white, radius: 1)
                        .shadow(color: .cyan, radius: 2)
                        .opacity(edgeOpacity).allowsHitTesting(false)
                }
            }
            .compositingGroup()
            .shadow(color: isSelected ? .white : .clear, radius: 1)
            .shadow(color: isSelected ? .cyan : .clear, radius: 4)
    }
}

struct AquariumSimulationTiming {
    private(set) var lastUpdateDate: Date?
    private(set) var requiresResumeBaseline = false

    mutating func pause() {
        lastUpdateDate = nil
        requiresResumeBaseline = true
    }

    /// pause中の実時間をMovementへ渡さず、再開後の最初のtickを新しい基準時刻にする。
    mutating func nextDeltaTime(at date: Date, isPaused: Bool) -> TimeInterval? {
        guard !isPaused else {
            pause()
            return nil
        }

        if requiresResumeBaseline {
            requiresResumeBaseline = false
            lastUpdateDate = date
            return nil
        }

        guard let lastUpdateDate else {
            self.lastUpdateDate = date
            return nil
        }

        self.lastUpdateDate = date
        return date.timeIntervalSince(lastUpdateDate)
    }
}

/// 1 tick内で共有する魚位置。Dictionary走査とIDのindex解決を1回にまとめる。
struct AquariumFishPositionSnapshot {
    static let empty = AquariumFishPositionSnapshot([:])

    fileprivate let positions: [CGPoint]
    private let indexByFishID: [UUID: Int]

    init(_ fishPositions: [UUID: CGPoint]) {
        var positions: [CGPoint] = []
        positions.reserveCapacity(fishPositions.count)
        var indexByFishID: [UUID: Int] = [:]
        indexByFishID.reserveCapacity(fishPositions.count)

        for (fishID, position) in fishPositions {
            indexByFishID[fishID] = positions.count
            positions.append(position)
        }

        self.positions = positions
        self.indexByFishID = indexByFishID
    }

    func neighborPositions(excluding fishID: UUID) -> AquariumNeighborPositions {
        AquariumNeighborPositions(
            positions: positions,
            excludedIndex: indexByFishID[fishID]
        )
    }
}

/// snapshotの配列を複製せず、指定した魚だけを除外して見せるCollection。
struct AquariumNeighborPositions: RandomAccessCollection {
    typealias Index = Int
    typealias Element = CGPoint

    static let empty = AquariumNeighborPositions(positions: [], excludedIndex: nil)

    fileprivate let positions: [CGPoint]
    fileprivate let excludedIndex: Int?

    var startIndex: Int { 0 }
    var endIndex: Int { positions.count - (excludedIndex == nil ? 0 : 1) }

    func index(after index: Int) -> Int { index + 1 }
    func index(before index: Int) -> Int { index - 1 }

    subscript(index: Int) -> CGPoint {
        precondition(indices.contains(index))
        let sourceIndex = if let excludedIndex, index >= excludedIndex {
            index + 1
        } else {
            index
        }
        return positions[sourceIndex]
    }
}

private struct SwimmingFishView: View {
    let fishID: UUID
    let species: FishSpecies
    let appearance: AquariumFishAppearance?
    let backgroundTheme: AquariumBackgroundTheme
    let isFavorite: Bool
    let aquariumSize: CGSize
    let updateDate: Date
    let isSimulationPaused: Bool
    let isSelectionEnabled: Bool
    let isSelected: Bool
    let neighborPositions: AquariumNeighborPositions
    let reportPosition: (CGPoint) -> Void
    let select: () -> Void
    let spriteAnimationPhase: TimeInterval
    let spriteTempoMultiplier: TimeInterval

    @State private var motion: AquariumFishMotion.State
    @State private var spriteDirectionTransition: FishSpriteDirectionTransition
    @State private var wingCycle: AquariumFishMotion.WingCycle?
    @State private var simulationTiming = AquariumSimulationTiming()
    @State private var elapsedTime: TimeInterval = 0
    @State private var positionReportTimeRemaining: TimeInterval = 0

    init(
        fishID: UUID,
        initialPosition: CGPoint? = nil,
        appearance: AquariumFishAppearance? = nil,
        species: FishSpecies,
        backgroundTheme: AquariumBackgroundTheme,
        isFavorite: Bool,
        aquariumSize: CGSize,
        updateDate: Date,
        isSimulationPaused: Bool,
        isSelectionEnabled: Bool,
        isSelected: Bool,
        neighborPositions: AquariumNeighborPositions,
        reportPosition: @escaping (CGPoint) -> Void,
        select: @escaping () -> Void
    ) {
        self.fishID = fishID
        self.appearance = appearance
        self.species = species
        self.backgroundTheme = backgroundTheme
        self.isFavorite = isFavorite
        self.aquariumSize = aquariumSize
        self.updateDate = updateDate
        self.isSimulationPaused = isSimulationPaused
        self.isSelectionEnabled = isSelectionEnabled
        self.isSelected = isSelected
        self.neighborPositions = neighborPositions
        self.reportPosition = reportPosition
        self.select = select
        self.spriteAnimationPhase = AquariumFishMotion.spriteAnimationPhase(for: fishID)
        self.spriteTempoMultiplier = AquariumFishMotion.spriteTempoMultiplier(for: fishID)

        let profile = AquariumFishMotion.movementProfile(for: species)
        var initialMotion = AquariumFishMotion.initialState(
            for: fishID,
            profile: profile,
            speedVariationProfile: AquariumFishMotion.speedVariationProfile(for: species),
            roamingBounds: profile.roamingStyle.bounds(
                in: aquariumSize,
                fishSize: AquariumFishSizing.displaySize(for: species, isFavorite: isFavorite)
            )
        )
        if let initialPosition { initialMotion.position = initialPosition }
        self._motion = State(initialValue: initialMotion)
        self._spriteDirectionTransition = State(
            initialValue: FishSpriteDirectionTransition(direction: initialMotion.facingDirection)
        )
        self._wingCycle = State(initialValue: AquariumFishMotion
            .wingSwimmingProfile(for: species)
            .map { _ in AquariumFishMotion.WingCycle(id: fishID, profile: .manta) })
    }

    var body: some View {
        ZStack {
            if let appearance, appearance.progress(at: updateDate) < 1 {
                AquariumFishAppearanceRing(progress: appearance.progress(at: updateDate))
            }
            fishImage
                .modifier(AquariumFishColorCorrection.correction(for: backgroundTheme, species: species))
                .modifier(AquariumSelectionGlow(isSelected: isSelected && isSelectionEnabled,
                    edgeOpacity: species.displayScale < 1 ? 1 : 0.95,
                    outlineWidth: species.displayScale < 1 ? 1 : species.displayScale < 2 ? 0.8 : 0.65))
                .scaleEffect(0.8 + 0.2 * appearanceProgress)
                .opacity(Double(appearance == nil ? 1 : 0.15 + 0.85 * appearanceProgress))
        }
            .frame(width: selectionHitTargetSize, height: selectionHitTargetSize)
            .contentShape(isSelectionEnabled ? AquariumFishHitTesting.path(
                image: fishSprite.interactionImage, canvasSize: selectionHitTargetSize,
                fishSize: fishSize, horizontalScale: fishSprite.resolvedHorizontalScale) : Path())
            .onTapGesture {
                guard isSelectionEnabled else { return }
                select()
            }
            .allowsHitTesting(isSelectionEnabled)
            .rotationEffect(.degrees(swimRotation + smallFishDirectionRotation))
            .scaleEffect(x: 1, y: swimVerticalScale)
            .offset(y: swimVerticalOffset)
            .opacity(motion.depthOpacity)
            .position(
                x: aquariumSize.width * motion.position.x,
                y: aquariumSize.height * motion.position.y
            )
            .zIndex(Double(motion.currentDepth))
            .onChange(of: updateDate) { _, newDate in
                updateMotion(at: newDate)
            }
            .onChange(of: isSimulationPaused) { _, isPaused in
                if isPaused {
                    simulationTiming.pause()
                }
            }
            .onChange(of: aquariumSize) { _, size in
                motion.updateRoamingBounds(motion.movementProfile.roamingStyle.bounds(
                    in: size, fishSize: fishSize
                ))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(fishAccessibilityLabel)
            .accessibilityIdentifier("aquarium.fish.\(fishID.uuidString)")
            .accessibilityValue(isSelectionEnabled && isSelected ? "選択中" : "")
    }

    private func updateMotion(at date: Date) {
        guard let deltaTime = simulationTiming.nextDeltaTime(
            at: date,
            isPaused: isSimulationPaused || (appearance?.progress(at: date) ?? 1) < 1
        ) else { return }
        elapsedTime += min(max(deltaTime, 0), AquariumFishMotion.maximumDeltaTime)
        if var wingCycle, let wingProfile {
            wingCycle.advance(
                deltaTime: deltaTime,
                frameCount: species.swimmingImageNames.count,
                frameDuration: spriteFrameDuration,
                profile: wingProfile
            )
            self.wingCycle = wingCycle
        }
        motion.advance(
            deltaTime: deltaTime,
            elapsedTime: elapsedTime,
            neighborPositions: neighborPositions,
            speedMultiplier: wingSpeedMultiplier,
            behaviorTargetSpeedMultiplier: AquariumFishMotion.behaviorTargetSpeedMultiplier(
                for: species,
                behavior: motion.behavior
            ),
            speedResponseMultiplier: wingSpeedResponseMultiplier,
            minimumSpeedMultiplier: wingMinimumSpeedMultiplier,
            steeringNoiseMultiplier: wingSteeringMultiplier
        )
        spriteDirectionTransition.update(
            toward: motion.facingDirection,
            deltaTime: deltaTime
        )
        positionReportTimeRemaining -= deltaTime
        if positionReportTimeRemaining <= 0 {
            reportPosition(motion.position)
            positionReportTimeRemaining = 0.45
        }
    }

    private var appearanceProgress: CGFloat {
        appearance?.fishProgress(at: updateDate) ?? 1
    }

    private var fishSprite: FishImageView {
        FishImageView(
            species: species,
            facingDirection: motion.facingDirection,
            spritePose: spriteDirectionTransition.pose,
            facingHorizontalScale: motion.facingHorizontalScale,
            animationTime: spriteAnimationTime,
            animationFrameDuration: spriteFrameDuration,
            animationPhase: species == .manta || species == .seahorse ? 0 : spriteAnimationPhase,
            fixedAnimationFrameIndex: fixedSpriteFrameIndex
        )
    }

    private var fishImage: some View {
        fishSprite.frame(width: fishSize, height: fishSize)
    }

    private var fishSize: CGFloat {
        AquariumFishSizing.displaySize(for: species, isFavorite: isFavorite)
    }

    private var selectionHitTargetSize: CGFloat {
        guard isSelectionEnabled else { return fishSize }
        return max(fishSize + 20, 56)
    }

    private var fishAccessibilityLabel: String {
        let base = isFavorite ? "お気に入りの\(species.name)" : species.name
        return isSelected ? "\(base)、選択中" : base
    }

    private var swimIntensity: CGFloat {
        min(max(motion.currentSpeed / max(motion.baseSpeed, 0.001), 0.15), 2.4)
    }

    private var spriteFrameDuration: TimeInterval {
        AquariumFishMotion.spriteFrameDuration(
            for: species,
            behavior: motion.behavior,
            currentSpeed: motion.currentSpeed,
            baseSpeed: motion.baseSpeed
        ) * spriteTempoMultiplier
    }

    private var wingProfile: WingSwimmingProfile? {
        AquariumFishMotion.wingSwimmingProfile(for: species)
    }

    private var spriteAnimationTime: TimeInterval? {
        if species == .seahorse {
            return AquariumFishMotion.seahorseSpriteAnimationTime(
                swimPhase: motion.swimPhase,
                frameCount: species.swimmingImageNames.count,
                frameDuration: spriteFrameDuration
            )
        }
        guard species == .manta else { return updateDate.timeIntervalSinceReferenceDate }
        guard wingCycle?.phase == .flapping else { return nil }
        return wingCycle?.flapElapsedTime
    }

    private var fixedSpriteFrameIndex: Int? {
        guard wingCycle?.phase == .gliding else { return nil }
        return wingProfile?.neutralFrameIndex
    }

    private var wingSpeedMultiplier: CGFloat {
        guard let wingProfile, let phase = wingCycle?.phase else { return 1 }
        return phase == .flapping
            ? wingProfile.flapSpeedMultiplier
            : wingProfile.glideSpeedMultiplier
    }

    private var wingSteeringMultiplier: CGFloat {
        guard let wingProfile, wingCycle?.phase == .gliding else { return 1 }
        return wingProfile.glideSteeringMultiplier
    }

    private var wingSpeedResponseMultiplier: CGFloat {
        guard let wingProfile, wingCycle?.phase == .gliding else { return 1 }
        return wingProfile.glideDecelerationResponseMultiplier
    }

    private var wingMinimumSpeedMultiplier: CGFloat {
        guard let wingProfile, wingCycle?.phase == .gliding else { return 0 }
        return wingProfile.glideMinimumSpeedMultiplier
    }

    private var wingPresentationMultiplier: CGFloat {
        guard let wingProfile, wingCycle?.phase == .gliding else { return 1 }
        return wingProfile.glidePresentationMultiplier
    }

    private var swimRotation: Double {
        guard species != .seahorse else { return 0 }
        return Double(
            sin(motion.swimPhase)
                * min(0.8 + swimIntensity * 0.45, 1.8)
                * motion.presentationMotionIntensity
                * wingPresentationMultiplier
        )
    }

    /// 小魚型のsideフレームを、flip後に画面内の進行方向へ回転する。
    private var smallFishDirectionRotation: Double {
        species.swimmingImageRotation(for: motion.facingDirection)
    }

    private var swimVerticalScale: CGFloat {
        guard species != .seahorse else { return 1 }
        return 1 + cos(motion.swimPhase * 1.07)
            * min(0.008 + swimIntensity * 0.005, 0.02)
            * motion.presentationMotionIntensity
            * wingPresentationMultiplier
    }

    private var swimVerticalOffset: CGFloat {
        if species == .seahorse {
            // frame1側で上昇、frame3で折り返し、frame5側で下降する描画専用の浮遊。
            return AquariumFishMotion.seahorseVisualOffsetY(swimPhase: motion.swimPhase)
        }
        return sin(motion.swimPhase * 0.53)
            * min(0.7 + swimIntensity * 0.45, 1.8)
            * motion.presentationMotionIntensity
            * wingPresentationMultiplier
    }

}

extension View {
    func aquariumGlass(cornerRadius: CGFloat = 22) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        }
    }
}

struct AquariumPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [.cyan.opacity(0.9), .blue.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: .blue.opacity(0.35), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct AquariumStudyStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.38), radius: 2, y: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Color.cyan.opacity(configuration.isPressed ? 0.28 : 0.22),
                in: Capsule()
            )
            .overlay(Capsule().stroke(.white.opacity(0.68), lineWidth: 1))
            .shadow(color: .cyan.opacity(0.18), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct AquariumSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.white.opacity(configuration.isPressed ? 0.12 : 0.18), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    AquariumView(player: nil)
        .modelContainer(for: AquariumDecorationPlacement.self, inMemory: true)
}
