import UIKit
import RobotIdiotCore

/// Tutoriel Expert — même langage que le tutoriel Aventure (pages, chrome, backdrop).
final class ExpertTutorialViewController: UIViewController {
    var onFinished: (() -> Void)?

    fileprivate enum Art {
        case welcome
        case repeatLoop
        case conditional
        case stars
        case start
    }

    fileprivate struct Page {
        let eyebrow: String
        let title: String
        let body: String
        let accent: UIColor
        let art: Art
    }

    private let pages: [Page]
    private var backdrop: AmbientBackdropView!
    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let chrome = ExpertTutorialChromeView()
    private let skipButton = AppTheme.filledButton(
        title: "Passer",
        systemImage: "xmark",
        prominent: false,
        compact: true,
        tone: .quiet
    )
    private let nextButton = AppTheme.filledButton(title: "Suivant", systemImage: "arrow.right", prominent: true)
    private let pageViews: [ExpertTutorialPageView]
    private var currentPage = 0
    private var hasAppeared = false

    init() {
        let pack = ExpertCatalog.tutorial
        let accents: [UIColor] = [
            AppTheme.interaction,
            UIColor(hex: 0x3EC6FF),
            UIColor(hex: 0x7B3FF2),
            AppTheme.gold,
            AppTheme.success
        ]
        let arts: [Art] = [.welcome, .repeatLoop, .conditional, .stars, .start]
        let eyebrows = [
            "Laboratoire",
            "Commande · REPETE",
            "Commande · SI",
            "Étoiles",
            "C’est parti"
        ]
        pages = pack.pages.enumerated().map { index, source in
            Page(
                eyebrow: eyebrows.indices.contains(index) ? eyebrows[index] : "Laboratoire",
                title: source.title,
                body: source.body,
                accent: accents.indices.contains(index) ? accents[index] : AppTheme.interaction,
                art: arts.indices.contains(index) ? arts[index] : .welcome
            )
        }
        pageViews = pages.map(ExpertTutorialPageView.init(page:))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        backdrop = AmbientBackdropView.install(in: view)

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
        skipButton.isHidden = !ExpertCatalog.tutorial.skipAllowed
        skipButton.addTarget(self, action: #selector(skipTutorial), for: .touchUpInside)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(skipButton)

        nextButton.addTarget(self, action: #selector(advance), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        chrome.addSubview(nextButton)
        chrome.addSubview(pageControl)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
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
            content.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor,
                multiplier: CGFloat(max(pages.count, 1))
            ),

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
        refreshChrome()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
            finish(markCompleted: true)
            return
        }
        go(to: currentPage + 1, animated: true)
    }

    @objc private func pageControlChanged() {
        go(to: pageControl.currentPage, animated: true)
    }

    @objc private func skipTutorial() {
        finish(markCompleted: true)
    }

    private func finish(markCompleted: Bool) {
        Soundscape.shared.play("select")
        if markCompleted {
            ExpertStore.shared.markTutorialCompleted()
        }
        onFinished?()
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
        let canSkip = ExpertCatalog.tutorial.skipAllowed
        skipButton.isHidden = last || !canSkip
        skipButton.isUserInteractionEnabled = !last && canSkip
        var configuration = nextButton.configuration ?? .filled()
        let cta = pages.indices.contains(currentPage)
            ? ExpertCatalog.tutorial.pages[currentPage].primaryCTA
            : nil
        configuration.title = last
            ? (cta ?? "Commencer l’entraînement")
            : (cta ?? "Suivant")
        configuration.image = UIImage(systemName: last ? "play.fill" : "arrow.right")
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

extension ExpertTutorialViewController: UIScrollViewDelegate {
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

private final class ExpertTutorialPageView: UIView {
    private let artHost = UIView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let accentBar = UIView()
    private var artViews: [UIView] = []
    private let page: ExpertTutorialViewController.Page

    init(page: ExpertTutorialViewController.Page) {
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
            artHost.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.4),

            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            accentBar.topAnchor.constraint(equalTo: artHost.bottomAnchor, constant: 18),
            accentBar.widthAnchor.constraint(equalToConstant: 36),
            accentBar.heightAnchor.constraint(equalToConstant: 6),

            copy.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 14),
            copy.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            copy.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            copy.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func prepareForEntrance() {
        guard !PlaySettings.prefersReducedMotion else { return }
        artViews.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 18).scaledBy(x: 0.92, y: 0.92)
        }
        eyebrowLabel.alpha = 0
        titleLabel.alpha = 0
        bodyLabel.alpha = 0
        accentBar.transform = CGAffineTransform(scaleX: 0.2, y: 1)
    }

