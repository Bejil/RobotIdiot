import UIKit
import RobotIdiotCore

/// Accueil du Laboratoire : hero, jauge, continuer, historique intégré.
final class ExpertHubViewController: UIViewController {
    private var backdrop: AmbientBackdropView!
    private let scrollView = UIScrollView()
    private let content = UIStackView()

    private let heroBadge = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let masteryCard = ExpertMasteryCard()
    private let continueButton = AppTheme.filledButton(
        title: "Continuer l’entraînement",
        systemImage: "play.fill",
        prominent: true
    )
    private let historyHeader = UILabel()
    private let historyStack = UIStackView()

    private var didAnimateEntrance = false
    private var entrancePieces: [UIView] {
        [heroBadge, titleLabel, subtitleLabel, masteryCard, continueButton, historyHeader, historyStack]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = "Le Laboratoire"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(replayTutorial)
        )
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Revoir le tutoriel"

        buildLayout()
        prepareEntrance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let navigation = navigationController {
            AppTheme.apply(to: navigation)
        }
        refresh()
        backdrop.start()
        if !ExpertStore.shared.tutorialCompleted {
            DispatchQueue.main.async { [weak self] in
                // Première visite : à la fin, enchaîner sur une simulation.
                self?.presentTutorial(launchOnFinish: true)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playEntranceIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func buildLayout() {
        backdrop = AmbientBackdropView.install(in: view)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 16
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        heroBadge.text = "MODE EXPERT"
        heroBadge.font = AppTheme.font(12, .heavy, textStyle: .caption1)
        heroBadge.textColor = AppTheme.line
        heroBadge.textAlignment = .center
        heroBadge.backgroundColor = AppTheme.interaction
        heroBadge.layer.cornerRadius = 12
        heroBadge.layer.masksToBounds = true

        titleLabel.text = "Le Laboratoire"
        titleLabel.font = AppTheme.font(34, .heavy, textStyle: .largeTitle)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        subtitleLabel.text = "Apprends à rendre ton robot autonome"
        subtitleLabel.font = AppTheme.font(16, .semibold, textStyle: .body)
        subtitleLabel.textColor = AppTheme.inkSoft
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        continueButton.addTarget(self, action: #selector(continueTraining), for: .touchUpInside)

        historyHeader.text = "Historique"
        historyHeader.font = AppTheme.font(20, .heavy, textStyle: .title3)
        historyHeader.textColor = AppTheme.ink
        historyHeader.adjustsFontForContentSizeCategory = true

        historyStack.axis = .vertical
        historyStack.spacing = 12
        historyStack.alignment = .fill

        let header = UIStackView(arrangedSubviews: [heroBadge, titleLabel, subtitleLabel])
        header.axis = .vertical
        header.alignment = .leading
        header.spacing = 10
        header.setCustomSpacing(14, after: heroBadge)
        header.setCustomSpacing(8, after: titleLabel)

        content.addArrangedSubview(header)
        content.addArrangedSubview(masteryCard)
        content.addArrangedSubview(continueButton)
        content.addArrangedSubview(historyHeader)
        content.addArrangedSubview(historyStack)
        content.setCustomSpacing(22, after: header)
        content.setCustomSpacing(18, after: masteryCard)
        content.setCustomSpacing(28, after: continueButton)
        content.setCustomSpacing(12, after: historyHeader)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),

            heroBadge.widthAnchor.constraint(equalToConstant: 126),
            heroBadge.heightAnchor.constraint(equalToConstant: 24),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 58)
        ])
    }

    private func prepareEntrance() {
        guard !PlaySettings.prefersReducedMotion else { return }
        for piece in entrancePieces {
            piece.alpha = 0
            piece.transform = CGAffineTransform(translationX: 0, y: 18).scaledBy(x: 0.98, y: 0.98)
        }
    }

    private func playEntranceIfNeeded() {
        guard !didAnimateEntrance else { return }
        didAnimateEntrance = true
        guard !PlaySettings.prefersReducedMotion else { return }
        for (index, piece) in entrancePieces.enumerated() {
            UIView.animate(
                withDuration: 0.42,
                delay: 0.05 * Double(index),
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.4,
                options: [.curveEaseOut]
            ) {
                piece.alpha = 1
                piece.transform = .identity
            }
        }
    }

    private func refresh() {
        let store = ExpertStore.shared
        let done = store.masteryCount
        let total = ExpertCatalog.totalSimulations
        masteryCard.configure(
            percent: store.masteryPercent,
            done: done,
            total: total
        )
        if var configuration = continueButton.configuration {
            configuration.title = done >= total ? "Rejouer / optimiser" : "Continuer l’entraînement"
            configuration.image = UIImage(systemName: done >= total ? "arrow.clockwise" : "play.fill")
            continueButton.configuration = configuration
        }
        rebuildHistory()
    }

    private func rebuildHistory() {
        historyStack.arrangedSubviews.forEach {
            historyStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let items = Array(ExpertStore.shared.completedSimulations().reversed())
        historyHeader.text = items.isEmpty
            ? "Historique"
            : "Historique · \(items.count)"
        if items.isEmpty {
            let empty = ExpertHistoryEmptyView()
            historyStack.addArrangedSubview(empty)
            return
        }
        for simulation in items {
            let row = ExpertHistoryRowView()
            row.configure(
                sequence: simulation.sequence,
                title: simulation.name,
                stars: ExpertStore.shared.bestStars(for: simulation.id),
                themeWorld: simulation.visualThemeWorld
            )
            row.onTap = { [weak self] in
                self?.openSimulation(simulation)
            }
            historyStack.addArrangedSubview(row)
        }
    }

    @objc private func continueTraining() {
        Soundscape.shared.play("select")
        if !ExpertStore.shared.tutorialCompleted {
            presentTutorial(launchOnFinish: true)
            return
        }
        openResumeSimulation()
    }

    @objc private func replayTutorial() {
        // Bouton « i » : revoir seulement, sans lancer le plateau.
        presentTutorial(launchOnFinish: false)
    }

    private func presentTutorial(launchOnFinish: Bool) {
        let tutorial = ExpertTutorialViewController()
        tutorial.onFinished = { [weak self, weak tutorial] in
            tutorial?.dismiss(animated: true) {
                guard let self else { return }
                if launchOnFinish {
                    self.openResumeSimulation()
                }
                self.refresh()
            }
        }
        present(tutorial, animated: true)
    }

    private func openResumeSimulation() {
        openSimulation(ExpertStore.shared.resumeSimulation())
    }

    private func openSimulation(_ simulation: ExpertSimulation) {
        let level = ExpertCatalog.playableLevel(for: simulation)
        let context = ExpertPlayContext(simulationId: simulation.id, simulationName: simulation.name)
        navigationController?.pushViewController(
            GameViewController(level: level, expert: context),
            animated: true
        )
    }
}

