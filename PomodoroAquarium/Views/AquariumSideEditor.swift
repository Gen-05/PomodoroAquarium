import CoreTransferable
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AquariumEditorCategory: String, CaseIterable, Identifiable {
    case fish
    case decoration
    case background

    var id: Self { self }

    var title: String {
        switch self {
        case .fish: "魚"
        case .decoration: "置物"
        case .background: "背景"
        }
    }

    var systemImage: String {
        switch self {
        case .fish: "fish.fill"
        case .decoration: "shippingbox.fill"
        case .background: "photo.fill"
        }
    }
}

enum AquariumSideEditorLayout {
    static let widthRatio: CGFloat = 0.36
    static let minimumWidth: CGFloat = 130
    static let maximumWidth: CGFloat = 160
    static let categoryTabWidth: CGFloat = 42
    static let collapsedHandleWidth: CGFloat = 38
    static let collapsedHandleHeight: CGFloat = 88
    static let excludedDropTopHeight: CGFloat = 52
    static let excludedDropBottomHeight: CGFloat = 82

    static func width(for screenWidth: CGFloat) -> CGFloat {
        min(max(screenWidth * widthRatio, minimumWidth), maximumWidth)
    }

    static func aquariumWidth(
        for screenWidth: CGFloat,
        isEditing: Bool,
        isPanelExpanded: Bool = true
    ) -> CGFloat {
        let occupiedWidth: CGFloat
        if !isEditing {
            occupiedWidth = 0
        } else if isPanelExpanded {
            occupiedWidth = width(for: screenWidth)
        } else {
            // 格納ハンドルは水槽の上へ重ね、描画領域を差し引かない。
            occupiedWidth = 0
        }
        return max(screenWidth - occupiedWidth, 1)
    }

    /// 右サイドバーの画面内X座標。レイアウト検証用にも同じ計算を利用する。
    static func panelMinX(for screenWidth: CGFloat) -> CGFloat {
        max(screenWidth - width(for: screenWidth), 0)
    }

    static func acceptsDrop(at location: CGPoint, in aquariumSize: CGSize) -> Bool {
        guard aquariumSize.width > 0,
              aquariumSize.height > excludedDropTopHeight + excludedDropBottomHeight else {
            return false
        }
        return location.x >= 0 &&
            location.x <= aquariumSize.width &&
            location.y >= excludedDropTopHeight &&
            location.y <= aquariumSize.height - excludedDropBottomHeight
    }
}

enum AquariumEditorCoordinateSpace {
    static let name = "aquariumEditorCanvas"
}

enum AquariumFishDragIntent: Equatable {
    case aquarium
    case scrolling
}

enum AquariumFishDragInteraction {
    static let minimumDistance: CGFloat = 6
    static let hitAreaExpansion: CGFloat = 16

    static func intent(for translation: CGSize) -> AquariumFishDragIntent {
        let horizontalDistance = abs(translation.width)
        let verticalDistance = abs(translation.height)
        return translation.width < 0 && horizontalDistance > verticalDistance
            ? .aquarium
            : .scrolling
    }
}

enum AquariumFishDragPresentation {
    static let minimumPreviewSize: CGFloat = 44
    static let maximumPreviewSize: CGFloat = 180

    static func previewSize(for species: FishSpecies) -> CGFloat {
        min(
            max(
                AquariumFishSizing.displaySize(for: species, isFavorite: false),
                minimumPreviewSize
            ),
            maximumPreviewSize
        )
    }

    static func frameDuration(for species: FishSpecies) -> TimeInterval {
        FishDetailStrokeAnimationState.frameDuration(for: species)
    }
}

private struct AquariumEditorScrollState: Equatable {
    var offset: CGFloat = 0
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0

    var scrollableDistance: CGFloat {
        max(contentHeight - viewportHeight, 0)
    }

    var isScrollable: Bool {
        scrollableDistance > 1
    }

    var hasMeasurements: Bool {
        contentHeight > 0 && viewportHeight > 0
    }

    var progress: CGFloat {
        guard isScrollable else { return 0 }
        return min(max(offset / scrollableDistance, 0), 1)
    }

