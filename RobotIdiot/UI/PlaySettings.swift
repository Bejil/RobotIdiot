import UIKit
import RobotIdiotCore

enum InterfaceScale: String {
    case system
    case large
    case extraLarge

    var category: UIContentSizeCategory? {
        switch self {
        case .system: return nil
        case .large: return .extraExtraLarge
        case .extraLarge: return .accessibilityExtraLarge
        }
    }
}

enum PlaySettings {
    static let changed = Notification.Name("robotidiot.settingsChanged")

    static var sound: Bool {
        get { stored("robotidiot.sound", default: true) }
        set { write(newValue, key: "robotidiot.sound") }
    }

    static var music: Bool {
        get { stored("robotidiot.music", default: false) }
        set { write(newValue, key: "robotidiot.music") }
    }

    static var haptics: Bool {
        get { stored("robotidiot.haptics", default: true) }
        set { write(newValue, key: "robotidiot.haptics") }
    }

    static var fastAnimation: Bool {
        get { stored("robotidiot.fastAnimation", default: false) }
        set { write(newValue, key: "robotidiot.fastAnimation") }
    }

    static var contrast: Bool {
        get { stored("robotidiot.contrast", default: false) }
        set { write(newValue, key: "robotidiot.contrast") }
    }

    static var reduceMotion: Bool {
        get { stored("robotidiot.reduceMotion", default: false) }
        set { write(newValue, key: "robotidiot.reduceMotion") }
    }

    static var scale: InterfaceScale {
        get { InterfaceScale(rawValue: UserDefaults.standard.string(forKey: "robotidiot.scale") ?? "") ?? .system }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "robotidiot.scale")
            NotificationCenter.default.post(name: changed, object: nil)
        }
    }

    static var tutorialSeen: Bool {
        get { stored("robotidiot.tutorialSeen", default: false) }
        set { write(newValue, key: "robotidiot.tutorialSeen") }
    }

    static func hasIntroduced(_ command: CommandType) -> Bool {
        introducedCommands.contains(command.rawValue)
    }

    static func introduce(_ command: CommandType) {
        var known = introducedCommands
        known.insert(command.rawValue)
        UserDefaults.standard.set(known.sorted(), forKey: introducedCommandsKey)
    }

    static func resetIntroducedCommands() {
        UserDefaults.standard.removeObject(forKey: introducedCommandsKey)
    }

    private static let introducedCommandsKey = "robotidiot.introducedCommands"

    private static var introducedCommands: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: introducedCommandsKey) ?? [])
    }

    static var prefersReducedMotion: Bool {
        reduceMotion || UIAccessibility.isReduceMotionEnabled
    }

    static func applyInterfaceScale(to window: UIWindow?) {
        guard let window else { return }
        if let category = scale.category {
            window.traitOverrides.preferredContentSizeCategory = category
        } else {
            window.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
        }
    }

    private static func stored(_ key: String, default defaultValue: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func write(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(name: changed, object: nil)
    }
}
