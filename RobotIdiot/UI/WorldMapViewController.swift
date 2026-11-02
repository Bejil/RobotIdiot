import UIKit
import RobotIdiotCore

final class WorldMapViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var unlockedWorld = 1
    private var progress = CampaignProgress(campaignSeed: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = "Campagne"
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        progress = CampaignStore.shared.progress()
        unlockedWorld = CampaignRules.unlockedWorld(in: progress)
        reloadCards()
    }

    private func reloadCards() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        for world in 1...(unlockedWorld + 1) {
            let blueprint = WorldGenerator.blueprint(campaignSeed: progress.campaignSeed, world: world)
            let locked = world > unlockedWorld
            let stars = CampaignRules.stars(inWorld: world, progress: progress)
            let maximum = CampaignLayout.standard.levelCount * 3
            let detail = locked
                ? "Termine le monde précédent."
                : "\(PlayerCopy.themeName(blueprint.theme)) · \(PlayerCopy.mechanicTitle(blueprint.families))\n\(stars) / \(maximum) étoiles"
            let card = WorldCardControl(
                world: world,
                badge: GameArt.worldBadge(blueprint.theme),
                title: PlayerCopy.worldTitle(world),
                detail: detail,
                locked: locked
            )
            card.addTarget(self, action: #selector(openWorld(_:)), for: .touchUpInside)
            stack.addArrangedSubview(card)
        }
    }

    @objc private func openWorld(_ sender: WorldCardControl) {
        guard sender.world <= unlockedWorld else { return }
        navigationController?.pushViewController(WorldLevelsViewController(world: sender.world), animated: true)
    }
}

private final class WorldCardControl: UIControl {
    let world: Int

    init(world: Int, badge: UIImage, title: String, detail: String, locked: Bool) {
        self.world = world
        super.init(frame: .zero)
        backgroundColor = AppTheme.card
        layer.cornerRadius = 26
        layer.borderWidth = 3
        layer.borderColor = (locked ? AppTheme.border : AppTheme.line).cgColor
        isEnabled = !locked
        alpha = locked ? 0.55 : 1

        let imageView = UIImageView(image: badge)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.font(22, .heavy, textStyle: .title3)
        titleLabel.textColor = locked ? AppTheme.inkSoft : AppTheme.ink
        titleLabel.adjustsFontForContentSizeCategory = true

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = AppTheme.font(14, .semibold, textStyle: .subheadline)
        detailLabel.textColor = AppTheme.inkSoft
        detailLabel.numberOfLines = 2
        detailLabel.adjustsFontForContentSizeCategory = true

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2
        text.isUserInteractionEnabled = false

        let row = UIStackView(arrangedSubviews: [imageView, text])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 72),
            imageView.heightAnchor.constraint(equalToConstant: 72),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 96)
        ])
        accessibilityLabel = locked ? "\(title), verrouillé" : "\(title). \(detail)"
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isHighlighted: Bool {
        didSet {
            transform = isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
}

final class WorldLevelsViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    let worldNumber: Int
    private let collectionView: UICollectionView
    private var progress = CampaignProgress(campaignSeed: 1)
    private var blueprint: WorldBlueprint?
    private var preparing: LevelAddress?

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
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        collectionView.backgroundColor = AppTheme.cream
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LevelTileCell.self, forCellWithReuseIdentifier: "level")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: guide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        reload()
        warmAhead()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let columns: CGFloat = collectionView.bounds.width > 700 ? 5 : 3
        let inset = layout.sectionInset.left + layout.sectionInset.right
        let spacing = layout.minimumInteritemSpacing * (columns - 1)
        let width = floor((collectionView.bounds.width - inset - spacing) / columns)
        let size = CGSize(width: width, height: width * 1.18)
        if layout.itemSize != size {
            layout.itemSize = size
            layout.invalidateLayout()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        CampaignLayout.standard.levelCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "level", for: indexPath) as! LevelTileCell
        let level = indexPath.row + 1
        let address = LevelAddress(world: worldNumber, level: level)
        let unlocked = CampaignRules.isLevelUnlocked(address, progress: progress)
        let finale = CampaignLayout.standard.isFinale(level)
        let stars = progress.score(at: address)?.stars ?? 0
        let caption: String
        if preparing == address {
            caption = "Préparation…"
        } else if unlocked {
            caption = PlayerCopy.paceTitle(blueprint?.slots[indexPath.row].pace ?? .accessible)
        } else {
            caption = "Verrouillé"
        }
        cell.apply(number: level, finale: finale, unlocked: unlocked, stars: stars, caption: caption)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        Soundscape.shared.play("select")
        let address = LevelAddress(world: worldNumber, level: indexPath.row + 1)
        guard CampaignRules.isLevelUnlocked(address, progress: progress), preparing == nil else { return }
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
        blueprint = WorldGenerator.blueprint(campaignSeed: progress.campaignSeed, world: worldNumber)
        navigationItem.title = PlayerCopy.worldTitle(worldNumber)
        collectionView.reloadData()
    }

    private func warmAhead() {
        let address = CampaignRules.continueAddress(in: progress)
        guard address.world == worldNumber else { return }
        CampaignStore.shared.warm(address)
        let following = CampaignRules.nextAddress(after: address)
        if following.world == worldNumber {
            CampaignStore.shared.warm(following)
        }
    }

    private func open(_ level: Level, address: LevelAddress) {
        let following = CampaignRules.nextAddress(after: address)
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
    private let numberLabel = UILabel()
    private let captionLabel = UILabel()
    private let stars = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = AppTheme.card
        contentView.layer.cornerRadius = 22
        contentView.layer.borderWidth = 3
        contentView.layer.borderColor = AppTheme.border.cgColor

        numberLabel.font = AppTheme.font(32, .heavy, textStyle: .title1)
        numberLabel.textAlignment = .center
        numberLabel.adjustsFontForContentSizeCategory = true

        captionLabel.font = AppTheme.font(12, .bold, textStyle: .caption2)
        captionLabel.textAlignment = .center
        captionLabel.numberOfLines = 2
        captionLabel.adjustsFontForContentSizeCategory = true

        stars.axis = .horizontal
        stars.distribution = .fillEqually
        stars.spacing = 2
        for _ in 0..<3 {
            let image = UIImageView(image: GameArt.star(filled: false))
            image.contentMode = .scaleAspectFit
            stars.addArrangedSubview(image)
        }

        let column = UIStackView(arrangedSubviews: [numberLabel, stars, captionLabel])
        column.axis = .vertical
        column.spacing = 4
        column.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            column.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            column.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stars.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(number: Int, finale: Bool, unlocked: Bool, stars earned: Int, caption: String) {
        numberLabel.text = finale ? "★" : "\(number)"
        numberLabel.textColor = unlocked ? (finale ? AppTheme.line : AppTheme.ink) : AppTheme.inkSoft
        captionLabel.text = caption
        captionLabel.textColor = unlocked ? AppTheme.inkSoft : AppTheme.inkSoft
        contentView.backgroundColor = finale && unlocked ? AppTheme.gold : AppTheme.card
        contentView.layer.borderColor = (finale && unlocked ? AppTheme.line : AppTheme.border).cgColor
        contentView.alpha = unlocked ? 1 : 0.55
        for (index, view) in stars.arrangedSubviews.enumerated() {
            (view as? UIImageView)?.image = GameArt.star(filled: index < earned)
        }
        let title = finale ? "Niveau final" : "Niveau \(number)"
        accessibilityLabel = unlocked ? "\(title), \(PlayerCopy.starCount(earned))" : "\(title), verrouillé"
        isAccessibilityElement = true
    }
}
