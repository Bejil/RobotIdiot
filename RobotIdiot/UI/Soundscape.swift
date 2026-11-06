import AVFoundation
import UIKit
import RobotIdiotCore

/// Sons et musique synthétisés. Aucun fichier audio n'est embarqué.
final class Soundscape {
    static let shared = Soundscape()

    private let engine = AVAudioEngine()
    private let effects = AVAudioPlayerNode()
    private let music = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var tones: [String: AVAudioPCMBuffer] = [:]
    private var unavailable = false
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let rigidHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let noticeHaptic = UINotificationFeedbackGenerator()
    /// Évite les doubles sons quand UIKit envoie plusieurs `sendAction` pour un même tap (ex. UIBarButtonItem).
    private var lastUISoundAt: CFTimeInterval = 0
    private var moveFlip = false
    private let musicRestingVolume: Float = 0.13
    private var musicFadeTimer: Timer?
    private var duckRestoreWork: DispatchWorkItem?

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(effects)
        engine.attach(music)
        engine.connect(effects, to: engine.mainMixerNode, format: format)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        effects.volume = 0.58
        music.volume = 0
        tones["tap"] = softTone(frequency: 540, seconds: 0.05, volume: 0.28, harmonic: 0.18)
        tones["ui"] = softTone(frequency: 920, seconds: 0.032, volume: 0.24, harmonic: 0.12)
        tones["toggle"] = sequence([640, 900], note: 0.04, volume: 0.22)
        tones["select"] = softTone(frequency: 680, seconds: 0.045, volume: 0.24, harmonic: 0.2)
        tones["move"] = footstep(pitch: 1)
        tones["moveAlt"] = footstep(pitch: 0.92)
        tones["turn"] = turnWhoosh()
        tones["collect"] = collectChime()
        tones["pickup"] = softTone(frequency: 760, seconds: 0.07, volume: 0.26, harmonic: 0.3)
        tones["open"] = doorOpen()
        tones["push"] = cratePush()
        tones["activate"] = switchClick()
        tones["success"] = victoryFanfare()
        tones["error"] = softTone(frequency: 168, seconds: 0.2, volume: 0.28, harmonic: 0.35)
        tones["bump"] = obstacleBump()
        tones["spikes"] = spikesHit()
        tones["water"] = waterSplash()
        tones["lava"] = lavaSizzle()
        tones["music"] = musicLoop()
        lightHaptic.prepare()
        softHaptic.prepare()
        mediumHaptic.prepare()
        rigidHaptic.prepare()
        heavyHaptic.prepare()
        selectionHaptic.prepare()
        noticeHaptic.prepare()
        NotificationCenter.default.addObserver(
            forName: PlaySettings.changed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMusic()
        }
    }

    /// Mur, buisson ou autre obstacle solide : le robot reste sur place.
    func playObstacleHit() {
        play("bump")
    }

    /// Danger mortel selon le terrain (pics, eau, lave).
    func playHazardHit(_ terrain: TerrainType) {
        switch terrain {
        case .spikes:
            play("spikes")
        case .water:
            play("water")
        case .lava:
            play("lava")
        default:
            play("error")
        }
    }

    func noteInteraction(sender: Any?, event: UIEvent?) {
        if sender is PaletteSwitch || sender is UISwitch {
            let nowOn = (sender as? PaletteSwitch)?.isOn ?? (sender as? UISwitch)?.isOn ?? false
            play("toggle", forceHaptic: nowOn && !PlaySettings.haptics)
            return
        }
        guard event != nil else { return }
        if sender is UITextField || sender is UITextView { return }
        if sender is UISegmentedControl {
            playDebouncedUISound("toggle")
        } else if sender is UIControl || sender is UIBarButtonItem {
            playDebouncedUISound("ui")
        }
    }

    private func playDebouncedUISound(_ name: String) {
        let now = CACurrentMediaTime()
        guard now - lastUISoundAt > 0.12 else { return }
        lastUISoundAt = now
        play(name)
    }

    func play(_ name: String, forceHaptic: Bool = false) {
        let resolved = resolve(name)
        pulse(resolved, force: forceHaptic)
        guard PlaySettings.sound, let buffer = tones[resolved] else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        if !effects.isPlaying { effects.play() }
        effects.scheduleBuffer(buffer, at: nil, options: [])
        duckMusicIfNeeded(for: resolved)
    }

    private func resolve(_ name: String) -> String {
        guard name == "move" else { return name }
        moveFlip.toggle()
        return moveFlip ? "move" : "moveAlt"
    }

    /// Suit le réglage Musique. Ne relance pas la boucle si elle tourne déjà.
    func refreshMusic() {
        guard PlaySettings.music, let buffer = tones["music"] else {
            fadeMusic(to: 0, thenStop: true)
            return
        }
        startIfNeeded()
        guard engine.isRunning else { return }
        if music.isPlaying {
            fadeMusic(to: musicRestingVolume)
            return
        }
        music.volume = 0
        music.scheduleBuffer(buffer, at: nil, options: .loops)
        music.play()
        fadeMusic(to: musicRestingVolume)
    }

    private func duckMusicIfNeeded(for name: String) {
        guard music.isPlaying, PlaySettings.music else { return }
        switch name {
        case "success", "error", "collect", "bump", "spikes", "water", "lava":
            break
        default:
            return
        }
        duckRestoreWork?.cancel()
        music.volume = musicRestingVolume * 0.32
        let work = DispatchWorkItem { [weak self] in
            self?.fadeMusic(to: self?.musicRestingVolume ?? 0.13)
        }
        duckRestoreWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    private func fadeMusic(to volume: Float, thenStop: Bool = false) {
        musicFadeTimer?.invalidate()
        let start = music.volume
        let steps = 10
        let stepDuration = 0.04
        var index = 0
        musicFadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            index += 1
            let progress = Float(index) / Float(steps)
            self.music.volume = start + (volume - start) * progress
            guard index >= steps else { return }
            timer.invalidate()
            self.musicFadeTimer = nil
            self.music.volume = volume
            if thenStop, volume <= 0.001 {
                self.music.stop()
            }
        }
    }

    private func pulse(_ name: String, force: Bool) {
        guard force || PlaySettings.haptics else { return }
        switch name {
        case "ui":
            lightHaptic.impactOccurred()
            lightHaptic.prepare()
        case "toggle", "select", "activate":
            selectionHaptic.selectionChanged()
            selectionHaptic.prepare()
        case "move", "moveAlt", "turn", "tap", "pickup", "open", "push":
            softHaptic.impactOccurred(intensity: 0.65)
            softHaptic.prepare()
        case "collect":
            softHaptic.impactOccurred(intensity: 0.85)
            softHaptic.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.lightHaptic.impactOccurred(intensity: 0.45)
                self.lightHaptic.prepare()
            }
        case "success":
            noticeHaptic.notificationOccurred(.success)
            noticeHaptic.prepare()
        case "error":
            noticeHaptic.notificationOccurred(.warning)
            noticeHaptic.prepare()
        case "bump":
            rigidHaptic.impactOccurred(intensity: 1)
            rigidHaptic.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.mediumHaptic.impactOccurred(intensity: 0.55)
                self.mediumHaptic.prepare()
            }
        case "spikes":
            rigidHaptic.impactOccurred(intensity: 1)
            rigidHaptic.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.rigidHaptic.impactOccurred(intensity: 0.85)
                self.rigidHaptic.prepare()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.noticeHaptic.notificationOccurred(.error)
                self.noticeHaptic.prepare()
            }
        case "water":
            softHaptic.impactOccurred(intensity: 0.9)
            softHaptic.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.softHaptic.impactOccurred(intensity: 0.55)
                self.softHaptic.prepare()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.lightHaptic.impactOccurred(intensity: 0.4)
                self.lightHaptic.prepare()
            }
        case "lava":
            heavyHaptic.impactOccurred(intensity: 1)
            heavyHaptic.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.heavyHaptic.impactOccurred(intensity: 0.7)
                self.heavyHaptic.prepare()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, force || PlaySettings.haptics else { return }
                self.noticeHaptic.notificationOccurred(.warning)
                self.noticeHaptic.prepare()
            }
        default:
            break
        }
    }

    private func startIfNeeded() {
        guard !unavailable else { return }
        do {
            // ambient + mixWithOthers : cohabite avec Spotify et respecte le silent switch.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            if !engine.isRunning {
                try engine.start()
            }
        } catch {
            unavailable = true
        }
    }

    private func softTone(
        frequency: Double,
        seconds: Double,
        volume: Float,
        harmonic: Double = 0.15
    ) -> AVAudioPCMBuffer? {
        synthesize(seconds: seconds) { time, _ in
            let attack = min(1, time / 0.01)
            let release = min(1, max(0, (seconds - time) / 0.035))
            let fundamental = sin(2 * Double.pi * frequency * time)
            let overtone = sin(2 * Double.pi * frequency * 2 * time) * harmonic
            return (fundamental + overtone) * attack * release * Double(volume)
        }
    }

    private func tone(frequency: Double, seconds: Double, volume: Float) -> AVAudioPCMBuffer? {
        softTone(frequency: frequency, seconds: seconds, volume: volume, harmonic: 0.12)
    }

    private func sequence(_ frequencies: [Double], note: Double, volume: Float) -> AVAudioPCMBuffer? {
        let pieces = frequencies.compactMap { softTone(frequency: $0, seconds: note, volume: volume, harmonic: 0.14) }
        return join(pieces)
    }

    private func join(_ pieces: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        let total = pieces.reduce(0) { $0 + Int($1.frameLength) }
        guard total > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let destination = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(total)
        var cursor = 0
        for piece in pieces {
            guard let source = piece.floatChannelData?[0] else { continue }
            let count = Int(piece.frameLength)
            for index in 0..<count {
                destination[cursor + index] = source[index]
            }
            cursor += count
        }
        return buffer
    }

    private func footstep(pitch: Double) -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.07) { time, index in
            let freq = 380 * pitch
            let body = sin(2 * Double.pi * freq * time) * exp(-time * 42)
            let soft = sin(2 * Double.pi * freq * 1.5 * time) * exp(-time * 55) * 0.35
            let noiseSeed = sin(Double(index) * 12.9898) * 43758.5453
            let scuff = (noiseSeed.truncatingRemainder(dividingBy: 1) * 2 - 1) * exp(-time * 70) * 0.12
            return (body + soft + scuff) * 0.32
        }
    }

    private func turnWhoosh() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.09) { time, _ in
            let freq = 280 + time * 220
            let sweep = sin(2 * Double.pi * freq * time) * exp(-time * 18)
            let air = sin(2 * Double.pi * (520 + time * 160) * time) * exp(-time * 28) * 0.35
            return (sweep + air) * 0.3
        }
    }

    private func collectChime() -> AVAudioPCMBuffer? {
        join([
            softTone(frequency: 784, seconds: 0.07, volume: 0.26, harmonic: 0.25),
            softTone(frequency: 988, seconds: 0.09, volume: 0.24, harmonic: 0.2),
            softTone(frequency: 1175, seconds: 0.11, volume: 0.2, harmonic: 0.18)
        ].compactMap { $0 })
    }

    private func doorOpen() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.14) { time, _ in
            let creak = sin(2 * Double.pi * (190 + time * 80) * time) * exp(-time * 10) * 0.55
            let latch = sin(2 * Double.pi * 740 * time) * exp(-time * 35) * 0.4
            return (creak + latch) * 0.34
        }
    }

    private func cratePush() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.12) { time, index in
            let scrape = sin(2 * Double.pi * 140 * time) * exp(-time * 14) * 0.6
            let wood = sin(2 * Double.pi * 260 * time) * exp(-time * 20) * 0.35
            let noiseSeed = sin(Double(index) * 78.233) * 43758.5453
            let grit = (noiseSeed.truncatingRemainder(dividingBy: 1) * 2 - 1) * exp(-time * 22) * 0.18
            return (scrape + wood + grit) * 0.36
        }
    }

    private func switchClick() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.06) { time, _ in
            let tick = sin(2 * Double.pi * 1100 * time) * exp(-time * 55)
            let body = sin(2 * Double.pi * 420 * time) * exp(-time * 38) * 0.45
            return (tick + body) * 0.3
        }
    }

    private func victoryFanfare() -> AVAudioPCMBuffer? {
        join([
            softTone(frequency: 523, seconds: 0.1, volume: 0.28, harmonic: 0.18),
            softTone(frequency: 659, seconds: 0.1, volume: 0.28, harmonic: 0.18),
            softTone(frequency: 784, seconds: 0.12, volume: 0.3, harmonic: 0.2),
            softTone(frequency: 1046, seconds: 0.16, volume: 0.26, harmonic: 0.16)
        ].compactMap { $0 })
    }

    private func musicLoop() -> AVAudioPCMBuffer? {
        // Phrase douce en Do majeur, un peu plus longue et moins mécanique.
        let melody: [(Double, Double)] = [
            (262, 0.34), (330, 0.34), (392, 0.34), (440, 0.42),
            (392, 0.28), (349, 0.28), (330, 0.34), (294, 0.42),
            (262, 0.34), (294, 0.28), (330, 0.34), (392, 0.5),
            (349, 0.34), (330, 0.42), (294, 0.5), (262, 0.62)
        ]
        let pieces = melody.compactMap { note in
            softTone(frequency: note.0, seconds: note.1, volume: 0.13, harmonic: 0.1)
        }
        return join(pieces)
    }

    private func obstacleBump() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.16) { time, _ in
            let thud = sin(2 * Double.pi * 95 * time) * exp(-time * 28)
            let knock = sin(2 * Double.pi * 210 * time) * exp(-time * 18) * 0.55
            let click = sin(2 * Double.pi * 880 * time) * exp(-time * 55) * 0.35
            return (thud + knock + click) * 0.55
        }
    }

    private func spikesHit() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.22) { time, _ in
            let metallic = sin(2 * Double.pi * 1450 * time) * exp(-time * 22)
            let ring = sin(2 * Double.pi * 920 * time) * exp(-time * 14) * 0.55
            let jab = sin(2 * Double.pi * 240 * time) * exp(-time * 30) * 0.7
            let spark = ((time * 17_000).truncatingRemainder(dividingBy: 1) * 2 - 1) * exp(-time * 40) * 0.25
            return (metallic + ring + jab + spark) * 0.48
        }
    }

    private func waterSplash() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.38) { time, index in
            let drop = sin(2 * Double.pi * (520 - time * 380) * time) * exp(-time * 6) * 0.55
            let bubble = sin(2 * Double.pi * (280 - time * 120) * time) * exp(-time * 4.5) * 0.4
            let noiseSeed = sin(Double(index) * 12.9898) * 43758.5453
            let foam = (noiseSeed.truncatingRemainder(dividingBy: 1) * 2 - 1) * exp(-time * 7) * 0.22
            return (drop + bubble + foam) * 0.5
        }
    }

    private func lavaSizzle() -> AVAudioPCMBuffer? {
        synthesize(seconds: 0.42) { time, index in
            let rumble = sin(2 * Double.pi * 70 * time) * exp(-time * 3.2) * 0.7
            let growl = sin(2 * Double.pi * 118 * time) * exp(-time * 4) * 0.45
            let noiseSeed = sin(Double(index) * 78.233) * 43758.5453
            let hiss = (noiseSeed.truncatingRemainder(dividingBy: 1) * 2 - 1) * exp(-time * 2.4) * 0.28
            let crackle = sin(2 * Double.pi * 640 * time) * exp(-time * 16) * 0.2
            return (rumble + growl + hiss + crackle) * 0.52
        }
    }

    private func synthesize(seconds: Double, sample: (_ time: Double, _ index: Int) -> Double) -> AVAudioPCMBuffer? {
        guard format.sampleRate > 0, format.channelCount > 0 else { return nil }
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let sampleRate = format.sampleRate
        for index in 0..<Int(frames) {
            let time = Double(index) / sampleRate
            data[index] = Float(max(-1, min(1, sample(time, index))))
        }
        return buffer
    }
}

