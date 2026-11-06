import UIKit
import SpriteKit
import RobotIdiotCore

final class GameViewController: UIViewController {
    private let level: Level
    private let campaign: LevelAddress?
    private let daily: DailyPlayContext?
    private var engine: SimulationEngine
    private let boardScene: BoardScene

    private let skView = SKView()
    private let boardSlot = UIView()
    private let boardFrame = UIView()
    private let worldTitleLabel = UILabel()
    private let levelTitleLabel = UILabel()
    private let editor = BlockEditorView()
    private let statusLabel = UILabel()
    private let sheet = UIView()
    private let sheetGrabber = UIView()
    private let sheetHandle = UIView()
    private let chromeRow = UIStackView()
    private let chromeLeftCluster = UIStackView()
    private let chromeSpacer = UIView()
    private let boltBadge = UIView()
    private let boltRow = UIStackView()
    private let boltIconView = UIImageView()
    private let boltCountLabel = UILabel()
    private var displayedBoltCount = 0
    private let helpButton = UIButton(type: .system)
    private let clearProgramButton = UIButton(type: .system)
    private let speedToggle = UIButton(type: .system)
    private let overlay = ResultOverlayView()
    private let errorAlert = ExecutionAlertView()
    private let commandIntro = CommandIntroAlertView()
    private let helpAlert = HelpAlertView()

    private let runButton = AppTheme.filledButton(title: "Exécuter", systemImage: "play.fill", prominent: true)

    private var tempo: PlaybackTempo
    private var isOpeningNext = false
    private var playbackToken = 0
    private var wantsContinuous = false
    private var isAnimating = false
    private var layoutConstraints: [NSLayoutConstraint] = []
    private var sheetHeightConstraint: NSLayoutConstraint?
    private var sheetHeight: CGFloat = 0
    private var sheetDragStartHeight: CGFloat = 0
    private var hasLaidOutSheet = false
    private var usesSideBySideLayout = false
    private var lastSideBySideSplit: (leftTrailing: CGFloat, rightLeading: CGFloat)?
    private var bonusRemainingCount = 0
    private var backdrop: AmbientBackdropView!

    init(level: Level, campaign: LevelAddress? = nil, daily: DailyPlayContext? = nil) {
        let keepNative = level.id.hasPrefix("RI-") || level.id.hasPrefix("DAILY-")
        let framed = keepNative ? level : LevelFraming.playfield(level)
        self.level = framed
        self.campaign = campaign
        self.daily = daily
        self.tempo = PlaySettings.fastAnimation ? .fast : .normal
        engine = SimulationEngine(level: framed, program: Program())
        boardScene = BoardScene(level: framed, contrast: PlaySettings.contrast)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        backdrop = AmbientBackdropView.install(in: view)
        navigationItem.backButtonDisplayMode = .minimal
        installBarButtons()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: PlaySettings.changed, object: nil)

