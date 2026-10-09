import SwiftUI

/// 所持・配置数は既存データを使用。水槽と同じ階層に置いてdrag元を保持する。
struct AquariumEditorSheet: View {
    let placements: [AquariumDecorationPlacement]
    let player: Player?
    let backgroundTheme: AquariumBackgroundTheme
    let editorCategory: AquariumEditorCategory
    let selectedFishID: UUID?
    @Binding var showsActiveFish: Bool
    let addDecoration: (String) -> Void
    let selectPlacement: (String) -> Void
    let addFish: (FishSpecies) -> Void
    let storeFish: (UUID) -> Void
    let selectFish: (UUID) -> Void
    let close: () -> Void
    let selectBackground: (AquariumBackgroundTheme) -> Void
    var storeAllFish: () -> Void = {}
    var storeAllDecorations: () -> Void = {}
    @State private var bulkStorageConfirmation: AquariumEditorBulkStorage?
    @State private var category: AquariumDecorationCategory?
    @State private var showsPlaced = false

    private var inventory: [AquariumDecorationInventoryItem] {
        AquariumDecorationEditorPresentation.inventory(from: placements)
    }
    private var kinds: [AquariumDecorationKind] {
        AquariumDecorationKind.allCases.filter { kind in
            (kind.stars != nil || inventory.contains { item in item.kind == kind }) &&
            (category == nil || kind.category == category)
        }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(editorCategory == .fish ? "魚" : editorCategory == .decoration ? "装飾" : "背景").font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark").frame(width: 44, height: 44) }
                    .accessibilityLabel("一覧を閉じる").accessibilityIdentifier("aquariumEditor.closeLibrary")
            }.padding(.horizontal, 16)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    if editorCategory == .decoration {
                        decorationContent
                    } else if editorCategory == .fish {
                        fishContent
                    } else {
                        ForEach(AquariumBackgroundTheme.allCases, id: \.self) { theme in
                            Button { selectBackground(theme) } label: {
                                HStack {
                                    Image(theme.imageName).resizable().scaledToFill().frame(width: 70, height: 65).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(theme.displayName)
                                    Spacer()
                                    if theme == backgroundTheme { Image(systemName: "checkmark") }
                                }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(16)
            }
            .scrollIndicators(.visible)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.78, green: 0.94, blue: 0.98).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("aquariumEditor.fullScreenLibrary")
        .alert(bulkStorageConfirmation == .fish ? "魚を全部しまいますか？" : "装飾を全部しまいますか？",
               isPresented: Binding(get: { bulkStorageConfirmation != nil }, set: { if !$0 { bulkStorageConfirmation = nil } }),
               presenting: bulkStorageConfirmation) { target in
            Button("キャンセル", role: .cancel) { bulkStorageConfirmation = nil }
            Button("全部しまう") {
                bulkStorageConfirmation = nil
                if target == .fish { storeAllFish() }
                else if target == .decorations { storeAllDecorations() }
            }
        } message: { target in
            if target == .fish {
                Text("水槽にいる魚\(player?.activeAquariumFish.count ?? 0)匹をすべてしまいます。\n所持している魚は失われません。")
            } else {
                Text("配置済みの装飾\(placements.filter(\.isPlaced).count)個をすべてしまいます。\n所持している装飾は失われません。")
            }
        }
    }

