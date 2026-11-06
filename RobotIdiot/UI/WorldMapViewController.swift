import UIKit
import RobotIdiotCore

#if DEBUG
private let debugUnlockAllCampaignLevels = true
#else
private let debugUnlockAllCampaignLevels = false
#endif

final class WorldMapViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let path = WorldPathView()
    private var unlockedWorld = 1
    private var progress = CampaignProgress(campaignSeed: 1)
    private var backdrop: AmbientBackdropView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = "Progression"
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        backdrop = AmbientBackdropView.install(in: view)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        path.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(path)
        view.addSubview(scrollView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            path.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            path.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 12),
            path.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            path.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let navigation = navigationController {
            AppTheme.apply(to: navigation)
        }
        backdrop.start()
        progress = CampaignStore.shared.progress()
        if debugUnlockAllCampaignLevels {
            unlockedWorld = CatalogCampaign.worldCount
        } else {
            unlockedWorld = min(
                CatalogCampaign.worldCount,
                CampaignRules.unlockedWorld(in: progress, layout: CatalogCampaign.layout)
            )
        }
        reloadCards()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
    }

    private func reloadCards() {
        path.stack.arrangedSubviews.forEach {
            path.stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let address = CampaignRules.continueAddress(in: progress, layout: CatalogCampaign.layout)
        let currentLevel = CatalogCampaign.level(at: address) == nil ? nil : address
        let maximum = CatalogCampaign.levelsPerWorld * 3
        for world in 1...CatalogCampaign.worldCount {
            let locked = !debugUnlockAllCampaignLevels && world > unlockedWorld
            let stars = CampaignRules.stars(inWorld: world, progress: progress)
            let finished = (1...CatalogCampaign.levelsPerWorld).allSatisfy {
                progress.score(at: LevelAddress(world: world, level: $0)) != nil
            }
            let state: WorldCardControl.State
            if locked {
                state = .locked
            } else if finished {
                state = .complete
            } else if currentLevel?.world == world {
                state = .current
            } else {
                state = .open
            }
            let levelNumber = currentLevel?.world == world ? currentLevel?.level : nil
            let card = WorldCardControl(
                world: world,
                image: UIImage(named: "World\(world)") ?? GameArt.worldBadge(CatalogCampaign.theme(for: world)),
                title: PlayerCopy.worldTitle(world),
                subtitle: locked ? "Termine d'abord le niveau précédent." : CatalogCampaign.mechanicTitle(for: world),
                stars: stars,
                maximum: maximum,
                levelNumber: levelNumber,
                state: state
            )
            card.addTarget(self, action: #selector(openWorld(_:)), for: .touchUpInside)
            path.stack.addArrangedSubview(card)
        }
    }

    @objc private func openWorld(_ sender: WorldCardControl) {
        guard debugUnlockAllCampaignLevels || sender.world <= unlockedWorld else { return }
        navigationController?.pushViewController(WorldLevelsViewController(world: sender.world), animated: true)
    }
}

private final class WorldPathView: UIView {
    let stack = UIStackView()
    private let line = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        line.strokeColor = UIColor.white.withAlphaComponent(0.55).cgColor
        line.fillColor = nil
        line.lineWidth = 2
        line.lineDashPattern = [1, 7]
        line.lineCap = .round
        layer.addSublayer(line)
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let dots = stack.arrangedSubviews.compactMap { $0.viewWithTag(90) }
        guard let first = dots.first, let last = dots.last, let host = first.superview else {
            line.path = nil
            return
        }
        let start = convert(first.center, from: host)
        let end = convert(last.center, from: last.superview)
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        line.path = path.cgPath
    }
}

private final class WorldCardControl: UIControl {
    enum State {
        case current
        case complete
        case open
        case locked
    }

    let world: Int

