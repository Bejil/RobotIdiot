import UIKit
import SpriteKit
import RobotIdiotCore

final class GameViewController: UIViewController {
    private let level: Level
    private let campaign: LevelAddress?
    private var engine: SimulationEngine
    private let boardScene: BoardScene

    private let skView = SKView()
    private let boardSlot = UIView()
    private let boardFrame = UIView()
    private let editor = BlockEditorView()
    private let statusLabel = UILabel()
    private let sheet = UIView()
    private let sheetGrabber = UIView()
    private let sheetHandle = UIView()
    private let limitsLabel = UILabel()
    private let helpButton = UIButton(type: .system)
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
    private var bonusRemainingCount = 0

    init(level: Level, campaign: LevelAddress? = nil) {
        let framed = level.id.hasPrefix("RI-") ? level : LevelFraming.playfield(level)
        self.level = framed
        self.campaign = campaign
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
        if let campaign {
            navigationItem.title = PlayerCopy.campaignTitle(campaign)
        } else {
            navigationItem.title = PlayerCopy.title(for: level)
        }
        navigationItem.backButtonDisplayMode = .minimal
        installBarButtons()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: PlaySettings.changed, object: nil)

        configureStatus()
        configureBoard()
        configureTransport()
        configureEditor()
        configureOverlay()
        configureErrorAlert()
        installSubviews()
        applyLayout()
        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (controller: Self, _) in
            controller.applyLayout()
        }

        boardScene.show(engine.state.game)
        skView.presentScene(boardScene)
        bonusRemainingCount = level.collectibles.count
        updateStatusIdle()
        updateControls()
        refreshBoltBarButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = .white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentCommandIntroIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
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

        limitsLabel.font = AppTheme.font(13, .semibold, textStyle: .footnote)
        limitsLabel.textColor = AppTheme.line
        limitsLabel.numberOfLines = 2
        limitsLabel.adjustsFontForContentSizeCategory = true
        limitsLabel.text = PlayerCopy.limits(for: level)

        var helpConfiguration = UIButton.Configuration.filled()
        helpConfiguration.title = "Aide"
        helpConfiguration.image = UIImage(systemName: "questionmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        helpConfiguration.imagePadding = 6
        helpConfiguration.baseBackgroundColor = AppTheme.gold
        helpConfiguration.baseForegroundColor = .black
        helpConfiguration.cornerStyle = .capsule
        helpConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        helpConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var updated = incoming
            updated.font = AppTheme.font(15, .heavy, textStyle: .headline)
            return updated
        }
        helpButton.configuration = helpConfiguration
        helpButton.accessibilityLabel = "Aide"
        helpButton.addTarget(self, action: #selector(showHelp), for: .touchUpInside)
    }

    private func configureEditor() {
        editor.setAllowedCommands(level.allowedCommands)
        editor.setProgramLimit(level.programConstraints)
        if let campaign, let saved = CampaignStore.shared.program(at: campaign) {
            editor.replaceProgram(saved)
        }
        editor.onProgramChange = { [weak self] program in
            guard let self else { return }
            if let campaign = self.campaign {
                CampaignStore.shared.save(program, at: campaign)
            }
            self.restoreRobot()
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
            self?.openNextLevel()
        }
    }

    private func configureErrorAlert() {
        errorAlert.isHidden = true
        errorAlert.onEdit = { [weak self] in
            self?.errorAlert.isHidden = true
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
        [boardSlot, boardFrame, sheet, sheetGrabber, sheetHandle, limitsLabel, helpButton, editor, runButton, speedToggle, overlay, errorAlert, commandIntro, helpAlert].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        boardSlot.isUserInteractionEnabled = false
        view.addSubview(boardSlot)
        view.addSubview(boardFrame)
        view.addSubview(sheet)
        view.addSubview(sheetGrabber)
        sheetGrabber.addSubview(sheetHandle)
        view.addSubview(limitsLabel)
        view.addSubview(helpButton)
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

    private func applyLayout() {
        NSLayoutConstraint.deactivate(layoutConstraints)
        let guide = view.safeAreaLayoutGuide
        let initialHeight = sheetHeight > 1 ? sheetHeight : max(280, view.bounds.height * 0.4)
        sheetHeight = initialHeight
        let height = sheet.heightAnchor.constraint(equalToConstant: initialHeight)
        sheetHeightConstraint = height
        layoutConstraints = [
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,

            boardSlot.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            boardSlot.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            boardSlot.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            boardSlot.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -12),

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
            sheetGrabber.heightAnchor.constraint(equalToConstant: 28),

            sheetHandle.centerXAnchor.constraint(equalTo: sheetGrabber.centerXAnchor),
            sheetHandle.centerYAnchor.constraint(equalTo: sheetGrabber.centerYAnchor),
            sheetHandle.widthAnchor.constraint(equalToConstant: 44),
            sheetHandle.heightAnchor.constraint(equalToConstant: 5),

            limitsLabel.topAnchor.constraint(equalTo: sheetGrabber.bottomAnchor, constant: 4),
            limitsLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            limitsLabel.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -10),

            helpButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            helpButton.centerYAnchor.constraint(equalTo: limitsLabel.centerYAnchor),
            helpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            helpButton.heightAnchor.constraint(equalToConstant: 36),

            editor.topAnchor.constraint(equalTo: limitsLabel.bottomAnchor, constant: 14),
            editor.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            editor.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),

            runButton.topAnchor.constraint(equalTo: editor.bottomAnchor, constant: 8),
            runButton.leadingAnchor.constraint(equalTo: editor.leadingAnchor),
            runButton.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            runButton.heightAnchor.constraint(equalToConstant: 52),

            speedToggle.leadingAnchor.constraint(equalTo: runButton.trailingAnchor, constant: 8),
            speedToggle.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
            speedToggle.centerYAnchor.constraint(equalTo: runButton.centerYAnchor),
            speedToggle.widthAnchor.constraint(equalToConstant: 72),
            speedToggle.heightAnchor.constraint(equalTo: runButton.heightAnchor)
        ]
        NSLayoutConstraint.activate(layoutConstraints)
        view.bringSubviewToFront(sheet)
        view.bringSubviewToFront(sheetGrabber)
        view.bringSubviewToFront(limitsLabel)
        view.bringSubviewToFront(helpButton)
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
        helpAlert.onBalanceChanged = { [weak self] in
            self?.refreshBoltBarButton()
        }
        helpAlert.present(level: level)
        helpAlert.isHidden = false
        view.bringSubviewToFront(helpAlert)
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
        refreshBoltBarButton()
    }

    private func refreshBoltBarButton() {
        let count = BoltWallet.shared.balance
        let label = UILabel()
        label.text = "\(count)"
        label.font = AppTheme.font(16, .heavy, textStyle: .headline)
        label.textColor = AppTheme.gold
        let icon = UIImageView(image: GameArt.piece(.bolt))
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let trailingPad = UIView()
        trailingPad.translatesAutoresizingMaskIntoConstraints = false
        trailingPad.widthAnchor.constraint(equalToConstant: 8).isActive = true
        let row = UIStackView(arrangedSubviews: [icon, label, trailingPad])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        row.isUserInteractionEnabled = false
        let item = UIBarButtonItem(customView: row)
        item.accessibilityLabel = "\(count) écrou\(count > 1 ? "s" : "")"
        var buttons = navigationItem.rightBarButtonItems ?? []
        buttons.removeAll { $0.accessibilityLabel?.contains("écrou") == true }
        buttons.insert(item, at: 0)
        navigationItem.rightBarButtonItems = buttons
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
        refreshBoltBarButton()
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
        let boltsGained = BoltWallet.shared.creditVictory(
            levelID: level.id,
            collected: engine.state.game.collectedThisAttempt
        )
        let exitTitle = campaign != nil ? "Carte du monde" : "Retour"
        var note = PlayerCopy.improvement(rating: rating, rules: rules, bonusCollected: bonusCollected)
        if boltsGained > 0 {
            let boltNote = boltsGained == 1 ? "+1 écrou !" : "+\(boltsGained) écrous !"
            note = note.isEmpty ? boltNote : "\(boltNote) \(note)"
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
            showBoltRecap: boltsGained > 0 || bonusCollected,
            nextTitle: nextLevelTitle,
            exitTitle: exitTitle
        )
        refreshBoltBarButton()
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

    private let robot = UIImageView()
    private let card = UIView()
    private let ribbon = UIView()
    private let ribbonTitle = UILabel()
    private let badge = UIView()
    private let badgeIcon = UIImageView()
    private let headlineLabel = UILabel()
    private let detailLabel = UILabel()
    private let hintButton = UIButton(type: .system)
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
            headlineLabel, detailLabel, hintButton, solutionButton, closeButton
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
            solutionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func present(level: Level) {
        self.level = level
        unlockedHint = false
        unlockedSolution = false
        headlineLabel.text = "Tu as besoin d'un coup de main ?"
        detailLabel.text = "Débloque un indice ou la solution complète avec tes écrous."
        refreshEconomyChrome()
        accessibilityViewIsModal = true
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    private func refreshEconomyChrome() {
        hintButton.isEnabled = !unlockedHint
        solutionButton.isEnabled = !unlockedSolution
        if unlockedHint {
            hintButton.configuration?.title = "Indice débloqué"
        } else {
            hintButton.configuration?.title = "Indice · \(RewardEconomy.hintCost) écrous"
        }
        if unlockedSolution {
            solutionButton.configuration?.title = "Solution débloquée"
        } else {
            solutionButton.configuration?.title = "Solution · \(RewardEconomy.fullSolutionCost) écrous"
        }
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
        guard let level, !unlockedHint else { return }
        if BoltWallet.shared.spendForHint() {
            unlockedHint = true
            if let commands = ActionSearch.shortest(level: level)?.commands, !commands.isEmpty {
                detailLabel.text = PlayerCopy.openingHint(commands: commands)
            } else if let catalog = CatalogCampaign.pack.levels.first(where: { $0.id == level.id }) {
                let program = CatalogCampaign.referenceProgram(for: catalog)
                let commands = program.instructions.map(\.command)
                detailLabel.text = PlayerCopy.openingHint(commands: commands)
            } else {
                detailLabel.text = "Regarde le drapeau et avance case par case."
            }
            onBalanceChanged?()
        } else {
            detailLabel.text = "Il te faut \(RewardEconomy.hintCost) écrous pour un indice."
        }
        refreshEconomyChrome()
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    @objc private func buySolution() {
        guard let level, !unlockedSolution else { return }
        if BoltWallet.shared.spendForFullSolution() {
            unlockedSolution = true
            unlockedHint = true
            if let catalog = CatalogCampaign.pack.levels.first(where: { $0.id == level.id }) {
                detailLabel.text = ProgramText.render(CatalogCampaign.referenceProgram(for: catalog)).source
            } else if let commands = ActionSearch.shortest(level: level)?.commands {
                let program = Program(instructions: commands.map { Instruction(command: $0) })
                detailLabel.text = ProgramText.render(program).source
            } else {
                detailLabel.text = "Aucune solution de référence disponible."
            }
            onBalanceChanged?()
        } else {
            detailLabel.text = "Il te faut \(RewardEconomy.fullSolutionCost) écrous pour la solution."
        }
        refreshEconomyChrome()
        accessibilityLabel = "\(headlineLabel.text ?? ""). \(detailLabel.text ?? "")"
    }

    @objc private func close() {
        onClose?()
    }
}
