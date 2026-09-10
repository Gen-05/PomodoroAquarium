import SwiftUI

enum StudyFinishedLayout {
    static let titleLineLimit = 3
    static let titleMinimumScaleFactor: CGFloat = 0.78
    static let contentHorizontalPadding: CGFloat = 28
}

struct StudyFinishedView: View {
    let studyMinutes: Int
    var endReason: StudySessionEndReason = .completed

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

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 68, weight: .medium))
                        .foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.35), radius: 14)

                    Text(endReason.isNormalCompletion ? "🎉 勉強終了！" : "勉強が途中で終了しました")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .lineLimit(StudyFinishedLayout.titleLineLimit)
                        .minimumScaleFactor(StudyFinishedLayout.titleMinimumScaleFactor)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 6) {
                        Text("集中時間")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text("\(studyMinutes)分")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }

                    if !endReason.isNormalCompletion {
                        Text("終了地点までの勉強時間で報酬を計算します")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("報酬を見る") {
                        dismiss()
                    }
                    .buttonStyle(AquariumPrimaryButtonStyle())
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, StudyFinishedLayout.contentHorizontalPadding)
                .padding(.vertical, 28)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.92)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
        .task {
            playCompletionFeedback()
            withAnimation(.easeOut(duration: 0.45)) {
                isVisible = true
            }
        }
    }

    private func playCompletionFeedback() {
        AppFeedbackService.shared.playStudyCompletion()
    }
}

#Preview {
    StudyFinishedView(studyMinutes: 25)
}