    func playEntrance(reducedMotion: Bool) {
        guard !reducedMotion else {
            artViews.forEach { $0.alpha = 1; $0.transform = .identity }
            eyebrowLabel.alpha = 1
            titleLabel.alpha = 1
            bodyLabel.alpha = 1
            accentBar.transform = .identity
            return
        }
        for (index, view) in artViews.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.05 * Double(index),
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseOut]
            ) {
                view.alpha = 1
                view.transform = .identity
            }
        }
        UIView.animate(withDuration: 0.36, delay: 0.1, options: [.curveEaseOut]) {
            self.eyebrowLabel.alpha = 1
            self.accentBar.transform = .identity
        }
        UIView.animate(withDuration: 0.4, delay: 0.16, options: [.curveEaseOut]) {
            self.titleLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.44, delay: 0.22, options: [.curveEaseOut]) {
            self.bodyLabel.alpha = 1
        }
    }

    private func buildArt(_ kind: ExpertTutorialViewController.Art) {
        artHost.subviews.forEach { $0.removeFromSuperview() }
        artViews.removeAll()
        switch kind {
        case .welcome:
            if let confetti = UIImage(named: "HomeConfetti") {
                pin(UIImageView(image: confetti), width: 0.92, height: 0.9, y: 0.02)
            }
            pin(UIImageView(image: UIImage(named: "HomeHero") ?? UIImage(named: "BoardMascot")), width: 0.58, height: 0.92, y: 0.06)
        case .repeatLoop:
            addCommandChips(["CommandLoop", "CommandForward", "CommandLeft", "CommandRight"])
        case .conditional:
            addCommandChips(["CommandIf", "CommandPickUp", "CommandUse", "CommandPush"])
        case .stars:
            if let rays = UIImage(named: "VictoryRays") {
                pin(UIImageView(image: rays), width: 0.95, height: 0.95, y: 0)
            }
            pin(UIImageView(image: UIImage(named: "VictoryRobot") ?? UIImage(named: "HomeHero")), width: 0.5, height: 0.82, y: 0.08)
            let starRow = UIStackView()
            starRow.axis = .horizontal
            starRow.spacing = 8
            starRow.translatesAutoresizingMaskIntoConstraints = false
            artHost.addSubview(starRow)
            NSLayoutConstraint.activate([
                starRow.centerXAnchor.constraint(equalTo: artHost.centerXAnchor),
                starRow.bottomAnchor.constraint(equalTo: artHost.bottomAnchor, constant: -2)
            ])
            for _ in 0..<3 {
                let star = UIImageView(image: UIImage(named: "VictoryStar") ?? GameArt.star(filled: true))
                star.contentMode = .scaleAspectFit
                star.translatesAutoresizingMaskIntoConstraints = false
                star.widthAnchor.constraint(equalToConstant: 34).isActive = true
                star.heightAnchor.constraint(equalToConstant: 34).isActive = true
                starRow.addArrangedSubview(star)
                artViews.append(star)
            }
        case .start:
            let board = UIImageView(image: UIImage(named: "BoardGrass"))
            board.contentMode = .scaleAspectFill
            board.clipsToBounds = true
            board.layer.cornerRadius = 22
            board.layer.cornerCurve = .continuous
            pin(board, width: 0.72, height: 0.62, y: 0.18)
            pin(UIImageView(image: UIImage(named: "BoardGoal") ?? UIImage(named: "W1Goal")), width: 0.26, height: 0.26, y: 0.14, x: 0.58)
            pin(UIImageView(image: UIImage(named: "BoardMascot")), width: 0.28, height: 0.34, y: 0.42, x: 0.2)
            let loop = UIImageView(image: UIImage(named: "CommandLoop"))
            loop.contentMode = .scaleAspectFit
            loop.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            loop.layer.cornerRadius = 16
            loop.clipsToBounds = true
            pin(loop, width: 0.22, height: 0.22, y: 0.02, x: 0.72)
        }
    }

    private func addCommandChips(_ names: [String]) {
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        artHost.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: artHost.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: artHost.centerYAnchor),
            grid.widthAnchor.constraint(equalTo: artHost.widthAnchor, multiplier: 0.9),
            grid.heightAnchor.constraint(equalTo: artHost.heightAnchor, multiplier: 0.72)
        ])
        for rowIndex in 0..<2 {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            for col in 0..<2 {
                let index = rowIndex * 2 + col
                guard names.indices.contains(index) else { continue }
                let chip = UIView()
                chip.backgroundColor = UIColor.white.withAlphaComponent(0.16)
                chip.layer.cornerRadius = 18
                chip.layer.cornerCurve = .continuous
                let icon = UIImageView(image: UIImage(named: names[index]))
                icon.contentMode = .scaleAspectFit
                icon.translatesAutoresizingMaskIntoConstraints = false
                chip.addSubview(icon)
                NSLayoutConstraint.activate([
                    icon.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
                    icon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
                    icon.widthAnchor.constraint(equalTo: chip.widthAnchor, multiplier: 0.5),
                    icon.heightAnchor.constraint(equalTo: chip.heightAnchor, multiplier: 0.5)
                ])
                row.addArrangedSubview(chip)
                artViews.append(chip)
            }
            grid.addArrangedSubview(row)
        }
        artViews.append(grid)
    }

    private func pin(_ view: UIView, width: CGFloat, height: CGFloat, y: CGFloat, x: CGFloat = 0.5) {
        if let imageView = view as? UIImageView {
            imageView.contentMode = imageView.contentMode == .scaleAspectFill ? .scaleAspectFill : .scaleAspectFit
        }
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
}

private final class ExpertTutorialChromeView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}