    private var fishContent: some View {
        VStack(spacing: 12) {
            Picker("魚一覧", selection: $showsActiveFish) {
                Text("追加する").tag(false)
                Text("水槽にいる魚").tag(true)
            }.pickerStyle(.segmented)
            if let player {
                Text("水槽 \(player.activeAquariumFish.count) / \(AquariumDisplayLimits.maxFishCount)匹").font(.caption)
                if showsActiveFish {
                    bulkStorageButton(.fish, count: player.activeAquariumFish.count)
                    if player.activeAquariumFish.isEmpty {
                        Text("水槽に魚がいません").font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("aquariumEditor.emptyFish")
                    }
                    ForEach(AquariumFishEditorPresentation.ownedSpecies(from: player.activeAquariumFish), id: \.self) { species in
                        VStack(alignment: .leading) {
                            Text("\(species.name)・水槽 \(player.aquariumCount(for: species))匹").font(.subheadline.bold())
                            ForEach(Array(player.activeAquariumFish.filter { $0.species == species }.enumerated()), id: \.element.id) { index, fish in
                                HStack {
                                    Button { selectFish(fish.id) } label: {
                                        HStack {
                                            let thumbnailSize = AquariumEditorFishThumbnailLayout.imageSize(for: species, isPlacedList: true)
                                            FishImageView(species: species)
                                                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                                                .frame(width: 60, height: 50)
                                            Text("\(species.name) \(index + 1)").font(.caption)
                                            Spacer(minLength: 0)
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.cyan).opacity(selectedFishID == fish.id ? 1 : 0)
                                        }
                                        .padding(6)
                                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }.buttonStyle(.plain)
                                    .accessibilityIdentifier("aquariumEditor.selectFish.\(fish.id.uuidString)")
                                    Button("水槽から戻す") { storeFish(fish.id) }
                                        .padding(.horizontal, 6).frame(minHeight: 56).font(.caption.bold())
                                        .accessibilityIdentifier("aquariumEditor.storeFish.\(fish.id.uuidString)")
                                }
                                .background(selectedFishID == fish.id ? Color.cyan.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedFishID == fish.id ? Color.cyan : .clear, lineWidth: 1.5))
                                .accessibilityValue(selectedFishID == fish.id ? "選択中" : "")
                            }
                        }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                } else {
                    Text("追加する魚をタップ").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                        ForEach(AquariumFishEditorPresentation.ownedSpecies(from: player.ownedFish), id: \.self) { species in
                            let counts = AquariumFishEditing.counts(species, player: player)
                            Button { addFish(species) } label: {
                            VStack(spacing: 6) {
                                let imageSize = AquariumEditorFishThumbnailLayout.imageSize(for: species)
                                FishImageView(species: species)
                                    .frame(width: imageSize.width, height: imageSize.height)
                                    .frame(width: 112, height: 86)
                                Text(species.name).font(.subheadline)
                                Text("所持 \(counts.owned)匹").font(.caption)
                                Text("水槽 \(counts.active) / \(counts.owned)").font(.caption)
                                Text("残り \(counts.available)匹").font(.caption)
                            }.frame(maxWidth: .infinity).padding(12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle()).opacity(counts.available > 0 && player.activeAquariumFish.count < AquariumDisplayLimits.maxFishCount ? 1 : 0.45)
                            }.buttonStyle(.plain)
                            .disabled(counts.available == 0 || player.activeAquariumFish.count >= AquariumDisplayLimits.maxFishCount)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("aquariumEditor.dragFish.\(species.rawValue)")
                            .background { if species == .clownfish { Color.clear.coreTutorialTarget(.tutorialClownfish) } }
                            .accessibilityHint("タップして水槽へ追加")
                        }
                    }
                }
            }
        }
    }

    private var decorationContent: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    categoryButton(nil, name: "すべて")
                    categoryButton(.plant, name: "海藻")
                    categoryButton(.rock, name: "岩")
                    categoryButton(.coral, name: "サンゴ")
                    categoryButton(.object, name: "その他")
                }
            }
            Picker("装飾一覧", selection: $showsPlaced) {
                Text("追加する").tag(false)
                Text("配置済み").tag(true)
            }.pickerStyle(.segmented)
            if showsPlaced {
                bulkStorageButton(.decorations, count: placements.filter(\.isPlaced).count)
                if !placements.contains(where: { $0.isPlaced }) {
                    Text("配置済みの装飾はありません").font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("aquariumEditor.emptyDecorations")
                }
                ForEach(placements.filter { $0.isPlaced && (category == nil || $0.kind.category == category) }) { placement in
                    Button { selectPlacement(placement.decorationID) } label: {
                        HStack {
                            thumbnail(placement.kind)
                            Text(placement.kind.displayName).font(.subheadline)
                            Spacer()
                            Image(systemName: "scope")
                        }.padding(8).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain)
                    .accessibilityIdentifier("aquariumEditor.selectPlaced.\(placement.decorationID)")
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                    ForEach(kinds, id: \.self) { kind in
                        let item = inventory.first { $0.kind == kind }
                        let remaining = (item?.ownedCount ?? 0) - (item?.placedCount ?? 0)
                        Button {
                            if let item, remaining > 0 { addDecoration(item.dragPlacementID) }
                        } label: {
                            VStack(spacing: 6) {
                                thumbnail(kind)
                                Text(kind.displayName).font(.caption).multilineTextAlignment(.center).frame(minHeight: 30)
                                Text(String(repeating: "★", count: kind.stars ?? 0)).font(.caption).foregroundStyle(.yellow)
                                Text("残り \(remaining) / \(item?.ownedCount ?? 0)").font(.caption)
                            }.frame(maxWidth: .infinity).padding(10)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).disabled(remaining <= 0).opacity(remaining > 0 ? 1 : 0.45)
                        .accessibilityIdentifier("aquariumEditor.add.\(kind.rawValue)")
                    }
                }
            }
        }
    }
    private func bulkStorageButton(_ target: AquariumEditorBulkStorage, count: Int) -> some View {
        Button { bulkStorageConfirmation = target } label: {
            Label(target == .fish ? "魚を全部しまう" : "装飾を全部しまう", systemImage: "tray.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).disabled(count == 0).opacity(count == 0 ? 0.4 : 1)
        .accessibilityIdentifier(target == .fish ? "aquariumEditor.storeAllFish" : "aquariumEditor.storeAllDecorations")
    }

    private func thumbnail(_ kind: AquariumDecorationKind) -> some View {
        AquariumDecorationView(decoration: AquariumDecoration(id: kind.rawValue, kind: kind, relativeX: 0.5, relativeY: 0.9, scale: 1), backgroundTheme: backgroundTheme)
            .scaleEffect(0.42).frame(width: 75, height: 65).allowsHitTesting(false)
    }
    private func categoryButton(_ value: AquariumDecorationCategory?, name: String) -> some View {
        Button { category = value } label: {
            Text(name).font(.subheadline).padding(.horizontal, 14).frame(minHeight: 44)
                .background(category == value ? Color.cyan.opacity(0.25) : Color.secondary.opacity(0.12), in: Capsule())
        }.buttonStyle(.plain)
    }
}

/// 編集一覧専用。図鑑で使う素材の透明余白比率を参照し、魚体の存在感を調整する。
enum AquariumEditorFishThumbnailLayout {
    static let viewport = CGSize(width: 112, height: 86)
    static func imageSize(for species: FishSpecies, isPlacedList: Bool = false) -> CGSize {
        let length: CGFloat
        switch species {
        case .clownfish: length = 34
        case .seahorse: length = 38
        case .pufferfish: length = 46
        case .jellyfish: length = 50
        case .manta: length = 74
        case .whaleShark: length = 100
        }
        let ratio = FishDetailImageLayout.visibleContentRatio(for: species)
        let canvas = length / max(ratio.width, ratio.height)
        let factor: CGFloat = isPlacedList ? 0.52 : 1
        return CGSize(width: canvas * factor, height: canvas * factor)
    }
}
