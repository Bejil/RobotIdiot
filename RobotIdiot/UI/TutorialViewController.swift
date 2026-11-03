import UIKit

final class TutorialViewController: UIViewController {
    fileprivate struct Page {
        let eyebrow: String
        let title: String
        let body: String
        let accent: UIColor
        let art: Art
    }

    fileprivate enum Art {
        case hero
        case facing
        case program
        case execute
        case victory
        case campaign
    }

    private let pages: [Page] = [
        Page(
            eyebrow: "Principe",
            title: "Le robot est idiot.\nC’est toi le cerveau.",
            body: "Il fait exactement ce que tu écris, dans l’ordre, sans jamais deviner. Une mauvaise instruction, et il bloque. Une bonne suite, et il atteint le drapeau.",
            accent: UIColor(hex: 0x7B3FF2),
            art: .hero
        ),
        Page(
            eyebrow: "Orientation",
            title: "La visière montre\noù il regarde.",
            body: "AVANCE suit toujours cette direction. TOURNE GAUCHE et TOURNE DROITE changent son regard. Avant d’écrire, regarde bien le plateau : murs, buissons, lave, eau et pointes comptent.",
            accent: UIColor(hex: 0x3EC6FF),
            art: .facing
        ),
        Page(
            eyebrow: "Phase 1 · Préparer",
            title: "Compose ton programme.",
            body: "Ajoute les commandes une par une. RÉPÈTE tourne sans fin tant que tu ne sors pas du bloc. SI n’exécute son contenu que si la condition est vraie — sinon le bloc est sauté.",
            accent: UIColor(hex: 0xFFB020),
            art: .program
        ),
        Page(
            eyebrow: "Phase 2 · Lancer",
            title: "Exécuter, puis Stop.",
            body: "Appuie sur Exécuter : le robot joue chaque instruction en direct. Tu peux Stop à tout moment pour corriger. Impossible d’avancer dans un mur ? Erreur bloquante — change le programme.",
            accent: UIColor(hex: 0x3DDC84),
            art: .execute
        ),
        Page(
            eyebrow: "Phase 3 · Réussir",
            title: "Atteins le drapeau.\nGagne des étoiles.",
            body: "Quand le robot arrive au drapeau, c’est gagné. Les étoiles récompensent un programme court et propre : moins d’actions inutiles, plus d’étoiles.",
            accent: UIColor(hex: 0xFFD200),
            art: .victory
        ),
        Page(
            eyebrow: "Phase 4 · Progresser",
            title: "Dix mondes,\ncent niveaux.",
            body: "Chaque monde introduit de nouveaux pièges et objets. Continue pour reprendre ta place, ou ouvre Progression pour choisir un niveau. Les nouvelles commandes s’expliquent toutes seules au moment où tu en as besoin.",
            accent: UIColor(hex: 0xFF5A6E),
            art: .campaign
        )
    ]

