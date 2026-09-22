import Foundation
import Observation
import SwiftData

enum CoreTutorialStep: String, CaseIterable {
    case homeIntro
    case homePointsIntro
    case homeStudySummaryIntro
    case waitingForHomeStartTap
    case studySetupIntro
    case studySettingsIntro
    case waitingForStudyStartTap
    case reward
    case aquariumIntro
    case waitingForFishPlacement
    case waitingForAquariumSave
    case finishing
}

enum CoreTutorialStorageKey {
    static let hasCompleted = "hasCompletedCoreTutorial"
    static let step = "coreTutorialStep"
    static let hasGrantedReward = "hasGrantedTutorialReward"
    static let hasGrantedPoints = "hasGrantedTutorialPoints"
    static let hasSavedAquarium = "hasSavedCoreTutorialAquarium"
}

enum CoreTutorialMode: Equatable {
    case production
    case preview
}

@MainActor
@Observable
final class CoreTutorialCoordinator {
    private let defaults: UserDefaults
    private let timerSessionStore: TimerSessionStore

    let mode: CoreTutorialMode

    private(set) var step: CoreTutorialStep
    private(set) var conversationIndex = 0
    private(set) var hasStartedFishDrag = false
    private(set) var hasCompletedTutorial: Bool

    init(
        mode: CoreTutorialMode = .production,
        defaults: UserDefaults = .standard,
        timerSessionStore: TimerSessionStore? = nil
    ) {
        self.mode = mode
        self.defaults = defaults
        self.timerSessionStore = timerSessionStore ?? TimerSessionStore(defaults: defaults)

        if mode == .preview {
            // UserDefaultsのArgumentDomain（UI Test起動引数を含む）にも影響されず、
            // Previewは毎回必ず最初から始める。
            hasCompletedTutorial = false
            step = .homeIntro
            return
        }

        let isCompleted = defaults.bool(forKey: CoreTutorialStorageKey.hasCompleted)
        hasCompletedTutorial = isCompleted

        if isCompleted {
            step = .finishing
        } else if defaults.bool(forKey: CoreTutorialStorageKey.hasSavedAquarium) {
            step = .finishing
        } else if defaults.bool(forKey: CoreTutorialStorageKey.hasGrantedReward) {
            step = .aquariumIntro
        } else {
            // 報酬前の中断は、必ずHomeから安全に体験し直す。
            if defaults.string(forKey: CoreTutorialStorageKey.step) == CoreTutorialStep.reward.rawValue {
                self.timerSessionStore.clearSession()
            }
            step = .homeIntro
        }
    }

    var isActive: Bool { !hasCompletedTutorial }

    var isPreviewMode: Bool { mode == .preview }

    var usesTutorialStudySetup: Bool {
        isActive && [
            CoreTutorialStep.studySetupIntro,
            .studySettingsIntro,
            .waitingForStudyStartTap,
            .reward
        ].contains(step)
    }

    var shouldShowGhostHand: Bool {
        isActive && step == .waitingForFishPlacement && !hasStartedFishDrag
    }

    func reconcile(with player: Player?) {
        guard isActive, let player else { return }

        let hasSavedAquarium = player.hasSavedCoreTutorialAquarium || (
            mode == .production && defaults.bool(forKey: CoreTutorialStorageKey.hasSavedAquarium)
        )
        let hasGrantedReward = player.hasGrantedCoreTutorialReward || (
            mode == .production && defaults.bool(forKey: CoreTutorialStorageKey.hasGrantedReward)
        )

        if hasSavedAquarium {
            transition(to: .finishing)
        } else if hasGrantedReward {
            transition(to: .aquariumIntro)
        } else if step != .homeIntro && step != .waitingForHomeStartTap {
            transition(to: .homeIntro)
        }
    }

    func dismissHomeIntro() {
        guard isActive else { return }
        switch step {
        case .homeIntro:
            transition(to: .homePointsIntro)
        case .homePointsIntro:
            transition(to: .homeStudySummaryIntro)
        case .homeStudySummaryIntro:
            transition(to: .waitingForHomeStartTap)
        default:
            break
        }
    }

    /// 同じTutorial Step内の短い会話だけを進める。
    /// 永続Stepとは分離し、中断時の既存復帰ルールを変えない。
    @discardableResult
    func advanceConversation(totalCount: Int) -> Bool {
        guard isActive, totalCount > 0 else { return false }
        guard conversationIndex < totalCount - 1 else { return true }
        conversationIndex += 1
        return false
    }

    func restartConversation() {
        guard isActive else { return }
        conversationIndex = 0
    }

    func didTapHomeStart() {
        guard isActive, step == .waitingForHomeStartTap else { return }
        transition(to: .studySetupIntro)
    }

