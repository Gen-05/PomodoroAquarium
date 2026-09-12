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
    static let excludedDropTopHeight: CGFloat = 52
    static let excludedDropBottomHeight: CGFloat = 82

    static func width(for screenWidth: CGFloat) -> CGFloat {
        min(max(screenWidth * widthRatio, minimumWidth), maximumWidth)
    }

    static func aquariumWidth(for screenWidth: CGFloat, isEditing: Bool) -> CGFloat {
        max(screenWidth - (isEditing ? width(for: screenWidth) : 0), 1)
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

struct AquariumFishDragSession: Equatable {
    let species: FishSpecies
    var location: CGPoint
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
        case background
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

    static func background(_ theme: AquariumBackgroundTheme) -> Self {
        Self(kind: .background, identifier: theme.rawValue)
    }

    var fishSpecies: FishSpecies? {
        guard kind == .fish else { return nil }
        return FishSpecies(rawValue: identifier)
    }

    var backgroundTheme: AquariumBackgroundTheme? {
        guard kind == .background else { return nil }
        return AquariumBackgroundTheme(rawValue: identifier)
    }
}

@MainActor
enum AquariumEditorDropCoordinator {
    static func addFish(from item: AquariumEditorDragItem, to player: Player) -> Bool {
        guard let species = item.fishSpecies else { return false }
        return player.addOneFishToAquarium(species: species)
    }

    static func completeFishDrag(
        species: FishSpecies,
        at location: CGPoint,
        aquariumSize: CGSize,
        player: Player
    ) -> Bool {
        guard AquariumSideEditorLayout.acceptsDrop(
            at: location,
            in: aquariumSize
        ) else { return false }
        return player.addOneFishToAquarium(species: species)
    }

    static func placeDecoration(
        from item: AquariumEditorDragItem,
        placement: AquariumDecorationPlacement,
        at location: CGPoint,
        aquariumSize: CGSize,
        in context: ModelContext
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
            in: context
        )
    }

    static func backgroundTheme(
        from item: AquariumEditorDragItem
    ) -> AquariumBackgroundTheme? {
        item.backgroundTheme
    }
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
    let finishEditing: () -> Void

    private var contentWidth: CGFloat {
        max(panelWidth - AquariumSideEditorLayout.categoryTabWidth, 80)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("編集")
                        .font(.headline)
                    Spacer(minLength: 0)
                    Button(action: finishEditing) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("水槽編集を終了")
                }

                editorContent
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(width: contentWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(.ultraThinMaterial)

            VStack(spacing: 8) {
                ForEach(AquariumEditorCategory.allCases) { category in
                    categoryButton(category)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
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

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(FishSpecies.allCases) { species in
                        fishCard(species)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private func fishCard(_ species: FishSpecies) -> some View {
        let ownedCount = player?.ownedFish.count { $0.species == species } ?? 0
        let activeCount = player?.aquariumCount(for: species) ?? 0
        let canAdd = ownedCount > activeCount &&
            (player?.activeAquariumFish.count ?? 0) < AquariumDisplayLimits.maxFishCount
        let card = VStack(spacing: 4) {
            AquariumFishDragHandle(
                species: species,
                canDrag: canAdd,
                updateDrag: updateFishDrag,
                finishDrag: finishFishDrag,
                cancelDrag: cancelFishDrag
            )
                .frame(width: 56, height: 38)
                .grayscale(ownedCount == 0 ? 1 : 0)

            Text(species.name)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(activeCount) / \(ownedCount)")
                .font(.caption2.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if canAdd {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 9))
                    .padding(5)
            }
        }
        .opacity(ownedCount == 0 ? 0.42 : (canAdd || activeCount > 0 ? 1 : 0.62))
        .accessibilityIdentifier("aquariumEditor.fish.\(species.rawValue)")

        card
    }

    private var decorationEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("水槽へドラッグ")
                .font(.caption.weight(.semibold))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(decorationPlacements) { placement in
                        decorationCard(placement)
                    }

                    ForEach(unownedDecorationKinds, id: \.rawValue) { kind in
                        lockedDecorationCard(kind)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var unownedDecorationKinds: [AquariumDecorationKind] {
        let ownedKinds = Set(decorationPlacements.map(\.kind))
        return AquariumDecorationKind.allCases.filter { !ownedKinds.contains($0) }
    }

    private func decorationCard(_ placement: AquariumDecorationPlacement) -> some View {
        VStack(spacing: 4) {
            AquariumDecorationView(decoration: placement.decoration)
                .scaleEffect(0.42)
                .frame(width: 66, height: 54)

            Text(placement.kind.displayName)
                .font(.caption2.weight(.semibold))

            Text(placement.isPlaced ? "配置中" : "収納中")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("aquariumEditor.decoration.\(placement.decorationID)")
        .draggable(AquariumEditorDragItem.decoration(id: placement.decorationID)) {
            AquariumDecorationView(decoration: placement.decoration)
                .scaleEffect(0.55)
                .frame(width: 86, height: 72)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func lockedDecorationCard(_ kind: AquariumDecorationKind) -> some View {
        VStack(spacing: 5) {
            Image(systemName: kind.storageIconName)
                .font(.title2)
            Text(kind.displayName)
                .font(.caption2.weight(.semibold))
            Label("未所持", systemImage: "lock.fill")
                .font(.system(size: 9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .grayscale(1)
        .opacity(0.42)
    }

    private var backgroundEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("水槽へドラッグ")
                .font(.caption.weight(.semibold))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(AquariumBackgroundTheme.allCases) { theme in
                        backgroundCard(theme)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func backgroundCard(_ theme: AquariumBackgroundTheme) -> some View {
        let isSelected = selectedBackgroundTheme == theme
        return VStack(spacing: 5) {
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
        }
        .padding(6)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("aquariumEditor.background.\(theme.rawValue)")
        .draggable(AquariumEditorDragItem.background(theme)) {
            LinearGradient(
                colors: theme.fallbackColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 100, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
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
        .accessibilityLabel(category.title)
        .accessibilityIdentifier("aquariumEditor.category.\(category.rawValue)")
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
            .contentShape(Rectangle())
            .simultaneousGesture(fishDragGesture, isEnabled: canDrag)
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
