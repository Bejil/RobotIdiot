import UIKit

/// Hôte plein écran pour les alertes chartées (fenêtre = au-dessus de la navigation bar).
enum AlertOverlayHost {
    static func view(for controller: UIViewController) -> UIView {
        if let window = controller.view.window {
            return window
        }
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return window
        }
        if let navigation = controller.navigationController {
            return navigation.view
        }
        if let tab = controller.tabBarController {
            return tab.view
        }
        if controller.view is UIScrollView, let parent = controller.parent {
            return parent.view
        }
        return controller.view
    }

    static func attach(_ overlay: UIView, to controller: UIViewController) {
        let host = view(for: controller)
        if overlay.superview !== host {
            overlay.removeFromSuperview()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: host.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
        }
        host.bringSubviewToFront(overlay)
    }

    static func detach(_ overlay: UIView) {
        overlay.isHidden = true
        overlay.removeFromSuperview()
    }
}

/// Centre le duo robot + carte (et non la carte seule, qui remontait tout le bloc).
enum ChartedAlertPlacement {
    static func pinComposition(
        in overlay: UIView,
        composition: UIView,
        card: UIView,
        robot: UIView,
        ribbon: UIView,
        badge: UIView
    ) {
        composition.translatesAutoresizingMaskIntoConstraints = false
        robot.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        ribbon.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false

        let centerY = composition.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        centerY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            composition.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            centerY,
            composition.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 18),
            composition.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -18),
            composition.widthAnchor.constraint(equalTo: overlay.widthAnchor, constant: -36).prioritized(.init(750)),
            composition.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            composition.topAnchor.constraint(greaterThanOrEqualTo: overlay.safeAreaLayoutGuide.topAnchor, constant: 8),
            composition.bottomAnchor.constraint(lessThanOrEqualTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            robot.topAnchor.constraint(equalTo: composition.topAnchor),
            robot.centerXAnchor.constraint(equalTo: composition.centerXAnchor),
            robot.widthAnchor.constraint(equalTo: composition.widthAnchor, multiplier: 0.62),
            robot.heightAnchor.constraint(equalTo: robot.widthAnchor, multiplier: 1.25),
            robot.bottomAnchor.constraint(equalTo: card.topAnchor, constant: 96),

            card.leadingAnchor.constraint(equalTo: composition.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: composition.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: composition.bottomAnchor),

            ribbon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            ribbon.topAnchor.constraint(equalTo: card.topAnchor, constant: -22),
            ribbon.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -48),
            ribbon.heightAnchor.constraint(equalToConstant: 58),

            badge.centerXAnchor.constraint(equalTo: ribbon.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: ribbon.topAnchor, constant: 2),
            badge.widthAnchor.constraint(equalToConstant: 48),
            badge.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
}

/// Confirmation chartée (même langage que l'alerte d'exécution).
final class ChartedConfirmAlertView: UIView {
    enum Accent {
        case destructive
        case primary

        var ribbon: UIColor {
            switch self {
            case .destructive: return UIColor(hex: 0xFF4B5C)
            case .primary: return UIColor(hex: 0x7B3FF2)
            }
        }

        var badge: UIColor {
            switch self {
            case .destructive: return UIColor(hex: 0xFF5D6C)
            case .primary: return UIColor(hex: 0x7B3FF2)
            }
        }

        var confirm: UIColor {
            switch self {
            case .destructive: return UIColor(hex: 0xE03131)
            case .primary: return UIColor(hex: 0x7B3FF2)
            }
        }

        var symbol: String {
            switch self {
            case .destructive: return "!"
            case .primary: return "?"
            }
        }

        var robotName: String {
            switch self {
            case .destructive: return "RobotSad"
            case .primary: return "HomeHero"
            }
        }
    }

    private var onCancel: (() -> Void)?
    private var onConfirm: (() -> Void)?
    private var onChoices: [() -> Void] = []

