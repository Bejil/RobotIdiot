import UIKit
import RobotIdiotCore

extension NSLayoutConstraint {
    func prioritized(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum ButtonTone {
    case action
    case primary
    case quiet
    case danger
}

enum AppTheme {
    static let cream = UIColor(hex: 0x101848)
    static let creamDeep = UIColor(hex: 0x182058)
    static let ink = UIColor(hex: 0xF6F3FF)
    static let inkSoft = UIColor(hex: 0xB7B3D9)
    static let line = UIColor(hex: 0x1A1440)
    static let teal = UIColor(hex: 0x7A2CF7)
    static let tealDark = UIColor(hex: 0x5CE1FF)
    static let coral = UIColor(hex: 0xFF5A6E)
    static let gold = UIColor(hex: 0xFFD200)
    static let success = UIColor(hex: 0x3DDC84)
    static let control = UIColor(hex: 0xC084FC)
    static let move = UIColor(hex: 0x3EC6FF)
    static let interaction = UIColor(hex: 0xFFB020)
    static let border = UIColor(hex: 0x3A4C96)
    static let blockAncestor = UIColor(hex: 0x32265F)
    static let floorA = UIColor(hex: 0x8BE37A)
    static let floorB = UIColor(hex: 0x6ED15C)
    static let goalFloor = UIColor(hex: 0xFFE14A)
    static let wall = UIColor(hex: 0x2C6B45)
    static let wallStroke = UIColor(hex: 0x1B4A30)
    static let robotBody = UIColor(hex: 0xF7F4EF)
    static let robotShadow = UIColor(hex: 0x0A1028)
    static let boardBackdrop = UIColor(hex: 0x57C24A)
    static let blockFill = UIColor(hex: 0x2A3488)
    static let blockActive = UIColor(hex: 0x4A3E16)
    static let blockFailed = UIColor(hex: 0x5A2434)
    static let card = UIColor(hex: 0x1C2874)

    static func font(_ size: CGFloat, _ weight: UIFont.Weight, textStyle: UIFont.TextStyle = .body) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let designed = base.fontDescriptor.withDesign(.rounded).map {
            UIFont(descriptor: $0, size: size)
        } ?? base
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: designed)
    }

    static func apply(to navigation: UINavigationController) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: ink,
            .font: font(18, .heavy, textStyle: .headline)
        ]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.compactScrollEdgeAppearance = appearance
        navigation.navigationBar.tintColor = gold
        navigation.navigationBar.isTranslucent = true
        navigation.navigationBar.barStyle = .black
    }

    static func filledButton(
        title: String,
        systemImage: String,
        prominent: Bool,
        compact: Bool = false,
        tone: ButtonTone? = nil
    ) -> UIButton {
        let tone = tone ?? (prominent ? ButtonTone.action : .quiet)
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: systemImage)
        configuration.imagePlacement = compact || tone == .quiet ? .top : .leading
        configuration.imagePadding = compact ? 2 : 8
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = compact ? 16 : 22
        switch tone {
        case .action:
            configuration.baseBackgroundColor = gold
            configuration.baseForegroundColor = line
        case .primary:
            configuration.baseBackgroundColor = teal
            configuration.baseForegroundColor = .white
        case .danger:
            configuration.baseBackgroundColor = coral
            configuration.baseForegroundColor = .white
        case .quiet:
            configuration.baseBackgroundColor = card
            configuration.baseForegroundColor = ink
            configuration.background.strokeColor = border
            configuration.background.strokeWidth = 1.5
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: compact ? 6 : 12,
            leading: compact ? 4 : 12,
            bottom: compact ? 6 : 12,
            trailing: compact ? 4 : 12
        )
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            let size: CGFloat = compact ? 13 : (tone == .quiet ? 15 : 18)
            outgoing.font = font(size, .heavy, textStyle: compact ? .caption1 : .headline)
            return outgoing
        }
        configuration.titleLineBreakMode = .byTruncatingTail
        let button = GameButton(configuration: configuration)
        button.accessibilityLabel = title
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = tone == .quiet ? 0 : 0.35
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 5)
        return button
    }
}

