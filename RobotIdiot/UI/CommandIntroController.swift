import UIKit
import RobotIdiotCore

/// Alerte posée sur le niveau, sur le même modèle que l'erreur d'exécution.
final class CommandIntroAlertView: UIView {
    var onFinished: (() -> Void)?

    private var commands: [CommandType] = []
    private var index = 0

    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UIView()
    private let badgeIcon = UIImageView()
    private let headlineLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressLabel = UILabel()
    private let nextButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x2A1458).withAlphaComponent(0.78)
        isAccessibilityElement = false

        card.backgroundColor = .white
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.translatesAutoresizingMaskIntoConstraints = false

        robot.image = UIImage(named: "HomeHero")
        robot.contentMode = .scaleAspectFit
        robot.isUserInteractionEnabled = false
        robot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(robot)
        addSubview(card)

        ribbon.backgroundColor = UIColor(hex: 0x7B3FF2)
        ribbon.layer.cornerRadius = 22
        ribbon.layer.cornerCurve = .continuous
        ribbon.layer.masksToBounds = true
        ribbon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ribbon)
        ribbonTitle.text = "Nouvelle commande !"
        ribbonTitle.font = AppTheme.font(22, .heavy, textStyle: .title2)
        ribbonTitle.textColor = .white
        ribbonTitle.textAlignment = .center
        ribbonTitle.adjustsFontSizeToFitWidth = true
        ribbonTitle.minimumScaleFactor = 0.7
        ribbonTitle.translatesAutoresizingMaskIntoConstraints = false
        ribbon.addSubview(ribbonTitle)

        badge.backgroundColor = UIColor(hex: 0x7B3FF2)
        badge.layer.cornerRadius = 24
        badge.layer.borderWidth = 4
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.tintColor = .white
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeIcon)
        addSubview(badge)

        headlineLabel.font = AppTheme.font(18, .heavy, textStyle: .headline)
        headlineLabel.textColor = AppTheme.line
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0
        headlineLabel.adjustsFontForContentSizeCategory = true

        detailLabel.font = AppTheme.font(16, .medium, textStyle: .body)
        detailLabel.textColor = AppTheme.line
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0
        detailLabel.adjustsFontForContentSizeCategory = true

        progressLabel.font = AppTheme.font(13, .bold, textStyle: .caption1)
        progressLabel.textColor = UIColor(hex: 0x667085)
        progressLabel.textAlignment = .center

        style(nextButton, title: "Suivant")
        nextButton.addTarget(self, action: #selector(advance), for: .touchUpInside)

        let message = UIStackView(arrangedSubviews: [headlineLabel, detailLabel, progressLabel, nextButton])
        message.axis = .vertical
        message.alignment = .fill
        message.spacing = 12
        message.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(message)

        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 36),
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 18),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -36).prioritized(.init(750)),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 440),

            robot.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            robot.widthAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.78),
            robot.heightAnchor.constraint(equalTo: robot.widthAnchor, multiplier: 1.25),
            robot.bottomAnchor.constraint(equalTo: card.topAnchor, constant: 108),

            ribbon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            ribbon.topAnchor.constraint(equalTo: card.topAnchor, constant: -22),
            ribbon.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -48),
            ribbon.heightAnchor.constraint(equalToConstant: 58),
            ribbonTitle.leadingAnchor.constraint(equalTo: ribbon.leadingAnchor, constant: 16),
            ribbonTitle.trailingAnchor.constraint(equalTo: ribbon.trailingAnchor, constant: -16),
            ribbonTitle.bottomAnchor.constraint(equalTo: ribbon.bottomAnchor, constant: -10),

            badge.centerXAnchor.constraint(equalTo: ribbon.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: ribbon.topAnchor, constant: 2),
            badge.widthAnchor.constraint(equalToConstant: 48),
            badge.heightAnchor.constraint(equalToConstant: 48),
            badgeIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 24),
            badgeIcon.heightAnchor.constraint(equalToConstant: 24),

            message.topAnchor.constraint(equalTo: card.topAnchor, constant: 46),
            message.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            message.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            message.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present(commands: [CommandType]) {
        self.commands = commands
        index = 0
        showCurrent()
        accessibilityViewIsModal = true
        guard !PlaySettings.prefersReducedMotion else {
            robot.transform = .identity
            card.transform = .identity
            ribbon.transform = .identity
            badge.transform = .identity
            return
        }
        robot.alpha = 0
        card.alpha = 0
        ribbon.alpha = 0
        badge.alpha = 0
        robot.transform = CGAffineTransform(translationX: 0, y: 28)
        card.transform = CGAffineTransform(scaleX: 0.86, y: 0.86).translatedBy(x: 0, y: 24)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5) {
            self.robot.alpha = 1
            self.card.alpha = 1
            self.ribbon.alpha = 1
            self.badge.alpha = 1
            self.robot.transform = .identity
            self.card.transform = .identity
        }
    }

    private func showCurrent() {
        guard commands.indices.contains(index) else { return }
        let lesson = CommandLesson.make(commands[index])
        headlineLabel.text = lesson.name
        detailLabel.text = lesson.explanation
        badgeIcon.image = GameArt.fitted(GameArt.commandIcon(commands[index]), side: 24)
        progressLabel.isHidden = commands.count < 2
        progressLabel.text = "\(index + 1) sur \(commands.count)"
        let announcement = "Nouvelle commande. \(lesson.name). \(lesson.explanation)"
        accessibilityLabel = announcement
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }

    private func style(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        configuration.imagePadding = 6
        configuration.imagePlacement = .trailing
        configuration.baseBackgroundColor = UIColor(hex: 0x7B3FF2)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.titleLineBreakMode = .byClipping
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(14, .bold, textStyle: .headline)
            return updated
        }
        button.configuration = configuration
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.accessibilityLabel = title
    }

    @objc private func advance() {
        guard commands.indices.contains(index) else { return }
        PlaySettings.introduce(commands[index])
        guard index + 1 < commands.count else {
            onFinished?()
            return
        }
        index += 1
        showCurrent()
    }
}