struct ExpertPlayContext {
    var simulationId: String
    var simulationName: String
}

// MARK: - Mastery card

private final class ExpertMasteryCard: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let bar = UIProgressView(progressViewStyle: .bar)
    private let captionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.card
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = AppTheme.border.cgColor

        titleLabel.text = "Maîtrise"
        titleLabel.font = AppTheme.font(13, .heavy, textStyle: .caption1)
        titleLabel.textColor = AppTheme.interaction
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = AppTheme.font(28, .heavy, textStyle: .title1)
        valueLabel.textColor = AppTheme.ink
        valueLabel.adjustsFontForContentSizeCategory = true

        bar.progressTintColor = AppTheme.interaction
        bar.trackTintColor = AppTheme.interaction.withAlphaComponent(0.18)
        bar.layer.cornerRadius = 5
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false

        captionLabel.font = AppTheme.font(14, .semibold, textStyle: .subheadline)
        captionLabel.textColor = AppTheme.inkSoft
        captionLabel.adjustsFontForContentSizeCategory = true

        let column = UIStackView(arrangedSubviews: [titleLabel, valueLabel, bar, captionLabel])
        column.axis = .vertical
        column.spacing = 8
        column.setCustomSpacing(4, after: titleLabel)
        column.setCustomSpacing(12, after: valueLabel)
        column.setCustomSpacing(10, after: bar)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            bar.heightAnchor.constraint(equalToConstant: 10)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(percent: Int, done: Int, total: Int) {
        if done >= total {
            valueLabel.text = "100 %"
            captionLabel.text = "Laboratoire maîtrisé · \(total) / \(total)"
        } else {
            valueLabel.text = "\(percent) %"
            captionLabel.text = "\(done) / \(total) simulations réussies"
        }
        bar.setProgress(Float(done) / Float(max(total, 1)), animated: false)
    }
}

// MARK: - History empty