    private let backdrop = TutorialBackdropView()
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let chrome = TutorialChromeView()
    private let skipButton = AppTheme.filledButton(
        title: "Passer",
        systemImage: "xmark",
        prominent: false,
        compact: true,
        tone: .quiet
    )
    private let nextButton = AppTheme.filledButton(title: "Suivant", systemImage: "arrow.right", prominent: true)
    private let pageViews: [TutorialPageView]
    private var currentPage = 0
    private var hasAppeared = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        pageViews = pages.map(TutorialPageView.init(page:))
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: 0x24145F)

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let content = UIStackView(arrangedSubviews: pageViews)
        content.axis = .horizontal
        content.alignment = .fill
        content.distribution = .fillEqually
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.currentPageIndicatorTintColor = AppTheme.gold
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.28)
        pageControl.addTarget(self, action: #selector(pageControlChanged), for: .valueChanged)
        pageControl.translatesAutoresizingMaskIntoConstraints = false

        chrome.isUserInteractionEnabled = true
        chrome.backgroundColor = .clear
        chrome.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chrome)

        if var skip = skipButton.configuration {
            skip.imagePlacement = .leading
            skip.imagePadding = 6
            skip.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
            skip.background.cornerRadius = 18
            skipButton.configuration = skip
        }
        skipButton.accessibilityLabel = "Passer le tutoriel"
        skipButton.addTarget(self, action: #selector(skipTutorial), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(skipButton)

        nextButton.addTarget(self, action: #selector(advance), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(nextButton)
        chrome.addSubview(pageControl)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            chrome.topAnchor.constraint(equalTo: view.topAnchor),
            chrome.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chrome.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chrome.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            skipButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            skipButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            skipButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            scrollView.topAnchor.constraint(equalTo: skipButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageControl.topAnchor, constant: -8),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, multiplier: CGFloat(pages.count)),

            pageControl.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -14),

            nextButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            nextButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            nextButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 58)
        ])

        for pageView in pageViews {
            pageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
            pageView.prepareForEntrance()
        }
        view.bringSubviewToFront(chrome)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PlaySettings.tutorialSeen = true
        backdrop.start()
        view.bringSubviewToFront(chrome)
        guard !hasAppeared else { return }
        hasAppeared = true
        pageViews.first?.playEntrance(reducedMotion: PlaySettings.prefersReducedMotion)
        pulseNext()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
    }

    @objc private func advance() {
        if currentPage >= pages.count - 1 {
            skipTutorial()
            return
        }
        go(to: currentPage + 1, animated: true)
    }

    @objc private func pageControlChanged() {
        go(to: pageControl.currentPage, animated: true)
    }

    @objc private func skipTutorial() {
        Soundscape.shared.play("select")
        PlaySettings.tutorialSeen = true
        presentingViewController?.dismiss(animated: true)
            ?? dismiss(animated: true)
    }

    private func go(to index: Int, animated: Bool) {
        let clamped = max(0, min(pages.count - 1, index))
        if clamped != currentPage {
            pageViews[currentPage].prepareForEntrance()
        }
        currentPage = clamped
        pageControl.currentPage = clamped
        let offset = CGPoint(x: scrollView.bounds.width * CGFloat(clamped), y: 0)
        scrollView.setContentOffset(offset, animated: animated)
        refreshChrome()
        pageViews[clamped].playEntrance(reducedMotion: PlaySettings.prefersReducedMotion)
        Soundscape.shared.play("ui")
    }

    private func refreshChrome() {
        let last = currentPage == pages.count - 1
        skipButton.isHidden = last
        skipButton.isUserInteractionEnabled = !last
        var configuration = nextButton.configuration ?? .filled()
        configuration.title = last ? "C’est parti !" : "Suivant"
        configuration.image = UIImage(systemName: last ? "flag.checkered" : "arrow.right")
        nextButton.configuration = configuration
        pulseNext()
    }

    private func pulseNext() {
        nextButton.layer.removeAnimation(forKey: "pulse")
        guard !PlaySettings.prefersReducedMotion else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.035
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        nextButton.layer.add(pulse, forKey: "pulse")
    }
}

extension TutorialViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(round(scrollView.contentOffset.x / max(scrollView.bounds.width, 1)))
        guard page != currentPage else { return }
        currentPage = page
        pageControl.currentPage = page
        refreshChrome()
        pageViews[page].playEntrance(reducedMotion: PlaySettings.prefersReducedMotion)
    }
}

// MARK: - Page

private final class TutorialPageView: UIView {
    private let artHost = UIView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let accentBar = UIView()
    private var artViews: [UIView] = []
    private let page: TutorialViewController.Page
    private var didAnimate = false

    init(page: TutorialViewController.Page) {
        self.page = page
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        artHost.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artHost)
        buildArt(page.art)

        eyebrowLabel.text = page.eyebrow.uppercased()
        eyebrowLabel.font = AppTheme.font(13, .heavy, textStyle: .caption1)
        eyebrowLabel.textColor = page.accent
        eyebrowLabel.adjustsFontForContentSizeCategory = true

