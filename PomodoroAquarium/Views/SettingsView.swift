//
//  SettingsView.swift
//  PomodoroAquarium
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var notificationStatus: NotificationAuthorizationState = .notDetermined
    @AppStorage(NotificationSettings.enabledKey) private var notificationsEnabled = false
    @AppStorage(AppPreferenceSettings.soundEnabledKey) private var soundEnabled = true
    @AppStorage(AppPreferenceSettings.soundEffectsVolumeKey) private var soundEffectsVolume = 1.0
    @AppStorage(AppPreferenceSettings.hapticsEnabledKey) private var hapticsEnabled = true
    @AppStorage(AppPreferenceSettings.hapticsIntensityKey) private var hapticsIntensity = 1.0

    var body: some View {
        Form {
            Section("通知") {
                notificationSettingsContent
            }

            Section("サウンド") {
                Toggle("効果音", isOn: $soundEnabled)
                settingSlider(
                    title: "音量",
                    systemImage: "speaker.wave.2.fill",
                    value: $soundEffectsVolume,
                    isEnabled: soundEnabled,
                    onEditingEnded: {
                        AppFeedbackService.shared.playSoundPreview()
                    }
                )
            }

            Section("触覚") {
                Toggle("触覚フィードバック", isOn: $hapticsEnabled)
                settingSlider(
                    title: "強さ",
                    systemImage: "waveform",
                    value: $hapticsIntensity,
                    isEnabled: hapticsEnabled,
                    onEditingEnded: {
                        AppFeedbackService.shared.playHapticPreview()
                    }
                )
            }

            Section("アプリ情報") {
                LabeledContent("バージョン", value: AppInformation.version())
                appLinkRow("プライバシーポリシー", url: AppLinks.privacyPolicy)
                appLinkRow("利用規約", url: AppLinks.termsOfService)
            }
        }
        .navigationTitle("設定")
        .onAppear(perform: refreshNotificationStatus)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshNotificationStatus()
            }
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            NotificationSettings.handleChange(isEnabled: isEnabled)
        }
        .onChange(of: soundEnabled) { _, isEnabled in
            if isEnabled {
                AppFeedbackService.shared.playSoundPreview()
            }
        }
        .onChange(of: hapticsEnabled) { _, isEnabled in
            if isEnabled {
                AppFeedbackService.shared.playHapticPreview()
            }
        }
    }

    private func settingSlider(
        title: String,
        systemImage: String,
        value: Binding<Double>,
        isEnabled: Bool,
        onEditingEnded: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Slider(value: value, in: 0...1) { isEditing in
                    if !isEditing && isEnabled {
                        onEditingEnded()
                    }
                }
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    @ViewBuilder
    private func appLinkRow(_ title: String, url: URL?) -> some View {
        if let url {
            Link(title, destination: url)
        } else {
            HStack {
                Text(title)
                Spacer()
                Text("準備中")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var notificationSettingsContent: some View {
        switch notificationStatus {
        case .authorized:
            Toggle("勉強・休憩終了の通知", isOn: $notificationsEnabled)
            Label("通知は許可されています", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("勉強・休憩終了時に通知します。")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .notDetermined:
            Text("通知はまだ設定されていません")
            Button("通知を許可する") {
                NotificationService.shared.requestAuthorization { granted in
                    Task { @MainActor in
                        notificationsEnabled = granted
                        refreshNotificationStatus()
                    }
                }
            }

        case .denied:
            Label("iPhoneの設定で通知がオフです", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("通知を受け取るには、iPhoneの設定から許可してください。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("設定を開く") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
        }
    }

    private func refreshNotificationStatus() {
        NotificationService.shared.authorizationStatus { status in
            Task { @MainActor in
                notificationStatus = status
                if status == .denied {
                    notificationsEnabled = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
