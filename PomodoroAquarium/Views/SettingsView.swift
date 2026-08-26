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

    var body: some View {
        Form {
            Section("通知") {
                notificationSettingsContent
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
