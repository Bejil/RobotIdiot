import UIKit

/// Alerte d'exécution : bandeau rouge, explication et retour à l'éditeur.
final class ExecutionAlertView: UIView {
    var onEdit: (() -> Void)?

    private let composition = UIView()
    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UILabel()
    private let headlineLabel = UILabel()
    private let detailLabel = UILabel()
    private let editButton = UIButton(type: .system)

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

        robot.image = UIImage(named: "RobotSad") ?? UIImage(named: "HomeHero")
        robot.contentMode = .scaleAspectFit
        robot.isUserInteractionEnabled = false
        robot.accessibilityLabel = "Robot triste"

        ribbon.backgroundColor = UIColor(hex: 0xFF4B5C)
        ribbon.layer.cornerRadius = 22
        ribbon.layer.cornerCurve = .continuous
        ribbon.layer.masksToBounds = true
        ribbonTitle.text = "Erreur d'exécution"
        ribbonTitle.font = AppTheme.font(22, .heavy, textStyle: .title2)
        ribbonTitle.textColor = .white
        ribbonTitle.textAlignment = .center
        ribbonTitle.translatesAutoresizingMaskIntoConstraints = false
        ribbon.addSubview(ribbonTitle)

        badge.text = "!"
        badge.font = AppTheme.font(26, .heavy, textStyle: .title2)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = UIColor(hex: 0xFF5D6C)
        badge.layer.cornerRadius = 24
        badge.layer.borderWidth = 4
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.masksToBounds = true

        addSubview(composition)
        composition.addSubview(robot)
        composition.addSubview(card)
        composition.addSubview(ribbon)
        composition.addSubview(badge)

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

        let message = UIStackView(arrangedSubviews: [headlineLabel, detailLabel])
        message.axis = .vertical
        message.alignment = .fill
        message.spacing = 6

        style(editButton, title: "Modifier", systemImage: "pencil")
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        let column = UIStackView(arrangedSubviews: [message, editButton])
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)

        ChartedAlertPlacement.pinComposition(
            in: self,
            composition: composition,
            card: card,
            robot: robot,
            ribbon: ribbon,
            badge: badge
        )
        NSLayoutConstraint.activate([
            ribbonTitle.leadingAnchor.constraint(equalTo: ribbon.leadingAnchor, constant: 16),
            ribbonTitle.trailingAnchor.constraint(equalTo: ribbon.trailingAnchor, constant: -16),
            ribbonTitle.bottomAnchor.constraint(equalTo: ribbon.bottomAnchor, constant: -10),

            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 46),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            editButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present(headline: String, detail: String) {
        headlineLabel.text = headline
        detailLabel.text = detail
        accessibilityViewIsModal = true
        let announcement = "Erreur d'exécution. \(headline) \(detail)"
        accessibilityLabel = announcement
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
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

    private func style(_ button: UIButton, title: String, systemImage: String?) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = systemImage.flatMap {
            UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        }
        configuration.imagePadding = 6
        configuration.imagePlacement = .leading
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
    }

    @objc private func editTapped() { onEdit?() }
}