    var visibleRatio: CGFloat {
        guard contentHeight > 0 else { return 1 }
        return min(max(viewportHeight / contentHeight, 0), 1)
    }

    mutating func update(contentHeight: CGFloat? = nil, viewportHeight: CGFloat? = nil) {
        if let contentHeight, contentHeight.isFinite, contentHeight >= 0 {
            self.contentHeight = contentHeight
        }
        if let viewportHeight, viewportHeight.isFinite, viewportHeight >= 0 {
            self.viewportHeight = viewportHeight
        }
        offset = min(max(offset, 0), scrollableDistance)
    }

    mutating func setProgress(_ progress: CGFloat) {
        guard progress.isFinite, isScrollable else {
            offset = 0
            return
        }
        offset = min(max(progress, 0), 1) * scrollableDistance
    }
}

private enum AquariumEditorScrollBarLayout {
    static let minimumThumbHeight: CGFloat = 44

    static func thumbHeight(for visibleRatio: CGFloat, trackHeight: CGFloat) -> CGFloat {
        guard trackHeight.isFinite, trackHeight > 0 else { return 0 }
        guard visibleRatio.isFinite else { return trackHeight }
        let proportionalHeight = trackHeight * min(max(visibleRatio, 0), 1)
        return min(max(proportionalHeight, minimumThumbHeight), trackHeight)
    }
}

private struct AquariumEditorControlledScrollView<Content: View>: View {
    @Binding var state: AquariumEditorScrollState
    let category: AquariumEditorCategory
    let visibleItemCount: Int
    let content: Content

#if DEBUG
    @State private var lastLoggedMeasurements: AquariumEditorScrollState?
#endif

    init(
        state: Binding<AquariumEditorScrollState>,
        category: AquariumEditorCategory,
        visibleItemCount: Int,
        @ViewBuilder content: () -> Content
    ) {
        _state = state
        self.category = category
        self.visibleItemCount = visibleItemCount
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { contentGeometry in
                            Color.clear
                                .onAppear {
                                    updateContentHeight(contentGeometry.size.height)
                                }
                                .onChange(of: contentGeometry.size.height) { _, newHeight in
                                    updateContentHeight(newHeight)
                                }
                        }
                    }
                    .offset(y: -state.offset)
            }
            .scrollDisabled(true)
            .onAppear {
                updateViewportHeight(geometry.size.height)
            }
            .onChange(of: geometry.size.height) { _, newHeight in
                updateViewportHeight(newHeight)
            }
        }
    }

    private func updateContentHeight(_ height: CGFloat) {
        var updatedState = state
        updatedState.update(contentHeight: height)
        if updatedState != state {
            state = updatedState
            logMeasurementsIfNeeded(updatedState)
        }
    }

    private func updateViewportHeight(_ height: CGFloat) {
        var updatedState = state
        updatedState.update(viewportHeight: height)
        if updatedState != state {
            state = updatedState
            logMeasurementsIfNeeded(updatedState)
        }
    }

    private func logMeasurementsIfNeeded(_ measurements: AquariumEditorScrollState) {
#if DEBUG
        guard measurements.hasMeasurements,
              lastLoggedMeasurements != measurements else {
            return
        }
        lastLoggedMeasurements = measurements
        NSLog(
            "[AquariumEditorScroll] category=\(category.rawValue) "
                + "items=\(visibleItemCount) "
                + "contentHeight=\(measurements.contentHeight) "
                + "viewportHeight=\(measurements.viewportHeight) "
                + "scrollableDistance=\(measurements.scrollableDistance)"
        )
#endif
    }
}

enum AquariumFishEditorPresentation {
    static func ownedSpecies(from ownedFish: [PlayerFish]) -> [FishSpecies] {
        FishSpecies.allCases.filter { species in
            ownedFish.contains { $0.species == species }
        }
    }
}

struct AquariumDecorationInventoryItem: Identifiable, Equatable {
    let kind: AquariumDecorationKind
    let placedCount: Int
    let ownedCount: Int
    let dragPlacementID: String

    var id: String { kind.rawValue }
    var canPlaceAnother: Bool { placedCount < ownedCount }
}