    func dismissStudySetupIntro() {
        guard isActive else { return }
        switch step {
        case .studySetupIntro:
            transition(to: .studySettingsIntro)
        case .studySettingsIntro:
            transition(to: .waitingForStudyStartTap)
        default:
            break
        }
    }

    func didTapStudyStart() {
        guard isActive, step == .waitingForStudyStartTap else { return }
        transition(to: .reward)
    }

    func didLeaveStudySetupBeforeStarting() {
        guard isActive,
              step == .studySetupIntro ||
                step == .studySettingsIntro ||
                step == .waitingForStudyStartTap else { return }
        transition(to: .waitingForHomeStartTap)
    }

    func didDismissReward() {
        guard isActive else { return }
        transition(to: .aquariumIntro)
    }

    func didSelectAquariumTab() {
        guard isActive, step == .aquariumIntro else { return }
        restartConversation()
    }

    func didEnterAquariumEditing(tutorialFishIsActive: Bool) {
        guard isActive else { return }
        transition(to: tutorialFishIsActive ? .waitingForAquariumSave : .waitingForFishPlacement)
    }

    func didStartFishDrag(species: FishSpecies) {
        guard isActive, step == .waitingForFishPlacement, species == .clownfish else { return }
        hasStartedFishDrag = true
    }

    func didObserveActiveFishIDs(_ activeFishIDs: [UUID], tutorialFishID: UUID?) {
        guard isActive,
              step == .waitingForFishPlacement,
              let tutorialFishID,
              activeFishIDs.contains(tutorialFishID) else { return }
        transition(to: .waitingForAquariumSave)
    }

    func didDiscardAquariumChanges() {
        guard isActive else { return }
        hasStartedFishDrag = false
        transition(to: .aquariumIntro)
    }

    func didSaveAquarium(with player: Player) {
        guard isActive,
              let fishID = player.coreTutorialRewardFishID,
              player.activeAquariumFishIDs.contains(fishID) else { return }
        player.hasSavedCoreTutorialAquarium = true
        defaults.set(true, forKey: CoreTutorialStorageKey.hasSavedAquarium)
        transition(to: .finishing)
    }

    func didSelectHomeTabAfterAquarium() {
        guard isActive, step == .finishing else { return }
        restartConversation()
    }

    func complete() {
        guard isActive, step == .finishing else { return }
        defaults.set(true, forKey: CoreTutorialStorageKey.hasCompleted)
        hasCompletedTutorial = true
    }

    func tutorialFishID(in player: Player?) -> UUID? {
        player?.coreTutorialRewardFishID
    }

    func grantRewardIfNeeded(
        to player: Player,
        in context: ModelContext
    ) throws -> FishAcquisitionResult {
        try CoreTutorialRewardService.grantIfNeeded(
            to: player,
            in: context,
            defaults: defaults
        )
    }

    private func transition(to newStep: CoreTutorialStep) {
        guard step != newStep else { return }
        step = newStep
        conversationIndex = 0
        defaults.set(newStep.rawValue, forKey: CoreTutorialStorageKey.step)
    }
}

enum CoreTutorialRewardService {
    static let studyMinutes = FishRewardService.minimumStudyMinutes

    @MainActor
    static func grantIfNeeded(
        to player: Player,
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> FishAcquisitionResult {
        _ = AquariumFishSelection.initializeIfNeeded(for: player)

        let previousClownfishCount = max(
            0,
            player.ownedFish.count(where: { $0.species == .clownfish }) -
                (player.hasGrantedCoreTutorialReward ? 1 : 0)
        )

        let tutorialFish: PlayerFish
        if player.hasGrantedCoreTutorialReward,
           let tutorialFishID = player.coreTutorialRewardFishID,
           let existingFish = player.ownedFish.first(where: { $0.id == tutorialFishID }) {
            tutorialFish = existingFish
        } else {
            let fish = PlayerFish(species: .clownfish)
            player.ownedFish.append(fish)
            player.coreTutorialRewardFishID = fish.id
            player.hasGrantedCoreTutorialReward = true
            tutorialFish = fish
        }

        if !player.hasGrantedCoreTutorialPoints {
            let points = CurrencyService.studyCompletionReward(
                for: studyMinutes,
                todayStudyMinutesBeforeCompletion: 0
            )
            CurrencyService.creditWithoutSaving(points, to: player)
            player.hasGrantedCoreTutorialPoints = true
        }

        // 魚・ポイント・二重付与防止フラグを同じSwiftData保存に含める。
        try context.save()
        defaults.set(true, forKey: CoreTutorialStorageKey.hasGrantedReward)
        defaults.set(true, forKey: CoreTutorialStorageKey.hasGrantedPoints)

        let currentCount = player.ownedFish.count { $0.species == .clownfish }
        return FishAcquisitionResult(
            fish: tutorialFish,
            previousOwnedCount: min(previousClownfishCount, max(0, currentCount - 1)),
            currentOwnedCount: currentCount
        )
    }
}