        titleLabel.text = page.title
        titleLabel.font = AppTheme.font(32, .heavy, textStyle: .title1)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        bodyLabel.text = page.body
        bodyLabel.font = AppTheme.font(17, .medium, textStyle: .body)
        bodyLabel.textColor = AppTheme.inkSoft
        bodyLabel.numberOfLines = 0
        bodyLabel.adjustsFontForContentSizeCategory = true

        accentBar.backgroundColor = page.accent
        accentBar.layer.cornerRadius = 3
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        let copy = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, bodyLabel])
        copy.axis = .vertical
        copy.spacing = 12
        copy.setCustomSpacing(8, after: eyebrowLabel)
        copy.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentBar)
        addSubview(copy)

        NSLayoutConstraint.activate([
            artHost.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            artHost.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            artHost.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            artHost.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.42),

            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            accentBar.topAnchor.constraint(equalTo: artHost.bottomAnchor, constant: 18),
            accentBar.widthAnchor.constraint(equalToConstant: 42),
            accentBar.heightAnchor.constraint(equalToConstant: 6),

            copy.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 14),
            copy.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            copy.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            copy.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func prepareForEntrance() {
        layer.removeAllAnimations()
        artViews.forEach {
            $0.layer.removeAllAnimations()
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 24).scaledBy(x: 0.9, y: 0.9)
        }
        eyebrowLabel.layer.removeAllAnimations()
        titleLabel.layer.removeAllAnimations()
        bodyLabel.layer.removeAllAnimations()
        accentBar.layer.removeAllAnimations()
        eyebrowLabel.alpha = 0
        titleLabel.alpha = 0
        bodyLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 16)
        bodyLabel.transform = CGAffineTransform(translationX: 0, y: 20)
        accentBar.transform = CGAffineTransform(scaleX: 0.2, y: 1)
        didAnimate = false
    }

    func playEntrance(reducedMotion: Bool) {
        if reducedMotion {
            artViews.forEach { $0.alpha = 1; $0.transform = .identity }
            titleLabel.alpha = 1
            titleLabel.transform = .identity
            bodyLabel.alpha = 1
            bodyLabel.transform = .identity
            eyebrowLabel.alpha = 1
            accentBar.transform = .identity
            didAnimate = true
            return
        }
        // Déjà préparé invisible : on n'efface plus un contenu visible.
        if !didAnimate && artViews.first?.alpha ?? 1 > 0.5 {
            prepareForEntrance()
            layoutIfNeeded()
        }
        didAnimate = true
        for (index, view) in artViews.enumerated() {
            UIView.animate(
                withDuration: 0.55,
                delay: 0.05 * Double(index),
                usingSpringWithDamping: 0.78,
                initialSpringVelocity: 0.6,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
        UIView.animate(withDuration: 0.45, delay: 0.12, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.eyebrowLabel.alpha = 1
            self.accentBar.transform = .identity
        }
        UIView.animate(
            withDuration: 0.5,
            delay: 0.18,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.4,
            options: [.beginFromCurrentState]
        ) {
            self.titleLabel.alpha = 1
            self.titleLabel.transform = .identity
        }
        UIView.animate(
            withDuration: 0.55,
            delay: 0.28,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.3,
            options: [.beginFromCurrentState]
        ) {
            self.bodyLabel.alpha = 1
            self.bodyLabel.transform = .identity
        }
        startIdleMotion()
    }

    private func startIdleMotion() {
        guard !PlaySettings.prefersReducedMotion else { return }
        for (index, view) in artViews.enumerated() {
            let bob = CABasicAnimation(keyPath: "transform.translation.y")
            bob.fromValue = -4 - CGFloat(index % 3)
            bob.toValue = 5 + CGFloat(index % 2)
            bob.duration = 2.2 + Double(index) * 0.35
            bob.autoreverses = true
            bob.repeatCount = .infinity
            bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            view.layer.add(bob, forKey: "bob")
        }
    }

    private func buildArt(_ kind: TutorialViewController.Art) {
        artHost.subviews.forEach { $0.removeFromSuperview() }
        artViews.removeAll()
        switch kind {
        case .hero:
            addHero(named: "HomeHero", confetti: true)
        case .facing:
            addFacingRow()
        case .program:
            addCommandRow()
        case .execute:
            addExecuteScene()
        case .victory:
            addVictoryScene()
        case .campaign:
            addCampaignScene()
        }
    }

    private func addHero(named: String, confetti: Bool) {
        if confetti, let image = UIImage(named: "HomeConfetti") {
            let view = UIImageView(image: image)
            view.contentMode = .scaleAspectFit
            pinArt(view, width: 0.92, height: 0.9, y: 0.02)
        }
        let robot = UIImageView(image: UIImage(named: named))
        robot.contentMode = .scaleAspectFit
        pinArt(robot, width: 0.62, height: 0.95, y: 0.05)
    }

    private func addFacingRow() {
        let names = ["RobotLeft", "BoardMascot", "RobotRight", "RobotBack"]
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .fill
        row.distribution = .fillEqually
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(row)
        NSLayoutConstraint.activate([
            row.centerXAnchor.constraint(equalTo: artHost.centerXAnchor),
            row.centerYAnchor.constraint(equalTo: artHost.centerYAnchor),
            row.widthAnchor.constraint(equalTo: artHost.widthAnchor, multiplier: 0.92),
            row.heightAnchor.constraint(equalTo: artHost.heightAnchor, multiplier: 0.7)
        ])
        for name in names {
            let image = UIImageView(image: UIImage(named: name))
            image.contentMode = .scaleAspectFit
            row.addArrangedSubview(image)
            artViews.append(image)
        }
    }

    private func addCommandRow() {
        let names = [
            "CommandForward", "CommandLeft", "CommandRight",
            "CommandLoop", "CommandIf", "CommandPickUp"
        ]
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: artHost.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: artHost.centerYAnchor),
            grid.widthAnchor.constraint(equalTo: artHost.widthAnchor, multiplier: 0.92),
            grid.heightAnchor.constraint(equalTo: artHost.heightAnchor, multiplier: 0.72)
        ])
        for rowIndex in 0..<2 {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            for col in 0..<3 {
                let name = names[rowIndex * 3 + col]
                let chip = UIView()
                chip.backgroundColor = UIColor.white.withAlphaComponent(0.14)
                chip.layer.cornerRadius = 18
                chip.layer.cornerCurve = .continuous
                let icon = UIImageView(image: UIImage(named: name))
                icon.contentMode = .scaleAspectFit
                icon.translatesAutoresizingMaskIntoConstraints = false
                chip.addSubview(icon)
                NSLayoutConstraint.activate([
                    icon.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
                    icon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
                    icon.widthAnchor.constraint(equalTo: chip.widthAnchor, multiplier: 0.52),
                    icon.heightAnchor.constraint(equalTo: chip.heightAnchor, multiplier: 0.52)
                ])
                row.addArrangedSubview(chip)
                artViews.append(chip)
            }
            grid.addArrangedSubview(row)
        }
    }

    private func addExecuteScene() {
        let board = UIImageView(image: UIImage(named: "BoardGrass"))
        board.contentMode = .scaleAspectFill
        board.clipsToBounds = true
        board.layer.cornerRadius = 24
        board.layer.cornerCurve = .continuous
        pinArt(board, width: 0.7, height: 0.62, y: 0.18)

        let flag = UIImageView(image: UIImage(named: "BoardFlag"))
        flag.contentMode = .scaleAspectFit
        pinArt(flag, width: 0.22, height: 0.28, y: 0.12, x: 0.62)

        let robot = UIImageView(image: UIImage(named: "BoardMascot"))
        robot.contentMode = .scaleAspectFit
        pinArt(robot, width: 0.28, height: 0.34, y: 0.42, x: 0.18)

        let play = makeBadge(system: "play.fill", color: AppTheme.success)
        pinView(play, width: 64, height: 64, y: 0.02, x: 0.72)
        artViews.append(play)
    }

    private func addVictoryScene() {
        if let rays = UIImage(named: "VictoryRays") {
            let view = UIImageView(image: rays)
            view.contentMode = .scaleAspectFit
            pinArt(view, width: 0.95, height: 0.95, y: 0)
        }
        if let confetti = UIImage(named: "VictoryConfetti") {
            let view = UIImageView(image: confetti)
            view.contentMode = .scaleAspectFit
            pinArt(view, width: 0.9, height: 0.7, y: 0.05)
        }
        let robot = UIImageView(image: UIImage(named: "VictoryRobot") ?? UIImage(named: "HomeHero"))
        robot.contentMode = .scaleAspectFit
        pinArt(robot, width: 0.55, height: 0.85, y: 0.1)

        let starRow = UIStackView()
        starRow.axis = .horizontal
        starRow.spacing = 8
        starRow.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(starRow)
        NSLayoutConstraint.activate([
            starRow.centerXAnchor.constraint(equalTo: artHost.centerXAnchor),
            starRow.bottomAnchor.constraint(equalTo: artHost.bottomAnchor, constant: -4)
        ])
        for _ in 0..<3 {
            let star = UIImageView(image: UIImage(named: "VictoryStar") ?? UIImage(systemName: "star.fill"))
            star.tintColor = AppTheme.gold
            star.contentMode = .scaleAspectFit
            star.translatesAutoresizingMaskIntoConstraints = false
            star.widthAnchor.constraint(equalToConstant: 36).isActive = true
            star.heightAnchor.constraint(equalToConstant: 36).isActive = true
            starRow.addArrangedSubview(star)
            artViews.append(star)
        }
    }

    private func addCampaignScene() {
        let logo = UIImageView(image: UIImage(named: "HomeLogo"))
        logo.contentMode = .scaleAspectFit
        pinArt(logo, width: 0.85, height: 0.34, y: 0.02)

        let worlds = UIStackView()
        worlds.axis = .horizontal
        worlds.spacing = 10
        worlds.distribution = .fillEqually
        worlds.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(worlds)
        NSLayoutConstraint.activate([
            worlds.leadingAnchor.constraint(equalTo: artHost.leadingAnchor, constant: 8),
            worlds.trailingAnchor.constraint(equalTo: artHost.trailingAnchor, constant: -8),
            worlds.bottomAnchor.constraint(equalTo: artHost.bottomAnchor, constant: -8),
            worlds.heightAnchor.constraint(equalTo: artHost.heightAnchor, multiplier: 0.48)
        ])
        for world in 1...4 {
            let tile = UIImageView(image: UIImage(named: "W\(world)Grass") ?? UIImage(named: "BoardGrass"))
            tile.contentMode = .scaleAspectFill
            tile.clipsToBounds = true
            tile.layer.cornerRadius = 16
            tile.layer.cornerCurve = .continuous
            let flag = UIImageView(image: UIImage(named: "W\(world)Flag") ?? UIImage(named: "BoardFlag"))
            flag.contentMode = .scaleAspectFit
            flag.translatesAutoresizingMaskIntoConstraints = false
            tile.addSubview(flag)
            NSLayoutConstraint.activate([
                flag.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                flag.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                flag.widthAnchor.constraint(equalTo: tile.widthAnchor, multiplier: 0.55),
                flag.heightAnchor.constraint(equalTo: tile.heightAnchor, multiplier: 0.55)
            ])
            worlds.addArrangedSubview(tile)
            artViews.append(tile)
        }
        artViews.insert(logo, at: 0)
    }

    private func makeBadge(system: String, color: UIColor) -> UIView {
        let badge = UIView()
        badge.backgroundColor = color
        badge.layer.cornerRadius = 32
        badge.layer.shadowColor = UIColor.black.cgColor
        badge.layer.shadowOpacity = 0.25
        badge.layer.shadowRadius = 8
        badge.layer.shadowOffset = CGSize(width: 0, height: 4)
        let icon = UIImageView(image: UIImage(systemName: system))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 26),
            icon.heightAnchor.constraint(equalToConstant: 26)
        ])
        return badge
    }

    private func pinArt(
        _ view: UIImageView,
        width: CGFloat,
        height: CGFloat,
        y: CGFloat,
        x: CGFloat = 0.5
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalTo: artHost.widthAnchor, multiplier: width),
            view.heightAnchor.constraint(equalTo: artHost.heightAnchor, multiplier: height),
            NSLayoutConstraint(
                item: view, attribute: .centerX, relatedBy: .equal,
                toItem: artHost, attribute: .right, multiplier: max(0.01, x), constant: 0
            ),
            NSLayoutConstraint(
                item: view, attribute: .top, relatedBy: .equal,
                toItem: artHost, attribute: .bottom, multiplier: max(0.01, y), constant: 0
            )
        ])
        artViews.append(view)
    }

    private func pinView(_ view: UIView, width: CGFloat, height: CGFloat, y: CGFloat, x: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height),
            NSLayoutConstraint(
                item: view, attribute: .centerX, relatedBy: .equal,
                toItem: artHost, attribute: .right, multiplier: max(0.01, x), constant: 0
            ),
            NSLayoutConstraint(
                item: view, attribute: .top, relatedBy: .equal,
                toItem: artHost, attribute: .bottom, multiplier: max(0.01, y), constant: 0
            )
        ])
    }
}

