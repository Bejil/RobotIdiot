import UIKit
import RobotIdiotCore

final class DailyHubViewController: UIViewController {
    private let selection: DailyFrozenSelection

    private var backdrop: AmbientBackdropView!
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let heroBadge = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tierChip = UILabel()
    private let challengeCard = DailyMissionCard()
    private let bugCard = DailyMissionCard()
    private let noteLabel = UILabel()
    private var didAnimateEntrance = false
    private var entrancePieces: [UIView] { [heroBadge, titleLabel, subtitleLabel, tierChip, challengeCard, bugCard, noteLabel] }

    init(selection: DailyFrozenSelection = DailyStore.shared.selection()) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = "Défis du jour"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)),
            style: .plain,
            target: self,
            action: #selector(goBack)
        )
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Retour"

        buildLayout()
        populate()
        prepareEntrance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let navigation = navigationController {
            AppTheme.apply(to: navigation)
        }
        refreshStatus()
        backdrop.start()
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

        heroBadge.text = "AUJOURD'HUI"
        heroBadge.font = AppTheme.font(12, .heavy, textStyle: .caption1)
        heroBadge.textColor = AppTheme.line
        heroBadge.textAlignment = .center
        heroBadge.backgroundColor = AppTheme.gold
        heroBadge.layer.cornerRadius = 12
        heroBadge.layer.masksToBounds = true
        heroBadge.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.font = AppTheme.font(34, .heavy, textStyle: .largeTitle)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        subtitleLabel.font = AppTheme.font(16, .semibold, textStyle: .body)
        subtitleLabel.textColor = AppTheme.inkSoft
        subtitleLabel.numberOfLines = 0
        subtitleLabel.adjustsFontForContentSizeCategory = true

        tierChip.font = AppTheme.font(13, .heavy, textStyle: .caption1)
        tierChip.textColor = AppTheme.ink
        tierChip.backgroundColor = AppTheme.card
        tierChip.layer.cornerRadius = 14
        tierChip.layer.borderWidth = 1.5
        tierChip.layer.borderColor = AppTheme.border.cgColor
        tierChip.layer.masksToBounds = true
        tierChip.textAlignment = .center

        challengeCard.addTarget(self, action: #selector(openChallenge), for: .touchUpInside)
        bugCard.addTarget(self, action: #selector(openBug), for: .touchUpInside)

        noteLabel.font = AppTheme.font(13, .medium, textStyle: .footnote)
        noteLabel.textColor = AppTheme.inkSoft.withAlphaComponent(0.9)
        noteLabel.numberOfLines = 0
        noteLabel.adjustsFontForContentSizeCategory = true

        let header = UIStackView(arrangedSubviews: [heroBadge, titleLabel, subtitleLabel, tierChip])
        header.axis = .vertical
        header.alignment = .leading
        header.spacing = 10
        header.setCustomSpacing(14, after: heroBadge)
        header.setCustomSpacing(8, after: titleLabel)
        header.setCustomSpacing(14, after: subtitleLabel)

        content.addArrangedSubview(header)
        content.addArrangedSubview(challengeCard)
        content.addArrangedSubview(bugCard)
        content.addArrangedSubview(noteLabel)
        content.setCustomSpacing(22, after: header)
        content.setCustomSpacing(14, after: challengeCard)
        content.setCustomSpacing(20, after: bugCard)

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

            heroBadge.widthAnchor.constraint(equalToConstant: 118),
            heroBadge.heightAnchor.constraint(equalToConstant: 24),
            tierChip.heightAnchor.constraint(equalToConstant: 28),
            challengeCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 148),
            bugCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 148)
        ])

        // Largeur du chip via padding texte
        tierChip.layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }

    /// Cache le contenu dès le chargement pour éviter le flash avant l'animation d'entrée.
    private func prepareEntrance() {
        guard !PlaySettings.prefersReducedMotion else { return }
        for piece in entrancePieces {
            piece.alpha = 0
            piece.transform = CGAffineTransform(translationX: 0, y: 18).scaledBy(x: 0.98, y: 0.98)
        }
    }

    private func populate() {
        titleLabel.text = formattedDate(selection.civilDate)
        subtitleLabel.text = "Deux missions figées pour ta journée."
        tierChip.text = "  Palier \(selection.tier)  "
        noteLabel.text = "Une seule récompense par mission et par jour. Les plateaux du défi et du bug sont distincts."

        challengeCard.configure(
            kind: .challenge,
            title: "Niveau du jour",
            eyebrow: selection.challengeId,
            reward: "+2 écrous",
            detail: challengeDetail(),
            done: DailyStore.shared.hasWonChallenge(on: selection.civilDate)
        )
        bugCard.configure(
            kind: .bug,
            title: "Bug du jour",
            eyebrow: selection.bugId,
            reward: "+1 écrou",
            detail: bugDetail(),
            done: DailyStore.shared.hasWonBug(on: selection.civilDate)
        )
    }

    private func refreshStatus() {
        let challengeDone = DailyStore.shared.hasWonChallenge(on: selection.civilDate)
        let bugDone = DailyStore.shared.hasWonBug(on: selection.civilDate)
        challengeCard.configure(
            kind: .challenge,
            title: "Niveau du jour",
            eyebrow: selection.challengeId,
            reward: "+2 écrous",
            detail: challengeDetail(),
            done: challengeDone
        )
        bugCard.configure(
            kind: .bug,
            title: "Bug du jour",
            eyebrow: selection.bugId,
            reward: "+1 écrou",
            detail: bugDetail(),
            done: bugDone
        )
    }

    private func challengeDetail() -> String {
        DailyStore.shared.hasWonChallenge(on: selection.civilDate)
            ? "Réussi · récompense déjà obtenue"
            : "Atteins la station · 3 étoiles sur les actions"
    }

    private func bugDetail() -> String {
        DailyStore.shared.hasWonBug(on: selection.civilDate)
            ? "Corrigé · récompense déjà obtenue"
            : "Remplace une seule commande incorrecte"
    }

    private func formattedDate(_ civil: String) -> String {
        guard let date = DailySelection.parseCivilDate(civil) else { return civil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = DailySelection.calendar().timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: date).capitalized(with: Locale(identifier: "fr_FR"))
    }

    private func playEntranceIfNeeded() {
        guard !didAnimateEntrance else { return }
        didAnimateEntrance = true
        guard !PlaySettings.prefersReducedMotion else {
            challengeCard.startIdleMotion()
            bugCard.startIdleMotion(delay: 0.35)
            return
        }

        for (index, piece) in entrancePieces.enumerated() {
            UIView.animate(
                withDuration: 0.48,
                delay: 0.04 + Double(index) * 0.055,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.55,
                options: [.allowUserInteraction, .curveEaseOut]
            ) {
                piece.alpha = 1
                piece.transform = .identity
            }
        }
        challengeCard.startIdleMotion()
        bugCard.startIdleMotion(delay: 0.35)
    }

    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func openChallenge() {
        guard let level = DailyCatalog.playableLevel(id: selection.challengeId) else { return }
        bounce(challengeCard)
        let context = DailyPlayContext(
            kind: .challenge,
            civilDate: selection.civilDate,
            contentId: selection.challengeId,
            baselineProgram: nil,
            titleOverride: "Niveau du jour"
        )
        navigationController?.pushViewController(
            GameViewController(level: level, daily: context),
            animated: true
        )
    }

    @objc private func openBug() {
        guard let bug = DailyCatalog.bugs.bugs.first(where: { $0.id == selection.bugId }),
              let level = DailyCatalog.playableLevel(id: bug.boardRef) else { return }
        bounce(bugCard)
        var playable = level
        let allowed = DailyCatalog.commandTypes(from: bug.availableCommands)
        if !allowed.isEmpty {
            playable.allowedCommands = allowed
        }
        let baseline = DailyCatalog.program(from: bug.bugProgram)
        let context = DailyPlayContext(
            kind: .bug,
            civilDate: selection.civilDate,
            contentId: bug.id,
            baselineProgram: baseline,
            titleOverride: "Bug du jour",
            instructions: bug.instructions
        )
        navigationController?.pushViewController(
            GameViewController(level: playable, daily: context),
            animated: true
        )
    }

    private func bounce(_ view: UIView) {
        guard !PlaySettings.prefersReducedMotion else { return }
        UIView.animate(withDuration: 0.12, animations: {
            view.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) {
                view.transform = .identity
            }
        })
    }
}