private final class ExpertHistoryEmptyView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppTheme.card.withAlphaComponent(0.72)
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        layer.borderColor = AppTheme.border.withAlphaComponent(0.55).cgColor

        let icon = UIImageView(
            image: UIImage(systemName: "flask", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        )
        icon.tintColor = AppTheme.interaction
        icon.contentMode = .scaleAspectFit

        let title = UILabel()
        title.text = "Encore aucune réussite"
        title.font = AppTheme.font(16, .heavy, textStyle: .headline)
        title.textColor = AppTheme.ink
        title.adjustsFontForContentSizeCategory = true

        let body = UILabel()
        body.text = "Tes simulations réussies apparaîtront ici. Rejoue-les pour gagner plus d’étoiles."
        body.font = AppTheme.font(14, .medium, textStyle: .subheadline)
        body.textColor = AppTheme.inkSoft
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let column = UIStackView(arrangedSubviews: [icon, title, body])
        column.axis = .vertical
        column.alignment = .leading
        column.spacing = 8
        column.setCustomSpacing(12, after: icon)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            column.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            column.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            column.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

// MARK: - History row

final class ExpertHistoryRowView: UIView {
    var onTap: (() -> Void)?

    private let accentBar = UIView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let starsRow = UIStackView()
    private let replayButton = AppTheme.filledButton(
        title: "Rejouer",
        systemImage: "arrow.clockwise",
        prominent: true,
        compact: true
    )
    private let panel = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .button

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = AppTheme.card
        panel.layer.cornerRadius = 16
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 1.5
        panel.layer.borderColor = AppTheme.border.cgColor
        panel.clipsToBounds = true
        addSubview(panel)

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = AppTheme.interaction
        panel.addSubview(accentBar)

        eyebrowLabel.font = AppTheme.font(11, .heavy, textStyle: .caption2)
        eyebrowLabel.textColor = AppTheme.interaction
        eyebrowLabel.adjustsFontForContentSizeCategory = true
        eyebrowLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLabel.font = AppTheme.font(19, .heavy, textStyle: .title3)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        starsRow.axis = .horizontal
        starsRow.spacing = 2
        starsRow.alignment = .center
        starsRow.setContentHuggingPriority(.required, for: .horizontal)

        if var configuration = replayButton.configuration {
            configuration.imagePlacement = .leading
            configuration.imagePadding = 3
            configuration.image = UIImage(
                systemName: "arrow.clockwise",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            )
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)
            configuration.background.cornerRadius = 11
            configuration.baseBackgroundColor = AppTheme.interaction
            configuration.baseForegroundColor = AppTheme.line
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = AppTheme.font(11, .heavy, textStyle: .caption2)
                return outgoing
            }
            replayButton.configuration = configuration
        }
        replayButton.layer.shadowOpacity = 0.35
        replayButton.layer.shadowRadius = 0
        replayButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        replayButton.setContentHuggingPriority(.required, for: .horizontal)
        replayButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        replayButton.addTarget(self, action: #selector(tapped), for: .touchUpInside)

        let metaRow = UIStackView(arrangedSubviews: [eyebrowLabel, UIView(), starsRow])
        metaRow.axis = .horizontal
        metaRow.alignment = .center
        metaRow.spacing = 8

        let titleRow = UIStackView(arrangedSubviews: [titleLabel, replayButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 10

        let column = UIStackView(arrangedSubviews: [metaRow, titleRow])
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(column)

        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),

            accentBar.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: panel.topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            column.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            column.topAnchor.constraint(equalTo: panel.topAnchor, constant: 10),
            column.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -10),

            replayButton.heightAnchor.constraint(equalToConstant: 28)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        panel.addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 16).cgPath
    }

    func configure(sequence: Int, title: String, stars: Int, themeWorld: Int) {
        let accent = Self.accent(for: themeWorld)
        accentBar.backgroundColor = accent
        eyebrowLabel.textColor = accent
        eyebrowLabel.text = "SIMULATION \(sequence)"
        titleLabel.text = title

        if var configuration = replayButton.configuration {
            configuration.baseBackgroundColor = accent
            configuration.baseForegroundColor = AppTheme.line
            replayButton.configuration = configuration
        }

        let earned = max(0, min(3, stars))
        starsRow.arrangedSubviews.forEach {
            starsRow.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for index in 0..<3 {
            let image = UIImageView(image: GameArt.star(filled: true))
            image.alpha = index < earned ? 1 : 0.2
            image.contentMode = .scaleAspectFit
            image.translatesAutoresizingMaskIntoConstraints = false
            image.widthAnchor.constraint(equalToConstant: 16).isActive = true
            image.heightAnchor.constraint(equalToConstant: 16).isActive = true
            starsRow.addArrangedSubview(image)
        }
        accessibilityLabel = "Simulation \(sequence), \(title). \(PlayerCopy.starCount(earned)). Rejouer."
    }

    private static func accent(for world: Int) -> UIColor {
        switch world {
        case 2: return UIColor(hex: 0x3EC6FF)
        case 3: return UIColor(hex: 0x3DDC84)
        case 4: return UIColor(hex: 0xC56BFF)
        case 5: return UIColor(hex: 0x7FE9FF)
        case 6: return UIColor(hex: 0x6B7BFF)
        case 7: return AppTheme.gold
        case 8: return UIColor(hex: 0x7DDE63)
        case 9: return UIColor(hex: 0xFF7A18)
        case 10: return UIColor(hex: 0x7B3FF2)
        case 11: return UIColor(hex: 0xFF5A6E)
        default: return AppTheme.interaction
        }
    }

    @objc private func tapped() {
        Soundscape.shared.play("select")
        onTap?()
    }
}