final class GameButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1, bounds.height > 1 else { return }
        let radius = layer.cornerRadius > 1 ? layer.cornerRadius : min(22, bounds.height / 2)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        setPressed(true)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        setPressed(false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        setPressed(false)
    }

    private func setPressed(_ pressed: Bool) {
        guard !PlaySettings.prefersReducedMotion else { return }
        UIView.animate(
            withDuration: pressed ? 0.08 : 0.42,
            delay: 0,
            usingSpringWithDamping: pressed ? 1 : 0.55,
            initialSpringVelocity: 0.7,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = pressed
                ? CGAffineTransform(translationX: 0, y: 3).scaledBy(x: 0.97, y: 0.97)
                : .identity
            self.layer.shadowOffset = CGSize(width: 0, height: pressed ? 1 : 5)
        }
    }
}

struct BoardPalette {
    var backdrop: UIColor
    var floorA: UIColor
    var floorB: UIColor
    var goal: UIColor
    var wall: UIColor
    var wallStroke: UIColor
    var grout: UIColor

    static func make(_ theme: ThemeIdentifier) -> BoardPalette {
        switch theme {
        case .orchard:
            return BoardPalette(
                backdrop: UIColor(hex: 0xE4F0D8),
                floorA: UIColor(hex: 0xDDEFC8),
                floorB: UIColor(hex: 0xCEE6C4),
                goal: UIColor(hex: 0xF2D56B),
                wall: UIColor(hex: 0x3E6B45),
                wallStroke: UIColor(hex: 0x2C4E32),
                grout: UIColor(hex: 0xC5DDB8)
            )
        case .night:
            return BoardPalette(
                backdrop: UIColor(hex: 0x1C2430),
                floorA: UIColor(hex: 0x314056),
                floorB: UIColor(hex: 0x28364A),
                goal: UIColor(hex: 0xE2B34A),
                wall: UIColor(hex: 0x121820),
                wallStroke: UIColor(hex: 0x0B1016),
                grout: UIColor(hex: 0x243044)
            )
        case .foundry:
            return BoardPalette(
                backdrop: UIColor(hex: 0xE7CDB4),
                floorA: UIColor(hex: 0xF0D2B4),
                floorB: UIColor(hex: 0xE7C4A8),
                goal: UIColor(hex: 0xF2B544),
                wall: UIColor(hex: 0x6B3A2A),
                wallStroke: UIColor(hex: 0x4E291E),
                grout: UIColor(hex: 0xD7B48A)
            )
        default:
            return BoardPalette(
                backdrop: AppTheme.boardBackdrop,
                floorA: AppTheme.floorA,
                floorB: AppTheme.floorB,
                goal: AppTheme.goalFloor,
                wall: AppTheme.wall,
                wallStroke: AppTheme.wallStroke,
                grout: UIColor(hex: 0x4EAE42)
            )
        }
    }

    func contrasted() -> BoardPalette {
        var copy = self
        copy.wallStroke = AppTheme.line
        copy.grout = AppTheme.line.withAlphaComponent(0.55)
        return copy
    }
}

/// Couleurs des pastilles de commande (palette éditeur + aide).
enum CommandChrome {
    static func badgeColors(_ command: CommandType) -> (background: UIColor, foreground: UIColor) {
        switch command.category {
        case .movement:
            return (UIColor(hex: 0x2F9BFF), .white)
        case .interaction:
            return (UIColor(hex: 0x7A2CF7), .white)
        case .control:
            return (UIColor(hex: 0xFFD200), UIColor(hex: 0x1A1440))
        }
    }

    /// Encre palette : noir pour le contrôle, blanc sinon.
    static func paletteInk(_ command: CommandType) -> UIColor {
        command.category == .control ? .black : .white
    }
}