enum AquariumDecorationEditorPresentation {
    static func inventory(
        from placements: [AquariumDecorationPlacement]
    ) -> [AquariumDecorationInventoryItem] {
        AquariumDecorationKind.allCases.compactMap { kind in
            let ownedPlacements = placements.filter { $0.kind == kind }
            guard let firstOwnedPlacement = ownedPlacements.first else { return nil }
            let placedCount = ownedPlacements.count(where: \.isPlaced)
            let nextStoredPlacement = ownedPlacements.first { !$0.isPlaced }

            return AquariumDecorationInventoryItem(
                kind: kind,
                placedCount: placedCount,
                ownedCount: ownedPlacements.count,
                dragPlacementID: nextStoredPlacement?.decorationID ?? firstOwnedPlacement.decorationID
            )
        }
    }
}

struct AquariumFishDragSession: Equatable {
    let species: FishSpecies
    var location: CGPoint
}

struct AquariumDecorationDragSession: Equatable {
    let decorationID: String
    var location: CGPoint
}

enum AquariumFishDragAvailability {
    static func canBeginDrag(ownedCount: Int, activeCount: Int) -> Bool {
        ownedCount > activeCount
    }
}

extension UTType {
    static let aquariumEditorItem = UTType(
        exportedAs: "com.genkiboo0511.pomodoro-aquarium.editor-item"
    )
}

struct AquariumEditorDragItem: Codable, Hashable, Transferable {
    enum Kind: String, Codable {
        case fish
        case decoration
    }

    let kind: Kind
    let identifier: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .aquariumEditorItem)
    }

    static func fish(_ species: FishSpecies) -> Self {
        Self(kind: .fish, identifier: species.rawValue)
    }

    static func decoration(id: String) -> Self {
        Self(kind: .decoration, identifier: id)
    }

    var fishSpecies: FishSpecies? {
        guard kind == .fish else { return nil }
        return FishSpecies(rawValue: identifier)
    }
}

@MainActor
enum AquariumEditorDropCoordinator {
    static func addFish(
        from item: AquariumEditorDragItem,
        preferredFishID: UUID? = nil,
        to player: Player
    ) -> AquariumFishDropResult {
        guard let species = item.fishSpecies else { return .unavailable }
        return addFish(species: species, preferredFishID: preferredFishID, to: player)
    }

    static func completeFishDrag(
        species: FishSpecies,
        at location: CGPoint,
        aquariumSize: CGSize,
        player: Player,
        preferredFishID: UUID? = nil
    ) -> AquariumFishDropResult {
        guard AquariumSideEditorLayout.acceptsDrop(
            at: location,
            in: aquariumSize
        ) else { return .outsideAquarium }
        return addFish(species: species, preferredFishID: preferredFishID, to: player)
    }

    private static func addFish(
        species: FishSpecies,
        preferredFishID: UUID?,
        to player: Player
    ) -> AquariumFishDropResult {
        guard player.activeAquariumFish.count < AquariumDisplayLimits.maxFishCount else {
            return .aquariumFull
        }

        let didAddFish: Bool
        if let preferredFishID {
            didAddFish = player.addFishToAquarium(playerFishID: preferredFishID)
        } else {
            didAddFish = player.addOneFishToAquarium(species: species)
        }
        return didAddFish ? .placed : .unavailable
    }

    static func placeDecoration(
        from item: AquariumEditorDragItem,
        placement: AquariumDecorationPlacement,
        at location: CGPoint,
        aquariumSize: CGSize,
        in context: ModelContext,
        persistChanges: Bool = true
    ) throws {
        guard item.kind == .decoration,
              item.identifier == placement.decorationID else {
            throw AquariumEditorDropError.invalidDecoration
        }
        let position = AquariumDecorationEditor.relativePosition(
            forDropLocation: location,
            aquariumSize: aquariumSize,
            kind: placement.kind
        )
        try AquariumDecorationService.confirmPlacement(
            placement,
            at: position,
            in: context,
            persistChanges: persistChanges
        )
    }

}

enum AquariumFishDropResult: Equatable {
    case placed
    case outsideAquarium
    case aquariumFull
    case unavailable
}

private enum AquariumEditorDropError: Error {
    case invalidDecoration
}

