import AVFoundation
import UIKit

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
    private let selectionHaptic = UISelectionFeedbackGenerator()
    private let noticeHaptic = UINotificationFeedbackGenerator()

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        engine.attach(effects)
        engine.attach(music)
        engine.connect(effects, to: engine.mainMixerNode, format: format)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        effects.volume = 0.55
        music.volume = 0.16
        tones["tap"] = tone(frequency: 520, seconds: 0.045, volume: 0.35)
        tones["ui"] = tone(frequency: 880, seconds: 0.028, volume: 0.3)
        tones["toggle"] = sequence([620, 860], note: 0.045, volume: 0.26)
        tones["select"] = tone(frequency: 640, seconds: 0.04, volume: 0.28)
        tones["move"] = tone(frequency: 440, seconds: 0.06, volume: 0.28)
        tones["turn"] = tone(frequency: 330, seconds: 0.07, volume: 0.28)
        tones["success"] = sequence([523, 659, 784], note: 0.11, volume: 0.32)
        tones["error"] = tone(frequency: 174, seconds: 0.18, volume: 0.3)
        tones["music"] = sequence([262, 330, 392, 440, 392, 330], note: 0.42, volume: 0.16)
        lightHaptic.prepare()
        softHaptic.prepare()
        selectionHaptic.prepare()
        noticeHaptic.prepare()
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
            play("toggle")
        } else if sender is UIControl || sender is UIBarButtonItem {
            play("ui")
        }
    }

    func play(_ name: String, forceHaptic: Bool = false) {
        pulse(name, force: forceHaptic)
        guard PlaySettings.sound, let buffer = tones[name] else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        if !effects.isPlaying { effects.play() }
        effects.scheduleBuffer(buffer, at: nil, options: [])
    }

    func setMusic(playing: Bool) {
        guard playing, PlaySettings.music, let buffer = tones["music"] else {
            if music.isPlaying { music.stop() }
            return
        }
        startIfNeeded()
        guard engine.isRunning else { return }
        if music.isPlaying { return }
        music.scheduleBuffer(buffer, at: nil, options: .loops)
        music.play()
    }

    private func pulse(_ name: String, force: Bool) {
        guard force || PlaySettings.haptics else { return }
        switch name {
        case "ui":
            lightHaptic.impactOccurred()
            lightHaptic.prepare()
        case "toggle", "select":
            selectionHaptic.selectionChanged()
            selectionHaptic.prepare()
        case "move", "turn", "tap":
            softHaptic.impactOccurred(intensity: 0.7)
            softHaptic.prepare()
        case "success":
            noticeHaptic.notificationOccurred(.success)
            noticeHaptic.prepare()
        case "error":
            noticeHaptic.notificationOccurred(.warning)
            noticeHaptic.prepare()
        default:
            break
        }
    }

    private func startIfNeeded() {
        guard !unavailable, !engine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
        } catch {
            unavailable = true
        }
    }

    private func tone(frequency: Double, seconds: Double, volume: Float) -> AVAudioPCMBuffer? {
        guard format.sampleRate > 0, format.channelCount > 0 else { return nil }
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        let sampleRate = format.sampleRate
        for index in 0..<Int(frames) {
            let time = Double(index) / sampleRate
            let attack = min(1, time / 0.012)
            let release = min(1, max(0, (seconds - time) / 0.028))
            let sample = sin(2 * Double.pi * frequency * time) * attack * release
            data[index] = Float(sample) * volume
        }
        return buffer
    }

    private func sequence(_ frequencies: [Double], note: Double, volume: Float) -> AVAudioPCMBuffer? {
        let pieces = frequencies.compactMap { tone(frequency: $0, seconds: note, volume: volume) }
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
