import SwiftUI

/// 複数獲得の表示進行だけを制御する。魚の付与・保存とは独立。
struct FishRewardSequenceHooks {
    let startsAutomatically: Bool
    let onPresentationFinished: () -> Void
    let onAdvance: () -> Void
}

struct MultipleFishRewardView: View {
    let results: [FishAcquisitionResult]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var autoAdvanceTask: Task<Void, Never>?

    var body: some View {
        Group {
            if currentIndex < results.count {
                let index = currentIndex
                FishRewardView(
                    result: results[index],
                    sequence: FishRewardSequenceHooks(
                        startsAutomatically: index > 0,
                        onPresentationFinished: { finishPresentation(at: index) },
                        onAdvance: { advance(from: index) }
                    )
                )
                .id(index)
                // overlayは1匹Viewの提案サイズ・padding・魚frameを変更しない。
                .overlay(alignment: .topTrailing) {
                    Text("\(index + 1) / \(results.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 14)
                        .padding(.trailing, 24)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("閉じる")
                    .padding(.leading, 12)
                }
            } else {
                MultipleFishRewardSummary(results: results)
            }
        }
        .onDisappear {
            autoAdvanceTask?.cancel()
            autoAdvanceTask = nil
        }
    }

    private func finishPresentation(at index: Int) {
        guard currentIndex == index, !results[index].isNewFish else { return }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(0.3)) } catch { return }
            guard !Task.isCancelled else { return }
            advance(from: index)
        }
    }

    private func advance(from index: Int) {
        // ボタン/画面tap/完了callbackが重なっても、同じ魚からは一度だけ進む。
        guard currentIndex == index else { return }
        autoAdvanceTask?.cancel()
        autoAdvanceTask = nil
        currentIndex += 1
    }
}

private struct MultipleFishRewardSummary: View {
    let results: [FishAcquisitionResult]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var labelHeight: CGFloat = 72

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        switch results.count {
        case 4: return 2
        case 5...6: return 3
        case 7...8: return 4
        default: return max(1, results.count)
        }
    }

    private var rowCount: Int { max(1, (results.count + columnCount - 1) / columnCount) }

    var body: some View {
        GeometryReader { screen in
            // 1匹Viewの横24pt paddingとstage寸法をそのまま基準にする。
            let stageSize = CGSize(
                width: max(0, screen.size.width - 48),
                height: FishRewardImageLayout.stageHeight
            )
            let baselineSizes = results.map {
                FishRewardImageLayout.displaySize(from: FishRewardImageLayout.detailDisplaySize(
                    for: $0.species, stageSize: stageSize
                ))
            }
            let maximumSize = baselineSizes.max() ?? FishDetailImageLayout.minimumPreferredSize
            let minimumContentHeight = CGFloat(rowCount) * (FishDetailImageLayout.minimumPreferredSize + labelHeight)
                + CGFloat(rowCount - 1) * 24 + 200

            let content = VStack(spacing: 24) {
                Text("今回の獲得 \(results.count)匹")
                    .font(.title.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                GeometryReader { area in
                    let cellWidth = max(0, (area.size.width - CGFloat(columnCount - 1) * 12) / CGFloat(columnCount))
                    let imageHeight = max(0, (area.size.height - CGFloat(rowCount - 1) * 24) / CGFloat(rowCount) - labelHeight)
                    // 全魚に同じ倍率。幅/高さ両方に収まる場合は必ず1.0を維持。
                    let uniformScale = max(0, min(1, cellWidth / maximumSize, imageHeight / maximumSize))
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount),
                        spacing: 24
                    ) {
                        ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                            MultipleFishSummaryCell(
                                result: result,
                                baselineSize: baselineSizes[index],
                                uniformScale: uniformScale,
                                imageRowHeight: maximumSize * uniformScale,
                                glowDiameter: min(cellWidth * 0.9, maximumSize * uniformScale * 1.25),
                                labelHeight: labelHeight
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Button("閉じる") { dismiss() }
                    .buttonStyle(AquariumStudyStartButtonStyle())
                    .frame(maxWidth: 260)
                    .accessibilityIdentifier("rewardPreview.multipleFish.close")
            }
                .frame(maxWidth: .infinity)
                // 通常文字サイズはviewport内に固定。スクロールで魚数を逃がさない。
                .frame(height: dynamicTypeSize.isAccessibilitySize
                    ? max(screen.size.height - 48, minimumContentHeight)
                    : max(0, screen.size.height - 48))
                .padding(24)

            if dynamicTypeSize.isAccessibilitySize {
                // 大きなアクセシビリティ文字だけ、文字の切れを防ぐ既存fallbackを維持。
                ScrollView { content }
                    .scrollIndicators(.hidden)
            } else {
                content
            }
        }
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: FishRewardMysteryAppearance.backgroundColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

private struct MultipleFishSummaryCell: View {
    let result: FishAcquisitionResult
    let baselineSize: CGFloat
    let uniformScale: CGFloat
    let imageRowHeight: CGFloat
    let glowDiameter: CGFloat
    let labelHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            FishImageView(
                species: result.species,
                fallbackSystemName: "fish.fill",
                fallbackColor: result.rarity.rewardColor
            )
            .frame(width: baselineSize * uniformScale, height: baselineSize * uniformScale)
            .frame(height: imageRowHeight)
            .background {
                MultipleFishSummaryGlow(rarity: result.rarity, diameter: glowDiameter)
            }

            VStack(spacing: 4) {
                Text(result.rarity.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.rarity.rewardColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(result.fishName)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if result.isNewFish {
                    Text("NEW!")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(height: labelHeight, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// まとめ専用の静かなグロー。背景だけを描き、魚のframe/倍率には関与しない。
private struct MultipleFishSummaryGlow: View {
    let rarity: FishRarity
    let diameter: CGFloat

    @State private var hasAppeared = false

    private var intensity: Double {
        switch rarity {
        case .common: 0.10
        case .rare: 0.24
        case .epic: 0.30
        case .legendary: 0.40
        }
    }

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(intensity * 0.22), location: 0),
                .init(color: rarity.rewardColor.opacity(intensity), location: 0.22),
                .init(color: rarity.rewardColor.opacity(intensity * 0.36), location: 0.58),
                .init(color: .clear, location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: max(diameter / 2, 0.01)
        )
        .frame(width: diameter, height: diameter)
        // 楕円化するのは背景光だけ。各cell幅と魚row内に収まり、隣へ大きく被らない。
        .scaleEffect(x: 1, y: 0.72)
        .frame(height: diameter * 0.72)
        .opacity(hasAppeared ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            withAnimation(.easeOut(duration: 0.3)) { hasAppeared = true }
        }
    }
}