enum InterfaceSounds {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        guard
            let original = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.sendAction(_:to:from:for:))
            ),
            let replacement = class_getInstanceMethod(
                UIApplication.self,
                #selector(UIApplication.robot_sendAction(_:to:from:for:))
            )
        else { return }
        method_exchangeImplementations(original, replacement)
    }
}

extension UIApplication {
    @objc func robot_sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool {
        Soundscape.shared.noteInteraction(sender: sender, event: event)
        return robot_sendAction(action, to: target, from: sender, for: event)
    }
}

/// Interrupteur dont la piste éteinte reste visible sur une carte blanche.
final class PaletteSwitch: UIControl {
    private var applying = false
    var isOn = false {
        didSet {
            guard !applying, oldValue != isOn else { return }
            refresh(animated: false)
        }
    }

    private let track = UIView()
    private let thumb = UIView()
    private var thumbX = NSLayoutConstraint()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = [.button]
        track.isUserInteractionEnabled = false
        track.translatesAutoresizingMaskIntoConstraints = false
        thumb.isUserInteractionEnabled = false
        thumb.backgroundColor = .white
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.layer.shadowColor = UIColor.black.cgColor
        thumb.layer.shadowOpacity = 0.18
        thumb.layer.shadowRadius = 1.5
        thumb.layer.shadowOffset = CGSize(width: 0, height: 1)
        addSubview(track)
        addSubview(thumb)
        thumbX = thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2)
        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbX,
            thumb.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumb.widthAnchor.constraint(equalToConstant: 27),
            thumb.heightAnchor.constraint(equalToConstant: 27)
        ])
        refresh(animated: false)
    }

    required init?(coder: NSCoder) { nil }

    override var intrinsicContentSize: CGSize { CGSize(width: 52, height: 32) }

    override func layoutSubviews() {
        super.layoutSubviews()
        track.layer.cornerRadius = bounds.height / 2
        thumb.layer.cornerRadius = 13.5
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        guard let touch, bounds.contains(touch.location(in: self)) else { return }
        applying = true
        isOn.toggle()
        applying = false
        refresh(animated: true)
        sendActions(for: .valueChanged)
    }

    override var accessibilityValue: String? {
        get { isOn ? "activé" : "désactivé" }
        set { }
    }

    private func refresh(animated: Bool) {
        accessibilityValue = isOn ? "activé" : "désactivé"
        let apply = {
            self.track.backgroundColor = self.isOn ? UIColor(hex: 0x7B3FF2) : UIColor(hex: 0x8E83B8)
            self.thumbX.constant = self.isOn ? 23 : 2
            self.layoutIfNeeded()
        }
        guard animated, !PlaySettings.prefersReducedMotion else {
            apply()
            return
        }
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: apply)
    }
}