/// Laisse passer les touches hors boutons / indicateurs, pour garder le swipe.
private final class TutorialChromeView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

// MARK: - Backdrop

private final class TutorialBackdropView: UIView {
    private let rays = UIImageView(image: UIImage(named: "HomeRays") ?? UIImage(named: "VictoryRays"))
    private let cyan = UIImageView(image: UIImage(named: "HomeCloudCyan"))
    private let blue = UIImageView(image: UIImage(named: "HomeCloudBlue"))
    private let band = UIImageView(image: UIImage(named: "HomeCloudBand"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x24145F)
        clipsToBounds = true
        rays.contentMode = .scaleAspectFit
        rays.alpha = 0.55
        rays.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rays)
        for cloud in [cyan, blue] {
            cloud.contentMode = .scaleAspectFit
            cloud.alpha = 0.45
            cloud.translatesAutoresizingMaskIntoConstraints = false
            addSubview(cloud)
        }
        band.contentMode = .scaleAspectFit
        band.alpha = 0.85
        band.translatesAutoresizingMaskIntoConstraints = false
        addSubview(band)
        NSLayoutConstraint.activate([
            rays.centerXAnchor.constraint(equalTo: centerXAnchor),
            rays.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            rays.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.35),
            rays.heightAnchor.constraint(equalTo: rays.widthAnchor, multiplier: 868 / 1006),

            cyan.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -20),
            cyan.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            cyan.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.1),
            cyan.heightAnchor.constraint(equalTo: cyan.widthAnchor, multiplier: 121 / 520),

            blue.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 24),
            blue.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            blue.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1.15),
            blue.heightAnchor.constraint(equalTo: blue.widthAnchor, multiplier: 112 / 469),

            band.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -40),
            band.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 40),
            band.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 20),
            band.heightAnchor.constraint(equalTo: widthAnchor, multiplier: 0.42)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func start() {
        guard !PlaySettings.prefersReducedMotion else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = -0.05
        spin.toValue = 0.05
        spin.duration = 10
        spin.autoreverses = true
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        rays.layer.add(spin, forKey: "spin")

        fade(cyan, from: 0.25, to: 0.7, duration: 4.5)
        fade(blue, from: 0.65, to: 0.25, duration: 5.5)

        let pan = CABasicAnimation(keyPath: "transform.translation.x")
        pan.fromValue = 10
        pan.toValue = -14
        pan.duration = 16
        pan.autoreverses = true
        pan.repeatCount = .infinity
        pan.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        band.layer.add(pan, forKey: "pan")
    }

    func stop() {
        rays.layer.removeAllAnimations()
        cyan.layer.removeAllAnimations()
        blue.layer.removeAllAnimations()
        band.layer.removeAllAnimations()
    }

    private func fade(_ view: UIView, from: CGFloat, to: CGFloat, duration: CFTimeInterval) {
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
