import Foundation
import UIKit
import AVFoundation

@MainActor
final class FeedbackManager: NSObject, AVAudioPlayerDelegate {
    static let shared = FeedbackManager()

    enum Scene {
        case mainMenu
        case levelSelect
        case gameplay
    }

    private enum StorageKeys {
        static let sound = "krank.setting.sound"
        static let haptics = "krank.setting.haptics"
        static let music = "krank.setting.music"
    }

    private enum Effect: CaseIterable {
        case tap
        case switchFlip
        case success
        case failure
        case hint

        var spec: ToneSpec {
            switch self {
            case .tap:
                return ToneSpec(frequency: 720, duration: 0.05, volume: 0.18)
            case .switchFlip:
                return ToneSpec(frequency: 510, duration: 0.06, volume: 0.20)
            case .success:
                return ToneSpec(frequency: 930, duration: 0.10, volume: 0.28)
            case .failure:
                return ToneSpec(frequency: 260, duration: 0.11, volume: 0.24)
            case .hint:
                return ToneSpec(frequency: 820, duration: 0.09, volume: 0.22)
            }
        }
    }

    private struct ToneSpec {
        let frequency: Double
        let duration: Double
        let volume: Float
    }

    private let defaults: UserDefaults
    private var didConfigure = false
    private var currentScene: Scene = .mainMenu
    private var musicPlayer: AVAudioPlayer?
    private var effectDataCache: [Effect: Data] = [:]
    private var activeEffectPlayers: [AVAudioPlayer] = []

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let impactLightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let impactMediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        configureAudioSession()
        selectionGenerator.prepare()
        impactLightGenerator.prepare()
        impactMediumGenerator.prepare()
        notificationGenerator.prepare()
        updateMusicPlayback(forceRestart: false)
    }

    func setScene(_ scene: Scene) {
        configureIfNeeded()
        currentScene = scene
        updateMusicPlayback(forceRestart: false)
    }

    func refreshSettings() {
        configureIfNeeded()
        updateMusicPlayback(forceRestart: false)
    }

    func playTap() {
        playEffect(.tap)
        triggerSelectionHaptic()
    }

    func playSwitchFlip() {
        playEffect(.switchFlip)
        triggerLightImpactHaptic()
    }

    func playSuccess() {
        playEffect(.success)
        triggerNotificationHaptic(.success)
    }

    func playFailure() {
        playEffect(.failure)
        triggerNotificationHaptic(.error)
    }

    func playHint() {
        playEffect(.hint)
        triggerMediumImpactHaptic()
    }

    func playSelection() {
        triggerSelectionHaptic()
    }

    func playWarning() {
        playEffect(.failure)
        triggerNotificationHaptic(.warning)
    }

    private var soundEnabled: Bool {
        defaults.object(forKey: StorageKeys.sound) as? Bool ?? true
    }

    private var hapticsEnabled: Bool {
        defaults.object(forKey: StorageKeys.haptics) as? Bool ?? true
    }

    private var musicEnabled: Bool {
        defaults.object(forKey: StorageKeys.music) as? Bool ?? true
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        // Ambient respects the hardware silent switch while still allowing mixed audio.
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func updateMusicPlayback(forceRestart: Bool) {
        guard musicEnabled else {
            stopMusic()
            return
        }

        if !forceRestart, let musicPlayer {
            musicPlayer.volume = 0.40
            if musicPlayer.isPlaying {
                return
            }
            configureAudioSession()
            if musicPlayer.play() {
                return
            }
        }

        guard let trackURL = bundledMusicURL(for: currentScene) else {
            return
        }

        configureAudioSession()
        guard let nextPlayer = try? AVAudioPlayer(contentsOf: trackURL) else {
            return
        }

        nextPlayer.numberOfLoops = -1
        nextPlayer.volume = 0.40
        nextPlayer.prepareToPlay()

        guard nextPlayer.play() else {
            return
        }
        stopMusic()
        musicPlayer = nextPlayer
    }

    private func bundledMusicURL(for scene: Scene) -> URL? {
        // Using the same provided track for all scenes for now.
        let baseNames: [String]
        switch scene {
        case .mainMenu, .levelSelect, .gameplay:
            baseNames = ["paulyudin-ambient-ambient-music-482398"]
        }

        for baseName in baseNames {
            if let url = Bundle.main.url(forResource: baseName, withExtension: "mp3", subdirectory: "Audio") {
                return url
            }
            if let url = Bundle.main.url(forResource: baseName, withExtension: "mp3") {
                return url
            }
        }

        return nil
    }

    private func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }

    private func playEffect(_ effect: Effect) {
        guard soundEnabled else { return }
        configureAudioSession()

        let data = effectDataCache[effect] ?? makeToneData(spec: effect.spec)
        effectDataCache[effect] = data

        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = effect.spec.volume
        player.delegate = self
        player.prepareToPlay()
        if player.play() {
            activeEffectPlayers.append(player)
        }
    }

    private func triggerSelectionHaptic() {
        guard hapticsEnabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    private func triggerLightImpactHaptic() {
        guard hapticsEnabled else { return }
        impactLightGenerator.impactOccurred(intensity: 0.75)
        impactLightGenerator.prepare()
    }

    private func triggerMediumImpactHaptic() {
        guard hapticsEnabled else { return }
        impactMediumGenerator.impactOccurred(intensity: 0.85)
        impactMediumGenerator.prepare()
    }

    private func triggerNotificationHaptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.activeEffectPlayers.removeAll { $0 === player }
        }
    }

    private func makeToneData(spec: ToneSpec) -> Data {
        let sampleRate = 44_100
        let sampleCount = max(1, Int(spec.duration * Double(sampleRate)))
        var samples = [Int16](repeating: 0, count: sampleCount)

        let fadeSampleCount = max(1, Int(Double(sampleRate) * 0.01))
        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleRate)
            let raw = sin(2.0 * .pi * spec.frequency * t)
            let fadeIn = min(1.0, Double(index) / Double(fadeSampleCount))
            let fadeOut = min(1.0, Double(sampleCount - index) / Double(fadeSampleCount))
            let envelope = min(fadeIn, fadeOut)
            let value = raw * envelope * 0.82
            let clamped = max(-1.0, min(1.0, value))
            samples[index] = Int16(clamped * Double(Int16.max))
        }

        return makeWAVData(from: samples, sampleRate: sampleRate)
    }

    private func makeAmbientLoopData(for scene: Scene) -> Data {
        let sampleRate = 44_100
        let duration = 5.8
        let sampleCount = max(1, Int(duration * Double(sampleRate)))

        let baseFrequency: Double
        let secondaryFrequency: Double
        switch scene {
        case .mainMenu:
            baseFrequency = 220
            secondaryFrequency = 330
        case .levelSelect:
            baseFrequency = 246.94
            secondaryFrequency = 369.99
        case .gameplay:
            baseFrequency = 261.63
            secondaryFrequency = 392
        }

        var samples = [Int16](repeating: 0, count: sampleCount)
        let fadeSampleCount = max(1, Int(Double(sampleRate) * 0.08))

        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleRate)
            let lfo = 0.55 + (0.45 * sin(2.0 * .pi * 0.09 * t))
            let p1 = sin(2.0 * .pi * baseFrequency * t)
            let p2 = sin(2.0 * .pi * secondaryFrequency * t) * 0.62
            let p3 = sin(2.0 * .pi * (baseFrequency * 0.5) * t) * 0.34
            let p4 = sin(2.0 * .pi * (secondaryFrequency * 2.0) * t) * 0.22
            let mix = (p1 + p2 + p3 + p4) * 0.39 * lfo

            let fadeIn = min(1.0, Double(index) / Double(fadeSampleCount))
            let fadeOut = min(1.0, Double(sampleCount - index) / Double(fadeSampleCount))
            let envelope = min(fadeIn, fadeOut)
            let value = mix * envelope
            let clamped = max(-1.0, min(1.0, value))
            samples[index] = Int16(clamped * Double(Int16.max))
        }

        return makeWAVData(from: samples, sampleRate: sampleRate)
    }

    private func makeWAVData(from samples: [Int16], sampleRate: Int) -> Data {
        let bitsPerSample: UInt16 = 16
        let channelCount: UInt16 = 1
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataSize = samples.count * bytesPerSample
        let byteRate = sampleRate * Int(channelCount) * bytesPerSample
        let blockAlign = channelCount * UInt16(bytesPerSample)

        var data = Data()
        data.reserveCapacity(44 + dataSize)

        data.append(contentsOf: Array("RIFF".utf8))
        data.append(uint32LE: UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(uint32LE: 16)
        data.append(uint16LE: 1)
        data.append(uint16LE: channelCount)
        data.append(uint32LE: UInt32(sampleRate))
        data.append(uint32LE: UInt32(byteRate))
        data.append(uint16LE: blockAlign)
        data.append(uint16LE: bitsPerSample)
        data.append(contentsOf: Array("data".utf8))
        data.append(uint32LE: UInt32(dataSize))

        for sample in samples {
            data.append(int16LE: sample)
        }

        return data
    }
}

private extension Data {
    mutating func append(uint16LE value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(uint32LE value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(int16LE value: Int16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
