import UIKit
import RobotIdiotCore

final class HomeViewController: UIViewController {
    private let backdrop = HomeBurstView()
    private let badge: UIImageView = {
        let view = UIImageView(image: UIImage(named: "HomeHero"))
        view.contentMode = .scaleAspectFit
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Robot Idiot"
        return view
    }()
    private let logo = UIImageView(image: UIImage(named: "HomeLogo"))
    private let confetti = UIImageView(image: UIImage(named: "HomeConfetti"))
    private let continueButton = AppTheme.filledButton(title: "Continuer", systemImage: "play.fill", prominent: true)
    private let campaignButton = UIButton(type: .custom)
    private let generatedButton = AppTheme.filledButton(title: "Défis libres", systemImage: "trophy", prominent: false, tone: .primary)
    private let settingsButton = UIButton(type: .custom)
    private let continueGlow = UIView()
    private var generationTicket = 0
    private var didPlayIntro = false
    private var waveToken = 0
    private var waveHigh = true
    private let curtain = UIControl()
    private let sheet = UIView()
    private let sheetTitle = UILabel()
    private let sheetStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        logo.contentMode = .scaleAspectFit
        logo.isAccessibilityElement = true
        logo.accessibilityLabel = "Robot Idiot"
        confetti.contentMode = .scaleAspectFit
        confetti.isUserInteractionEnabled = false