    init(
        world: Int,
        image: UIImage,
        title: String,
        subtitle: String,
        stars: Int,
        maximum: Int,
        levelNumber: Int?,
        state: State
    ) {
        self.world = world
        super.init(frame: .zero)

        let dot = UIView()
        dot.tag = 90
        dot.backgroundColor = .white
        dot.layer.cornerRadius = 7
        dot.layer.borderWidth = state == .current ? 3 : 0
        dot.layer.borderColor = AppTheme.gold.cgColor
        dot.isUserInteractionEnabled = false
        dot.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.isUserInteractionEnabled = false
        card.backgroundColor = state == .current ? UIColor(hex: 0xFFF4C8) : UIColor(hex: 0xF4F0FF)
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = state == .current ? 3 : 0
        card.layer.borderColor = AppTheme.gold.cgColor
        card.alpha = state == .locked ? 0.55 : 1
        card.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(20, .heavy, textStyle: .title3)
        titleLabel.textColor = UIColor(hex: 0x1A1440)
        titleLabel.adjustsFontForContentSizeCategory = true

        let detailLabel = UILabel()
        detailLabel.text = subtitle
        detailLabel.font = AppTheme.font(14, .semibold, textStyle: .subheadline)
        detailLabel.textColor = UIColor(hex: 0x5C5678)
        detailLabel.numberOfLines = 2
        detailLabel.adjustsFontForContentSizeCategory = true

        var lines: [UIView] = [titleLabel, detailLabel]
        if let levelNumber {
            let levelLabel = UILabel()
            levelLabel.text = "Niveau \(levelNumber)"
            levelLabel.font = AppTheme.font(13, .heavy, textStyle: .footnote)
            levelLabel.textColor = UIColor(hex: 0x7B3FF2)
            levelLabel.adjustsFontForContentSizeCategory = true
            lines.append(levelLabel)
        }

        let star = UIImageView(image: GameArt.star(filled: true))
        star.contentMode = .scaleAspectFit
        star.translatesAutoresizingMaskIntoConstraints = false
        let count = UILabel()
        count.text = "\(stars)/\(maximum)"
        count.font = AppTheme.font(13, .heavy, textStyle: .caption1)
        count.textColor = .white
        let pill = UIStackView(arrangedSubviews: [star, count])
        pill.axis = .horizontal
        pill.spacing = 4
        pill.alignment = .center
        pill.isLayoutMarginsRelativeArrangement = true
        pill.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 10)
        pill.backgroundColor = UIColor(hex: 0x241B52)
        pill.layer.cornerRadius = 12
        pill.layer.masksToBounds = true
        lines.append(pill)

        let text = UIStackView(arrangedSubviews: lines)
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = 3
        text.translatesAutoresizingMaskIntoConstraints = false

        let action = UIView()
        action.backgroundColor = UIColor(hex: 0x3DDC84)
        action.layer.cornerRadius = 22
        action.layer.borderWidth = 3
        action.layer.borderColor = UIColor.white.cgColor
        action.layer.shadowColor = UIColor(hex: 0x14924A).cgColor
        action.layer.shadowOpacity = 0.45
        action.layer.shadowRadius = 0
        action.layer.shadowOffset = CGSize(width: 0, height: 4)
        action.translatesAutoresizingMaskIntoConstraints = false
        let glyph = UIImageView()
        glyph.tintColor = .white
        glyph.contentMode = .scaleAspectFit
        glyph.translatesAutoresizingMaskIntoConstraints = false
        action.addSubview(glyph)
        switch state {
        case .complete:
            glyph.image = UIImage(systemName: "checkmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .black))
        case .locked:
            action.isHidden = true
        case .current, .open:
            glyph.image = UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .black))
        }

        card.addSubview(imageView)
        card.addSubview(text)
        card.addSubview(action)
        addSubview(dot)
        addSubview(card)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14),

            card.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.topAnchor.constraint(equalTo: topAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            imageView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 78),
            imageView.heightAnchor.constraint(equalToConstant: 78),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 8),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -8),

            action.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            action.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: 44),
            action.heightAnchor.constraint(equalToConstant: 44),
            glyph.centerXAnchor.constraint(equalTo: action.centerXAnchor, constant: state == .complete ? 0 : 1),
            glyph.centerYAnchor.constraint(equalTo: action.centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: 22),
            glyph.heightAnchor.constraint(equalToConstant: 22),

            text.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(
                equalTo: state == .locked ? card.trailingAnchor : action.leadingAnchor,
                constant: state == .locked ? -12 : -8
            ),
            text.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            star.widthAnchor.constraint(equalToConstant: 16),
            star.heightAnchor.constraint(equalToConstant: 16)
        ])

        var spoken = "\(title). \(subtitle). \(stars) étoiles sur \(maximum)."
        if let levelNumber {
            spoken += " Niveau \(levelNumber) en cours."
        }
        if state == .locked {
            spoken += " Monde verrouillé."
        }
        accessibilityLabel = spoken
        isAccessibilityElement = true
        isEnabled = state != .locked
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            guard isEnabled else { return }
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
}

