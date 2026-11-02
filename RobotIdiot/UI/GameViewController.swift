import UIKit
import SpriteKit
import RobotIdiotCore

final class GameViewController: UIViewController {
    private let level: Level
    private let campaign: LevelAddress?
    private let challengeID: UUID?
    private var engine: SimulationEngine
    private let boardScene: BoardScene

    private let skView = SKView()
    private let boardFrame = UIView()
    private let editor = BlockEditorView()
    private let statusLabel = UILabel()
    private let sheet = UIView()
    private let limitsLabel = UILabel()
    private let helpButton = UIButton(type: .system)
    private let speedToggle = UIButton(type: .system)
    private let overlay = ResultOverlayView()
    private let errorAlert = ExecutionAlertView()

    private let runButton = AppTheme.filledButton(title: "Exécuter", systemImage: "play.fill", prominent: true)

    private var tempo: PlaybackTempo
    private var isOpeningNext = false
    private var playbackToken = 0
    private var wantsContinuous = false
    private var isAnimating = false
    private var layoutConstraints: [NSLayoutConstraint] = []

    init(level: Level, campaign: LevelAddress? = nil, challenge: UUID? = nil) {
        let framed = LevelFraming.playfield(level)
        self.level = framed
        self.campaign = campaign
        self.challengeID = challenge
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
        } else if challengeID != nil {
            navigationItem.title = "Défi · \(PlayerCopy.title(for: level))"
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
        updateStatusIdle()
        updateControls()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.tintColor = .white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Soundscape.shared.setMusic(playing: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = AppTheme.gold
        playbackToken += 1
        wantsContinuous = false
        boardScene.cancelPlayback()
        Soundscape.shared.setMusic(playing: false)
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
        editor.onProgramChange = { [weak self] _ in
            self?.restoreRobot()
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
    }

    private func installSubviews() {
        [boardFrame, sheet, limitsLabel, helpButton, editor, runButton, speedToggle, overlay, errorAlert].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(boardFrame)
        view.addSubview(sheet)
        view.addSubview(limitsLabel)
        view.addSubview(helpButton)
        view.addSubview(editor)
        view.addSubview(runButton)
        view.addSubview(speedToggle)
        view.addSubview(overlay)
        view.addSubview(errorAlert)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorAlert.topAnchor.constraint(equalTo: view.topAnchor),
            errorAlert.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorAlert.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorAlert.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func applyLayout() {
        NSLayoutConstraint.deactivate(layoutConstraints)
        let guide = view.safeAreaLayoutGuide
        layoutConstraints = [
            boardFrame.topAnchor.constraint(equalTo: guide.topAnchor, constant: 4),
            boardFrame.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            boardFrame.leadingAnchor.constraint(greaterThanOrEqualTo: guide.leadingAnchor, constant: 12),
            boardFrame.trailingAnchor.constraint(lessThanOrEqualTo: guide.trailingAnchor, constant: -12),
            boardFrame.widthAnchor.constraint(equalTo: guide.widthAnchor, constant: -24).prioritized(.defaultHigh),
            boardFrame.heightAnchor.constraint(equalTo: boardFrame.widthAnchor),
            boardFrame.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.46),

            sheet.topAnchor.constraint(equalTo: boardFrame.bottomAnchor, constant: 16),
            sheet.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            limitsLabel.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 28),
            limitsLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            limitsLabel.trailingAnchor.constraint(equalTo: helpButton.leadingAnchor, constant: -10),

            helpButton.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            helpButton.centerYAnchor.constraint(equalTo: limitsLabel.centerYAnchor),
            helpButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            helpButton.heightAnchor.constraint(equalToConstant: 36),

            editor.topAnchor.constraint(equalTo: limitsLabel.bottomAnchor, constant: 22),
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
    }

    private func refreshSpeedToggle() {
        let title = tempo == .fast ? "x2" : "x1"
        speedToggle.setTitle(title, for: .normal)
        speedToggle.accessibilityValue = title
    }

    @objc private func showHelp() {
        let help = LevelHelpController(level: level)
        present(help, animated: true)
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
        if view.window != nil {
            Soundscape.shared.setMusic(playing: true)
        }
    }

    @objc private func toggleFavorite() {
        guard let challengeID, let entry = ChallengeStore.shared.entry(challengeID) else { return }
        ChallengeStore.shared.setFavorite(challengeID, !entry.favorite)
        installBarButtons()
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
        var items = [settings]
        if let challengeID {
            let favorite = ChallengeStore.shared.entry(challengeID)?.favorite == true
            let star = UIBarButtonItem(
                image: UIImage(systemName: favorite ? "star.fill" : "star"),
                style: .plain,
                target: self,
                action: #selector(toggleFavorite)
            )
            star.tintColor = favorite ? AppTheme.gold : .white
            star.accessibilityLabel = favorite ? "Retirer des favoris" : "Ajouter aux favoris"
            items.append(star)
        }
        navigationItem.rightBarButtonItems = items
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
            Soundscape.shared.play("success")
            showResult()
        case .failed, .safetyStopped:
            wantsContinuous = false
            editor.isLocked = false
            Soundscape.shared.play("error")
            editor.setErrorMessage(nil)
            let fault = outcome.state.fault ?? (outcome.state.status == .safetyStopped ? .safetyStop : nil)
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
        errorAlert.present(headline: copy.headline, detail: copy.detail)
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
        updateStatusIdle()
        updateControls()
    }

    private func showResult() {
        let metrics = engine.state.game.metrics
        let rating = ScoreEvaluator.rating(
            succeeded: true,
            blockCount: editor.program.blockCount,
            executedInstructions: metrics.executedInstructions,
            rules: level.scoringRules
        )
        let score = LevelScore(
            stars: rating.count,
            blockCount: editor.program.blockCount,
            executedInstructions: metrics.executedInstructions
        )
        if let campaign {
            CampaignStore.shared.record(score, at: campaign)
        }
        if let challengeID {
            ChallengeStore.shared.record(score, id: challengeID)
        }
        let exitTitle: String
        if campaign != nil {
            exitTitle = "Carte du monde"
        } else if challengeID != nil {
            exitTitle = "Défis"
        } else {
            exitTitle = "Retour"
        }
        overlay.present(
            rating: rating,
            blockCount: editor.program.blockCount,
            executed: metrics.executedInstructions,
            moves: metrics.moves,
            note: PlayerCopy.improvement(rating: rating, rules: level.scoringRules),
            nextTitle: nextLevelTitle,
            exitTitle: exitTitle
        )
        errorAlert.isHidden = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        overlay.isHidden = false
        view.bringSubviewToFront(overlay)
        updateControls()
        statusLabel.text = "Le drapeau est atteint."
    }

    private func describe(_ outcome: StepOutcome) {
        switch outcome.event {
        case .moved(_, _, let forward, _):
            statusLabel.text = forward ? "Le robot avance." : "Le robot recule."
            if !wantsContinuous { Soundscape.shared.play("move") }
        case .turned(_, let direction, _):
            statusLabel.text = "Le robot regarde vers \(PlayerCopy.directionPhrase(direction))."
            if !wantsContinuous { Soundscape.shared.play("turn") }
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
        if let campaign, CampaignLayout.standard.isFinale(campaign.level) {
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

    private func failedIdentifier(in event: SimulationEvent?) -> UUID? {
        guard case .blocked(let fault) = event else { return nil }
        switch fault {
        case .pathBlocked(_, let identifier, _, _),
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
            let next = CampaignRules.nextAddress(after: campaign)
            if next.world != campaign.world { return "Monde suivant" }
            if CampaignLayout.standard.isFinale(next.level) { return "Niveau final" }
            return "Niveau suivant"
        }
        if challengeID != nil {
            return "Autre défi"
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
        if challengeID != nil {
            openAnotherChallenge()
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
        let address = CampaignRules.nextAddress(after: campaign)
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

    private func openAnotherChallenge() {
        guard let challengeID, !isOpeningNext,
              let recipe = ChallengeStore.shared.entry(challengeID)?.recipe else { return }
        isOpeningNext = true
        let next = recipe.advanced()
        GeneratedLevelFlow.produce(next.request()) { [weak self] generated in
            guard let self, let navigation = self.navigationController else { return }
            var stack = navigation.viewControllers
            guard stack.last === self else { return }
            let entry = ChallengeStore.shared.append(level: generated.level, recipe: next)
            stack.removeLast()
            stack.append(GameViewController(level: entry.level, challenge: entry.id))
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

private final class LevelHelpController: UIViewController {
    private let level: Level

    init(level: Level) {
        self.level = level
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }

        let robot = UIImageView(image: UIImage(named: "HomeHero"))
        robot.contentMode = .scaleAspectFit
        robot.translatesAutoresizingMaskIntoConstraints = false
        robot.heightAnchor.constraint(equalToConstant: 150).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = "Aide"
        titleLabel.font = AppTheme.font(28, .heavy, textStyle: .title1)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 0

        let limits = UILabel()
        limits.text = PlayerCopy.limits(for: level)
        limits.font = AppTheme.font(16, .heavy, textStyle: .headline)
        limits.textColor = AppTheme.gold
        limits.numberOfLines = 0

        let body = UILabel()
        body.text = """
        \(PlayerCopy.briefing(for: level))

        Le robot fait exactement ce que tu écris. La visière montre où il regarde.

        Le plateau fait 7 cases sur 7. Le bord arrête le robot. Un mur dessiné l'arrête aussi.

        Répète tourne sans fin. Si ne s'exécute que lorsque la condition est vraie.
        """
        body.font = AppTheme.font(17, .medium, textStyle: .body)
        body.textColor = AppTheme.inkSoft
        body.numberOfLines = 0

        let button = AppTheme.filledButton(title: "J'ai compris", systemImage: "checkmark", prominent: true)
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let stack = UIStackView(arrangedSubviews: [robot, titleLabel, limits, body, button])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24)
        ])
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