        styleMain(continueButton, mark: "play", radius: 30)
        styleMain(generatedButton, mark: "trophy", radius: 28)
        if var configuration = generatedButton.configuration {
            configuration.baseBackgroundColor = UIColor(hex: 0x6C3CE0)
            generatedButton.configuration = configuration
        }
        continueButton.addTarget(self, action: #selector(continueCampaign), for: .touchUpInside)
        campaignButton.addTarget(self, action: #selector(openCampaign), for: .touchUpInside)
        generatedButton.addTarget(self, action: #selector(openChallenges), for: .touchUpInside)

        let stage = UIView()
        stage.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(badge)

        continueGlow.backgroundColor = AppTheme.gold.withAlphaComponent(0.28)
        continueGlow.layer.cornerRadius = 36
        continueGlow.isUserInteractionEnabled = false
        continueGlow.translatesAutoresizingMaskIntoConstraints = false

        let continueHolder = UIView()
        continueGlow.translatesAutoresizingMaskIntoConstraints = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueHolder.addSubview(continueGlow)
        continueHolder.addSubview(continueButton)
        NSLayoutConstraint.activate([
            continueButton.topAnchor.constraint(equalTo: continueHolder.topAnchor),
            continueButton.leadingAnchor.constraint(equalTo: continueHolder.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: continueHolder.trailingAnchor),
            continueButton.bottomAnchor.constraint(equalTo: continueHolder.bottomAnchor),
            continueGlow.topAnchor.constraint(equalTo: continueButton.topAnchor, constant: 8),
            continueGlow.leadingAnchor.constraint(equalTo: continueButton.leadingAnchor, constant: 10),
            continueGlow.trailingAnchor.constraint(equalTo: continueButton.trailingAnchor, constant: -10),
            continueGlow.bottomAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: -4)
        ])

        configureSquare(campaignButton, mark: "list", fill: UIColor(hex: 0x7B3FF2), tint: .white, label: "Progression")
        configureLabeled(settingsButton, mark: "gear", fill: UIColor(hex: 0x5B6CFF), tint: .white, title: "Réglages")
        settingsButton.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        let continueRow = UIStackView(arrangedSubviews: [continueHolder, campaignButton])
        continueRow.axis = .horizontal
        continueRow.spacing = 12
        continueRow.alignment = .fill
        continueRow.translatesAutoresizingMaskIntoConstraints = false

        let actions = UIStackView(arrangedSubviews: [continueRow, generatedButton, settingsButton])
        actions.axis = .vertical
        actions.spacing = 12
        actions.alignment = .fill
        actions.translatesAutoresizingMaskIntoConstraints = false

        let titleBox = UIView()
        titleBox.translatesAutoresizingMaskIntoConstraints = false
        logo.translatesAutoresizingMaskIntoConstraints = false
        confetti.translatesAutoresizingMaskIntoConstraints = false
        titleBox.addSubview(confetti)
        titleBox.addSubview(logo)

        let column = UIStackView(arrangedSubviews: [titleBox, stage, actions])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 8
        column.setCustomSpacing(-18, after: stage)
        column.setCustomSpacing(22, after: actions)
        column.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.backgroundColor = .clear
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        let canvas = UIView()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        view.addSubview(scroll)
        scroll.addSubview(canvas)
        canvas.addSubview(column)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            canvas.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            canvas.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor),

            column.centerXAnchor.constraint(equalTo: canvas.centerXAnchor),
            column.centerYAnchor.constraint(equalTo: canvas.centerYAnchor),
            column.topAnchor.constraint(greaterThanOrEqualTo: canvas.topAnchor, constant: 8),
            column.bottomAnchor.constraint(lessThanOrEqualTo: canvas.bottomAnchor, constant: -8),
            column.widthAnchor.constraint(equalTo: canvas.widthAnchor, constant: -40).prioritized(UILayoutPriority(750)),
            column.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            column.leadingAnchor.constraint(greaterThanOrEqualTo: canvas.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(lessThanOrEqualTo: canvas.trailingAnchor, constant: -20),

            titleBox.widthAnchor.constraint(equalTo: column.widthAnchor),
            titleBox.heightAnchor.constraint(equalToConstant: 168),
            confetti.centerXAnchor.constraint(equalTo: titleBox.centerXAnchor),
            confetti.centerYAnchor.constraint(equalTo: titleBox.centerYAnchor),
            confetti.widthAnchor.constraint(equalTo: titleBox.widthAnchor, constant: 36),
            confetti.heightAnchor.constraint(equalTo: titleBox.heightAnchor),
            logo.centerXAnchor.constraint(equalTo: titleBox.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: titleBox.centerYAnchor),
            logo.widthAnchor.constraint(equalTo: titleBox.widthAnchor, constant: -36),
            logo.heightAnchor.constraint(equalTo: titleBox.heightAnchor, constant: -8),

            stage.widthAnchor.constraint(equalTo: column.widthAnchor),
            stage.heightAnchor.constraint(equalToConstant: 250),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: stage.bottomAnchor),
            badge.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
            badge.bottomAnchor.constraint(equalTo: stage.bottomAnchor, constant: 16),
            badge.widthAnchor.constraint(equalToConstant: 230),
            badge.heightAnchor.constraint(equalTo: badge.widthAnchor, multiplier: 1.18),

            actions.widthAnchor.constraint(equalTo: column.widthAnchor),
            continueButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
            campaignButton.widthAnchor.constraint(equalTo: campaignButton.heightAnchor),
            generatedButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 62),
            settingsButton.heightAnchor.constraint(equalToConstant: 64)
        ])

        installSheet()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if didPlayIntro {
            backdrop.start()
            startWave()
        } else {
            playIntro()
        }
        guard !PlaySettings.tutorialSeen,
              presentedViewController == nil,
              navigationController?.viewControllers.count == 1,
              curtain.alpha < 0.1 else { return }
        present(TutorialViewController(), animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshContinueTitle()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        generationTicket += 1
        waveToken += 1
        backdrop.stop()
        continueButton.isEnabled = true
        generatedButton.isEnabled = true
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func styleMain(_ button: UIButton, mark: String, radius: CGFloat) {
        guard var configuration = button.configuration else { return }
        configuration.image = GameArt.fitted(GameArt.mark(mark), side: 26)
        configuration.imagePadding = 10
        configuration.background.cornerRadius = radius
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        button.configuration = configuration
        button.contentHorizontalAlignment = .center
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 62).isActive = true
    }

    private func configureSquare(_ button: UIButton, mark: String, fill: UIColor, tint: UIColor, label: String) {
        button.backgroundColor = fill
        button.layer.cornerRadius = 22
        button.accessibilityLabel = label
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.28
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        let image = UIImageView(image: GameArt.fitted(GameArt.mark(mark), side: 34))
        image.tintColor = tint
        image.contentMode = .scaleAspectFit
        image.isUserInteractionEnabled = false
        image.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(image)
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 34),
            image.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func configureLabeled(_ button: UIButton, mark: String, fill: UIColor, tint: UIColor, title: String) {
        button.backgroundColor = fill
        button.layer.cornerRadius = 22
        button.accessibilityLabel = title
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.28
        button.layer.shadowRadius = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        let image = UIImageView(image: GameArt.fitted(GameArt.mark(mark), side: 26))
        image.tintColor = tint
        image.contentMode = .scaleAspectFit
        image.isUserInteractionEnabled = false
        let label = UILabel()
        label.text = title
        label.font = AppTheme.font(18, .heavy, textStyle: .headline)
        label.textColor = tint
        label.adjustsFontForContentSizeCategory = true
        let row = UIStackView(arrangedSubviews: [image, label])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 26),
            image.heightAnchor.constraint(equalToConstant: 26),
            row.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    private func playIntro() {
        didPlayIntro = true
        backdrop.start()
        guard !PlaySettings.prefersReducedMotion else {
            return
        }
        logo.alpha = 0
        logo.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
        confetti.alpha = 0
        badge.alpha = 0
        badge.transform = CGAffineTransform(translationX: 0, y: 28).scaledBy(x: 0.7, y: 0.7)
        let mains = [continueButton, generatedButton, settingsButton]
        let squares = [campaignButton]
        (mains + squares).forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 26)
        }
        UIView.animate(withDuration: 0.7, delay: 0.02, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5) {
            self.logo.alpha = 1
            self.logo.transform = .identity
            self.confetti.alpha = 1
        }
        UIView.animate(withDuration: 0.75, delay: 0.08, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.7) {
            self.badge.alpha = 1
            self.badge.transform = .identity
        } completion: { _ in
            self.startWave()
        }
        for (index, button) in mains.enumerated() {
            UIView.animate(withDuration: 0.55, delay: 0.22 + Double(index) * 0.07, usingSpringWithDamping: 0.74, initialSpringVelocity: 0.4) {
                button.alpha = 1
                button.transform = .identity
            }
        }
        for (index, button) in squares.enumerated() {
            button.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            UIView.animate(withDuration: 0.5, delay: 0.42 + Double(index) * 0.06, usingSpringWithDamping: 0.58, initialSpringVelocity: 0.6) {
                button.alpha = 1
                button.transform = .identity
            }
        }
        continueGlow.alpha = 0
        UIView.animate(withDuration: 1.15, delay: 0.7, options: [.repeat, .autoreverse, .allowUserInteraction, .curveEaseInOut]) {
            self.continueGlow.alpha = 1
            self.continueGlow.transform = CGAffineTransform(scaleX: 1.04, y: 1.08)
        }
    }

    private func startWave() {
        waveToken += 1
        let token = waveToken
        guard !PlaySettings.prefersReducedMotion else { return }
        func tick() {
            guard token == self.waveToken, self.view.window != nil else { return }
            self.waveHigh.toggle()
            let lift: CGFloat = self.waveHigh ? -8 : 3
            let tilt: CGFloat = self.waveHigh ? -0.05 : 0.05
            UIView.animate(withDuration: 0.9, delay: 0, options: [.allowUserInteraction, .curveEaseInOut]) {
                self.badge.transform = CGAffineTransform(translationX: 0, y: lift).rotated(by: tilt)
            } completion: { _ in
                tick()
            }
        }
        tick()
    }

    private func refreshContinueTitle() {
        let progress = CampaignStore.shared.progress()
        let address = CampaignRules.continueAddress(in: progress, layout: CatalogCampaign.layout)
        let finished = CatalogCampaign.level(at: address) == nil
        let starting = address.world == 1 && address.level == 1
        let title = finished ? "Terminé" : (starting ? "Démarrer" : "Continuer")
        let place = finished || progress.records.isEmpty ? nil : PlayerCopy.campaignTitle(address)
        guard var configuration = continueButton.configuration else { return }
        configuration.title = title
        configuration.subtitle = place
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = AppTheme.font(12, .bold, textStyle: .caption1)
            outgoing.foregroundColor = AppTheme.line.withAlphaComponent(0.8)
            return outgoing
        }
        continueButton.configuration = configuration
        continueButton.accessibilityLabel = place.map { "\(title), \($0)" } ?? title
    }

    @objc private func continueCampaign() {
        generationTicket += 1
        let ticket = generationTicket
        continueButton.isEnabled = false
        let address = CampaignRules.continueAddress(in: CampaignStore.shared.progress(), layout: CatalogCampaign.layout)
        guard CatalogCampaign.level(at: address) != nil else {
            continueButton.isEnabled = true
            navigationController?.pushViewController(WorldMapViewController(), animated: true)
            return
        }
        CampaignStore.shared.materialize(address) { [weak self] level in
            guard let self, self.generationTicket == ticket else { return }
            self.continueButton.isEnabled = true
            self.navigationController?.pushViewController(
                GameViewController(level: level, campaign: address),
                animated: true
            )
        }
    }

    @objc private func openCampaign() {
        navigationController?.pushViewController(WorldMapViewController(), animated: true)
    }

    @objc private func openChallenges() {
        navigationController?.pushViewController(ChallengeViewController(), animated: true)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc private func showLessons() {
        sheetStack.arrangedSubviews.forEach {
            sheetStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        sheetTitle.text = "Leçons"
        for (index, level) in PrototypeLevel.playable.enumerated() {
            let button = AppTheme.filledButton(title: PlayerCopy.title(for: level), systemImage: "play.fill", prominent: false, tone: .primary)
            guard var configuration = button.configuration else { continue }
            configuration.image = GameArt.fitted(GameArt.mark("play"), side: 18)
            configuration.background.cornerRadius = 18
            button.configuration = configuration
            button.tag = index
            button.addTarget(self, action: #selector(play(_:)), for: .touchUpInside)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            sheetStack.addArrangedSubview(button)
        }
        presentSheet()
    }

    @objc private func play(_ sender: UIButton) {
        guard PrototypeLevel.playable.indices.contains(sender.tag) else { return }
        dismissSheet()
        let level = PrototypeLevel.playable[sender.tag]
        navigationController?.pushViewController(GameViewController(level: level), animated: true)
    }

    private func installSheet() {
        curtain.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        curtain.alpha = 0
        curtain.isHidden = true
        curtain.translatesAutoresizingMaskIntoConstraints = false
        curtain.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        sheet.backgroundColor = AppTheme.card
        sheet.layer.cornerRadius = 28
        sheet.layer.borderWidth = 3
        sheet.layer.borderColor = AppTheme.line.cgColor
        sheet.translatesAutoresizingMaskIntoConstraints = false
        sheetTitle.font = AppTheme.font(24, .heavy, textStyle: .title2)
        sheetTitle.textColor = AppTheme.ink
        sheetTitle.textAlignment = .center
        sheetStack.axis = .vertical
        sheetStack.spacing = 10
        let column = UIStackView(arrangedSubviews: [sheetTitle, sheetStack])
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        sheet.addSubview(column)
        view.addSubview(curtain)
        view.addSubview(sheet)
        NSLayoutConstraint.activate([
            curtain.topAnchor.constraint(equalTo: view.topAnchor),
            curtain.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            curtain.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            curtain.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            sheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            column.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 22),
            column.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 18),
            column.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -18),
            column.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -22)
        ])
        sheet.isHidden = true
        sheet.transform = CGAffineTransform(translationX: 0, y: 280)
    }

    private func presentSheet() {
        sheet.isHidden = false
        curtain.isHidden = false
        if PlaySettings.prefersReducedMotion {
            curtain.alpha = 1
            sheet.transform = .identity
            return
        }
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4) {
            self.curtain.alpha = 1
            self.sheet.transform = .identity
        }
    }

    @objc private func dismissSheet() {
        let finish = {
            self.curtain.isHidden = true
            self.sheet.isHidden = true
        }
        guard !PlaySettings.prefersReducedMotion else {
            curtain.alpha = 0
            sheet.transform = CGAffineTransform(translationX: 0, y: 280)
            sheet.isHidden = true
            finish()
            return
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.curtain.alpha = 0
            self.sheet.transform = CGAffineTransform(translationX: 0, y: 280)
        }, completion: { _ in finish() })
    }
}

