#if DEBUG
import SwiftUI
import SwiftData

struct DecorationTutorialPreviewHost: View {
    let session: DecorationTutorialPreviewSession
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Decoration Tutorial Preview").font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Button(action: onFinish) { Label("終了", systemImage: "xmark.circle.fill") }
                    .font(.subheadline.bold()).frame(minHeight: 44)
                    .accessibilityIdentifier("decorationTutorialPreview.exit")
            }
            .padding(.horizontal, 12)
            .background(.regularMaterial)
            .zIndex(1)

            MainTabView(coreTutorialMode: .decorationPreview, defaults: session.defaults,
                timerSessionStore: session.timerSessionStore,
                notificationService: DisabledTimerNotificationService.shared,
                editorDraftStore: session.draftStore, decorationTutorial: session.tutorial,
                shopItems: DecorationTutorialPreviewSession.products)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .defaultAppStorage(session.defaults)
        .modelContainer(session.modelContainer)
        .environment(\.aquariumFishViewingSession, session.fishViewingSession)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("decorationTutorialPreview.container")
        .interactiveDismissDisabled()
    }
}
#endif
