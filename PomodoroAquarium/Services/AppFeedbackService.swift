import AVFoundation
import Foundation
import UIKit

enum AppPreferenceSettings {
    // 既存ユーザーとの互換性のため、効果音Toggleは従来キーを継続利用する。
    static let soundEnabledKey = "soundEnabled"
    static let soundEffectsVolumeKey = "soundEffectsVolume"
    static let hapticsEnabledKey = "hapticsEnabled"
    static let hapticsIntensityKey = "hapticsIntensity"

    // BGM実装時は効果音と独立してこのキー群を利用する。
    static let backgroundMusicEnabledKey = "backgroundMusicEnabled"
    static let backgroundMusicVolumeKey = "backgroundMusicVolume"

    static func isSoundEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: soundEnabledKey) as? Bool ?? true
    }

    static func soundEffectsVolume(in defaults: UserDefaults = .standard) -> Double {
        storedUnitValue(forKey: soundEffectsVolumeKey, in: defaults)
    }

    static func isHapticsEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: hapticsEnabledKey) as? Bool ?? true
    }

    static func hapticsIntensity(in defaults: UserDefaults = .standard) -> Double {
        storedUnitValue(forKey: hapticsIntensityKey, in: defaults)
    }

    private static func storedUnitValue(forKey key: String, in defaults: UserDefaults) -> Double {
        guard defaults.object(forKey: key) != nil else { return 1 }
        return min(1, max(0, defaults.double(forKey: key)))
    }
}

enum HapticIntensityLevel: Equatable {
    case weak
    case medium
    case strong

    static func level(for intensity: Double) -> Self {
        switch min(1, max(0, intensity)) {
        case ..<0.34: .weak
        case ..<0.67: .medium
        default: .strong
        }
    }
}

protocol FeedbackPerforming {
    func playCompletionSound(volume: Float)
    func playSuccessHaptic(level: HapticIntensityLevel)
    func playImpactHaptic(level: HapticIntensityLevel)
}

private final class SystemFeedbackPerformer: FeedbackPerforming {
    private let soundPlayer = CompletionSoundPlayer()

    func playCompletionSound(volume: Float) {
        soundPlayer.play(volume: volume)
    }

    func playSuccessHaptic(level: HapticIntensityLevel) {
        switch level {
        case .weak:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        case .strong:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func playImpactHaptic(level: HapticIntensityLevel) {
        switch level {
        case .weak:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
        case .strong:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        }
    }
}

private final class CompletionSoundPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private lazy var buffer: AVAudioPCMBuffer? = makeChimeBuffer()

    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: buffer?.format)
    }

    func play(volume: Float) {
        guard volume > 0, let buffer else { return }
        playerNode.stop()
        playerNode.volume = min(1, max(0, volume))
        do {
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts)
            playerNode.play()
        } catch {
            // 音声再生失敗はタイマー完了処理へ影響させない。
        }
    }

    private func makeChimeBuffer() -> AVAudioPCMBuffer? {
        let sampleRate = 44_100.0
        let duration = 0.42
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let envelope = Float(max(0, 1 - time / duration))
            let firstTone = sin(2 * Double.pi * 659.25 * time)
            let secondTone = sin(2 * Double.pi * 783.99 * time) * 0.45
            samples[frame] = Float(firstTone + secondTone) * envelope * 0.32
        }
        return buffer
    }
}

struct AppFeedbackService {
    private let defaults: UserDefaults
    private let performer: FeedbackPerforming

    static let shared = AppFeedbackService()

    init(
        defaults: UserDefaults = .standard,
        performer: FeedbackPerforming = SystemFeedbackPerformer()
    ) {
        self.defaults = defaults
        self.performer = performer
    }

    func playStudyCompletion() {
        if AppPreferenceSettings.isSoundEnabled(in: defaults) {
            performer.playCompletionSound(
                volume: Float(AppPreferenceSettings.soundEffectsVolume(in: defaults))
            )
        }
        guard AppPreferenceSettings.isHapticsEnabled(in: defaults) else { return }
        performer.playSuccessHaptic(level: currentHapticLevel)
    }

    func playFishAcquisition(isNewFish: Bool) {
        guard AppPreferenceSettings.isHapticsEnabled(in: defaults) else { return }
        if isNewFish {
            performer.playSuccessHaptic(level: currentHapticLevel)
        } else {
            performer.playImpactHaptic(level: currentHapticLevel)
        }
    }

    /// 設定画面専用。勉強完了などの本番イベント処理は伴わない。
    func playSoundPreview() {
        guard AppPreferenceSettings.isSoundEnabled(in: defaults) else { return }
        performer.playCompletionSound(
            volume: Float(AppPreferenceSettings.soundEffectsVolume(in: defaults))
        )
    }

    /// 設定画面専用。保存済み強度を既存の段階へ変換して1回だけ発生させる。
    func playHapticPreview() {
        guard AppPreferenceSettings.isHapticsEnabled(in: defaults) else { return }
        performer.playImpactHaptic(level: currentHapticLevel)
    }

    private var currentHapticLevel: HapticIntensityLevel {
        .level(for: AppPreferenceSettings.hapticsIntensity(in: defaults))
    }
}

enum AppInformation {
    static func version(in bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

enum AppLinks {
    // 公開URL確定後、この定義だけを差し替える。
    static let privacyPolicy: URL? = nil
    static let termsOfService: URL? = nil
}