/// Bande d'images répétées qui défile sans saut.
final class DriftStrip: UIView {
    private let track = UIView()
    private var image: UIImage?
    private var builtWidth: CGFloat = -1
    private var tileWidth: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isUserInteractionEnabled = false
        track.isUserInteractionEnabled = false
        addSubview(track)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ image: UIImage?) {
        self.image = image
        builtWidth = -1
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image, bounds.width > 1, abs(bounds.width - builtWidth) > 0.5 else { return }
        builtWidth = bounds.width
        let ratio = image.size.width / max(image.size.height, 1)
        tileWidth = max(bounds.height * ratio, 1)
        let count = Int(ceil(bounds.width / tileWidth)) + 2
        track.layer.removeAllAnimations()
        track.subviews.forEach { $0.removeFromSuperview() }
        track.frame = CGRect(x: 0, y: 0, width: tileWidth * CGFloat(count), height: bounds.height)
        for index in 0..<count {
            let view = UIImageView(image: image)
            view.frame = CGRect(x: CGFloat(index) * tileWidth, y: 0, width: tileWidth, height: bounds.height)
            view.contentMode = .scaleToFill
            track.addSubview(view)
        }
    }

    func start(duration: TimeInterval, reversed: Bool) {
        guard tileWidth > 1 else { return }
        track.layer.removeAnimation(forKey: "drift")
        let move = CABasicAnimation(keyPath: "transform.translation.x")
        move.fromValue = reversed ? -tileWidth : 0
        move.toValue = reversed ? 0 : -tileWidth
        move.duration = duration
        move.repeatCount = .infinity
        move.timingFunction = CAMediaTimingFunction(name: .linear)
        track.layer.add(move, forKey: "drift")
    }

    func stop() {
        track.layer.removeAnimation(forKey: "drift")
    }
}