final class WorldLevelsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    let worldNumber: Int
    private let collectionView: UICollectionView
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private var progress = CampaignProgress(campaignSeed: 1, formulaVersion: CatalogCampaign.formulaVersion)
    private var preparing: LevelAddress?
    private var gridSide: CGFloat = 100
    private var gridSpan: CGFloat = 320
    private var rowHeight: CGFloat = 100
    private var ambient: AmbientBackdropView!

    init(world: Int) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.worldNumber = world
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = PlayerCopy.worldTitle(worldNumber)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        ambient = AmbientBackdropView.install(in: view)
        let backdrop = UIImageView(image: UIImage(named: "WorldBackdrop\(worldNumber)"))
        backdrop.contentMode = .scaleAspectFill
        backdrop.clipsToBounds = true
        backdrop.alpha = 0.42
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        let dim = UIView()
        dim.backgroundColor = UIColor(hex: 0x101848).withAlphaComponent(0.28)
        dim.isUserInteractionEnabled = false
        dim.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.isHidden = true
        subtitleLabel.font = AppTheme.font(18, .semibold, textStyle: .headline)
        subtitleLabel.textColor = .white
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.layer.shadowColor = UIColor.black.cgColor
        subtitleLabel.layer.shadowOpacity = 0.45
        subtitleLabel.layer.shadowRadius = 3
        subtitleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LevelTileCell.self, forCellWithReuseIdentifier: "level")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)
        view.addSubview(dim)
        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            dim.topAnchor.constraint(equalTo: view.topAnchor),
            dim.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        applyTransparentNavigationBar()
        ambient.start()
        reload()
        warmAhead()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        ambient.stop()
        if isMovingFromParent, let navigation = navigationController {
            AppTheme.apply(to: navigation)
        }
    }

    private func applyTransparentNavigationBar() {
        guard let navigation = navigationController else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: AppTheme.font(18, .heavy, textStyle: .headline)
        ]
        navigation.navigationBar.standardAppearance = appearance
        navigation.navigationBar.scrollEdgeAppearance = appearance
        navigation.navigationBar.compactAppearance = appearance
        navigation.navigationBar.compactScrollEdgeAppearance = appearance
        navigation.navigationBar.tintColor = .white
        navigation.navigationBar.isTranslucent = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let spacing: CGFloat = 10
        let pad: CGFloat = 16
        let width = collectionView.bounds.width
        let height = collectionView.bounds.height
        guard width > 1, height > 1 else { return }
        let side = floor((width - pad * 2 - spacing * 2) / 3)
        let span = side * 3 + spacing * 2
        let bottomPad = pad + view.safeAreaInsets.bottom
        let available = height - pad - bottomPad - spacing * 3
        let row = max(78, floor(available / 4))
        let metricsChanged = abs(gridSide - side) > 0.5 || abs(rowHeight - row) > 0.5
        gridSide = side
        gridSpan = span
        rowHeight = row
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: pad, left: pad, bottom: bottomPad, right: pad)
        if metricsChanged {
            layout.invalidateLayout()
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if indexPath.item == CatalogCampaign.layout.levelCount - 1 {
            return CGSize(width: gridSpan, height: rowHeight)
        }
        return CGSize(width: gridSide, height: rowHeight)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        CatalogCampaign.layout.levelCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "level", for: indexPath) as! LevelTileCell
        let level = indexPath.row + 1
        let address = LevelAddress(world: worldNumber, level: level)
        let unlocked = debugUnlockAllCampaignLevels
            || CampaignRules.isLevelUnlocked(address, progress: progress, layout: CatalogCampaign.layout)
        let stars = progress.score(at: address)?.stars ?? 0
        let wide = level == CatalogCampaign.layout.levelCount
        let optimum = CatalogCampaign.level(at: address)?.scoringRules.efficientExecutionMaxSteps
        let detail: String
        if preparing == address {
            detail = "Préparation…"
        } else if !unlocked {
            detail = "Verrouillé"
        } else if let optimum {
            detail = optimum <= 1 ? "1 commande" : "\(optimum) commandes"
        } else {
            detail = "Niveau \(level)"
        }
        cell.apply(number: level, wide: wide, unlocked: unlocked, stars: stars, detail: detail, preparing: preparing == address)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        Soundscape.shared.play("select")
        let address = LevelAddress(world: worldNumber, level: indexPath.row + 1)
        let unlocked = debugUnlockAllCampaignLevels
            || CampaignRules.isLevelUnlocked(address, progress: progress, layout: CatalogCampaign.layout)
        guard unlocked, preparing == nil else { return }
        if let level = CampaignStore.shared.level(at: address) {
            open(level, address: address)
            return
        }
        preparing = address
        collectionView.reloadData()
        CampaignStore.shared.materialize(address) { [weak self] level in
            guard let self else { return }
            self.preparing = nil
            self.reload()
            guard self.view.window != nil else { return }
            self.open(level, address: address)
        }
    }

    private func reload() {
        progress = CampaignStore.shared.progress()
        navigationItem.title = PlayerCopy.worldTitle(worldNumber)
        subtitleLabel.text = CatalogCampaign.mechanicTitle(for: worldNumber)
        collectionView.reloadData()
    }

    private func warmAhead() {
        let address = CampaignRules.continueAddress(in: progress, layout: CatalogCampaign.layout)
        guard address.world == worldNumber else { return }
        CampaignStore.shared.warm(address)
        let following = CampaignRules.nextAddress(after: address, layout: CatalogCampaign.layout)
        if following.world == worldNumber {
            CampaignStore.shared.warm(following)
        }
    }

    private func open(_ level: Level, address: LevelAddress) {
        let following = CampaignRules.nextAddress(after: address, layout: CatalogCampaign.layout)
        if following.world == worldNumber {
            CampaignStore.shared.warm(following)
        }
        navigationController?.pushViewController(
            GameViewController(level: level, campaign: address),
            animated: true
        )
    }
}