        configureStatus()
        configureBoard()
        configureLevelHeaders()
        configureTransport()
        configureEditor()
        configureOverlay()
        configureErrorAlert()
        installSubviews()
        applyLayout()
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (controller: Self, _) in
            controller.applyLayout()
        }

        boardScene.show(engine.state.game)
        skView.presentScene(boardScene)
        bonusRemainingCount = level.collectibles.count
        updateStatusIdle()
        updateControls()
        refreshBoltBadge()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let navigation = navigationController {
            AppTheme.apply(to: navigation)
            navigation.navigationBar.tintColor = .white
        }
        backdrop.start()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentCommandIntroIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
        navigationController?.navigationBar.tintColor = AppTheme.gold
        playbackToken += 1
        wantsContinuous = false
        boardScene.cancelPlayback()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func configureStatus() {
        statusLabel.font = AppTheme.font(15, .semibold, textStyle: .subheadline)
        statusLabel.textColor = AppTheme.ink
        statusLabel.numberOfLines = 0
        statusLabel.adjustsFontForContentSizeCategory = true

        statusLabel.isHidden = true
    }

    private func configureBoard() {
        boardFrame.backgroundColor = UIColor(hex: 0x3EAE4C)
        boardFrame.layer.cornerRadius = 12
        boardFrame.layer.cornerCurve = .continuous
        boardFrame.layer.borderWidth = 0
        boardFrame.clipsToBounds = true
        skView.allowsTransparency = false
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.isAccessibilityElement = true
        skView.translatesAutoresizingMaskIntoConstraints = false
        boardFrame.addSubview(skView)
        NSLayoutConstraint.activate([
            skView.topAnchor.constraint(equalTo: boardFrame.topAnchor),
            skView.leadingAnchor.constraint(equalTo: boardFrame.leadingAnchor),
            skView.trailingAnchor.constraint(equalTo: boardFrame.trailingAnchor),
            skView.bottomAnchor.constraint(equalTo: boardFrame.bottomAnchor)
        ])
    }

    private func configureLevelHeaders() {
        let world: Int
        let levelNumber: Int
        let finale: Bool
        if let campaign {
            world = campaign.world
            levelNumber = campaign.level
            finale = CatalogCampaign.layout.isFinale(campaign.level)
        } else {
            world = level.worldNumber
            levelNumber = level.levelNumber
            finale = false
        }

        navigationItem.title = finale
            ? "Monde \(world) / Niveau final"
            : "Monde \(world) / Niveau \(levelNumber)"

        worldTitleLabel.isHidden = true
        worldTitleLabel.isAccessibilityElement = false

        // Sous le titre nav : consignes / limites (ex-label à gauche d'Aide).
        if let daily, daily.kind == .bug, let instructions = daily.instructions, !instructions.isEmpty {
            levelTitleLabel.text = instructions
        } else if let daily {
            levelTitleLabel.text = daily.titleOverride
        } else {
            levelTitleLabel.text = PlayerCopy.limits(for: level)
        }
        levelTitleLabel.font = AppTheme.font(15, .semibold, textStyle: .subheadline)
        levelTitleLabel.textColor = AppTheme.inkSoft
        levelTitleLabel.textAlignment = .left
        levelTitleLabel.adjustsFontForContentSizeCategory = true
        levelTitleLabel.adjustsFontSizeToFitWidth = true
        levelTitleLabel.minimumScaleFactor = 0.8
        levelTitleLabel.numberOfLines = 2
    }

    private func configureTransport() {
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)
        runButton.accessibilityHint = "Lance le programme du robot"

        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 28
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.layer.masksToBounds = true

        sheetGrabber.backgroundColor = .clear
        sheetGrabber.isUserInteractionEnabled = true
        sheetGrabber.accessibilityLabel = "Agrandir le panneau des commandes"
        sheetGrabber.accessibilityTraits = .adjustable
        sheetHandle.backgroundColor = UIColor(hex: 0xC8C4D8)
        sheetHandle.layer.cornerRadius = 2.5
        sheetHandle.isUserInteractionEnabled = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragSheet(_:)))
        pan.cancelsTouchesInView = false
        sheetGrabber.addGestureRecognizer(pan)

        speedToggle.backgroundColor = .white
        speedToggle.setTitleColor(.black, for: .normal)
        speedToggle.titleLabel?.font = AppTheme.font(18, .heavy, textStyle: .headline)
        speedToggle.layer.cornerRadius = 16
        speedToggle.layer.borderWidth = 2
        speedToggle.layer.borderColor = UIColor.black.cgColor
        speedToggle.addTarget(self, action: #selector(toggleSpeed), for: .touchUpInside)
        speedToggle.accessibilityLabel = "Vitesse d'animation"
        refreshSpeedToggle()

        boltBadge.backgroundColor = UIColor(hex: 0x1A1440)
        boltBadge.layer.cornerRadius = 16
        boltBadge.layer.cornerCurve = .continuous
        boltBadge.layer.borderWidth = 1.5
        boltBadge.layer.borderColor = AppTheme.gold.cgColor
        boltBadge.isAccessibilityElement = true

        boltRow.axis = .horizontal
        boltRow.alignment = .center
        boltRow.spacing = 5
        boltRow.isUserInteractionEnabled = false
        boltRow.translatesAutoresizingMaskIntoConstraints = false
        boltBadge.addSubview(boltRow)

        boltIconView.image = GameArt.piece(.bolt)
        boltIconView.contentMode = .scaleAspectFit
        boltCountLabel.font = AppTheme.font(16, .heavy, textStyle: .headline)
        boltCountLabel.textColor = AppTheme.gold
        boltCountLabel.adjustsFontForContentSizeCategory = true
        boltRow.addArrangedSubview(boltIconView)
        boltRow.addArrangedSubview(boltCountLabel)
        NSLayoutConstraint.activate([
            boltRow.topAnchor.constraint(equalTo: boltBadge.topAnchor, constant: 5),
            boltRow.bottomAnchor.constraint(equalTo: boltBadge.bottomAnchor, constant: -5),
            boltRow.leadingAnchor.constraint(equalTo: boltBadge.leadingAnchor, constant: 8),
            boltRow.trailingAnchor.constraint(equalTo: boltBadge.trailingAnchor, constant: -10),
            boltIconView.widthAnchor.constraint(equalToConstant: 18),
            boltIconView.heightAnchor.constraint(equalToConstant: 18),
            boltBadge.heightAnchor.constraint(equalToConstant: 32)
        ])
        refreshBoltBadge()

        var helpConfiguration = UIButton.Configuration.filled()
        helpConfiguration.title = "Aide"
        helpConfiguration.image = UIImage(systemName: "questionmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        helpConfiguration.imagePadding = 5
        helpConfiguration.baseBackgroundColor = AppTheme.gold
        helpConfiguration.baseForegroundColor = .black
        helpConfiguration.cornerStyle = .capsule
        helpConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        helpConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(14, .heavy, textStyle: .headline)
            return updated
        }
        helpButton.configuration = helpConfiguration
        helpButton.accessibilityLabel = "Aide"
        helpButton.addTarget(self, action: #selector(showHelp), for: .touchUpInside)

        var clearConfiguration = UIButton.Configuration.filled()
        clearConfiguration.title = "Effacer"
        clearConfiguration.image = UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
        clearConfiguration.imagePadding = 5
        clearConfiguration.baseBackgroundColor = UIColor(hex: 0xE03131)
        clearConfiguration.baseForegroundColor = .white
        clearConfiguration.cornerStyle = .capsule
        clearConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        clearConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(14, .heavy, textStyle: .headline)
            return updated
        }
        clearProgramButton.configuration = clearConfiguration
        clearProgramButton.accessibilityLabel = "Effacer toutes les commandes"
        clearProgramButton.addTarget(self, action: #selector(clearAllCommands), for: .touchUpInside)

        boltBadge.setContentHuggingPriority(.required, for: .horizontal)
        boltBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        helpButton.setContentHuggingPriority(.required, for: .horizontal)
        helpButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        clearProgramButton.setContentHuggingPriority(.required, for: .horizontal)
        clearProgramButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        chromeLeftCluster.setContentHuggingPriority(.required, for: .horizontal)
        chromeLeftCluster.setContentCompressionResistancePriority(.required, for: .horizontal)
        chromeSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        chromeSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chromeSpacer.isUserInteractionEnabled = false

        chromeLeftCluster.axis = .horizontal
        chromeLeftCluster.alignment = .center
        chromeLeftCluster.spacing = 8
        chromeLeftCluster.addArrangedSubview(boltBadge)
        chromeLeftCluster.addArrangedSubview(helpButton)

        chromeRow.axis = .horizontal
        chromeRow.alignment = .center
        chromeRow.spacing = 8
        chromeRow.addArrangedSubview(chromeLeftCluster)
        chromeRow.addArrangedSubview(chromeSpacer)
        chromeRow.addArrangedSubview(clearProgramButton)
    }

    private func configureEditor() {
        editor.setAllowedCommands(level.allowedCommands)
        editor.setProgramLimit(level.programConstraints)
        if let daily, daily.kind == .bug, let baseline = daily.baselineProgram {
            editor.enableSinglePrimitiveReplace(baseline: baseline)
        } else if let campaign, let saved = CampaignStore.shared.program(at: campaign) {
            editor.replaceProgram(saved)
        }
        editor.onProgramChange = { [weak self] program in
            guard let self else { return }
            if let campaign = self.campaign {
                CampaignStore.shared.save(program, at: campaign)
            }
            // Pendant l'édition au repos, ne pas resetter le plateau :
            // ça coupait et relançait l'animation idle du robot.
            if self.isAnimating || self.wantsContinuous {
                self.restoreRobot()
                return
            }
            self.engine.reset(program: program)
            self.editor.clearHighlight()
            self.editor.setErrorMessage(nil)
            self.updateControls()
        }
    }

    private func configureOverlay() {
        overlay.isHidden = true
        overlay.onRetry = { [weak self] in
            self?.navigationController?.setNavigationBarHidden(false, animated: true)
            self?.overlay.isHidden = true
            self?.restoreRobot()
        }
        overlay.onExit = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        overlay.onNext = { [weak self] in
            guard let self else { return }
            AdsService.shared.showLevelSuccessInterstitial(from: self) {
                self.openNextLevel()
            }
        }
    }

    private func configureErrorAlert() {
        errorAlert.isHidden = true
        errorAlert.onEdit = { [weak self] in
            guard let self else { return }
            AdsService.shared.showErrorInterstitial(from: self) {
                self.errorAlert.isHidden = true
            }
        }
        commandIntro.isHidden = true
        commandIntro.onFinished = { [weak self] in
            self?.commandIntro.isHidden = true
        }
        helpAlert.isHidden = true
        helpAlert.onClose = { [weak self] in
            self?.helpAlert.isHidden = true
        }
    }

    private func installSubviews() {
        [boardSlot, boardFrame, worldTitleLabel, levelTitleLabel, sheet, sheetGrabber, sheetHandle, chromeRow, editor, runButton, speedToggle, overlay, errorAlert, commandIntro, helpAlert].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        boardSlot.isUserInteractionEnabled = false
        view.addSubview(boardSlot)
        view.addSubview(boardFrame)
        view.addSubview(worldTitleLabel)
        view.addSubview(levelTitleLabel)
        view.addSubview(sheet)
        view.addSubview(sheetGrabber)
        sheetGrabber.addSubview(sheetHandle)
        view.addSubview(chromeRow)
        view.addSubview(editor)
        view.addSubview(runButton)
        view.addSubview(speedToggle)
        view.addSubview(overlay)
        view.addSubview(errorAlert)
        view.addSubview(commandIntro)
        view.addSubview(helpAlert)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorAlert.topAnchor.constraint(equalTo: view.topAnchor),
            errorAlert.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorAlert.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorAlert.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            commandIntro.topAnchor.constraint(equalTo: view.topAnchor),
            commandIntro.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commandIntro.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            commandIntro.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            helpAlert.topAnchor.constraint(equalTo: view.topAnchor),
            helpAlert.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            helpAlert.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            helpAlert.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.bounds.height > 1 else { return }
        let sideBySide = shouldUseSideBySideLayout()
        let splitChanged: Bool = {
            guard sideBySide else { return false }
            let split = sideBySideSplitX()
            guard let last = lastSideBySideSplit else { return true }
            return abs(last.leftTrailing - split.leftTrailing) > 0.5
                || abs(last.rightLeading - split.rightLeading) > 0.5
        }()
        if sideBySide != usesSideBySideLayout || splitChanged {
            applyLayout()
        } else if !usesSideBySideLayout {
            if !hasLaidOutSheet {
                hasLaidOutSheet = true
                sheetHeight = collapsedSheetHeightBaseline()
            }
            let clamped = clampSheetHeight(sheetHeight)
            sheetHeight = clamped
            if let constraint = sheetHeightConstraint, abs(constraint.constant - clamped) > 0.5 {
                constraint.constant = clamped
            }
        }
        // Espace sous le fond gris : petit écart + boutons + marge basse + home indicator.
        // (Le stack ajoute déjà 8 pt au-dessus du spacer.)
        editor.reserveBottomActions(height: 52 + 8 + 6 + view.safeAreaInsets.bottom)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.applyLayout()
        })
    }

    private struct VerticalFold {
        let frame: CGRect
        let isActive: Bool
    }

    /// Duo (charnière verticale) ou écran assez large → un panneau par moitié.
    private func shouldUseSideBySideLayout() -> Bool {
        let size = view.bounds.size
        guard size.width > 1, size.height > 1 else { return false }
        // Duo (charnière verticale) : toujours un panneau par écran.
        if verticalFold() != nil { return true }
        // iPad / iPhone portrait : même UI empilée que sur iPhone.
        if size.height >= size.width { return false }
        // Paysage assez large : plateau | commandes.
        return size.width >= 600
    }

    /// Charnière verticale (pli livre). Inclut la région inactive (Duo à plat, largeur 0).
    private func verticalFold() -> VerticalFold? {
        guard #available(iOS 27.1, *) else { return nil }
        let regions = view.reservedRegions(kind: .division, options: .includeInactive)
        guard let region = regions.first(where: { region in
            // Pli livre : bande verticale (plus haute que large, ou très étroite / nulle à plat).
            region.frame.height >= region.frame.width || region.frame.width <= 48
        }) else { return nil }
        return VerticalFold(frame: region.frame, isActive: region.isActive)
    }

    /// Fin de la moitié gauche (plateau) / début de la moitié droite (commandes), calés sur la charnière.
    private func sideBySideSplitX() -> (leftTrailing: CGFloat, rightLeading: CGFloat) {
        let width = view.bounds.width
        let gap: CGFloat = 12
        if let fold = verticalFold() {
            // Toujours respecter le pli (actif ou non) : un contenu par écran, rien sur la charnière.
            let left = max(fold.frame.minX - gap, 200)
            let right = min(fold.frame.maxX + gap, width - 200)
            if right > left { return (left, right) }
        }
        // iPad / large sans charnière : moitié exacte de la vue.
        let mid = width * 0.5
        return (mid - gap, mid + gap)
    }

    private func boardHeaderConstraints(
        topAnchor: NSLayoutYAxisAnchor,
        leadingAnchor: NSLayoutXAxisAnchor,
        trailingAnchor: NSLayoutXAxisAnchor,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        topInset: CGFloat = 10
    ) -> [NSLayoutConstraint] {
        [
            // worldTitleLabel masqué : le titre vit dans la navigation bar.
            worldTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            worldTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            worldTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: trailingInset),
            worldTitleLabel.heightAnchor.constraint(equalToConstant: 0),

            levelTitleLabel.topAnchor.constraint(equalTo: topAnchor, constant: topInset),
            levelTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            levelTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: trailingInset)
        ]
    }

    private func applyLayout() {
        NSLayoutConstraint.deactivate(layoutConstraints)
        usesSideBySideLayout = shouldUseSideBySideLayout()
        if usesSideBySideLayout {
            lastSideBySideSplit = sideBySideSplitX()
            applySideBySideLayout()
        } else {
            lastSideBySideSplit = nil
            applyStackedLayout()
        }
        editor.reserveBottomActions(height: 52 + 8 + 6 + view.safeAreaInsets.bottom)
        bringGameChromeToFront()
    }

    private func applyStackedLayout() {
        let guide = view.safeAreaLayoutGuide
        let initialHeight = sheetHeight > 1 ? sheetHeight : max(300, view.bounds.height * 0.46)
        sheetHeight = initialHeight
        let height = sheet.heightAnchor.constraint(equalToConstant: initialHeight)
        sheetHeightConstraint = height

        sheet.layer.cornerRadius = 28
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetGrabber.isHidden = false
        sheetHandle.isHidden = false
        sheetGrabber.isUserInteractionEnabled = true

        worldTitleLabel.textAlignment = .center
        levelTitleLabel.textAlignment = .center
        levelTitleLabel.isHidden = false

        layoutConstraints = boardHeaderConstraints(
            topAnchor: guide.topAnchor,
            leadingAnchor: guide.leadingAnchor,
            trailingAnchor: guide.trailingAnchor,
            leadingInset: 20,
            trailingInset: -20,
            topInset: 4
        ) + [
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,

            boardSlot.topAnchor.constraint(equalTo: levelTitleLabel.bottomAnchor, constant: 8),
            boardSlot.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            boardSlot.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -14),
            boardSlot.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -10),

            boardFrame.centerXAnchor.constraint(equalTo: boardSlot.centerXAnchor),
            boardFrame.centerYAnchor.constraint(equalTo: boardSlot.centerYAnchor),
            boardFrame.widthAnchor.constraint(equalTo: boardFrame.heightAnchor),
            boardFrame.widthAnchor.constraint(lessThanOrEqualTo: boardSlot.widthAnchor),
            boardFrame.heightAnchor.constraint(lessThanOrEqualTo: boardSlot.heightAnchor),
            boardFrame.widthAnchor.constraint(equalTo: boardSlot.widthAnchor).prioritized(UILayoutPriority(750)),
            boardFrame.heightAnchor.constraint(equalTo: boardSlot.heightAnchor).prioritized(UILayoutPriority(750)),

            sheetGrabber.topAnchor.constraint(equalTo: sheet.topAnchor),
            sheetGrabber.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            sheetGrabber.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            sheetGrabber.heightAnchor.constraint(equalToConstant: 18),

            sheetHandle.centerXAnchor.constraint(equalTo: sheetGrabber.centerXAnchor),
            sheetHandle.centerYAnchor.constraint(equalTo: sheetGrabber.centerYAnchor),
            sheetHandle.widthAnchor.constraint(equalToConstant: 40),
            sheetHandle.heightAnchor.constraint(equalToConstant: 4),

            chromeRow.topAnchor.constraint(equalTo: sheetGrabber.bottomAnchor, constant: 2),
            chromeRow.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            chromeRow.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            chromeRow.heightAnchor.constraint(equalToConstant: 32),
            helpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
            helpButton.heightAnchor.constraint(equalToConstant: 32),
            clearProgramButton.heightAnchor.constraint(equalToConstant: 32),
            clearProgramButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),

            editor.topAnchor.constraint(equalTo: chromeRow.bottomAnchor, constant: 14),
            editor.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 10),
            editor.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -10),
            editor.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Sous la liste du programme (à droite de la palette), pas sous toute la largeur.
            runButton.leadingAnchor.constraint(
                equalTo: editor.leadingAnchor,
                constant: BlockEditorView.paletteLaneWidth
            ),
            runButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            runButton.heightAnchor.constraint(equalToConstant: 52),

            speedToggle.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: 8),
            speedToggle.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
            speedToggle.centerYAnchor.constraint(equalTo: runButton.centerYAnchor),
            speedToggle.widthAnchor.constraint(equalToConstant: 72),
            speedToggle.heightAnchor.constraint(equalTo: runButton.heightAnchor)
        ]
        NSLayoutConstraint.activate(layoutConstraints)
    }

    private func applySideBySideLayout() {
        let guide = view.safeAreaLayoutGuide
        sheetHeightConstraint = nil

        sheet.layer.cornerRadius = 24
        sheet.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        sheetGrabber.isHidden = true
        sheetHandle.isHidden = true
        sheetGrabber.isUserInteractionEnabled = false

        let split = sideBySideSplitX()
        let leftPad: CGFloat = 24
        let bottomPad: CGFloat = 28
        worldTitleLabel.textAlignment = .left
        levelTitleLabel.textAlignment = .left
        levelTitleLabel.isHidden = false

        // Gauche = plateau (+ sous-titre) ; droite = commandes. Ancré sur view pour coller à la charnière.
        layoutConstraints = [
            worldTitleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            worldTitleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: leftPad),
            worldTitleLabel.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: split.leftTrailing - 16),
            worldTitleLabel.heightAnchor.constraint(equalToConstant: 0),

            levelTitleLabel.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            levelTitleLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: leftPad),
            levelTitleLabel.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: split.leftTrailing - 16),

            boardSlot.topAnchor.constraint(equalTo: levelTitleLabel.bottomAnchor, constant: 10),
            boardSlot.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: leftPad),
            boardSlot.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: split.leftTrailing - 8),
            boardSlot.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomPad),

            boardFrame.centerXAnchor.constraint(equalTo: boardSlot.centerXAnchor),
            boardFrame.centerYAnchor.constraint(equalTo: boardSlot.centerYAnchor),
            boardFrame.widthAnchor.constraint(equalTo: boardFrame.heightAnchor),
            boardFrame.widthAnchor.constraint(lessThanOrEqualTo: boardSlot.widthAnchor),
            boardFrame.heightAnchor.constraint(lessThanOrEqualTo: boardSlot.heightAnchor),
            boardFrame.widthAnchor.constraint(equalTo: boardSlot.widthAnchor).prioritized(UILayoutPriority(750)),
            boardFrame.heightAnchor.constraint(equalTo: boardSlot.heightAnchor).prioritized(UILayoutPriority(750)),
            boardFrame.leadingAnchor.constraint(greaterThanOrEqualTo: boardSlot.leadingAnchor),
            boardFrame.trailingAnchor.constraint(lessThanOrEqualTo: boardSlot.trailingAnchor),

            sheet.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: split.rightLeading),
            sheet.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            sheet.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -bottomPad),

            // Grabber conservé dans la hiérarchie mais masqué : contraintes minimales.
            sheetGrabber.topAnchor.constraint(equalTo: sheet.topAnchor),
            sheetGrabber.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            sheetGrabber.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            sheetGrabber.heightAnchor.constraint(equalToConstant: 0),
            sheetHandle.centerXAnchor.constraint(equalTo: sheetGrabber.centerXAnchor),
            sheetHandle.centerYAnchor.constraint(equalTo: sheetGrabber.centerYAnchor),
            sheetHandle.widthAnchor.constraint(equalToConstant: 44),
            sheetHandle.heightAnchor.constraint(equalToConstant: 5),

            chromeRow.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 8),
            chromeRow.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 10),
            chromeRow.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -10),
            chromeRow.heightAnchor.constraint(equalToConstant: 32),
            helpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 84),
            helpButton.heightAnchor.constraint(equalToConstant: 32),
            clearProgramButton.heightAnchor.constraint(equalToConstant: 32),
            clearProgramButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),

            editor.topAnchor.constraint(equalTo: chromeRow.bottomAnchor, constant: 14),
            editor.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 8),
            editor.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -8),
            editor.bottomAnchor.constraint(equalTo: sheet.bottomAnchor),

            runButton.leadingAnchor.constraint(
                equalTo: editor.leadingAnchor,
                constant: BlockEditorView.paletteLaneWidth
            ),
            runButton.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -max(14, view.safeAreaInsets.bottom + 6)),
            runButton.heightAnchor.constraint(equalToConstant: 52),

            speedToggle.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: 8),
            speedToggle.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
            speedToggle.centerYAnchor.constraint(equalTo: runButton.centerYAnchor),
            speedToggle.widthAnchor.constraint(equalToConstant: 72),
            speedToggle.heightAnchor.constraint(equalTo: runButton.heightAnchor)
        ]
        NSLayoutConstraint.activate(layoutConstraints)
    }

    private func bringGameChromeToFront() {
        view.bringSubviewToFront(worldTitleLabel)
        view.bringSubviewToFront(levelTitleLabel)
        view.bringSubviewToFront(sheet)
        view.bringSubviewToFront(sheetGrabber)
        view.bringSubviewToFront(chromeRow)
        view.bringSubviewToFront(editor)
        view.bringSubviewToFront(runButton)
        view.bringSubviewToFront(speedToggle)
        view.bringSubviewToFront(overlay)
        view.bringSubviewToFront(errorAlert)
        view.bringSubviewToFront(commandIntro)
        view.bringSubviewToFront(helpAlert)
    }

    private func maxSheetHeight() -> CGFloat {
        view.bounds.height * (2.0 / 3.0)
    }

    private func collapsedSheetHeightBaseline() -> CGFloat {
        let guide = view.safeAreaLayoutGuide.layoutFrame
        let width = max(guide.width - 24, 120)
        let preferredBoard = min(width, view.bounds.height * 0.42)
        return view.bounds.height - guide.minY - 4 - preferredBoard - 12
    }

    private func clampSheetHeight(_ value: CGFloat) -> CGFloat {
        let maximum = maxSheetHeight()
        let minimum = min(max(collapsedSheetHeightBaseline(), 240), maximum)
        return min(maximum, max(minimum, value))
    }

    private func applySheetHeight(_ height: CGFloat, animated: Bool) {
        sheetHeight = height
        sheetHeightConstraint?.constant = height
        guard animated else {
            view.layoutIfNeeded()
            return
        }
        UIView.animate(
            withDuration: PlaySettings.prefersReducedMotion ? 0.12 : 0.28,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func dragSheet(_ gesture: UIPanGestureRecognizer) {
        guard !usesSideBySideLayout else { return }
        switch gesture.state {
        case .began:
            sheetDragStartHeight = sheetHeight
            Soundscape.shared.play("ui")
        case .changed:
            let translation = gesture.translation(in: view).y
            // Tirage vers le haut → panneau plus haut → plateau plus petit.
            applySheetHeight(clampSheetHeight(sheetDragStartHeight - translation), animated: false)
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).y
            let collapsed = clampSheetHeight(collapsedSheetHeightBaseline())
            let expanded = maxSheetHeight()
            let mid = (collapsed + expanded) * 0.5
            let target: CGFloat
            if velocity < -650 {
                target = expanded
            } else if velocity > 650 {
                target = collapsed
            } else {
                target = sheetHeight > mid ? expanded : collapsed
            }
            applySheetHeight(target, animated: true)
        default:
            break
        }
    }

    private func refreshSpeedToggle() {
        let title = tempo == .fast ? "x2" : "x1"
        speedToggle.setTitle(title, for: .normal)
        speedToggle.accessibilityValue = title
    }

    @objc private func showHelp() {
        helpAlert.host = self
        helpAlert.onBalanceChanged = { [weak self] in
            self?.refreshBoltBadge(animated: true)
        }
        helpAlert.present(level: level)
        helpAlert.isHidden = false
        view.bringSubviewToFront(helpAlert)
    }

    @objc private func clearAllCommands() {
        editor.requestClearProgram()
        refreshClearProgramButton()
    }

    private func refreshClearProgramButton() {
        let enabled = editor.canClearProgram
        clearProgramButton.isEnabled = enabled
        clearProgramButton.alpha = enabled ? 1 : 0.45
    }

    @objc private func toggleSpeed() {
        tempo = tempo.toggled
        PlaySettings.fastAnimation = tempo == .fast
        refreshSpeedToggle()
    }

    @objc private func settingsChanged() {
        let desired: PlaybackTempo = PlaySettings.fastAnimation ? .fast : .normal
        if tempo != desired {
            tempo = desired
            refreshSpeedToggle()
        }
        boardScene.applyMotionPreference()
    }

    private func presentCommandIntroIfNeeded() {
        guard presentedViewController == nil, commandIntro.isHidden else { return }
        let taught = commandsTaughtBeforeThisLevel()
        var seen = Set<CommandType>()
        let fresh = level.allowedCommands.filter { command in
            guard !taught.contains(command), !PlaySettings.hasIntroduced(command), seen.insert(command).inserted else { return false }
            return true
        }
        guard !fresh.isEmpty else { return }
        commandIntro.present(commands: fresh)
        commandIntro.isHidden = false
        view.bringSubviewToFront(commandIntro)
    }

    /// Commandes déjà présentes dans un niveau de campagne plus ancien.
    /// Hors campagne, chaque commande encore inconnue est présentée.
    private func commandsTaughtBeforeThisLevel() -> Set<CommandType> {
        guard let campaign else { return [] }
        var known = Set<CommandType>()
        for source in CatalogCampaign.pack.levels {
            let earlier = source.world < campaign.world
                || (source.world == campaign.world && source.worldLevel < campaign.level)
            guard earlier else { continue }
            for name in source.unlockedCommands {
                if let command = CommandType(rawValue: name) {
                    known.insert(command)
                }
            }
        }
        return known
    }

    private func installBarButtons() {
        let settings = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSensorySettings)
        )
        settings.accessibilityLabel = "Réglages"
        settings.tintColor = .white
        navigationItem.rightBarButtonItems = [settings]
    }

    private func refreshBoltBadge(animated: Bool = false) {
        let count = BoltWallet.shared.balance
        let gained = count - displayedBoltCount
        boltCountLabel.text = "\(count)"
        boltBadge.accessibilityLabel = "\(count) écrou\(count > 1 ? "s" : "")"
        let shouldPulse = animated && gained > 0 && !PlaySettings.prefersReducedMotion
        displayedBoltCount = count
        guard shouldPulse else { return }
        boltBadge.layer.removeAnimation(forKey: "boltPulse")
        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1, 1.12, 0.96, 1]
        pop.keyTimes = [0, 0.35, 0.7, 1]
        pop.duration = 0.42
        boltBadge.layer.add(pop, forKey: "boltPulse")
        UIView.animate(withDuration: 0.18, animations: {
            self.boltBadge.backgroundColor = AppTheme.gold.withAlphaComponent(0.28)
            self.boltBadge.layer.borderColor = UIColor.white.cgColor
        }, completion: { _ in
            UIView.animate(withDuration: 0.28) {
                self.boltBadge.backgroundColor = UIColor(hex: 0x1A1440)
                self.boltBadge.layer.borderColor = AppTheme.gold.cgColor
            }
        })
    }

    @objc private func showSensorySettings() {
        let controller = SensorySettingsController()
        controller.modalPresentationStyle = .popover
        if let popover = controller.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
            popover.permittedArrowDirections = .up
            popover.backgroundColor = UIColor(hex: 0xF4F0FF)
            popover.delegate = controller
        }
        present(controller, animated: true)
    }

    @objc private func runTapped() {
        if wantsContinuous {
            restoreRobot()
            return
        }
        guard !isAnimating else { return }
        guard !editor.hasInvalidDraft else {
            editor.setErrorMessage("Corrige le texte avant d'exécuter.")
            return
        }
        guard !editor.program.instructions.isEmpty else { return }
        guard programIsRunnable() else { return }
        beginRun(continuous: true)
    }

    private func beginRun(continuous: Bool) {
        if engine.state.status.isTerminal {
            engine.reset(program: editor.program)
            boardScene.show(engine.state.game)
        }
        wantsContinuous = continuous
        editor.isLocked = true
        editor.setErrorMessage(nil)
        helpAlert.isHidden = true
        overlay.isHidden = true
        playbackToken += 1
        advance(token: playbackToken)
    }

    private func advance(token: Int) {
        guard token == playbackToken else { return }
        let outcome = engine.step()
        editor.highlight(active: outcome.state.activeInstructionID, failed: failedIdentifier(in: outcome.event))
        describe(outcome)
        isAnimating = true
        updateControls()
        boardScene.play(
            event: outcome.event,
            resulting: outcome.state.game,
            tempo: tempo,
            reduceMotion: PlaySettings.prefersReducedMotion
        ) { [weak self] in
            guard let self, token == self.playbackToken else { return }
            self.isAnimating = false
            self.finish(outcome)
        }
    }

    private func finish(_ outcome: StepOutcome) {
        switch outcome.state.status {
        case .succeeded:
            wantsContinuous = false
            editor.isLocked = false
            showResult()
        case .failed, .safetyStopped:
            wantsContinuous = false
            editor.isLocked = false
            let fault = outcome.state.fault ?? (outcome.state.status == .safetyStopped ? .safetyStop : nil)
            if !Self.hasCollisionFeedback(fault) {
                Soundscape.shared.play("error")
            }
            editor.setErrorMessage(nil)
            if let fault {
                editor.highlight(
                    active: outcome.state.activeInstructionID,
                    failed: failedIdentifier(in: outcome.event)
                )
                showExecutionAlert(fault: fault, game: outcome.state.game)
            }
        case .exhausted:
            wantsContinuous = false
            editor.isLocked = false
            Soundscape.shared.play("error")
            editor.setErrorMessage(nil)
            showExecutionAlert(fault: nil, game: outcome.state.game)
        case .inProgress:
            if wantsContinuous {
                advance(token: playbackToken)
                return
            }
            editor.isLocked = false
        case .ready:
            editor.isLocked = false
        }
        updateControls()
    }

    private func showExecutionAlert(fault: ExecutionFault?, game: GameState) {
        let copy = PlayerCopy.executionAlert(for: fault, game: game)
        commandIntro.isHidden = true
        errorAlert.present(headline: copy.headline, detail: copy.detail)
        helpAlert.isHidden = true
        errorAlert.isHidden = false
        view.bringSubviewToFront(errorAlert)
        returnRobotToStart()
    }

    private func returnRobotToStart() {
        playbackToken += 1
        wantsContinuous = false
        isAnimating = false
        boardScene.cancelPlayback()
        engine.reset(program: editor.program)
        editor.isLocked = false
        boardScene.show(engine.state.game)
        bonusRemainingCount = level.collectibles.count
        updateControls()
    }

    private func restoreRobot() {
        playbackToken += 1
        wantsContinuous = false
        isAnimating = false
        boardScene.cancelPlayback()
        engine.reset(program: editor.program)
        editor.clearHighlight()
        editor.setErrorMessage(nil)
        editor.isLocked = false
        overlay.isHidden = true
        errorAlert.isHidden = true
        boardScene.show(engine.state.game)
        bonusRemainingCount = level.collectibles.count
        updateStatusIdle()
        updateControls()
        refreshBoltBadge()
    }

    private func showResult() {
        let metrics = engine.state.game.metrics
        let bonusCollected = engine.state.game.collectedBonusThisAttempt
        var rules = level.scoringRules
        // Les niveaux V7 fournissent déjà starTargets ; ne pas écraser avec ActionSearch.
        if rules.compactProgramMaxBlocks == nil,
           rules.efficientExecutionMaxStepsWithBonus == nil,
           rules.efficientExecutionMaxSteps == nil,
           let optimum = ActionSearch.shortest(level: level)?.actionCount {
            let word = optimum > 1 ? "commandes" : "commande"
            rules = ScoringRules(
                compactProgramMaxBlocks: nil,
                efficientExecutionMaxSteps: optimum,
                referenceNote: "La solution optimale compte \(optimum) \(word)."
            )
        }
        let rating = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: editor.program.blockCount,
            executedInstructions: metrics.executedInstructions,
            rules: rules,
            bonusCollected: bonusCollected
        )
        let score = LevelScore(
            stars: rating.count,
            blockCount: editor.program.blockCount,
            executedInstructions: metrics.executedInstructions
        )
        if let campaign {
            CampaignStore.shared.record(score, at: campaign)
        }
        var boltsGained = 0
        var showBoltRecap = false
        if let daily {
            switch daily.kind {
            case .challenge:
                boltsGained = DailyStore.shared.creditChallengeVictory(on: daily.civilDate)
                showBoltRecap = true
            case .bug:
                if editor.hasModifiedFromBaseline {
                    boltsGained = DailyStore.shared.creditBugVictory(on: daily.civilDate)
                    showBoltRecap = true
                }
            }
        } else {
            boltsGained = BoltWallet.shared.creditVictory(
                levelID: level.id,
                collected: engine.state.game.collectedThisAttempt
            )
            showBoltRecap = boltsGained > 0 || bonusCollected
        }
        let exitTitle = daily != nil ? "Retour" : (campaign != nil ? "Carte du monde" : "Retour")
        var note = PlayerCopy.improvement(rating: rating, rules: rules, bonusCollected: bonusCollected)
        if let daily, daily.kind == .bug, !editor.hasModifiedFromBaseline {
            note = "Modifie une commande avant de rejouer pour gagner la récompense."
        } else if boltsGained > 0 {
            let boltNote = boltsGained == 1 ? "+1 écrou !" : "+\(boltsGained) écrous !"
            note = note.isEmpty ? boltNote : "\(boltNote) \(note)"
        } else if daily != nil {
            note = note.isEmpty ? "Récompense déjà obtenue aujourd'hui." : "\(note) (déjà obtenu)"
        } else if bonusCollected {
            note = note.isEmpty
                ? "Écrou déjà obtenu sur ce niveau."
                : "\(note) (écrou déjà obtenu)"
        }
        overlay.present(
            rating: rating,
            blockCount: editor.program.blockCount,
            executed: metrics.executedInstructions,
            moves: metrics.moves,
            note: note,
            boltsGained: boltsGained,
            boltBalance: BoltWallet.shared.balance,
            showBoltRecap: showBoltRecap,
            nextTitle: daily == nil ? nextLevelTitle : nil,
            exitTitle: exitTitle
        )
        refreshBoltBadge(animated: boltsGained > 0)
        errorAlert.isHidden = true
        commandIntro.isHidden = true
        helpAlert.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        overlay.isHidden = false
        view.bringSubviewToFront(overlay)
        updateControls()
        statusLabel.text = boltsGained > 0
            ? "Drapeau atteint. +\(boltsGained) écrou\(boltsGained > 1 ? "s" : "") !"
            : "Le drapeau est atteint."
        if daily != nil {
            // Laisse l'écran de victoire s'installer, puis pitch notifications (≤ 1× / jour).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                guard let self, self.view.window != nil, !self.overlay.isHidden else { return }
                DailyReminderNotifications.promptAfterDailyVictory(from: self)
            }
        }
    }

    private func describe(_ outcome: StepOutcome) {
        switch outcome.event {
        case .moved(_, _, let forward, _):
            let remaining = outcome.state.game.remainingCollectibles.count
            let justCollected = remaining < bonusRemainingCount
            bonusRemainingCount = remaining
            if justCollected {
                statusLabel.text = "Écrou récupéré !"
            } else {
                statusLabel.text = forward ? "Le robot avance." : "Le robot recule."
            }
            if !wantsContinuous && !justCollected { Soundscape.shared.play("move") }
        case .turned(_, let direction, _):
            statusLabel.text = "Le robot regarde vers \(PlayerCopy.directionPhrase(direction))."
            if !wantsContinuous { Soundscape.shared.play("turn") }
        case .collectedBonus:
            statusLabel.text = "Écrou récupéré !"
            Soundscape.shared.play("success")
        case .pickedUp:
            statusLabel.text = "Le robot ramasse la clé."
            Soundscape.shared.play("tap")
        case .used:
            statusLabel.text = "La porte s'ouvre."
            Soundscape.shared.play("tap")
        case .pushed:
            statusLabel.text = "La caisse avance d'une case."
            Soundscape.shared.play("tap")
        case .activated(_, _, let isActive):
            statusLabel.text = isActive ? "L'interrupteur s'active." : "L'interrupteur s'éteint."
            Soundscape.shared.play("tap")
        case .enteredLoop:
            statusLabel.text = "Le robot entre dans Répète."
        case .testedCondition(_, let condition, let passed):
            let name = PlayerCopy.conditionTitle(condition)
            statusLabel.text = passed
                ? "Si \(name) : oui."
                : "Si \(name) : non, le robot saute ce bloc."
        case .blocked(let fault):
            statusLabel.text = PlayerCopy.explain(fault)
        case .enteredHazard(_, _, let terrain, _, _):
            switch terrain {
            case .spikes:
                statusLabel.text = "Le robot a marché sur des pics."
            case .water:
                statusLabel.text = "Le robot a coulé dans l'eau."
            case .lava:
                statusLabel.text = "Le robot a coulé dans la lave."
            default:
                statusLabel.text = "Le robot a marché sur un danger."
            }
        case .safetyStopped:
            statusLabel.text = PlayerCopy.explain(.safetyStop)
        case .finishedWithoutGoal:
            statusLabel.text = "Le programme est terminé, mais le drapeau n'a pas été atteint."
        case .succeeded:
            statusLabel.text = "Le drapeau est atteint."
        case nil:
            updateStatusIdle()
        }
        skView.accessibilityLabel = PlayerCopy.boardSummary(robot: outcome.state.game.robot)
    }

    private func updateStatusIdle() {
        var text = PlayerCopy.briefing(for: level)
        if let campaign, CatalogCampaign.layout.isFinale(campaign.level) {
            text = "Niveau final. \(text)"
        }
        statusLabel.text = "\(text) \(PlayerCopy.ready(direction: engine.state.game.robot.orientation))"
        skView.accessibilityLabel = PlayerCopy.boardSummary(robot: engine.state.game.robot)
    }

    private func updateControls() {
        let running = wantsContinuous
        if var configuration = runButton.configuration {
            configuration.title = running ? "Stop" : "Exécuter"
            configuration.image = UIImage(systemName: running ? "stop.fill" : "play.fill")
            configuration.baseBackgroundColor = running ? AppTheme.coral : AppTheme.success
            configuration.baseForegroundColor = running ? .white : AppTheme.line
            runButton.configuration = configuration
            runButton.accessibilityLabel = configuration.title
            runButton.accessibilityHint = running
                ? "Arrête le programme et ramène le robot au départ"
                : "Lance le programme du robot"
        }
        runButton.isEnabled = running || !editor.program.instructions.isEmpty
        refreshClearProgramButton()
    }

    private static func hasCollisionFeedback(_ fault: ExecutionFault?) -> Bool {
        switch fault {
        case .pathBlocked, .pushBlocked:
            return true
        case .hazard(_, _, let terrain, _):
            switch terrain {
            case .spikes, .water, .lava:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    private func failedIdentifier(in event: SimulationEvent?) -> UUID? {
        if case .enteredHazard = event, case .hazard(_, let identifier, _, _)? = engine.state.fault {
            return identifier
        }
        guard case .blocked(let fault) = event else { return nil }
        switch fault {
        case .pathBlocked(_, let identifier, _, _),
             .hazard(_, let identifier, _, _),
             .commandUnavailable(_, let identifier),
             .nothingToPickUp(let identifier),
             .nothingToUse(let identifier),
             .incompatibleUse(let identifier),
             .nothingToPush(let identifier),
             .pushBlocked(let identifier, _),
             .nothingToActivate(let identifier),
             .missingCondition(let identifier),
             .cycle(let identifier):
            return identifier
        case .safetyStop:
            return nil
        }
    }

    private var nextLevelTitle: String? {
        if let campaign {
            let next = CampaignRules.nextAddress(after: campaign, layout: CatalogCampaign.layout)
            guard CatalogCampaign.level(at: next) != nil else { return nil }
            if next.world != campaign.world { return "Monde suivant" }
            return "Niveau suivant"
        }
        if level.id.hasPrefix("gen-") {
            return "Autre niveau"
        }
        return PrototypeLevel.level(after: level.id).map { "Niveau suivant · \(PlayerCopy.title(for: $0))" }
    }

    private func openNextLevel() {
        if campaign != nil {
            openNextCampaignLevel()
            return
        }
        if level.id.hasPrefix("gen-") {
            openAnotherGeneratedLevel()
            return
        }
        guard let next = PrototypeLevel.level(after: level.id),
              let navigation = navigationController else { return }
        var stack = navigation.viewControllers
        stack.removeLast()
        stack.append(GameViewController(level: next))
        navigation.setViewControllers(stack, animated: true)
    }

    private func openNextCampaignLevel() {
        guard let campaign, !isOpeningNext else { return }
        isOpeningNext = true
        let address = CampaignRules.nextAddress(after: campaign, layout: CatalogCampaign.layout)
        guard CatalogCampaign.level(at: address) != nil else { return }
        CampaignStore.shared.materialize(address) { [weak self] level in
            guard let self, let navigation = self.navigationController else { return }
            var stack = navigation.viewControllers
            guard stack.last === self else { return }
            stack.removeLast()
            if address.world != campaign.world,
               let index = stack.lastIndex(where: { $0 is WorldLevelsViewController }) {
                stack.remove(at: index)
                stack.append(WorldLevelsViewController(world: address.world))
            }
            stack.append(GameViewController(level: level, campaign: address))
            navigation.setViewControllers(stack, animated: true)
        }
    }

    private func openAnotherGeneratedLevel() {
        guard !isOpeningNext else { return }
        isOpeningNext = true
        let request = GeneratedLevelFlow.request(
            seed: SeedCursor.advance(),
            world: level.worldNumber,
            level: level.levelNumber + 1
        )
        GeneratedLevelFlow.produce(request) { [weak self] generated in
            guard let self, let navigation = self.navigationController else { return }
            var stack = navigation.viewControllers
            guard stack.last === self else { return }
            stack.removeLast()
            stack.append(GameViewController(level: generated.level))
            navigation.setViewControllers(stack, animated: true)
        }
    }

    private func programIsRunnable() -> Bool {
        guard let issue = ProgramValidator.issues(in: editor.program, level: level).first else {
            return true
        }
        editor.setErrorMessage(PlayerCopy.explain(issue))
        return false
    }
}

/// Alerte d'aide : indice et solution contre des écrous.
private final class HelpAlertView: UIView {
    var onClose: (() -> Void)?
    var onBalanceChanged: (() -> Void)?
    weak var host: UIViewController?

    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UIView()
    private let badgeIcon = UIImageView()
    private let headlineLabel = UILabel()
    private let detailLabel = UILabel()
    private let hintButton = UIButton(type: .system)
    private let adHintButton = UIButton(type: .system)
    private let solutionButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var level: Level?
    private var unlockedHint = false
    private var unlockedSolution = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x2A1458).withAlphaComponent(0.78)

        card.backgroundColor = .white
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowRadius = 18
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.translatesAutoresizingMaskIntoConstraints = false

        robot.image = UIImage(named: "HomeHero")
        robot.contentMode = .scaleAspectFit
        robot.isUserInteractionEnabled = false
        robot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(robot)
        addSubview(card)

        ribbon.backgroundColor = UIColor(hex: 0x7B3FF2)
        ribbon.layer.cornerRadius = 22
        ribbon.layer.cornerCurve = .continuous
        ribbon.layer.masksToBounds = true
        ribbon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(ribbon)
        ribbonTitle.text = "Aide"
        ribbonTitle.font = AppTheme.font(22, .heavy, textStyle: .title2)
        ribbonTitle.textColor = .white
        ribbonTitle.textAlignment = .center
        ribbonTitle.translatesAutoresizingMaskIntoConstraints = false
        ribbon.addSubview(ribbonTitle)

        badge.backgroundColor = UIColor(hex: 0x7B3FF2)
        badge.layer.cornerRadius = 24
        badge.layer.borderWidth = 4
        badge.layer.borderColor = UIColor.white.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeIcon.image = UIImage(systemName: "questionmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold))
        badgeIcon.tintColor = .white
        badgeIcon.contentMode = .scaleAspectFit
        badgeIcon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeIcon)
        addSubview(badge)

        headlineLabel.font = AppTheme.font(18, .heavy, textStyle: .headline)
        headlineLabel.textColor = AppTheme.line
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0

        detailLabel.font = AppTheme.font(16, .medium, textStyle: .body)
        detailLabel.textColor = AppTheme.line
        detailLabel.textAlignment = .center
        detailLabel.numberOfLines = 0

        styleSpendButton(
            hintButton,
            title: "Indice · \(RewardEconomy.hintCost) écrous",
            fill: AppTheme.gold,
            ink: .black
        )
        hintButton.addTarget(self, action: #selector(buyHint), for: .touchUpInside)

        styleSpendButton(
            adHintButton,
            title: "Solution gratuite · pub",
            fill: UIColor(hex: 0x2E8B57),
            ink: .white
        )
        adHintButton.addTarget(self, action: #selector(watchAdForSolution), for: .touchUpInside)

        styleSpendButton(
            solutionButton,
            title: "Solution · \(RewardEconomy.fullSolutionCost) écrous",
            fill: UIColor(hex: 0x3A4C96),
            ink: .white
        )
        solutionButton.addTarget(self, action: #selector(buySolution), for: .touchUpInside)

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Annuler"
        configuration.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
        configuration.imagePadding = 6
        configuration.imagePlacement = .trailing
        configuration.baseBackgroundColor = UIColor(hex: 0x7B3FF2)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(16, .bold, textStyle: .headline)
            return updated
        }
        closeButton.configuration = configuration
        closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)

        let message = UIStackView(arrangedSubviews: [
            headlineLabel, detailLabel, hintButton, adHintButton, solutionButton, closeButton
        ])
        message.axis = .vertical
        message.spacing = 12
        message.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(message)

        NSLayoutConstraint.activate([
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 36),
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 18),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -18),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -36).prioritized(.init(750)),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 440),

            robot.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            robot.widthAnchor.constraint(equalTo: card.widthAnchor, multiplier: 0.78),
            robot.heightAnchor.constraint(equalTo: robot.widthAnchor, multiplier: 1.25),
            robot.bottomAnchor.constraint(equalTo: card.topAnchor, constant: 108),

            ribbon.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            ribbon.topAnchor.constraint(equalTo: card.topAnchor, constant: -22),
            ribbon.widthAnchor.constraint(equalTo: card.widthAnchor, constant: -48),
            ribbon.heightAnchor.constraint(equalToConstant: 58),
            ribbonTitle.leadingAnchor.constraint(equalTo: ribbon.leadingAnchor, constant: 16),
            ribbonTitle.trailingAnchor.constraint(equalTo: ribbon.trailingAnchor, constant: -16),
            ribbonTitle.bottomAnchor.constraint(equalTo: ribbon.bottomAnchor, constant: -10),

            badge.centerXAnchor.constraint(equalTo: ribbon.centerXAnchor),
            badge.centerYAnchor.constraint(equalTo: ribbon.topAnchor, constant: 2),
            badge.widthAnchor.constraint(equalToConstant: 48),
            badge.heightAnchor.constraint(equalToConstant: 48),
            badgeIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeIcon.widthAnchor.constraint(equalToConstant: 24),
            badgeIcon.heightAnchor.constraint(equalToConstant: 24),

            message.topAnchor.constraint(equalTo: card.topAnchor, constant: 46),
            message.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            message.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            message.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            hintButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            adHintButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            solutionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present(level: Level) {
        self.level = level
        let storedSolution = HelpUnlockStore.shared.solution(for: level.id)
        let storedHint = HelpUnlockStore.shared.hint(for: level.id)
        unlockedSolution = storedSolution != nil
        unlockedHint = unlockedSolution || storedHint != nil
        headlineLabel.text = "Tu as besoin d'un coup de main ?"
        if let storedSolution {
            detailLabel.text = storedSolution
        } else if let storedHint {
            detailLabel.text = storedHint
        } else {
            detailLabel.text = "Indice et solution contre des écrous, ou regarde une pub pour la solution gratuite."
        }
        refreshEconomyChrome()
        accessibilityViewIsModal = true
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    private func refreshEconomyChrome() {
        // Indice débloqué → masquer le bouton payant. Solution → masquer indice, solution et pub.
        hintButton.isHidden = unlockedHint
        solutionButton.isHidden = unlockedSolution
        adHintButton.isHidden = unlockedSolution
        hintButton.configuration?.title = "Indice · \(RewardEconomy.hintCost) écrous"
        solutionButton.configuration?.title = "Solution · \(RewardEconomy.fullSolutionCost) écrous"
        adHintButton.configuration?.title = "Solution gratuite · pub"
    }

    private func styleSpendButton(_ button: UIButton, title: String, fill: UIColor, ink: UIColor) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = fill
        configuration.baseForegroundColor = ink
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(15, .bold, textStyle: .headline)
            return updated
        }
        button.configuration = configuration
    }

    @objc private func buyHint() {
        guard !unlockedHint else { return }
        if BoltWallet.shared.spendForHint() {
            grantHint()
            onBalanceChanged?()
        } else {
            detailLabel.text = "Il te faut \(RewardEconomy.hintCost) écrous pour un indice."
            refreshEconomyChrome()
            accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
        }
    }

    @objc private func watchAdForSolution() {
        guard !unlockedSolution, let host else { return }
        // Masquer l'alerte : AdMob refuse souvent de présenter au-dessus d'un overlay custom.
        isHidden = true
        AdsService.shared.showHelpRewarded(from: host, onReward: { [weak self] in
            guard let self else { return }
            self.isHidden = false
            self.grantSolution()
        }, onUnavailable: { [weak self] in
            guard let self else { return }
            self.isHidden = false
            self.detailLabel.text = "La publicité n'est pas disponible pour le moment. Réessaie."
        })
    }

    private func grantHint() {
        guard let level else { return }
        if unlockedHint {
            if let stored = HelpUnlockStore.shared.hint(for: level.id) {
                detailLabel.text = stored
            }
            refreshEconomyChrome()
            return
        }
        unlockedHint = true
        let text: String
        if let commands = ActionSearch.shortest(level: level)?.commands, !commands.isEmpty {
            text = PlayerCopy.openingHint(commands: commands)
        } else if let catalog = CatalogCampaign.pack.levels.first(where: { $0.id == level.id }) {
            let program = CatalogCampaign.referenceProgram(for: catalog)
            let commands = program.instructions.map(\.command)
            text = PlayerCopy.openingHint(commands: commands)
        } else {
            text = "Regarde le drapeau et avance case par case."
        }
        detailLabel.text = text
        HelpUnlockStore.shared.saveHint(text, for: level.id)
        refreshEconomyChrome()
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    private func grantSolution() {
        guard let level else { return }
        if unlockedSolution {
            if let stored = HelpUnlockStore.shared.solution(for: level.id) {
                detailLabel.text = stored
            }
            refreshEconomyChrome()
            return
        }
        unlockedSolution = true
        unlockedHint = true
        let text: String
        if let catalog = CatalogCampaign.pack.levels.first(where: { $0.id == level.id }) {
            text = ProgramText.render(CatalogCampaign.referenceProgram(for: catalog)).source
        } else if let commands = ActionSearch.shortest(level: level)?.commands {
            let program = Program(instructions: commands.map { Instruction(command: $0) })
            text = ProgramText.render(program).source
        } else {
            text = "Aucune solution de référence disponible."
        }
        detailLabel.text = text
        HelpUnlockStore.shared.saveSolution(text, for: level.id)
        refreshEconomyChrome()
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    @objc private func buySolution() {
        guard !unlockedSolution else { return }
        if BoltWallet.shared.spendForFullSolution() {
            grantSolution()
            onBalanceChanged?()
        } else {
            detailLabel.text = "Il te faut \(RewardEconomy.fullSolutionCost) écrous pour la solution."
            refreshEconomyChrome()
            accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
        }
    }

    @objc private func close() {
        onClose?()
    }
}