    private let composition = UIView()
    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UILabel()
    private let headlineLabel = UILabel()
    private let detailLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private let choicesScroll = UIScrollView()
    private let choicesStack = UIStackView()
    private let actions = UIStackView()
    private var choicesScrollHeight: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x2A1458).withAlphaComponent(0.78)
        isAccessibilityElement = false
        accessibilityViewIsModal = true

        card.backgroundColor = .white
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 8)

        robot.contentMode = .scaleAspectFit
        robot.isUserInteractionEnabled = false

        ribbon.layer.cornerRadius = 22
        ribbon.layer.cornerCurve = .continuous
        ribbon.layer.masksToBounds = true
        ribbonTitle.font = AppTheme.font(22, .heavy, textStyle: .title2)
        ribbonTitle.textColor = .white
        ribbonTitle.textAlignment = .center
        ribbonTitle.adjustsFontSizeToFitWidth = true
        ribbonTitle.minimumScaleFactor = 0.7
        ribbonTitle.translatesAutoresizingMaskIntoConstraints = false
        ribbon.addSubview(ribbonTitle)

        badge.font = AppTheme.font(26, .heavy, textStyle: .title2)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.layer.cornerRadius = 24
        badge.layer.borderWidth = 4
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.masksToBounds = true

        composition.isUserInteractionEnabled = true
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

        styleOutline(cancelButton, title: "Annuler")
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        choicesStack.axis = .vertical
        choicesStack.spacing = 10
        choicesStack.alignment = .fill
        choicesStack.translatesAutoresizingMaskIntoConstraints = false
        choicesScroll.translatesAutoresizingMaskIntoConstraints = false
        choicesScroll.showsVerticalScrollIndicator = true
        choicesScroll.alwaysBounceVertical = false
        choicesScroll.addSubview(choicesStack)
        choicesScroll.isHidden = true
        let scrollHeight = choicesScroll.heightAnchor.constraint(equalToConstant: 0)
        scrollHeight.priority = .defaultHigh
        choicesScrollHeight = scrollHeight

        actions.axis = .vertical
        actions.spacing = 10
        actions.alignment = .fill
        actions.addArrangedSubview(choicesScroll)
        actions.addArrangedSubview(confirmButton)
        actions.addArrangedSubview(cancelButton)

        let message = UIStackView(arrangedSubviews: [headlineLabel, detailLabel])
        message.axis = .vertical
        message.alignment = .fill
        message.spacing = 6

        let column = UIStackView(arrangedSubviews: [message, actions])
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

            confirmButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            choicesStack.topAnchor.constraint(equalTo: choicesScroll.contentLayoutGuide.topAnchor),
            choicesStack.leadingAnchor.constraint(equalTo: choicesScroll.contentLayoutGuide.leadingAnchor),
            choicesStack.trailingAnchor.constraint(equalTo: choicesScroll.contentLayoutGuide.trailingAnchor),
            choicesStack.bottomAnchor.constraint(equalTo: choicesScroll.contentLayoutGuide.bottomAnchor),
            choicesStack.widthAnchor.constraint(equalTo: choicesScroll.frameLayoutGuide.widthAnchor),
            scrollHeight
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    @discardableResult
    static func present(
        on host: UIView,
        ribbon: String,
        headline: String,
        detail: String,
        confirmTitle: String,
        cancelTitle: String? = "Annuler",
        accent: Accent = .destructive,
        confirmSystemImage: String? = "trash",
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> ChartedConfirmAlertView {
        host.subviews.compactMap { $0 as? ChartedConfirmAlertView }.forEach { $0.removeFromSuperview() }
        let alert = ChartedConfirmAlertView()
        alert.configure(
            ribbon: ribbon,
            headline: headline,
            detail: detail,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            accent: accent,
            confirmSystemImage: confirmSystemImage
        )
        alert.onCancel = onCancel
        alert.onConfirm = onConfirm
        alert.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(alert)
        NSLayoutConstraint.activate([
            alert.topAnchor.constraint(equalTo: host.topAnchor),
            alert.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            alert.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            alert.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        host.bringSubviewToFront(alert)
        alert.playEntrance()
        return alert
    }

    @discardableResult
    static func present(
        from controller: UIViewController,
        ribbon: String,
        headline: String,
        detail: String,
        confirmTitle: String,
        cancelTitle: String? = "Annuler",
        accent: Accent = .destructive,
        confirmSystemImage: String? = "trash",
        onCancel: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> ChartedConfirmAlertView {
        present(
            on: AlertOverlayHost.view(for: controller),
            ribbon: ribbon,
            headline: headline,
            detail: detail,
            confirmTitle: confirmTitle,
            cancelTitle: cancelTitle,
            accent: accent,
            confirmSystemImage: confirmSystemImage,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
    }

    /// Message informatif à un seul bouton (remplace les bandeaux d'erreur de l'éditeur).
    @discardableResult
    static func presentNotice(
        from controller: UIViewController,
        ribbon: String = "Attention",
        message: String,
        confirmTitle: String = "Compris"
    ) -> ChartedConfirmAlertView {
        present(
            from: controller,
            ribbon: ribbon,
            headline: message,
            detail: "",
            confirmTitle: confirmTitle,
            cancelTitle: nil,
            accent: .primary,
            confirmSystemImage: "exclamationmark.circle",
            onConfirm: {}
        )
    }

    /// Choix multiple (ex. condition d’un SI), même chrome que les autres alertes du jeu.
    @discardableResult
    static func presentChoices(
        from controller: UIViewController,
        ribbon: String,
        headline: String,
        detail: String = "",
        choices: [(title: String, systemImage: String?)],
        cancelTitle: String = "Annuler",
        accent: Accent = .primary,
        onCancel: (() -> Void)? = nil,
        onChoose: @escaping (Int) -> Void
    ) -> ChartedConfirmAlertView {
        let host = AlertOverlayHost.view(for: controller)
        host.subviews.compactMap { $0 as? ChartedConfirmAlertView }.forEach { $0.removeFromSuperview() }
        let alert = ChartedConfirmAlertView()
        alert.configureChoices(
            ribbon: ribbon,
            headline: headline,
            detail: detail,
            choices: choices,
            cancelTitle: cancelTitle,
            accent: accent,
            onCancel: onCancel,
            onChoose: onChoose
        )
        alert.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(alert)
        NSLayoutConstraint.activate([
            alert.topAnchor.constraint(equalTo: host.topAnchor),
            alert.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            alert.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            alert.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        host.bringSubviewToFront(alert)
        alert.playEntrance()
        return alert
    }

    private func configure(
        ribbon title: String,
        headline: String,
        detail: String,
        confirmTitle: String,
        cancelTitle: String?,
        accent: Accent,
        confirmSystemImage: String?
    ) {
        applyChrome(ribbon: title, headline: headline, detail: detail, accent: accent)
        choicesScroll.isHidden = true
        choicesScrollHeight?.constant = 0
        confirmButton.isHidden = false
        styleFilled(confirmButton, title: confirmTitle, systemImage: confirmSystemImage, color: accent.confirm)
        applyCancel(cancelTitle)
        confirmButton.accessibilityLabel = confirmTitle
        let announcement = "\(title). \(headline) \(detail)"
        accessibilityLabel = announcement
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }

    private func configureChoices(
        ribbon title: String,
        headline: String,
        detail: String,
        choices: [(title: String, systemImage: String?)],
        cancelTitle: String,
        accent: Accent,
        onCancel: (() -> Void)?,
        onChoose: @escaping (Int) -> Void
    ) {
        applyChrome(ribbon: title, headline: headline, detail: detail, accent: accent)
        self.onCancel = onCancel
        onConfirm = nil
        confirmButton.isHidden = true
        choicesScroll.isHidden = false
        choicesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        onChoices = choices.indices.map { index in { onChoose(index) } }
        for (index, choice) in choices.enumerated() {
            let button = UIButton(type: .system)
            styleFilled(button, title: choice.title, systemImage: choice.systemImage, color: accent.confirm)
            button.tag = index
            button.accessibilityLabel = choice.title
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            button.addTarget(self, action: #selector(choiceTapped(_:)), for: .touchUpInside)
            choicesStack.addArrangedSubview(button)
        }
        let rowHeight: CGFloat = 58
        let contentHeight = CGFloat(max(choices.count, 1)) * rowHeight - 10
        choicesScrollHeight?.constant = min(contentHeight, 280)
        applyCancel(cancelTitle)
        let announcement = "\(title). \(headline) \(detail)"
        accessibilityLabel = announcement
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }

    private func applyChrome(ribbon title: String, headline: String, detail: String, accent: Accent) {
        ribbon.backgroundColor = accent.ribbon
        ribbonTitle.text = title
        badge.backgroundColor = accent.badge
        badge.text = accent.symbol
        robot.image = UIImage(named: accent.robotName) ?? UIImage(named: "HomeHero")
        robot.accessibilityLabel = accent == .destructive ? "Robot triste" : "Robot"
        headlineLabel.text = headline
        detailLabel.text = detail
        detailLabel.isHidden = detail.isEmpty
    }

    private func applyCancel(_ cancelTitle: String?) {
        if let cancelTitle {
            cancelButton.isHidden = false
            if var configuration = cancelButton.configuration {
                configuration.title = cancelTitle
                cancelButton.configuration = configuration
            }
            cancelButton.accessibilityLabel = cancelTitle
        } else {
            cancelButton.isHidden = true
        }
    }

    private func playEntrance() {
        guard !PlaySettings.prefersReducedMotion else {
            robot.transform = .identity
            card.transform = .identity
            return
        }
        alpha = 1
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

    private func dismiss(then action: (() -> Void)?) {
        let finish = { [weak self] in
            self?.removeFromSuperview()
            action?()
        }
        guard !PlaySettings.prefersReducedMotion else {
            finish()
            return
        }
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.92, y: 0.92).translatedBy(x: 0, y: 12)
        }, completion: { _ in finish() })
    }

    private func styleFilled(_ button: UIButton, title: String, systemImage: String?, color: UIColor) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = systemImage.flatMap {
            UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        }
        configuration.imagePadding = 6
        configuration.imagePlacement = .leading
        configuration.baseBackgroundColor = color
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

    private func styleOutline(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.bordered()
        configuration.title = title
        configuration.baseForegroundColor = AppTheme.line
        configuration.baseBackgroundColor = UIColor(hex: 0xF2F3F7)
        configuration.cornerStyle = .capsule
        configuration.background.strokeColor = UIColor(hex: 0xD0D5DD)
        configuration.background.strokeWidth = 1.5
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(14, .bold, textStyle: .headline)
            return updated
        }
        button.configuration = configuration
    }

    @objc private func cancelTapped() {
        let handler = onCancel
        dismiss(then: handler)
    }

    @objc private func confirmTapped() {
        let handler = onConfirm
        dismiss(then: handler)
    }

    @objc private func choiceTapped(_ sender: UIButton) {
        guard onChoices.indices.contains(sender.tag) else { return }
        let handler = onChoices[sender.tag]
        dismiss(then: handler)
    }
}
