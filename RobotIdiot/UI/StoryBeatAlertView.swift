import UIKit

/// Dialogue du robot pour les transitions de monde et l'épilogue.
final class StoryBeatAlertView: UIView {
    var onFinished: (() -> Void)?

    private var pages: [RobotStory.Page] = []
    private var index = 0
    private var chapterID = ""

    private let composition = UIView()
    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UIView()
    private let badgeIcon = UIImageView()
    private let quoteLabel = UILabel()
    private let asideLabel = UILabel()
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

        robot.image = UIImage(named: "HomeHero")
        robot.contentMode = .scaleAspectFit
        robot.isUserInteractionEnabled = false

        ribbon.backgroundColor = UIColor(hex: 0x1A1440)
        ribbon.layer.cornerRadius = 22
        ribbon.layer.cornerCurve = .continuous
        ribbon.layer.masksToBounds = true
        ribbon.layer.borderWidth = 2
        ribbon.layer.borderColor = AppTheme.gold.cgColor
        ribbonTitle.font = AppTheme.font(20, .heavy, textStyle: .title2)
        ribbonTitle.textColor = AppTheme.gold
        ribbonTitle.textAlignment = .center
        ribbonTitle.adjustsFontSizeToFitWidth = true
        ribbonTitle.minimumScaleFactor = 0.7
        ribbonTitle.translatesAutoresizingMaskIntoConstraints = false
        ribbon.addSubview(ribbonTitle)

        badge.backgroundColor = AppTheme.gold
        badge.layer.cornerRadius = 24
        badge.layer.borderWidth = 4
        badge.layer.borderColor = UIColor.white.cgColor
        badge.layer.masksToBounds = true
        badgeIcon.image = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.tintColor = UIColor(hex: 0x1A1440)
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeIcon)

        addSubview(composition)
        composition.addSubview(robot)
        composition.addSubview(card)
        composition.addSubview(ribbon)
        composition.addSubview(badge)

        quoteLabel.font = AppTheme.font(17, .semibold, textStyle: .body)
        quoteLabel.textColor = AppTheme.line
        quoteLabel.textAlignment = .center
        quoteLabel.numberOfLines = 0
        quoteLabel.adjustsFontForContentSizeCategory = true

        asideLabel.font = AppTheme.font(14, .medium, textStyle: .footnote)
        asideLabel.textColor = UIColor(hex: 0x667085)
        asideLabel.textAlignment = .center
        asideLabel.numberOfLines = 0
        asideLabel.adjustsFontForContentSizeCategory = true

        progressLabel.font = AppTheme.font(13, .bold, textStyle: .caption1)
        progressLabel.textColor = UIColor(hex: 0x667085)
        progressLabel.textAlignment = .center

        style(nextButton, title: "Suivant")
        nextButton.addTarget(self, action: #selector(advance), for: .touchUpInside)

        let message = UIStackView(arrangedSubviews: [quoteLabel, asideLabel, progressLabel, nextButton])
        message.axis = .vertical
        message.alignment = .fill
        message.spacing = 12
        message.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(message)

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
            badgeIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 22),
            badgeIcon.heightAnchor.constraint(equalToConstant: 22),

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

    func present(_ chapter: RobotStory.Chapter) {
        chapterID = chapter.id
        pages = chapter.pages
        index = 0
        ribbonTitle.text = chapter.ribbon
        showCurrent()
        accessibilityViewIsModal = true
        animateIn()
    }

    private func showCurrent() {
        guard pages.indices.contains(index) else { return }
        let page = pages[index]
        quoteLabel.text = "« \(page.line) »"
        asideLabel.text = page.aside
        asideLabel.isHidden = (page.aside ?? "").isEmpty
        progressLabel.isHidden = pages.count < 2
        progressLabel.text = "\(index + 1) sur \(pages.count)"
        let isLast = index + 1 >= pages.count
        style(nextButton, title: isLast ? "Continuer" : "Suivant")
        let announcement = "\(ribbonTitle.text ?? ""). \(page.line). \(page.aside ?? "")"
        accessibilityLabel = announcement
        UIAccessibility.post(notification: .screenChanged, argument: announcement)
    }

    private func animateIn() {
        guard !PlaySettings.prefersReducedMotion else {
            robot.transform = .identity
            card.transform = .identity
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

    private func style(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(
            systemName: title == "Continuer" ? "checkmark" : "play.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        )
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
        guard pages.indices.contains(index) else { return }
        Soundscape.shared.play("ui")
        guard index + 1 < pages.count else {
            PlaySettings.markStorySeen(chapterID)
            onFinished?()
            return
        }
        index += 1
        showCurrent()
    }
}
