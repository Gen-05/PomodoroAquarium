import AudioToolbox
import SwiftUI
import UIKit

struct StudyFinishedView: View {
    let studyMinutes: Int

    @Environment(\.dismiss) private var dismiss
    @State private var isVisible = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.28),
                    Color.blue.opacity(0.16),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 68, weight: .medium))
                    .foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.35), radius: 14)

                Text("🎉 勉強終了！")
                    .font(.largeTitle.bold())

                VStack(spacing: 6) {
                    Text("集中時間")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(studyMinutes)分")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Button("報酬を見る") {
                    dismiss()
                }
                .buttonStyle(AquariumPrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(32)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.92)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
        .task {
            playCompletionFeedback()
            withAnimation(.easeOut(duration: 0.45)) {
                isVisible = true
            }
        }
    }

    private func playCompletionFeedback() {
        AudioServicesPlaySystemSound(1005)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#Preview {
    StudyFinishedView(studyMinutes: 25)
}
