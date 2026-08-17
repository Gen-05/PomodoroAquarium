//
//  HomeView.swift
//  PomodoroAquarium
//
//  Created by 阿部弦生 on 2026/07/11.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    
    @AppStorage("studyTime") private var studyTime = "25"
    @AppStorage("breakTime") private var breakTime = "5"
    @AppStorage("lastStudyDate") private var lastStudyDate = ""
    @AppStorage(AquariumThemeStore.storageKey)
    private var backgroundThemeRawValue = AquariumBackgroundTheme.aquarium.rawValue
    
    @Environment(\.modelContext) private var modelContext
    
    @Query private var players: [Player]
    @Query private var decorationPlacements: [AquariumDecorationPlacement]
    @State private var showsInterruptionBanner = false
    @State private var resumesPersistedTimer = false
    @State private var isEditingAquarium = false
    @State private var isEditingDecoration = false
    @State private var showsDecorationStorage = false
    @State private var decorationRestoreRequestID: String?
    @State private var selectedDecorationCategory: AquariumDecorationCategory?
    @State private var showsBackgroundThemePicker = false
    @State private var originalBackgroundTheme: AquariumBackgroundTheme?
    @State private var previewBackgroundTheme: AquariumBackgroundTheme?
    
    private var player: Player? {
        players.first
    }

    private var storedDecorations: [AquariumDecorationPlacement] {
        AquariumDecorationService.storedPlacements(from: decorationPlacements)
    }

    private var filteredStoredDecorations: [AquariumDecorationPlacement] {
        AquariumDecorationService.storedPlacements(
            from: decorationPlacements,
            category: selectedDecorationCategory
        )
    }

    private var savedBackgroundTheme: AquariumBackgroundTheme {
        AquariumThemeStore.theme(from: backgroundThemeRawValue)
    }

    private var displayedBackgroundTheme: AquariumBackgroundTheme {
        previewBackgroundTheme ?? savedBackgroundTheme
    }

    var body: some View {
        NavigationStack{
            ZStack {
                AquariumView(
                    player: player,
                    backgroundTheme: displayedBackgroundTheme,
                    isEditing: isEditingAquarium,
                    onDecorationEditingChanged: updateDecorationEditingState,
                    decorationRestoreRequestID: decorationRestoreRequestID,
                    onDecorationRestoreRequestHandled: {
                        decorationRestoreRequestID = nil
                    }
                )
                
                VStack(spacing: 20) {
                    if showsInterruptionBanner {
                        interruptionBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    if isEditingAquarium {
                        if !isEditingDecoration &&
                            !showsDecorationStorage &&
                            !showsBackgroundThemePicker {
                            Group {
                                Text("水草や岩をタップして移動できます")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .aquariumGlass(cornerRadius: 16)

                                HStack(spacing: 12) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            showsDecorationStorage = true
                                        }
                                    } label: {
                                        Label("収納", systemImage: "shippingbox.fill")
                                    }
                                    .buttonStyle(AquariumSecondaryButtonStyle())

                                    Button {
                                        beginBackgroundThemeEditing()
                                    } label: {
                                        Label("背景", systemImage: "photo.fill")
                                    }
                                    .buttonStyle(AquariumSecondaryButtonStyle())

                                    Button("完了") {
                                        withAnimation { isEditingAquarium = false }
                                    }
                                    .buttonStyle(AquariumPrimaryButtonStyle())
                                }
                            }
                            .transition(.opacity)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Text("今日の勉強時間")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            Text("\((player?.todayStudyMinutes ?? 0) / 60)時間\((player?.todayStudyMinutes ?? 0) % 60)分")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .aquariumGlass(cornerRadius: 18)

                        Button {
                            withAnimation { isEditingAquarium = true }
                        } label: {
                            Label("水槽編集", systemImage: "move.3d")
                        }
                        .buttonStyle(AquariumSecondaryButtonStyle())

                        NavigationLink {
                            TimerView(
                                studyTime: Int(studyTime) ?? 25,
                                breakTime: Int(breakTime) ?? 5,
                                player: player
                            )
                        } label: {
                            Label("勉強をはじめる", systemImage: "timer")
                        }
                        .buttonStyle(AquariumPrimaryButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                if showsDecorationStorage {
                    decorationStorageOverlay
                        .zIndex(20)
                }

                if showsBackgroundThemePicker {
                    backgroundThemePickerOverlay
                        .zIndex(21)
                }
            }
            .navigationTitle("ポモドーロ水族館")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        BookView()
                    } label: {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.16), in: Circle())
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(
                            studyTime: $studyTime,
                            breakTime: $breakTime
                        )
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.16), in: Circle())
                    }
                }
            }
            .navigationDestination(isPresented: $resumesPersistedTimer) {
                TimerView(
                    studyTime: Int(studyTime) ?? 25,
                    breakTime: Int(breakTime) ?? 5,
                    player: player
                )
            }
        }
        .onAppear {
            inspectPersistedTimerSession()
            let now = Date()
            let calendar = Calendar.current
            let today = DateFormatter.yyyyMMdd.string(from: now)

            let currentPlayer: Player
            if let player {
                currentPlayer = player
            } else {
                let newPlayer = Player()
                modelContext.insert(newPlayer)
                currentPlayer = newPlayer
            }

            if lastStudyDate.isEmpty {
                lastStudyDate = today
            } else if let lastDate = DateFormatter.yyyyMMdd.date(from: lastStudyDate),
                      !calendar.isDate(lastDate, inSameDayAs: now) {
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)

                if let yesterday,
                   calendar.isDate(lastDate, inSameDayAs: yesterday) {
                    currentPlayer.yesterdayStudyMinutes = currentPlayer.todayStudyMinutes
                } else {
                    currentPlayer.yesterdayStudyMinutes = 0
                }

                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            } else if DateFormatter.yyyyMMdd.date(from: lastStudyDate) == nil {
                currentPlayer.yesterdayStudyMinutes = 0
                currentPlayer.todayStudyMinutes = 0
                lastStudyDate = today
            }
        }
    }

    private var decorationStorageOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { closeDecorationStorage() }

                decorationStoragePanel
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height * 0.31)
                    .background(.ultraThinMaterial)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            topTrailingRadius: 24
                        )
                    )
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.45))
                            .frame(width: 42, height: 5)
                            .padding(.top, 8)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 18, y: -6)
                    .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
    }

    private var decorationStoragePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("装飾の収納", systemImage: "shippingbox.fill")
                    .font(.headline)
                Spacer()
                Button(action: closeDecorationStorage) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryButton(title: "すべて", category: nil)
                    ForEach(AquariumDecorationCategory.allCases) { category in
                        categoryButton(title: category.displayName, category: category)
                    }
                }
            }

            if filteredStoredDecorations.isEmpty {
                ContentUnavailableView(
                    storedDecorations.isEmpty
                        ? "収納中の装飾はありません"
                        : "このカテゴリの装飾はありません",
                    systemImage: "shippingbox"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(filteredStoredDecorations) { placement in
                            decorationStorageCard(placement)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.top, 18)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    private func categoryButton(
        title: String,
        category: AquariumDecorationCategory?
    ) -> some View {
        Button(title) {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDecorationCategory = category
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(selectedDecorationCategory == category ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            selectedDecorationCategory == category
                ? Color.blue.opacity(0.85)
                : Color.white.opacity(0.16),
            in: Capsule()
        )
    }

    private func decorationStorageCard(
        _ placement: AquariumDecorationPlacement
    ) -> some View {
        Button {
            decorationRestoreRequestID = placement.decorationID
            closeDecorationStorage()
        } label: {
            VStack(spacing: 8) {
                AquariumDecorationView(decoration: placement.decoration)
                    .scaleEffect(0.5)
                    .frame(height: 72)

                Text(placement.kind.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(width: 104)
            .padding(10)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3))
            }
        }
        .buttonStyle(.plain)
    }

    private func closeDecorationStorage() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showsDecorationStorage = false
        }
    }

    private var backgroundThemePickerOverlay: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { cancelBackgroundThemeEditing() }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("水槽の背景", systemImage: "photo.fill")
                            .font(.headline)
                        Spacer()
                        Button("キャンセル", action: cancelBackgroundThemeEditing)
                            .font(.caption.weight(.semibold))
                        Button("確定", action: confirmBackgroundThemeEditing)
                            .font(.caption.weight(.bold))
                            .buttonStyle(.borderedProminent)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(AquariumBackgroundTheme.allCases) { theme in
                                backgroundThemeCard(theme)
                            }
                        }
                    }
                }
                .padding(.top, 18)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .frame(height: geometry.size.height * 0.31)
                .background(.ultraThinMaterial)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 24,
                        topTrailingRadius: 24
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 18, y: -6)
                .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea()
    }

    private func backgroundThemeCard(_ theme: AquariumBackgroundTheme) -> some View {
        let isSelected = previewBackgroundTheme == theme

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                previewBackgroundTheme = theme
            }
        } label: {
            VStack(spacing: 7) {
                LinearGradient(
                    colors: theme.fallbackColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: 112, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white, .blue)
                            .padding(6)
                    }
                }

                Text(theme.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .background(
                isSelected ? Color.blue.opacity(0.18) : Color.white.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private func beginBackgroundThemeEditing() {
        originalBackgroundTheme = savedBackgroundTheme
        previewBackgroundTheme = savedBackgroundTheme
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = true
        }
    }

    private func cancelBackgroundThemeEditing() {
        previewBackgroundTheme = originalBackgroundTheme
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = false
        }
        previewBackgroundTheme = nil
        originalBackgroundTheme = nil
    }

    private func confirmBackgroundThemeEditing() {
        if let previewBackgroundTheme {
            backgroundThemeRawValue = previewBackgroundTheme.rawValue
        }
        withAnimation(.easeInOut(duration: 0.22)) {
            showsBackgroundThemePicker = false
        }
        previewBackgroundTheme = nil
        originalBackgroundTheme = nil
    }

    private var interruptionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 3) {
                Text("前回の勉強は中断されました")
                    .font(.subheadline.weight(.semibold))
                Text("勉強時間と魚獲得には反映されません")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Button {
                withAnimation { showsInterruptionBanner = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
    }

    private func inspectPersistedTimerSession() {
        switch TimerSessionStore.shared.launchStatus(at: Date()) {
        case .recoverable:
            resumesPersistedTimer = true
        case .interrupted, .none, .sameProcess:
            break
        }

        if TimerSessionStore.shared.consumeInterruptionBanner() {
            withAnimation { showsInterruptionBanner = true }
        }
    }

    private func updateDecorationEditingState(isEditing: Bool) {
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingDecoration = isEditing
        }
    }

}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}


#Preview {
    TimerView(
        studyTime: 25,
        breakTime: 5,
        player: nil
    )
}