struct AquariumSideEditor: View {
    let player: Player?
    let decorationPlacements: [AquariumDecorationPlacement]
    let selectedBackgroundTheme: AquariumBackgroundTheme
    let panelWidth: CGFloat
    @Binding var selectedCategory: AquariumEditorCategory
    let updateFishDrag: (FishSpecies, CGPoint) -> Void
    let finishFishDrag: (FishSpecies, CGPoint) -> Void
    let cancelFishDrag: () -> Void
    let updateDecorationDrag: (String, CGPoint) -> Void
    let finishDecorationDrag: (String, CGPoint) -> Void
    let cancelDecorationDrag: () -> Void
    let selectBackground: (AquariumBackgroundTheme) -> Void
    let finishEditing: () -> Void
    let collapse: () -> Void
    let showTutorial: () -> Void
    var showsFinishButton = true
    var isCoreTutorialActive = false

    @State private var fishScrollState = AquariumEditorScrollState()
    @State private var decorationScrollState = AquariumEditorScrollState()
    @State private var backgroundScrollState = AquariumEditorScrollState()

    private var contentWidth: CGFloat {
        max(panelWidth - AquariumSideEditorLayout.categoryTabWidth, 80)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Button(action: showTutorial) {
                        Image(systemName: "questionmark.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCoreTutorialActive)
                    .accessibilityHidden(isCoreTutorialActive)
                    .accessibilityLabel("水槽編集の使い方")
                    .accessibilityIdentifier("aquariumEditor.help")
                    Button(action: collapse) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCoreTutorialActive)
                    .accessibilityHidden(isCoreTutorialActive)
                    .accessibilityLabel("編集パネルを閉じる")
                    .accessibilityIdentifier("aquariumEditor.collapsePanel")
                    if showsFinishButton {
                        Button(action: finishEditing) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("水槽編集を終了")
                    }
                }

                editorContent
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 10 + MainTabBarHitShieldLayout.tabBarHeight)
            .frame(width: contentWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(.ultraThinMaterial)

            VStack(spacing: 8) {
                ForEach(AquariumEditorCategory.allCases) { category in
                    categoryButton(category)
                }
                editorScrollBar
            }
            .padding(.top, 10)
            .padding(.bottom, 10 + MainTabBarHitShieldLayout.tabBarHeight)
            .frame(width: AquariumSideEditorLayout.categoryTabWidth)
            .background(.thinMaterial)
        }
        .frame(width: panelWidth)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18
            )
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: -4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("水槽編集ツール")
        .accessibilityIdentifier("aquariumEditor.panel")
    }

    @ViewBuilder
    private var editorContent: some View {
        switch selectedCategory {
        case .fish:
            fishEditor
        case .decoration:
            decorationEditor
        case .background:
            backgroundEditor
        }
    }

    private var fishEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("水槽の魚")
                    .font(.caption.weight(.semibold))
                Text("\(player?.activeAquariumFish.count ?? 0) / \(AquariumDisplayLimits.maxFishCount)")
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("aquariumActiveFishCount")
            }

            AquariumEditorControlledScrollView(
                state: $fishScrollState,
                category: .fish,
                visibleItemCount: ownedFishSpecies.count
            ) {
                VStack(spacing: 8) {
                    ForEach(ownedFishSpecies) { species in
                        fishCard(species)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var ownedFishSpecies: [FishSpecies] {
        AquariumFishEditorPresentation.ownedSpecies(from: player?.ownedFish ?? [])
    }

    private var activeScrollState: AquariumEditorScrollState {
        switch selectedCategory {
        case .fish:
            fishScrollState
        case .decoration:
            decorationScrollState
        case .background:
            backgroundScrollState
        }
    }

    private var editorScrollBar: some View {
        AquariumEditorScrollBar(
            progress: activeScrollState.progress,
            visibleRatio: activeScrollState.visibleRatio,
            isScrollable: activeScrollState.isScrollable,
            isInteractionEnabled: !isCoreTutorialActive,
            accessibilityLabel: "\(selectedCategory.title)一覧のスクロール",
            onProgressChanged: updateActiveScrollProgress
        )
        .frame(width: 36)
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
        .accessibilityHidden(isCoreTutorialActive)
        .accessibilityIdentifier("aquariumEditor.\(selectedCategory.rawValue)ScrollBar")
    }

    private func updateActiveScrollProgress(_ progress: CGFloat) {
        guard !isCoreTutorialActive, progress.isFinite else { return }

        switch selectedCategory {
        case .fish:
            fishScrollState.setProgress(progress)
        case .decoration:
            decorationScrollState.setProgress(progress)
        case .background:
            backgroundScrollState.setProgress(progress)
        }
    }

    @ViewBuilder
    private func fishCard(_ species: FishSpecies) -> some View {
        let ownedCount = player?.ownedFish.count { $0.species == species } ?? 0
        let activeCount = player?.aquariumCount(for: species) ?? 0
        let canDrag = AquariumFishDragAvailability.canBeginDrag(
            ownedCount: ownedCount,
            activeCount: activeCount
        )
        let card = VStack(spacing: 4) {
            AquariumFishDragHandle(
                species: species,
                canDrag: canDrag && (!isCoreTutorialActive || species == .clownfish),
                updateDrag: updateFishDrag,
                finishDrag: finishFishDrag,
                cancelDrag: cancelFishDrag
            )
                .frame(width: 56, height: 38)
                .grayscale(ownedCount == 0 ? 1 : 0)
                .anchorPreference(
                    key: CoreTutorialTargetPreferenceKey.self,
                    value: .bounds
                ) { anchor in
                    species == .clownfish ? [.tutorialClownfish: anchor] : [:]
                }

            Text(species.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(activeCount) / \(ownedCount)")
                .font(.caption2.monospacedDigit())

            Label("水槽へ", systemImage: "arrow.left")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
                .opacity(canDrag ? 1 : 0)
                .accessibilityHidden(!canDrag)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if canDrag {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 9))
                    .padding(5)
            }
        }
        .opacity(ownedCount == 0 ? 0.42 : (canDrag || activeCount > 0 ? 1 : 0.62))
        .accessibilityHidden(isCoreTutorialActive && species != .clownfish)
        .accessibilityIdentifier("aquariumEditor.fish.\(species.rawValue)")

        card
    }

    private var decorationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("水槽へドラッグ")
                .font(.caption.weight(.semibold))

            AquariumEditorControlledScrollView(
                state: $decorationScrollState,
                category: .decoration,
                visibleItemCount: decorationInventory.count
            ) {
                VStack(spacing: 8) {
                    ForEach(decorationInventory) { item in
                        decorationCard(item)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var decorationInventory: [AquariumDecorationInventoryItem] {
        AquariumDecorationEditorPresentation.inventory(from: decorationPlacements)
    }

    @ViewBuilder
    private func decorationCard(_ item: AquariumDecorationInventoryItem) -> some View {
        if let placement = decorationPlacements.first(where: {
            $0.decorationID == item.dragPlacementID
        }) {
            VStack(spacing: 4) {
                AquariumDecorationDragHandle(
                    placement: placement,
                    canDrag: item.canPlaceAnother,
                    updateDrag: updateDecorationDrag,
                    finishDrag: finishDecorationDrag,
                    cancelDrag: cancelDecorationDrag
                )
                .frame(width: 66, height: 54)

                Text(item.kind.displayName)
                    .font(.caption2.weight(.semibold))

                Text("\(item.placedCount) / \(item.ownedCount)")
                    .font(.caption2.monospacedDigit())

                Label("水槽へ", systemImage: "arrow.left")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(item.canPlaceAnother ? 1 : 0)
                    .accessibilityHidden(!item.canPlaceAnother)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("aquariumEditor.decoration.\(item.kind.rawValue)")
            .opacity(item.canPlaceAnother ? 1 : 0.62)
        }
    }

    private var backgroundEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タップして背景を選択")
                .font(.caption.weight(.semibold))

            AquariumEditorControlledScrollView(
                state: $backgroundScrollState,
                category: .background,
                visibleItemCount: availableBackgroundThemes.count
            ) {
                VStack(spacing: 8) {
                    ForEach(availableBackgroundThemes) { theme in
                        backgroundCard(theme)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var availableBackgroundThemes: [AquariumBackgroundTheme] {
        AquariumBackgroundTheme.allCases
    }

    private func backgroundCard(_ theme: AquariumBackgroundTheme) -> some View {
        let isSelected = selectedBackgroundTheme == theme
        return Button {
            selectBackground(theme)
        } label: {
            VStack(spacing: 5) {
                LinearGradient(
                    colors: theme.fallbackColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .blue)
                            .padding(4)
                    }
                }

                Text(theme.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(6)
            .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(isCoreTutorialActive)
        .accessibilityHidden(isCoreTutorialActive)
        .accessibilityIdentifier("aquariumEditor.background.\(theme.rawValue)")
        .accessibilityValue(isSelected ? "選択中" : "未選択")
    }

    private func categoryButton(_ category: AquariumEditorCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedCategory = category
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: category.systemImage)
                    .font(.caption.weight(.bold))
                Text(category.title)
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 36, height: 48)
            .background(
                isSelected ? Color.blue.opacity(0.88) : Color.white.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .disabled(isCoreTutorialActive)
        .accessibilityHidden(isCoreTutorialActive)
        .accessibilityLabel(category.title)
        .accessibilityIdentifier("aquariumEditor.category.\(category.rawValue)")
    }
}

private struct AquariumEditorScrollBar: View {
    let progress: CGFloat
    let visibleRatio: CGFloat
    let isScrollable: Bool
    let isInteractionEnabled: Bool
    let accessibilityLabel: String
    let onProgressChanged: (CGFloat) -> Void

    @State private var dragStartProgress: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = geometry.size.height
            let proportionalThumbHeight = resolvedThumbHeight(for: trackHeight)
            let movementThumbExtent = min(
                proportionalThumbHeight,
                AquariumEditorScrollBarLayout.minimumThumbHeight
            )
            let travel = max(trackHeight - movementThumbExtent, 0)
            let thumbCenterY = movementThumbExtent / 2 + travel * clampedProgress

            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.16),
                                .cyan.opacity(0.34),
                                .white.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, movementThumbExtent / 2)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.12), lineWidth: 0.5)
                            .frame(width: 4)
                            .padding(.vertical, movementThumbExtent / 2)
                    }

                Color.clear
                    .frame(width: 36, height: movementThumbExtent)
                    .contentShape(Rectangle())
                    .overlay {
                        Image(systemName: "fish.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .cyan.opacity(0.88)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .rotationEffect(fishRotation)
                            .scaleEffect(isDragging ? 1.12 : 1)
                            .opacity(isDragging ? 1 : 0.86)
                            .shadow(
                                color: .cyan.opacity(isDragging ? 0.58 : 0.24),
                                radius: isDragging ? 6 : 2,
                                y: 0
                            )
                            .animation(.easeOut(duration: 0.14), value: isDragging)
                    }
                    .position(x: geometry.size.width / 2, y: thumbCenterY)
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                guard travel > 0,
                                      isScrollable,
                                      isInteractionEnabled else {
                                    return
                                }
                                let startProgress = dragStartProgress ?? clampedProgress
                                if dragStartProgress == nil {
                                    dragStartProgress = startProgress
                                }
                                onProgressChanged(
                                    min(max(
                                        startProgress + value.translation.height / travel,
                                        0
                                    ), 1)
                                )
                            }
                            .onEnded { _ in
                                dragStartProgress = nil
                            },
                        isEnabled: isScrollable && isInteractionEnabled
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(
            isInteractionEnabled
                ? (isScrollable ? 1 : 0.45)
                : 0.35
        )
        .allowsHitTesting(isScrollable && isInteractionEnabled)
        .accessibilityElement()
        .accessibilityHidden(!isScrollable || !isInteractionEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int(clampedProgress * 100))パーセント")
        .accessibilityAdjustableAction { direction in
            guard isScrollable, isInteractionEnabled else { return }
            switch direction {
            case .increment:
                onProgressChanged(min(clampedProgress + 0.1, 1))
            case .decrement:
                onProgressChanged(max(clampedProgress - 0.1, 0))
            @unknown default:
                break
            }
        }
    }

    private var clampedProgress: CGFloat {
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    private var isDragging: Bool {
        dragStartProgress != nil
    }

    private var fishRotation: Angle {
        .degrees(Double((clampedProgress - 0.5) * 40))
    }

    private func resolvedThumbHeight(for trackHeight: CGFloat) -> CGFloat {
        AquariumEditorScrollBarLayout.thumbHeight(
            for: visibleRatio,
            trackHeight: trackHeight
        )
    }
}

private struct AquariumDecorationDragHandle: View {
    let placement: AquariumDecorationPlacement
    let canDrag: Bool
    let updateDrag: (String, CGPoint) -> Void
    let finishDrag: (String, CGPoint) -> Void
    let cancelDrag: () -> Void

    @State private var dragIntent: AquariumFishDragIntent?

    var body: some View {
        AquariumDecorationView(decoration: placement.decoration)
            .scaleEffect(0.42)
            .padding(AquariumFishDragInteraction.hitAreaExpansion)
            .contentShape(Rectangle())
            .simultaneousGesture(decorationDragGesture, isEnabled: canDrag)
            .padding(-AquariumFishDragInteraction.hitAreaExpansion)
            .accessibilityHint(canDrag ? "左へ滑らせて水槽へ追加" : "すでに水槽へ配置中です")
    }

    private var decorationDragGesture: some Gesture {
        DragGesture(
            minimumDistance: AquariumFishDragInteraction.minimumDistance,
            coordinateSpace: .named(AquariumEditorCoordinateSpace.name)
        )
        .onChanged { value in
            if dragIntent == nil {
                dragIntent = AquariumFishDragInteraction.intent(for: value.translation)
            }
            guard dragIntent == .aquarium else { return }
            updateDrag(placement.decorationID, value.location)
        }
        .onEnded { value in
            defer { dragIntent = nil }
            guard dragIntent == .aquarium else {
                cancelDrag()
                return
            }
            finishDrag(placement.decorationID, value.location)
        }
    }
}

struct AquariumDecorationDragPreview: View {
    let decoration: AquariumDecoration

    var body: some View {
        AquariumDecorationView(decoration: decoration)
            .scaleEffect(0.72)
            .frame(width: 110, height: 110)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct AquariumFishDragHandle: View {
    let species: FishSpecies
    let canDrag: Bool
    let updateDrag: (FishSpecies, CGPoint) -> Void
    let finishDrag: (FishSpecies, CGPoint) -> Void
    let cancelDrag: () -> Void

    @State private var dragIntent: AquariumFishDragIntent?

    var body: some View {
        FishImageView(species: species)
            .padding(AquariumFishDragInteraction.hitAreaExpansion)
            .contentShape(Rectangle())
            .highPriorityGesture(fishDragGesture, isEnabled: canDrag)
            .padding(-AquariumFishDragInteraction.hitAreaExpansion)
            .accessibilityHint(canDrag ? "左へ滑らせて水槽へ追加" : "水槽へ追加できません")
    }

    private var fishDragGesture: some Gesture {
        DragGesture(
            minimumDistance: AquariumFishDragInteraction.minimumDistance,
            coordinateSpace: .named(AquariumEditorCoordinateSpace.name)
        )
        .onChanged { value in
            if dragIntent == nil {
                dragIntent = AquariumFishDragInteraction.intent(for: value.translation)
            }
            guard dragIntent == .aquarium else { return }
            updateDrag(species, value.location)
        }
        .onEnded { value in
            defer { dragIntent = nil }
            guard dragIntent == .aquarium else {
                cancelDrag()
                return
            }
            finishDrag(species, value.location)
        }
    }
}

struct AquariumFishDragPreview: View {
    let species: FishSpecies

    private var previewSize: CGFloat {
        AquariumFishDragPresentation.previewSize(for: species)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            FishImageView(
                species: species,
                animationTime: timeline.date.timeIntervalSinceReferenceDate,
                animationFrameDuration: AquariumFishDragPresentation.frameDuration(for: species)
            )
            .frame(width: previewSize, height: previewSize)
        }
        .frame(width: previewSize, height: previewSize)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