/// Rayons et nuages derrière le robot. L'animation ne change aucun état de jeu.
private final class HomeBurstView: UIView {
    private let rays = UIImageView()
    private let cyanClouds = UIImageView(image: UIImage(named: "HomeCloudCyan"))
    private let blueClouds = UIImageView(image: UIImage(named: "HomeCloudBlue"))
    private let groundClip = UIView()
    private let groundRow = UIView()
    private var moving = false
    private var arrangedWidth: CGFloat = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        backgroundColor = UIColor(hex: 0x24145F)
        rays.image = UIImage(named: "HomeRays")
        rays.contentMode = .scaleAspectFill
        rays.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rays)
        NSLayoutConstraint.activate([
            rays.centerXAnchor.constraint(equalTo: centerXAnchor),
            rays.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            rays.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.35),
            rays.heightAnchor.constraint(equalTo: rays.widthAnchor, multiplier: 0.86)
        ])
        cyanClouds.alpha = 0.72
        blueClouds.alpha = 0.5
        for cloud in [cyanClouds, blueClouds] {
            cloud.contentMode = .scaleAspectFill
            cloud.isUserInteractionEnabled = false
            addSubview(cloud)
        }
        groundClip.clipsToBounds = true
        groundClip.isUserInteractionEnabled = false
        groundRow.isUserInteractionEnabled = false
        groundClip.addSubview(groundRow)
        addSubview(groundClip)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 1 else { return }
        cyanClouds.frame = CGRect(x: -24, y: bounds.height * 0.1, width: bounds.width + 48, height: 86)
        blueClouds.frame = CGRect(x: -36, y: bounds.height * 0.24, width: bounds.width + 72, height: 96)
        placeGround()
        let widthChanged = abs(bounds.width - arrangedWidth) > 0.5
        arrangedWidth = bounds.width
        if widthChanged && moving {
            startDecor()
        }
    }

    private func placeGround() {
        let height: CGFloat = 128
        groundClip.frame = CGRect(x: 0, y: bounds.height - height, width: bounds.width, height: height)
        let rowWidth = bounds.width + 180
        let rowHeight = height + 36
        let rebuild = groundRow.subviews.isEmpty || abs(groundRow.bounds.width - rowWidth) > 1
        groundRow.bounds = CGRect(x: 0, y: 0, width: rowWidth, height: rowHeight)
        groundRow.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        groundRow.center = CGPoint(x: groundClip.bounds.midX, y: groundClip.bounds.maxY)
        guard rebuild, UIImage(named: "HomeCloudBand") != nil else { return }
        groundRow.subviews.forEach { $0.removeFromSuperview() }
        let view = UIImageView(image: UIImage(named: "HomeCloudBand"))
        view.frame = groundRow.bounds
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        groundRow.addSubview(view)
    }

    func start() {
        guard !PlaySettings.prefersReducedMotion else { return }
        moving = true
        guard rays.layer.animation(forKey: "spin") == nil else {
            startDecor()
            return
        }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = -0.04
        spin.toValue = 0.04
        spin.duration = 8
        spin.autoreverses = true
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rays.layer.add(spin, forKey: "spin")
        startDecor()
    }

    func stop() {
        moving = false
        rays.layer.removeAnimation(forKey: "spin")
        groundRow.layer.removeAnimation(forKey: "ken")
        cyanClouds.layer.removeAnimation(forKey: "fade")
        blueClouds.layer.removeAnimation(forKey: "fade")
    }

    private func startDecor() {
        guard bounds.width > 1, moving else { return }
        fade(cyanClouds, from: 0.28, to: 0.92, duration: 4.2)
        fade(blueClouds, from: 0.9, to: 0.22, duration: 5.4)
        groundRow.layer.removeAnimation(forKey: "ken")
        let zoom = CABasicAnimation(keyPath: "transform.scale")
        zoom.fromValue = 1.04
        zoom.toValue = 1.2
        let pan = CABasicAnimation(keyPath: "transform.translation.x")
        pan.fromValue = 18
        pan.toValue = -22
        let group = CAAnimationGroup()
        group.animations = [zoom, pan]
        group.duration = 18
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        groundRow.layer.add(group, forKey: "ken")
    }

    private func fade(_ view: UIView, from: CGFloat, to: CGFloat, duration: CFTimeInterval) {
        guard view.layer.animation(forKey: "fade") == nil else { return }
        view.alpha = from
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = to
        fade.duration = duration
        fade.autoreverses = true
        fade.repeatCount = .infinity
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        view.layer.add(fade, forKey: "fade")
    }
}