private struct CommandLesson {
    var name: String
    var explanation: String

    static func make(_ command: CommandType) -> CommandLesson {
        switch command {
        case .moveForward:
            return CommandLesson(name: "AVANCE", explanation: "Avance d'une case dans la direction de la visière.")
        case .moveBackward:
            return CommandLesson(name: "RECULE", explanation: "Recule d'une case. La direction du robot ne change pas.")
        case .turnLeft:
            return CommandLesson(name: "GAUCHE", explanation: "Tourne d'un quart de tour vers la gauche, sans changer de case.")
        case .turnRight:
            return CommandLesson(name: "DROITE", explanation: "Tourne d'un quart de tour vers la droite, sans changer de case.")
        case .pickUp:
            return CommandLesson(name: "RAMASSE", explanation: "Ramasse la clé posée sur la case du robot.")
        case .use:
            return CommandLesson(name: "UTILISE", explanation: "Face à une porte verrouillée, utilise la clé. Elle est consommée et la porte s'ouvre.")
        case .push:
            return CommandLesson(name: "POUSSE", explanation: "Pousse la caisse d'une case vers l'avant. Le robot prend sa place.")
        case .activate:
            return CommandLesson(name: "ACTIVE", explanation: "Sur l'interrupteur, active-le une seule fois. La grille s'ouvre et reste ouverte.")
        case .forever:
            return CommandLesson(name: "RÉPÈTE", explanation: "Répète indéfiniment les instructions contenues dans le bloc.")
        case .ifBlock:
            return CommandLesson(name: "SI", explanation: "Les instructions du bloc s'exécutent quand la condition est vraie. Une condition fausse saute le bloc.")
        }
    }
}