private final class LevelTileCell: UICollectionViewCell {
    private let eyebrow = UILabel()
    private let numberLabel = UILabel()
    private let compactDetail = UILabel()
    private let compactStars = UIStackView()
    private let compactColumn = UIStackView()

    private let finaleMark = UIImageView()
    private let finaleTitle = UILabel()
    private let wideDetail = UILabel()
    private let wideStars = UIStackView()
    private let wideRow = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.backgroundColor = UIColor(hex: 0xF7F4FF)
        contentView.layer.cornerRadius = 22
        contentView.layer.cornerCurve = .continuous
        layer.shadowColor = UIColor(hex: 0x1A1440).cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        styleCaption(eyebrow, text: "Niveau", size: 13, color: UIColor(hex: 0x7B3FF2))
        numberLabel.font = AppTheme.font(40, .black, textStyle: .largeTitle)
        numberLabel.textColor = UIColor(hex: 0x1A1440)
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true
        styleCaption(compactDetail, text: "", size: 13, color: UIColor(hex: 0x5C5678))
        fill(compactStars, side: 26)
        compactColumn.addArrangedSubview(eyebrow)
        compactColumn.addArrangedSubview(numberLabel)
        compactColumn.addArrangedSubview(compactStars)
        compactColumn.addArrangedSubview(compactDetail)
        compactColumn.axis = .vertical
        compactColumn.alignment = .center
        compactColumn.spacing = 6
        compactColumn.setCustomSpacing(2, after: eyebrow)
        compactColumn.translatesAutoresizingMaskIntoConstraints = false

