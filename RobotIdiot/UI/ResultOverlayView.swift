import UIKit
import RobotIdiotCore

final class ResultOverlayView: UIView {
    var onRetry: (() -> Void)?
    var onNext: (() -> Void)?
    var onExit: (() -> Void)?

    private let rays = UIImageView(image: UIImage(named: "VictoryRays"))
    private let clouds = DriftStrip()
    private let ribbon = UIImageView(image: UIImage(named: "VictoryRibbon"))
    private let confetti = UIImageView(image: UIImage(named: "VictoryConfetti"))
    private let robot = UIImageView(image: UIImage(named: "VictoryRobot"))
    private let stars = UIStackView()
    private var starViews: [UIImageView] = []
    private let detailsCard = UIView()
    private let sizeValue = UILabel()
    private let actionValue = UILabel()
    private let moveValue = UILabel()
    private let boltValue = UILabel()
    private let noteLabel = UILabel()
    private let boltRow = UIStackView()
    private let nextButton = AppTheme.filledButton(title: "Niveau suivant", systemImage: "play.fill", prominent: true)
    private let retryButton = AppTheme.filledButton(title: "Réessayer", systemImage: "arrow.clockwise", prominent: false, tone: .primary)
    private let exitButton = AppTheme.filledButton(title: "Retour", systemImage: "house.fill", prominent: false, tone: .primary)
    private var playing = false
    private var driftedWidth: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x10245F)
        isAccessibilityElement = false

        rays.contentMode = .scaleAspectFill
        rays.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rays)

        clouds.show(UIImage(named: "VictoryClouds"))
        clouds.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clouds)

        ribbon.contentMode = .scaleAspectFit
        ribbon.isAccessibilityElement = true
        ribbon.accessibilityLabel = "Niveau réussi !"
        ribbon.translatesAutoresizingMaskIntoConstraints = false

        confetti.contentMode = .scaleAspectFit
        confetti.isUserInteractionEnabled = false
        confetti.translatesAutoresizingMaskIntoConstraints = false

        robot.contentMode = .scaleAspectFit
        robot.isAccessibilityElement = false
        robot.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        robot.setContentHuggingPriority(.defaultLow, for: .vertical)
        robot.translatesAutoresizingMaskIntoConstraints = false

        stars.axis = .horizontal
        stars.spacing = 10
        stars.alignment = .center
        stars.translatesAutoresizingMaskIntoConstraints = false
        let starImage = UIImage(named: "VictoryStar")
        for _ in 0..<3 {
            let image = UIImageView(image: starImage)
            image.contentMode = .scaleAspectFit
            image.translatesAutoresizingMaskIntoConstraints = false
            image.widthAnchor.constraint(equalToConstant: 78).isActive = true
            image.heightAnchor.constraint(equalToConstant: 74).isActive = true
            stars.addArrangedSubview(image)
            starViews.append(image)
        }

        style(nextButton, fill: AppTheme.gold, ink: AppTheme.line, imageOnRight: true)
        style(retryButton, fill: UIColor(hex: 0x7B3FF2), ink: .white, imageOnRight: true)
        style(exitButton, fill: UIColor(hex: 0x7B3FF2), ink: .white, imageOnRight: true)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        nextButton.isHidden = true

        detailsCard.backgroundColor = .white
        detailsCard.layer.cornerRadius = 24
        detailsCard.layer.cornerCurve = .continuous
        detailsCard.translatesAutoresizingMaskIntoConstraints = false
        let heading = UILabel()
        heading.text = "Détails"
        heading.font = AppTheme.font(18, .heavy, textStyle: .headline)
        heading.textColor = AppTheme.line
        heading.setContentCompressionResistancePriority(.required, for: .vertical)
        boltRow.axis = .horizontal
        boltRow.spacing = 8
        boltRow.isHidden = true
        let boltIcon = UIImageView(image: GameArt.piece(.bolt))
        boltIcon.contentMode = .scaleAspectFit
        boltIcon.translatesAutoresizingMaskIntoConstraints = false
        boltIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        boltIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        boltValue.font = AppTheme.font(16, .heavy, textStyle: .body)
        boltValue.textColor = AppTheme.line
        boltRow.addArrangedSubview(boltIcon)
        boltRow.addArrangedSubview(boltValue)

        let rows = UIStackView(arrangedSubviews: [
            heading,
            detailRow(title: "Taille", value: sizeValue),
            detailRow(title: "Actions", value: actionValue),
            detailRow(title: "Déplacements", value: moveValue),
            boltRow,
            noteLabel
        ])
        rows.axis = .vertical
        rows.spacing = 8
        rows.setCustomSpacing(12, after: heading)
        rows.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.font = AppTheme.font(14, .medium, textStyle: .subheadline)
        noteLabel.textColor = UIColor(hex: 0x5C6578)
        noteLabel.numberOfLines = 0
        noteLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        detailsCard.setContentCompressionResistancePriority(.required, for: .vertical)
        detailsCard.addSubview(rows)

        let actions = UIStackView(arrangedSubviews: [nextButton, retryButton, exitButton])
        actions.axis = .vertical
        actions.spacing = 10
        actions.translatesAutoresizingMaskIntoConstraints = false

        let stage = UIView()
        stage.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(confetti)
        stage.addSubview(robot)

        addSubview(ribbon)
        addSubview(stars)
        addSubview(stage)
        addSubview(detailsCard)
        addSubview(actions)

        NSLayoutConstraint.activate([
            rays.topAnchor.constraint(equalTo: topAnchor),
            rays.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -12),
            rays.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 12),
            rays.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.72),

            clouds.leadingAnchor.constraint(equalTo: leadingAnchor),
            clouds.trailingAnchor.constraint(equalTo: trailingAnchor),
            clouds.heightAnchor.constraint(equalToConstant: 120),
            clouds.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: 24),

            ribbon.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            ribbon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            ribbon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            ribbon.heightAnchor.constraint(equalToConstant: 108),

            stars.topAnchor.constraint(equalTo: ribbon.bottomAnchor, constant: 6),
            stars.centerXAnchor.constraint(equalTo: centerXAnchor),

            stage.topAnchor.constraint(equalTo: stars.bottomAnchor, constant: 4),
            stage.leadingAnchor.constraint(equalTo: leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: trailingAnchor),
            stage.bottomAnchor.constraint(equalTo: detailsCard.topAnchor, constant: -8),

            detailsCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            detailsCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            detailsCard.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -12),
            rows.topAnchor.constraint(equalTo: detailsCard.topAnchor, constant: 14),
            rows.leadingAnchor.constraint(equalTo: detailsCard.leadingAnchor, constant: 16),
            rows.trailingAnchor.constraint(equalTo: detailsCard.trailingAnchor, constant: -16),
            rows.bottomAnchor.constraint(equalTo: detailsCard.bottomAnchor, constant: -14),

            confetti.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
            confetti.centerYAnchor.constraint(equalTo: robot.centerYAnchor),
            confetti.widthAnchor.constraint(equalTo: stage.widthAnchor, multiplier: 0.92),
            confetti.heightAnchor.constraint(equalTo: confetti.widthAnchor, multiplier: 0.47),

            robot.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
            robot.centerYAnchor.constraint(equalTo: stage.centerYAnchor),
            robot.widthAnchor.constraint(equalTo: stage.widthAnchor, multiplier: 0.62).prioritized(.defaultHigh),
            robot.heightAnchor.constraint(equalTo: robot.widthAnchor, multiplier: 1.03).prioritized(.defaultHigh),
            robot.heightAnchor.constraint(lessThanOrEqualTo: stage.heightAnchor),
            robot.topAnchor.constraint(greaterThanOrEqualTo: stage.topAnchor),
            robot.bottomAnchor.constraint(lessThanOrEqualTo: stage.bottomAnchor),

            actions.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            actions.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            actions.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            nextButton.heightAnchor.constraint(equalToConstant: 58),
            retryButton.heightAnchor.constraint(equalToConstant: 52),
            exitButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard playing, bounds.width > 1, abs(bounds.width - driftedWidth) > 0.5 else { return }
        driftedWidth = bounds.width
        clouds.start(duration: 34, reversed: false)
    }

    func present(
        rating: StarRating,
        blockCount: Int,
        executed: Int,
        moves: Int,
        note: String,
        boltsGained: Int = 0,
        boltBalance: Int = 0,
        showBoltRecap: Bool = false,
        nextTitle: String? = nil,
        exitTitle: String = "Retour"
    ) {
        sizeValue.text = PlayerCopy.blockCount(blockCount)
        actionValue.text = executed == 1 ? "1 action" : "\(executed) actions"
        moveValue.text = moves == 1 ? "1 déplacement" : "\(moves) déplacements"
        if boltsGained > 0 {
            boltRow.isHidden = false
            boltValue.text = "+\(boltsGained) · total \(boltBalance)"
        } else if showBoltRecap {
            boltRow.isHidden = false
            boltValue.text = "Déjà obtenu · total \(boltBalance)"
        } else {
            boltRow.isHidden = true
        }
        noteLabel.text = note
        noteLabel.isHidden = note.isEmpty
        nextButton.isHidden = nextTitle == nil
        exitButton.isHidden = exitTitle == "Carte du monde" && nextTitle != nil
        if var configuration = nextButton.configuration, let nextTitle {
            configuration.title = nextTitle
            nextButton.configuration = configuration
            nextButton.accessibilityLabel = nextTitle
        }
        if var configuration = exitButton.configuration, exitButton.isHidden == false {
            configuration.title = exitTitle
            configuration.image = UIImage(systemName: "chevron.backward")
            exitButton.configuration = configuration
            exitButton.accessibilityLabel = exitTitle
        }
        for (index, imageView) in starViews.enumerated() {
            imageView.alpha = index < rating.count ? 1 : 0.28
        }
        accessibilityViewIsModal = true
        let earned = rating.count
        var label = "Niveau réussi. \(earned) étoile\(earned > 1 ? "s" : "")."
        if boltsGained > 0 {
            label += " +\(boltsGained) écrou\(boltsGained > 1 ? "s" : "")."
        }
        accessibilityLabel = label
        UIAccessibility.post(notification: .screenChanged, argument: ribbon)
        playing = true
        animateArrival()
    }

    private func style(_ button: UIButton, fill: UIColor, ink: UIColor, imageOnRight: Bool) {
        guard var configuration = button.configuration else { return }
        configuration.baseBackgroundColor = fill
        configuration.baseForegroundColor = ink
        configuration.imagePlacement = imageOnRight ? .trailing : .leading
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.background.cornerRadius = 26
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.font(20, .heavy, textStyle: .headline)
            return outgoing
        }
        button.configuration = configuration
    }

    private func detailRow(title: String, value: UILabel) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(16, .semibold, textStyle: .body)
        titleLabel.textColor = AppTheme.line
        value.font = AppTheme.font(16, .heavy, textStyle: .body)
        value.textColor = AppTheme.line
        value.textAlignment = .right
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        value.setContentCompressionResistancePriority(.required, for: .vertical)
        let row = UIStackView(arrangedSubviews: [titleLabel, value])
        row.axis = .horizontal
        row.spacing = 12
        return row
    }

    private func animateArrival() {
        clouds.start(duration: 34, reversed: false)
        guard !PlaySettings.prefersReducedMotion else { return }
        rays.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 1.4, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
            self.rays.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        }
        ribbon.alpha = 0
        ribbon.transform = CGAffineTransform(translationX: 0, y: -36).scaledBy(x: 0.86, y: 0.86)
        UIView.animate(withDuration: 0.6, delay: 0.02, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.ribbon.alpha = 1
            self.ribbon.transform = .identity
        }
        for (index, view) in starViews.enumerated() {
            view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: -0.4)
            UIView.animate(
                withDuration: 0.55,
                delay: 0.16 + Double(index) * 0.08,
                usingSpringWithDamping: 0.52,
                initialSpringVelocity: 0.8
            ) {
                view.transform = .identity
            }
        }
        confetti.alpha = 0
        confetti.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.5, delay: 0.2, options: [.allowUserInteraction, .curveEaseOut]) {
            self.confetti.alpha = 1
            self.confetti.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 1.6, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                self.confetti.transform = CGAffineTransform(scaleX: 1.06, y: 1.06).rotated(by: 0.04)
            }
        }
        robot.alpha = 0
        robot.transform = CGAffineTransform(translationX: 0, y: 40).scaledBy(x: 0.72, y: 0.72)
        UIView.animate(withDuration: 0.7, delay: 0.18, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.6) {
            self.robot.alpha = 1
            self.robot.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.85, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                self.robot.transform = CGAffineTransform(translationX: 0, y: -12)
            }
        }
        detailsCard.alpha = 0
        detailsCard.transform = CGAffineTransform(translationX: 0, y: 18)
        UIView.animate(withDuration: 0.45, delay: 0.24, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4) {
            self.detailsCard.alpha = 1
            self.detailsCard.transform = .identity
        }
        for (index, button) in [nextButton, retryButton, exitButton].enumerated() where !button.isHidden {
            button.alpha = 0
            button.transform = CGAffineTransform(translationX: 0, y: 24)
            UIView.animate(withDuration: 0.45, delay: 0.28 + Double(index) * 0.06, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
                button.alpha = 1
                button.transform = .identity
            }
        }
    }

    @objc private func retryTapped() { onRetry?() }
    @objc private func nextTapped() { onNext?() }
    @objc private func exitTapped() { onExit?() }
}