struct DailyPlayContext {
    enum Kind {
        case challenge
        case bug
    }

    var kind: Kind
    var civilDate: String
    var contentId: String
    var baselineProgram: Program?
    var titleOverride: String
    var instructions: String?
}

// MARK: - Mission card

private final class DailyMissionCard: UIControl {
    enum Kind {
        case challenge
        case bug

        var fill: UIColor {
            switch self {
            case .challenge: return UIColor(hex: 0x1FA971)
            case .bug: return UIColor(hex: 0xE8590C)
            }
        }

        var deep: UIColor {
            switch self {
            case .challenge: return UIColor(hex: 0x0B6B45)
            case .bug: return UIColor(hex: 0xA83B05)
            }
        }

        var symbol: String {
            switch self {
            case .challenge: return "flag.fill"
            case .bug: return "ant.fill"
            }
        }

        var cta: String {
            switch self {
            case .challenge: return "Jouer"
            case .bug: return "Corriger"
            }
        }
    }

    private let glow = UIView()
    private let panel = UIView()
    private let iconWell = UIView()
    private let iconView = UIImageView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let rewardPill = UILabel()
    private let statusPill = UILabel()
    private let cta = UILabel()
    private let sheen = UIView()
    private var idleToken = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        kind: Kind,
        title: String,
        eyebrow: String,
        reward: String,
        detail: String,
        done: Bool
    ) {
        panel.backgroundColor = kind.fill
        glow.backgroundColor = kind.fill.withAlphaComponent(0.35)
        iconWell.backgroundColor = kind.deep.withAlphaComponent(0.55)
        iconView.image = UIImage(
            systemName: done ? "checkmark.seal.fill" : kind.symbol,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        )
        eyebrowLabel.text = eyebrow.uppercased()
        titleLabel.text = title
        detailLabel.text = detail
        rewardPill.text = "  \(reward)  "
        statusPill.text = done ? "  Fait  " : "  Nouveau  "
        statusPill.backgroundColor = done
            ? UIColor.white.withAlphaComponent(0.22)
            : AppTheme.gold
        statusPill.textColor = done ? .white : AppTheme.line
        cta.text = done ? "Rejouer" : kind.cta
        accessibilityLabel = "\(title). \(detail). \(reward)."
        accessibilityTraits = .button
    }

    func startIdleMotion(delay: TimeInterval = 0) {
        idleToken += 1
        let token = idleToken
        guard !PlaySettings.prefersReducedMotion else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.float(token: token, up: true)
            self?.runSheen(token: token)
        }
    }

    override var isHighlighted: Bool {
        didSet {
            let scale: CGFloat = isHighlighted ? 0.985 : 1
            UIView.animate(withDuration: 0.12) {
                self.panel.transform = CGAffineTransform(scaleX: scale, y: scale)
                self.glow.alpha = self.isHighlighted ? 0.55 : 1
            }
        }
    }

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false

        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.layer.cornerRadius = 28
        glow.isUserInteractionEnabled = false
        addSubview(glow)

        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isUserInteractionEnabled = false
        panel.layer.cornerRadius = 26
        panel.layer.cornerCurve = .continuous
        panel.layer.borderWidth = 2.5
        panel.layer.borderColor = UIColor.black.withAlphaComponent(0.55).cgColor
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.28
        panel.layer.shadowRadius = 0
        panel.layer.shadowOffset = CGSize(width: 0, height: 5)
        panel.clipsToBounds = true
        addSubview(panel)

        sheen.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        sheen.translatesAutoresizingMaskIntoConstraints = false
        sheen.transform = CGAffineTransform(rotationAngle: -.pi / 6)
        panel.addSubview(sheen)

        iconWell.translatesAutoresizingMaskIntoConstraints = false
        iconWell.layer.cornerRadius = 18
        iconWell.layer.borderWidth = 1.5
        iconWell.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        panel.addSubview(iconWell)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconWell.addSubview(iconView)

        eyebrowLabel.font = AppTheme.font(11, .heavy, textStyle: .caption2)
        eyebrowLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        eyebrowLabel.adjustsFontForContentSizeCategory = true

        titleLabel.font = AppTheme.font(24, .heavy, textStyle: .title2)
        titleLabel.textColor = .white
        titleLabel.adjustsFontForContentSizeCategory = true

        detailLabel.font = AppTheme.font(14, .semibold, textStyle: .footnote)
        detailLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        detailLabel.numberOfLines = 0
        detailLabel.adjustsFontForContentSizeCategory = true

        rewardPill.font = AppTheme.font(12, .heavy, textStyle: .caption1)
        rewardPill.textColor = AppTheme.line
        rewardPill.backgroundColor = AppTheme.gold
        rewardPill.layer.cornerRadius = 11
        rewardPill.layer.masksToBounds = true

        statusPill.font = AppTheme.font(12, .heavy, textStyle: .caption1)
        statusPill.layer.cornerRadius = 11
        statusPill.layer.masksToBounds = true

        let pills = UIStackView(arrangedSubviews: [rewardPill, statusPill])
        pills.axis = .horizontal
        pills.spacing = 8
        pills.alignment = .center

        let text = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, detailLabel, pills])
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = 4
        text.setCustomSpacing(8, after: detailLabel)
        text.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(text)

        cta.font = AppTheme.font(15, .heavy, textStyle: .headline)
        cta.textColor = .white
        cta.textAlignment = .center
        cta.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        cta.layer.cornerRadius = 16
        cta.layer.masksToBounds = true
        cta.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(cta)

        NSLayoutConstraint.activate([
            glow.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            glow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            glow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            glow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            sheen.topAnchor.constraint(equalTo: panel.topAnchor, constant: -40),
            sheen.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: 40),
            sheen.widthAnchor.constraint(equalToConstant: 46),
            sheen.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: -60),

            iconWell.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            iconWell.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),
            iconWell.widthAnchor.constraint(equalToConstant: 46),
            iconWell.heightAnchor.constraint(equalToConstant: 46),
            iconView.centerXAnchor.constraint(equalTo: iconWell.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconWell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            text.leadingAnchor.constraint(equalTo: iconWell.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            text.topAnchor.constraint(equalTo: panel.topAnchor, constant: 16),

            cta.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            cta.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            cta.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 14),
            cta.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -16),
            cta.heightAnchor.constraint(equalToConstant: 36),

            rewardPill.heightAnchor.constraint(equalToConstant: 22),
            statusPill.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func float(token: Int, up: Bool) {
        guard token == idleToken, window != nil else { return }
        UIView.animate(
            withDuration: 2.2,
            delay: 0,
            options: [.allowUserInteraction, .curveEaseInOut]
        ) {
            self.glow.transform = CGAffineTransform(translationX: 0, y: up ? -3 : 2)
        } completion: { [weak self] _ in
            self?.float(token: token, up: !up)
        }
    }

    private func runSheen(token: Int) {
        guard token == idleToken, window != nil else { return }
        sheen.layer.removeAllAnimations()
        sheen.transform = CGAffineTransform(translationX: -80, y: 0).rotated(by: -.pi / 6)
        UIView.animate(
            withDuration: 1.4,
            delay: 1.8,
            options: [.curveEaseInOut]
        ) {
            self.sheen.transform = CGAffineTransform(translationX: self.bounds.width + 80, y: 0)
                .rotated(by: -.pi / 6)
        } completion: { [weak self] _ in
            guard let self, token == self.idleToken else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                self.runSheen(token: token)
            }
        }
    }
}