        finaleMark.image = GameArt.victoryStar(earned: true)
        finaleMark.contentMode = .scaleAspectFit
        finaleMark.translatesAutoresizingMaskIntoConstraints = false
        finaleTitle.text = "Final"
        finaleTitle.font = AppTheme.font(32, .black, textStyle: .title1)
        finaleTitle.textColor = UIColor(hex: 0x1A1440)
        finaleTitle.adjustsFontForContentSizeCategory = true
        styleCaption(wideDetail, text: "", size: 15, color: UIColor(hex: 0x5C5678))
        wideDetail.textAlignment = .left
        let wideEyebrow = UILabel()
        styleCaption(wideEyebrow, text: "Niveau", size: 13, color: UIColor(hex: 0x7B3FF2))
        wideEyebrow.textAlignment = .left
        let text = UIStackView(arrangedSubviews: [wideEyebrow, finaleTitle, wideDetail])
        text.axis = .vertical
        text.alignment = .leading
        text.spacing = 2
        fill(wideStars, side: 28)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        wideRow.addArrangedSubview(finaleMark)
        wideRow.addArrangedSubview(text)
        wideRow.addArrangedSubview(spacer)
        wideRow.addArrangedSubview(wideStars)
        wideRow.axis = .horizontal
        wideRow.alignment = .center
        wideRow.spacing = 14
        wideRow.isHidden = true
        wideRow.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(compactColumn)
        contentView.addSubview(wideRow)
        NSLayoutConstraint.activate([
            finaleMark.widthAnchor.constraint(equalToConstant: 48),
            finaleMark.heightAnchor.constraint(equalToConstant: 46),
            compactColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            compactColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            compactColumn.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            wideRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            wideRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            wideRow.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: contentView.layer.cornerRadius).cgPath
    }

    func apply(number: Int, wide: Bool, unlocked: Bool, stars earned: Int, detail: String, preparing: Bool) {
        compactColumn.isHidden = wide
        wideRow.isHidden = !wide
        eyebrow.text = "Niveau"
        numberLabel.text = preparing ? "…" : "\(number)"
        compactDetail.text = detail
        wideDetail.text = detail
        contentView.backgroundColor = wide ? UIColor(hex: 0xF3E8FF) : UIColor(hex: 0xF7F4FF)
        contentView.layer.cornerRadius = wide ? 24 : 22
        contentView.alpha = unlocked ? 1 : 0.55
        paint(compactStars, earned: earned)
        paint(wideStars, earned: earned)
        let title = wide ? "Niveau final" : "Niveau \(number)"
        accessibilityLabel = "\(title). \(detail). \(PlayerCopy.starCount(earned))"
        isAccessibilityElement = true
    }

    private func styleCaption(_ label: UILabel, text: String, size: CGFloat, color: UIColor) {
        label.text = text
        label.font = AppTheme.font(size, .bold, textStyle: .caption1)
        label.textColor = color
        label.textAlignment = .center
        label.adjustsFontForContentSizeCategory = true
    }

    private func fill(_ stack: UIStackView, side: CGFloat) {
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        for _ in 0..<3 {
            let image = UIImageView(image: GameArt.victoryStar(earned: false))
            image.contentMode = .scaleAspectFit
            image.translatesAutoresizingMaskIntoConstraints = false
            image.widthAnchor.constraint(equalToConstant: side).isActive = true
            image.heightAnchor.constraint(equalToConstant: side * 0.92).isActive = true
            stack.addArrangedSubview(image)
        }
    }

    private func paint(_ stack: UIStackView, earned: Int) {
        for (index, view) in stack.arrangedSubviews.enumerated() {
            (view as? UIImageView)?.image = GameArt.victoryStar(earned: index < earned)
        }
    }
}
