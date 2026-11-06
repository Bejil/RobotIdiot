import UIKit
import RobotIdiotCore

final class BlockEditorView: UIView, UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UITextViewDelegate {
    /// Largeur de la colonne commandes + espacement avant le programme.
    static let paletteLaneWidth: CGFloat = 72

    private let headerLabel = UILabel()
    private let countLabel = UILabel()
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let clearButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private let targetButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let bannerLabel = UILabel()
    private let banner = UIView()
    private let palette = UIStackView()
    private let paletteScroll = UIScrollView()
    private let emptyLabel = UILabel()
    private let modeControl = UISegmentedControl(items: ["Blocs", "Texte"])
    private let textRow = UIStackView()
    private let gutterView = UITextView()
    private let textView = UITextView()
    private let programColumn = UIStackView()
    private let actionsSpacer = UIView()
    private var actionsSpacerHeight: NSLayoutConstraint?

    private var undoStack: [Program] = []
    private var redoStack: [Program] = []
    private var activeID: UUID?
    private var failedID: UUID?
    private var ancestorIDs: Set<UUID> = []
    private var insertionParentID: UUID?
    private var allowed: [CommandType] = CommandType.movement
    private var constraintsLimit: ProgramConstraints = .flat
    private var textDraft: String?
    private var displayedLineIDs: [UUID?] = []
    private var suggestionItems: [TextCompletion] = []
    private var suggestionRange = NSRange(location: 0, length: 0)
    private var isApplyingText = false

    private(set) var program = Program()
    var onProgramChange: ((Program) -> Void)?
    var hasInvalidDraft: Bool {
        modeControl.selectedSegmentIndex == 1 && textDraft != nil
    }

    /// Mode « bug du jour » : une seule substitution de primitive.
    private(set) var isSinglePrimitiveReplaceMode = false
    private var baselineProgram: Program?
    private var selectedReplaceID: UUID?
    private var replacedID: UUID?

    var hasModifiedFromBaseline: Bool {
        guard let baselineProgram else { return false }
        return !program.hasSameCommands(as: baselineProgram)
    }

    var isLocked = false {
        didSet { applyLock() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setAllowedCommands(_ commands: [CommandType]) {
        allowed = commands
        rebuildPalette()
        refreshHint()
    }

    func setProgramLimit(_ constraints: ProgramConstraints) {
        constraintsLimit = constraints
        refreshChrome()
    }

    func replaceProgram(_ program: Program) {
        self.program = program
        textDraft = nil
        undoStack.removeAll()
        redoStack.removeAll()
        if isSinglePrimitiveReplaceMode {
            selectedReplaceID = nil
            replacedID = nil
            baselineProgram = program
        }
        reload()
    }

    /// Charge le programme buggé et n'autorise qu'une substitution de primitive.
    func enableSinglePrimitiveReplace(baseline: Program) {
        isSinglePrimitiveReplaceMode = true
        baselineProgram = baseline
        selectedReplaceID = nil
        replacedID = nil
        modeControl.selectedSegmentIndex = 0
        modeControl.isEnabled = false
        modeControl.isHidden = true
        textRow.isHidden = true
        clearButton.isHidden = true
        replaceProgram(baseline)
        hintLabel.text = "Touche une commande, puis choisis son remplacement dans la colonne de gauche."
        refreshChrome()
    }

    func setErrorMessage(_ message: String?) {
        // Ancien bandeau rouge : remplacé par les alertes chartées.
        banner.isHidden = true
        bannerLabel.text = nil
        guard let message, !message.isEmpty else { return }
        guard let host = nearestViewController else {
            UIAccessibility.post(notification: .announcement, argument: message)
            return
        }
        ChartedConfirmAlertView.presentNotice(from: host, message: message)
    }

    func highlight(active: UUID?, failed: UUID?) {
        activeID = active
        failedID = failed
        ancestorIDs = Set(
            (active.map { program.ancestorIDs(of: $0) } ?? [])
                + (failed.map { program.ancestorIDs(of: $0) } ?? [])
        )
        refreshVisibleCells()
        if modeControl.selectedSegmentIndex == 1 {
            colorize()
            scrollText(to: failed ?? active)
            return
        }
        let target = failed ?? active
        if let target, let row = program.rows.firstIndex(where: { $0.id == target }) {
            let position: UITableView.ScrollPosition = failed == nil ? .middle : .bottom
            tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: position, animated: failed == nil)
        }
    }

    func clearHighlight() {
        highlight(active: nil, failed: nil)
    }

    private func build() {
        backgroundColor = .clear

        headerLabel.text = "Programme"
        headerLabel.font = AppTheme.font(20, .bold, textStyle: .title3)
        headerLabel.textColor = AppTheme.ink
        headerLabel.adjustsFontForContentSizeCategory = true

        countLabel.font = AppTheme.font(14, .semibold, textStyle: .footnote)
        countLabel.textColor = AppTheme.inkSoft
        countLabel.adjustsFontForContentSizeCategory = true

        configureIconButton(undoButton, image: "arrow.uturn.backward", label: "Annuler", action: #selector(undo))
        configureIconButton(redoButton, image: "arrow.uturn.forward", label: "Rétablir", action: #selector(redo))
        configureIconButton(clearButton, image: "trash", label: "Effacer le programme", action: #selector(confirmClear))

        hintLabel.font = AppTheme.font(13, .medium, textStyle: .footnote)
        hintLabel.textColor = AppTheme.inkSoft
        hintLabel.numberOfLines = 0
        hintLabel.adjustsFontForContentSizeCategory = true

        targetButton.titleLabel?.font = AppTheme.font(13, .bold, textStyle: .footnote)
        targetButton.titleLabel?.numberOfLines = 0
        targetButton.setTitleColor(AppTheme.control, for: .normal)
        targetButton.contentHorizontalAlignment = .leading
        targetButton.addTarget(self, action: #selector(targetBannerTapped), for: .touchUpInside)
        targetButton.isHidden = true

        modeControl.selectedSegmentIndex = 0
        modeControl.selectedSegmentTintColor = AppTheme.teal
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: AppTheme.font(14, .bold, textStyle: .footnote)], for: .selected)
        modeControl.setTitleTextAttributes([.foregroundColor: AppTheme.ink, .font: AppTheme.font(14, .bold, textStyle: .footnote)], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeControl.accessibilityLabel = "Mode de l'éditeur"

        configureCodeView(gutterView, editable: false)
        gutterView.textColor = AppTheme.inkSoft
        gutterView.textContainerInset = UIEdgeInsets(top: 8, left: 2, bottom: 8, right: 2)
        configureCodeView(textView, editable: true)
        textView.backgroundColor = AppTheme.card
        textView.layer.cornerRadius = 16
        textView.layer.cornerCurve = .continuous
        textView.clipsToBounds = true
        textView.delegate = self
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .allCharacters
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.spellCheckingType = .no
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.accessibilityLabel = "Programme en texte"

        textRow.axis = .horizontal
        textRow.spacing = 4
        textRow.alignment = .fill
        textRow.addArrangedSubview(gutterView)
        textRow.addArrangedSubview(textView)
        textRow.isHidden = true
        gutterView.isUserInteractionEnabled = false
        gutterView.widthAnchor.constraint(equalToConstant: 28).isActive = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = UIColor(hex: 0xF2F3F7)
        tableView.layer.cornerRadius = 16
        tableView.layer.cornerCurve = .continuous
        tableView.clipsToBounds = true
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0)
        tableView.insetsContentViewsToSafeArea = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.register(CommandBlockCell.self, forCellReuseIdentifier: CommandBlockCell.reuseID)
        tableView.dragInteractionEnabled = true
        tableView.allowsSelection = true
        tableView.allowsSelectionDuringEditing = true

        tableView.dragDelegate = self
        tableView.dropDelegate = self

        emptyLabel.text = "Ajoute une commande."
        emptyLabel.font = AppTheme.font(16, .medium, textStyle: .body)
        emptyLabel.textColor = UIColor(hex: 0x667085)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        banner.backgroundColor = AppTheme.blockFailed
        banner.layer.cornerRadius = 14
        banner.layer.cornerCurve = .continuous
        banner.isHidden = true
        bannerLabel.font = AppTheme.font(15, .semibold, textStyle: .subheadline)
        bannerLabel.textColor = AppTheme.ink
        bannerLabel.numberOfLines = 0
        bannerLabel.adjustsFontForContentSizeCategory = true
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        banner.addSubview(bannerLabel)

        palette.axis = .vertical
        palette.spacing = 8
        palette.alignment = .fill
        palette.translatesAutoresizingMaskIntoConstraints = false
        paletteScroll.showsVerticalScrollIndicator = false
        paletteScroll.alwaysBounceVertical = true
        paletteScroll.addSubview(palette)

        // Colonne programme : fond gris s'arrête au-dessus des boutons.
        // La palette à gauche continue jusqu'en bas.
        actionsSpacer.backgroundColor = .clear
        actionsSpacer.isUserInteractionEnabled = false
        let spacerHeight = actionsSpacer.heightAnchor.constraint(equalToConstant: 0)
        actionsSpacerHeight = spacerHeight

        programColumn.axis = .vertical
        programColumn.spacing = 8
        programColumn.alignment = .fill
        programColumn.addArrangedSubview(tableView)
        programColumn.addArrangedSubview(textRow)
        programColumn.addArrangedSubview(banner)
        programColumn.addArrangedSubview(actionsSpacer)

        let workspace = UIStackView(arrangedSubviews: [paletteScroll, programColumn])
        workspace.axis = .horizontal
        workspace.spacing = 16
        workspace.alignment = .fill
        workspace.translatesAutoresizingMaskIntoConstraints = false
        addSubview(workspace)

        banner.setContentHuggingPriority(.required, for: .vertical)
        actionsSpacer.setContentHuggingPriority(.required, for: .vertical)
        actionsSpacer.setContentCompressionResistancePriority(.required, for: .vertical)
        paletteScroll.backgroundColor = .clear
        paletteScroll.setContentHuggingPriority(.init(1), for: .vertical)
        paletteScroll.setContentCompressionResistancePriority(.init(1), for: .vertical)
        paletteScroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        paletteScroll.setContentCompressionResistancePriority(.required, for: .horizontal)
        tableView.setContentHuggingPriority(.init(1), for: .vertical)
        tableView.setContentCompressionResistancePriority(.init(1), for: .vertical)
        textRow.setContentHuggingPriority(.init(1), for: .vertical)
        textRow.setContentCompressionResistancePriority(.init(1), for: .vertical)

        NSLayoutConstraint.activate([
            workspace.topAnchor.constraint(equalTo: topAnchor),
            workspace.leadingAnchor.constraint(equalTo: leadingAnchor),
            workspace.trailingAnchor.constraint(equalTo: trailingAnchor),
            workspace.bottomAnchor.constraint(equalTo: bottomAnchor),
            bannerLabel.topAnchor.constraint(equalTo: banner.topAnchor, constant: 10),
            bannerLabel.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 12),
            bannerLabel.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -12),
            bannerLabel.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -10),
            paletteScroll.widthAnchor.constraint(equalToConstant: 56),
            palette.topAnchor.constraint(equalTo: paletteScroll.contentLayoutGuide.topAnchor),
            palette.bottomAnchor.constraint(equalTo: paletteScroll.contentLayoutGuide.bottomAnchor),
            palette.leadingAnchor.constraint(equalTo: paletteScroll.contentLayoutGuide.leadingAnchor),
            palette.trailingAnchor.constraint(equalTo: paletteScroll.contentLayoutGuide.trailingAnchor),
            palette.widthAnchor.constraint(equalTo: paletteScroll.frameLayoutGuide.widthAnchor),
            spacerHeight,
            tableView.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).prioritized(.defaultHigh),
            textRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).prioritized(.defaultHigh)
        ])

        rebuildPalette()
        refreshHint()
        refreshChrome()
    }

    /// Réserve sous le programme la place pour Exécuter / vitesse (sans agrandir le fond gris).
    func reserveBottomActions(height: CGFloat) {
        actionsSpacerHeight?.constant = max(0, height)
    }

    private func configureIconButton(_ button: UIButton, image: String, label: String, action: Selector) {
        button.setImage(UIImage(systemName: image), for: .normal)
        button.tintColor = AppTheme.tealDark
        button.accessibilityLabel = label
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private var paletteCommands: [CommandType] {
        let preferred: [CommandType] = [
            .moveForward, .turnLeft, .turnRight, .forever, .ifBlock, .moveBackward,
            .pickUp, .use, .push, .activate
        ]
        return preferred.filter { allowed.contains($0) }
    }

    private func rebuildPalette() {
        palette.arrangedSubviews.forEach {
            palette.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        if modeControl.selectedSegmentIndex == 1 {
            let set = ProgramText.completions(
                in: textView.text ?? "",
                cursorUTF16: textView.selectedRange.location,
                allowed: allowed
            )
            suggestionItems = set.items
            suggestionRange = set.replacementUTF16
            for (index, item) in set.items.enumerated() {
                let button = completionButton(item, index: index)
                palette.addArrangedSubview(button)
            }
            return
        }
        suggestionItems = []
        for command in paletteCommands {
            palette.addArrangedSubview(paletteButton(command))
        }
    }

    private func paletteButton(_ command: CommandType) -> UIButton {
        let button = AppTheme.filledButton(
            title: PlayerCopy.commandShortTitle(command),
            systemImage: PlayerCopy.commandSymbol(command),
            prominent: true,
            compact: true
        )
        button.tag = CommandType.allCases.firstIndex(of: command) ?? 0
        button.accessibilityLabel = PlayerCopy.commandTitle(command)
        button.addTarget(self, action: #selector(addCommand(_:)), for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 56).isActive = true
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let ink: UIColor = command.category == .control ? .black : .white
        if var configuration = button.configuration {
            let colors = commandBadgeColors(command)
            configuration.title = PlayerCopy.commandShortTitle(command)
            configuration.image = GameArt.fitted(GameArt.commandIcon(command), side: 22)
            configuration.imagePlacement = .top
            configuration.imagePadding = 1
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 2, bottom: 4, trailing: 2)
            configuration.background.cornerRadius = 14
            configuration.baseBackgroundColor = colors.background
            configuration.baseForegroundColor = ink
            configuration.titleLineBreakMode = .byClipping
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = AppTheme.font(9, .heavy, textStyle: .caption2)
                outgoing.foregroundColor = ink
                return outgoing
            }
            button.configuration = configuration
        }
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.titleLabel?.numberOfLines = 1
        return button
    }

    private func refreshHint() {
        if modeControl.selectedSegmentIndex == 1 {
            hintLabel.text = "Une commande par ligne. Deux espaces de plus pour entrer dans Répète ou Si."
            return
        }
        if allowed.contains(.push) {
            hintLabel.text = "Pousse déplace la caisse d'une case, et le robot avance à sa place."
        } else if allowed.contains(.activate) {
            hintLabel.text = "Active l'interrupteur sous le robot, ou celui juste devant."
        } else if allowed.contains(.pickUp) {
            hintLabel.text = "Ramasse la clé sur ta case. Utilise l'ouvre devant une porte fermée."
        } else if allowed.contains(.forever) || allowed.contains(.ifBlock) {
            hintLabel.text = "Répète tourne sans fin. Touche Répète ou Si pour ajouter dedans, ou fais glisser une commande dessus."
        } else {
            hintLabel.text = "Avance suit le viseur. Tourner change la direction."
        }
    }

    @objc private func targetBannerTapped() {
        if isSinglePrimitiveReplaceMode {
            revertBugEdits(selecting: selectedReplaceID ?? replacedID)
            return
        }
        insertionParentID = nil
        refreshChrome()
        refreshVisibleCells()
    }

    @objc private func addCommand(_ sender: UIButton) {
        guard !isLocked, CommandType.allCases.indices.contains(sender.tag) else { return }
        let command = CommandType.allCases[sender.tag]
        guard allowed.contains(command) else { return }
        if isSinglePrimitiveReplaceMode {
            applySinglePrimitiveReplace(command)
            return
        }
        if let limit = constraintsLimit.maxBlocks, program.blockCount >= limit {
            setErrorMessage(PlayerCopy.explain(ProgramIssue.tooManyBlocks(limit: limit)))
            return
        }
        let parentDepth = insertionParentID.flatMap { id in program.rows.first { $0.id == id }?.depth }
        let nextDepth = (parentDepth ?? -1) + 2
        if nextDepth > constraintsLimit.maxNestingDepth {
            setErrorMessage(PlayerCopy.explain(ProgramIssue.nestingTooDeep(limit: constraintsLimit.maxNestingDepth)))
            return
        }
        let parent = insertionParentID
        var inserted: UUID?
        commit { program in
            inserted = program.append(command, toParent: parent)
        }
        guard let inserted else {
            insertionParentID = nil
            setErrorMessage("Choisis un bloc Répète ou Si pour ajouter dedans.")
            refreshChrome()
            return
        }
        if command.isContainer {
            insertionParentID = inserted
            refreshChrome()
            refreshVisibleCells()
        }
        if let row = program.rows.firstIndex(where: { $0.id == inserted }) {
            tableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .bottom, animated: true)
        }
    }

    @objc private func undo() {
        guard !isLocked else { return }
        if textDraft != nil {
            textDraft = nil
            showProgramInText()
            return
        }
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(program)
        program = previous
        insertionParentID = nil
        textDraft = nil
        if isSinglePrimitiveReplaceMode {
            if let baselineProgram, program.hasSameCommands(as: baselineProgram) {
                replacedID = nil
                selectedReplaceID = nil
            }
        }
        reload()
        if modeControl.selectedSegmentIndex == 1 { showProgramInText() }
        onProgramChange?(program)
    }

    @objc private func redo() {
        guard !isLocked, !isSinglePrimitiveReplaceMode, let next = redoStack.popLast() else { return }
        undoStack.append(program)
        program = next
        insertionParentID = nil
        textDraft = nil
        reload()
        if modeControl.selectedSegmentIndex == 1 { showProgramInText() }
        onProgramChange?(program)
    }

    var canClearProgram: Bool {
        !program.instructions.isEmpty && !isLocked && !isSinglePrimitiveReplaceMode
    }

    func requestClearProgram() {
        confirmClear()
    }

    @objc private func confirmClear() {
        guard canClearProgram, let host = nearestViewController else { return }
        ChartedConfirmAlertView.present(
            from: host,
            ribbon: "Attention",
            headline: "Effacer le programme ?",
            detail: "Toutes les commandes seront retirées.",
            confirmTitle: "Effacer",
            accent: .destructive,
            confirmSystemImage: "trash"
        ) { [weak self] in
            self?.insertionParentID = nil
            self?.commit { $0.instructions.removeAll() }
        }
    }

    private func commit(_ change: (inout Program) -> Void) {
        undoStack.append(program)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        change(&program)
        if let parent = insertionParentID, program.instruction(id: parent) == nil {
            insertionParentID = nil
        }
        activeID = nil
        failedID = nil
        ancestorIDs = []
        reload()
        onProgramChange?(program)
    }

    private func reload() {
        tableView.reloadData()
        refreshChrome()
    }

    private func applySinglePrimitiveReplace(_ command: CommandType) {
        guard !command.isContainer else {
            setErrorMessage("Dans ce défi, seuls les blocs simples peuvent être remplacés.")
            return
        }
        let target = selectedReplaceID ?? replacedID
        guard let target,
              let current = program.instruction(id: target),
              !current.command.isContainer else {
            setErrorMessage("Touche d'abord la commande incorrecte dans le programme.")
            return
        }
        // Une autre commande a déjà été modifiée : on la rétablit avant d'éditer la nouvelle cible.
        if let replacedID, replacedID != target, hasModifiedFromBaseline {
            revertBugEdits(selecting: target)
        }
        guard let live = program.instruction(id: selectedReplaceID ?? target),
              !live.command.isContainer else {
            setErrorMessage("Touche d'abord la commande incorrecte dans le programme.")
            return
        }
        let replaceID = selectedReplaceID ?? target
        commit { program in
            _ = program.replacePrimitive(command, on: replaceID)
        }
        selectedReplaceID = replaceID
        replacedID = hasModifiedFromBaseline ? replaceID : nil
        setErrorMessage(nil)
        refreshChrome()
        refreshVisibleCells()
    }

    /// Remet le programme buggé d'origine et sélectionne éventuellement une nouvelle cible.
    private func revertBugEdits(selecting id: UUID?) {
        guard let baselineProgram else { return }
        undoStack.removeAll()
        redoStack.removeAll()
        program = baselineProgram
        replacedID = nil
        selectedReplaceID = id
        insertionParentID = nil
        activeID = nil
        failedID = nil
        ancestorIDs = []
        setErrorMessage(nil)
        reload()
        onProgramChange?(program)
    }

    private func refreshChrome() {
        if let limit = constraintsLimit.maxBlocks {
            countLabel.text = "\(PlayerCopy.blockCount(program.blockCount)) sur \(limit)"
        } else {
            countLabel.text = PlayerCopy.blockCount(program.blockCount)
        }
        undoButton.isEnabled = !undoStack.isEmpty && !isLocked
        redoButton.isEnabled = !redoStack.isEmpty && !isLocked && !isSinglePrimitiveReplaceMode
        clearButton.isEnabled = !program.instructions.isEmpty && !isLocked && !isSinglePrimitiveReplaceMode
        emptyLabel.isHidden = !program.instructions.isEmpty
        tableView.backgroundView = program.instructions.isEmpty ? emptyLabel : nil
        if isSinglePrimitiveReplaceMode {
            insertionParentID = nil
            if hasModifiedFromBaseline {
                targetButton.isHidden = false
                targetButton.setTitle("1 commande modifiée. Touche ici ou une autre commande pour annuler.", for: .normal)
                targetButton.accessibilityLabel = "Annuler la modification"
                targetButton.isEnabled = true
            } else {
                targetButton.isHidden = true
            }
            return
        }
        if let parent = insertionParentID, let instruction = program.instruction(id: parent), instruction.command.isContainer {
            let name = PlayerCopy.commandTitle(instruction.command)
            targetButton.setTitle("Ajout dans \(name). Touche pour revenir à la suite.", for: .normal)
            targetButton.accessibilityLabel = "Ajout dans \(name)"
            targetButton.isHidden = false
            targetButton.isEnabled = !isLocked
        } else {
            insertionParentID = nil
            targetButton.isHidden = true
        }
    }

    private func applyLock() {
        paletteScroll.isUserInteractionEnabled = !isLocked
        paletteScroll.alpha = isLocked ? 0.45 : 1
        textView.isEditable = !isLocked
        refreshChrome()
        refreshVisibleCells()
    }

    private func refreshVisibleCells() {
        for case let cell as CommandBlockCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell) else { continue }
            configure(cell, at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        program.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommandBlockCell.reuseID, for: indexPath) as! CommandBlockCell
        configure(cell, at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !isLocked, program.rows.indices.contains(indexPath.row) else { return }
        let instruction = program.rows[indexPath.row].instruction
        if isSinglePrimitiveReplaceMode {
            guard !instruction.command.isContainer else {
                setErrorMessage("Les blocs Répète et Si ne se modifient pas ici.")
                return
            }
            Soundscape.shared.play("select")
            // Changer de cible annule l'éventuelle substitution déjà faite (une seule à la fois).
            if let replacedID, replacedID != instruction.id, hasModifiedFromBaseline {
                revertBugEdits(selecting: instruction.id)
                return
            }
            selectedReplaceID = instruction.id
            setErrorMessage(nil)
            refreshChrome()
            refreshVisibleCells()
            return
        }
        guard instruction.command.isContainer else { return }
        Soundscape.shared.play("select")
        insertionParentID = insertionParentID == instruction.id ? nil : instruction.id
        refreshChrome()
        refreshVisibleCells()
    }

    private func configure(_ cell: CommandBlockCell, at indexPath: IndexPath) {
        let row = program.rows[indexPath.row]
        let instruction = row.instruction
        let allowsStructural = !isLocked && !isSinglePrimitiveReplaceMode
        let isReplaceTarget = isSinglePrimitiveReplaceMode
            && (instruction.id == selectedReplaceID || instruction.id == replacedID)
        cell.apply(
            instruction: instruction,
            depth: row.depth,
            position: indexPath.row + 1,
            total: program.rows.count,
            isActive: instruction.id == activeID || isReplaceTarget,
            isAncestor: ancestorIDs.contains(instruction.id),
            isFailed: instruction.id == failedID,
            isInsertionTarget: instruction.id == insertionParentID,
            allowsEditing: allowsStructural
        )
        cell.onDelete = { [weak self] in
            guard let self, !self.isSinglePrimitiveReplaceMode else { return }
            self.commit { $0.remove(id: instruction.id) }
        }
        cell.onCondition = { [weak self] condition in
            guard let self, !self.isSinglePrimitiveReplaceMode else { return }
            self.commit { $0.setCondition(condition, on: instruction.id) }
        }
        if isSinglePrimitiveReplaceMode {
            cell.accessibilityCustomActions = []
        } else {
            cell.accessibilityCustomActions = [
                action("Monter") { [weak self] in
                    self?.shift(instruction.id, offset: -1) ?? false
                },
                action("Descendre") { [weak self] in
                    self?.shift(instruction.id, offset: 1) ?? false
                },
                action("Dupliquer") { [weak self] in
                    self?.commit { $0.duplicate(id: instruction.id) }
                    return true
                }
            ]
        }
    }

    private func shift(_ id: UUID, offset: Int) -> Bool {
        var trial = program
        guard trial.moveSibling(id, offset: offset) else { return false }
        commit { $0.moveSibling(id, offset: offset) }
        return true
    }

    private func action(_ name: String, handler: @escaping () -> Bool) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: name) { _ in handler() }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        !isLocked && !isSinglePrimitiveReplaceMode && program.nestingDepth <= 1
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath, program.nestingDepth <= 1 else { return }
        Soundscape.shared.play("select")
        undoStack.append(program)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        program.relocateRoot(from: sourceIndexPath.row, to: destinationIndexPath.row)
        activeID = nil
        failedID = nil
        ancestorIDs = []
        refreshChrome()
        refreshVisibleCells()
        onProgramChange?(program)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        .none
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard !isLocked, !isSinglePrimitiveReplaceMode, program.rows.indices.contains(indexPath.row) else { return nil }
        let instruction = program.rows[indexPath.row].instruction
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let up = UIAction(title: "Monter", image: UIImage(systemName: "arrow.up")) { _ in
                Soundscape.shared.play("select")
                _ = self?.shift(instruction.id, offset: -1)
            }
            let down = UIAction(title: "Descendre", image: UIImage(systemName: "arrow.down")) { _ in
                Soundscape.shared.play("select")
                _ = self?.shift(instruction.id, offset: 1)
            }
            let duplicate = UIAction(title: "Dupliquer", image: UIImage(systemName: "plus.square.on.square")) { _ in
                Soundscape.shared.play("select")
                self?.commit { $0.duplicate(id: instruction.id) }
            }
            return UIMenu(children: [up, down, duplicate])
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isLocked, !isSinglePrimitiveReplaceMode, program.rows.indices.contains(indexPath.row) else { return nil }
        let instruction = program.rows[indexPath.row].instruction
        let duplicate = UIContextualAction(style: .normal, title: "Dupliquer") { [weak self] _, _, done in
            Soundscape.shared.play("select")
            self?.commit { $0.duplicate(id: instruction.id) }
            done(true)
        }
        duplicate.backgroundColor = AppTheme.teal
        let delete = UIContextualAction(style: .destructive, title: "Supprimer") { [weak self] _, _, done in
            Soundscape.shared.play("ui")
            self?.commit { $0.remove(id: instruction.id) }
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, duplicate])
    }

    private var nearestViewController: UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let controller = next as? UIViewController { return controller }
            responder = next
        }
        return nil
    }

    private func configureCodeView(_ view: UITextView, editable: Bool) {
        view.isEditable = editable
        view.isSelectable = editable
        view.backgroundColor = .clear
        view.font = codeFont
        view.textColor = AppTheme.ink
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = true
        view.showsVerticalScrollIndicator = editable
        view.adjustsFontForContentSizeCategory = true
    }

    private var codeFont: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedSystemFont(ofSize: 15, weight: .medium))
    }

    private func completionButton(_ item: TextCompletion, index: Int) -> UIButton {
        let title: String
        let symbol: String
        let command: CommandType?
        switch item {
        case .command(let value):
            title = PlayerCopy.commandShortTitle(value)
            symbol = PlayerCopy.commandSymbol(value)
            command = value
        case .condition(let condition):
            title = PlayerCopy.conditionTitle(condition)
            symbol = "questionmark.diamond"
            command = nil
        }
        let button = AppTheme.filledButton(title: title, systemImage: symbol, prominent: true, compact: true)
        button.tag = index
        button.accessibilityLabel = title
        button.addTarget(self, action: #selector(insertCompletion(_:)), for: .touchUpInside)
        let width: CGFloat = command == nil ? 132 : 76
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        if let command, command.category == .control, var configuration = button.configuration {
            configuration.baseBackgroundColor = AppTheme.control
            button.configuration = configuration
        }
        if let command, command.category == .movement, var configuration = button.configuration {
            configuration.baseBackgroundColor = AppTheme.move
            configuration.baseForegroundColor = AppTheme.line
            button.configuration = configuration
        }
        if let command, command.category == .interaction, var configuration = button.configuration {
            configuration.baseBackgroundColor = AppTheme.gold
            configuration.baseForegroundColor = AppTheme.line
            configuration.image = GameArt.commandIcon(command)
            button.configuration = configuration
        }
        if command == nil, var configuration = button.configuration {
            configuration.baseBackgroundColor = AppTheme.coral
            configuration.baseForegroundColor = .white
            configuration.image = GameArt.mark("spark")
            button.configuration = configuration
        } else if let command, var configuration = button.configuration {
            configuration.image = GameArt.commandIcon(command)
            button.configuration = configuration
        }
        return button
    }

    @objc private func modeChanged() {
        let writing = modeControl.selectedSegmentIndex == 1
        tableView.isHidden = writing
        targetButton.isHidden = writing || insertionParentID == nil
        textRow.isHidden = !writing
        if writing {
            if let textDraft {
                setText(textDraft)
            } else {
                showProgramInText()
            }
        }
        refreshHint()
        rebuildPalette()
        refreshChrome()
    }

    @objc private func insertCompletion(_ sender: UIButton) {
        guard !isLocked, suggestionItems.indices.contains(sender.tag) else { return }
        let token = suggestionItems[sender.tag].token
        let source = (textView.text ?? "") as NSString
        let range = suggestionRange
        guard NSMaxRange(range) <= source.length else { return }
        let updated = source.replacingCharacters(in: range, with: token)
        let cursor = range.location + (token as NSString).length
        isApplyingText = true
        textView.text = updated
        textView.selectedRange = NSRange(location: cursor, length: 0)
        isApplyingText = false
        textViewDidChange(textView)
    }

    private func showProgramInText() {
        let rendered = ProgramText.render(program)
        displayedLineIDs = rendered.lineIDs
        textDraft = nil
        setText(rendered.source)
        setErrorMessage(nil)
    }

    private func setText(_ value: String) {
        isApplyingText = true
        textView.text = value
        textView.selectedRange = NSRange(location: (value as NSString).length, length: 0)
        isApplyingText = false
        refreshGutter()
        colorize()
        rebuildPalette()
    }

    private func refreshGutter() {
        let count = max(1, (textView.text ?? "").components(separatedBy: "\n").count)
        gutterView.text = (1...count).map(String.init).joined(separator: "\n")
        gutterView.contentOffset = CGPoint(x: 0, y: textView.contentOffset.y)
    }

    private func adoptText() {
        let source = textView.text ?? ""
        let parsed = ProgramText.parse(source, allowed: allowed)
        if let diagnostic = parsed.diagnostics.first {
            textDraft = source
            displayedLineIDs = parsed.lineIDs
            setErrorMessage("Ligne \(diagnostic.line) : \(diagnostic.message)")
            refreshChrome()
            return
        }
        guard let candidate = parsed.program else { return }
        if let issue = adoptionIssue(candidate) {
            textDraft = source
            displayedLineIDs = parsed.lineIDs
            setErrorMessage(issue)
            refreshChrome()
            return
        }
        textDraft = nil
        if ProgramText.render(candidate).source == ProgramText.render(program).source {
            displayedLineIDs = ProgramText.adoptedLineIDs(parsed.lineIDs, program: program)
            setErrorMessage(nil)
            refreshChrome()
            return
        }
        displayedLineIDs = parsed.lineIDs
        commit { $0 = candidate }
    }

    private func adoptionIssue(_ candidate: Program) -> String? {
        if candidate.nestingDepth > constraintsLimit.maxNestingDepth {
            return PlayerCopy.explain(ProgramIssue.nestingTooDeep(limit: constraintsLimit.maxNestingDepth))
        }
        if let limit = constraintsLimit.maxBlocks, candidate.blockCount > limit {
            return PlayerCopy.explain(ProgramIssue.tooManyBlocks(limit: limit))
        }
        if containsEmptyForever(candidate.instructions) {
            return PlayerCopy.explain(.emptyForever)
        }
        return nil
    }

    private func containsEmptyForever(_ nodes: [Instruction]) -> Bool {
        for node in nodes {
            if node.command == .forever && node.children.isEmpty { return true }
            if containsEmptyForever(node.children) { return true }
        }
        return false
    }

    private func colorize() {
        let source = textView.text ?? ""
        let selected = textView.selectedRange
        let offset = textView.contentOffset
        let attributed = NSMutableAttributedString(string: source, attributes: [
            .font: codeFont,
            .foregroundColor: AppTheme.ink
        ])
        var location = 0
        for (index, line) in source.components(separatedBy: "\n").enumerated() {
            let length = (line as NSString).length
            guard length > 0 else {
                location += 1
                continue
            }
            let range = NSRange(location: location, length: length)
            if index < displayedLineIDs.count, let identifier = displayedLineIDs[index] {
                if identifier == failedID {
                    attributed.addAttribute(.backgroundColor, value: AppTheme.blockFailed, range: range)
                } else if identifier == activeID {
                    attributed.addAttribute(.backgroundColor, value: AppTheme.blockActive, range: range)
                }
            }
            paint(line: line, base: range, in: attributed)
            location += length + 1
        }
        isApplyingText = true
        textView.textStorage.setAttributedString(attributed)
        textView.selectedRange = selected
        textView.contentOffset = offset
        isApplyingText = false
    }

    private func paint(line: String, base: NSRange, in text: NSMutableAttributedString) {
        let body = line.drop { $0 == " " }
        let indent = line.count - body.count
        let parts = body.split(separator: " ").map(String.init)
        guard let first = parts.first else { return }
        let word = first.uppercased()
        let wordRange = NSRange(location: base.location + indent, length: (first as NSString).length)
        if let command = CommandType.allCases.first(where: { $0.rawValue == word }), NSMaxRange(wordRange) <= text.length {
            text.addAttribute(.foregroundColor, value: syntaxColor(for: command), range: wordRange)
        }
        guard word == "SI", parts.count >= 2 else { return }
        let gap = body.distance(from: body.startIndex, to: body.range(of: parts[1])?.lowerBound ?? body.endIndex)
        let conditionRange = NSRange(location: base.location + indent + gap, length: (parts[1] as NSString).length)
        if NSMaxRange(conditionRange) <= text.length {
            text.addAttribute(.foregroundColor, value: AppTheme.coral, range: conditionRange)
        }
    }

    private func syntaxColor(for command: CommandType) -> UIColor {
        switch command.category {
        case .movement: return AppTheme.move
        case .interaction: return AppTheme.interaction
        case .control: return AppTheme.control
        }
    }

    private func scrollText(to identifier: UUID?) {
        guard let identifier, let index = displayedLineIDs.firstIndex(of: identifier) else { return }
        let lines = (textView.text ?? "").components(separatedBy: "\n")
        var location = 0
        for line in lines.prefix(index) {
            location += (line as NSString).length + 1
        }
        textView.scrollRangeToVisible(NSRange(location: min(location, (textView.text as NSString?)?.length ?? 0), length: 0))
    }

    private func tryRelocate(_ id: UUID, to placement: ProgramPlacement) {
        var trial = program
        guard trial.relocate(id, to: placement) else { return }
        if trial.nestingDepth > constraintsLimit.maxNestingDepth {
            setErrorMessage(PlayerCopy.explain(ProgramIssue.nestingTooDeep(limit: constraintsLimit.maxNestingDepth)))
            return
        }
        textDraft = nil
        commit { $0.relocate(id, to: placement) }
    }

    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard !isLocked, !isSinglePrimitiveReplaceMode, program.rows.indices.contains(indexPath.row) else { return [] }
        let identifier = program.rows[indexPath.row].id
        let item = UIDragItem(itemProvider: NSItemProvider(object: identifier.uuidString as NSString))
        item.localObject = identifier
        return [item]
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard !isLocked, session.localDragSession != nil else {
            return UITableViewDropProposal(operation: .cancel)
        }
        if let row = destinationIndexPath?.row,
           program.rows.indices.contains(row),
           program.rows[row].instruction.command.isContainer,
           let dragged = session.items.first?.localObject as? UUID,
           dragged != program.rows[row].id {
            return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let dragged = coordinator.items.first?.dragItem.localObject as? UUID else { return }
        Soundscape.shared.play("select")
        if coordinator.proposal.intent == .insertIntoDestinationIndexPath,
           let row = coordinator.destinationIndexPath?.row,
           program.rows.indices.contains(row) {
            tryRelocate(dragged, to: .into(program.rows[row].id))
            return
        }
        guard let row = coordinator.destinationIndexPath?.row else {
            tryRelocate(dragged, to: .atRootEnd)
            return
        }
        if program.rows.indices.contains(row) {
            tryRelocate(dragged, to: .before(program.rows[row].id))
        } else {
            tryRelocate(dragged, to: .atRootEnd)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === self.textView, !isApplyingText else { return }
        refreshGutter()
        colorize()
        adoptText()
        rebuildPalette()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView === self.textView, !isApplyingText, modeControl.selectedSegmentIndex == 1 else { return }
        rebuildPalette()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n", range.length == 0, !isLocked else { return true }
        let source = (textView.text ?? "") as NSString
        let lineRange = source.lineRange(for: NSRange(location: range.location, length: 0))
        let raw = source.substring(with: lineRange)
        let contentEnd = lineRange.location + lineRange.length - (raw.hasSuffix("\n") ? 1 : 0)
        guard range.location == contentEnd else { return true }
        let line = raw.trimmingCharacters(in: .newlines)
        let indent = line.prefix { $0 == " " }.count
        let words = line.trimmingCharacters(in: .whitespaces).split(separator: " ").map(String.init)
        let opener = words.first?.uppercased() == "REPETE" || (words.first?.uppercased() == "SI" && words.count >= 2)
        let insertion = "\n" + String(repeating: " ", count: indent + (opener ? 2 : 0))
        let updated = source.replacingCharacters(in: range, with: insertion)
        isApplyingText = true
        textView.text = updated
        textView.selectedRange = NSRange(location: range.location + (insertion as NSString).length, length: 0)
        isApplyingText = false
        textViewDidChange(textView)
        return false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === textView else { return }
        gutterView.contentOffset = CGPoint(x: 0, y: textView.contentOffset.y)
    }
}

private func commandBadgeColors(_ command: CommandType) -> (background: UIColor, foreground: UIColor) {
    switch command.category {
    case .movement:
        return (UIColor(hex: 0x2F9BFF), .white)
    case .interaction:
        return (UIColor(hex: 0x7A2CF7), .white)
    case .control:
        return (UIColor(hex: 0xFFD200), UIColor(hex: 0x1A1440))
    }
}

private final class CommandBlockCell: UITableViewCell {
    static let reuseID = "CommandBlockCell"

    private let card = UIView()
    private let stripe = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let indexLabel = UILabel()
    private let gripView = UIImageView()
    private let conditionButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private var indentConstraint: NSLayoutConstraint!
    private var conditionWidth: NSLayoutConstraint!
    private var gripWidth: NSLayoutConstraint!
    var onDelete: (() -> Void)?
    var onCondition: ((ConditionType) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = .white
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        stripe.translatesAutoresizingMaskIntoConstraints = false
        stripe.layer.cornerRadius = 8
        stripe.layer.cornerCurve = .continuous
        card.addSubview(stripe)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        stripe.addSubview(iconView)

        indexLabel.font = AppTheme.font(12, .bold, textStyle: .caption2)
        indexLabel.textColor = UIColor(hex: 0x667085)
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(indexLabel)

        titleLabel.font = AppTheme.font(15, .bold, textStyle: .subheadline)
        titleLabel.textColor = AppTheme.line
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        gripView.image = UIImage(
            systemName: "line.3.horizontal",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        )
        gripView.tintColor = UIColor(hex: 0x98A2B3)
        gripView.contentMode = .scaleAspectFit
        gripView.accessibilityLabel = "Déplacer"
        gripView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(gripView)

        conditionButton.translatesAutoresizingMaskIntoConstraints = false
        conditionButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        conditionButton.tintColor = AppTheme.control
        conditionButton.accessibilityLabel = "Changer la condition"
        conditionButton.showsMenuAsPrimaryAction = true
        card.addSubview(conditionButton)

        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = AppTheme.coral
        deleteButton.accessibilityLabel = "Supprimer"
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        card.addSubview(deleteButton)

        indentConstraint = card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        conditionWidth = conditionButton.widthAnchor.constraint(equalToConstant: 0)
        gripWidth = gripView.widthAnchor.constraint(equalToConstant: 18)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            indentConstraint,
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),

            stripe.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            stripe.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stripe.widthAnchor.constraint(equalToConstant: 28),
            stripe.heightAnchor.constraint(equalToConstant: 28),

            iconView.centerXAnchor.constraint(equalTo: stripe.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: stripe.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            indexLabel.leadingAnchor.constraint(equalTo: stripe.trailingAnchor, constant: 8),
            indexLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: indexLabel.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: gripView.leadingAnchor, constant: -6),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),

            gripView.trailingAnchor.constraint(equalTo: conditionButton.leadingAnchor, constant: -2),
            gripView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            gripWidth,
            gripView.heightAnchor.constraint(equalToConstant: 16),

            conditionButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor),
            conditionButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            conditionWidth,
            conditionButton.heightAnchor.constraint(equalToConstant: 28),

            deleteButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            deleteButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(
        instruction: Instruction,
        depth: Int,
        position: Int,
        total: Int,
        isActive: Bool,
        isAncestor: Bool,
        isFailed: Bool,
        isInsertionTarget: Bool,
        allowsEditing: Bool
    ) {
        if instruction.command == .ifBlock, let condition = instruction.condition {
            titleLabel.text = "Si · \(PlayerCopy.conditionTitle(condition))"
        } else {
            titleLabel.text = PlayerCopy.commandTitle(instruction.command)
        }
        indexLabel.text = "\(position)"
        let colors = commandBadgeColors(instruction.command)
        iconView.image = GameArt.commandIcon(instruction.command)
        iconView.tintColor = isFailed ? .white : colors.foreground
        stripe.backgroundColor = isFailed ? UIColor.white.withAlphaComponent(0.22) : colors.background
        titleLabel.textColor = isFailed ? .white : AppTheme.line
        indexLabel.textColor = isFailed ? UIColor.white.withAlphaComponent(0.85) : UIColor(hex: 0x667085)
        card.backgroundColor = isFailed ? AppTheme.coral : .white
        card.layer.borderWidth = (isActive || isFailed || isInsertionTarget) ? 2 : 0
        card.layer.borderColor = (isFailed ? UIColor.white : colors.background).cgColor
        deleteButton.isHidden = !allowsEditing
        deleteButton.tintColor = isFailed ? .white : AppTheme.coral
        gripView.isHidden = !allowsEditing
        gripWidth.constant = allowsEditing ? 18 : 0
        gripView.tintColor = isFailed ? .white : UIColor(hex: 0x98A2B3)
        deleteButton.accessibilityLabel = "Supprimer \(titleLabel.text ?? "")"
        indentConstraint.constant = 12 + CGFloat(depth) * 18
        let nested = depth > 0 ? ", imbriquée" : ""
        accessibilityLabel = "\(titleLabel.text ?? ""), commande \(position) sur \(total)\(nested)"

        let showsCondition = instruction.command == .ifBlock && allowsEditing
        conditionButton.isHidden = !showsCondition
        conditionWidth.constant = showsCondition ? 36 : 0
        if showsCondition {
            let current = instruction.condition
            conditionButton.menu = UIMenu(children: ConditionType.allCases.map { condition in
                UIAction(
                    title: PlayerCopy.conditionTitle(condition),
                    state: condition == current ? .on : .off
                ) { [weak self] _ in
                    Soundscape.shared.play("select")
                    self?.onCondition?(condition)
                }
            })
        } else {
            conditionButton.menu = nil
        }

        if isAncestor, !isFailed, !isActive {
            card.backgroundColor = UIColor(hex: 0xF7F8FC)
        }
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onDelete = nil
        onCondition = nil
        accessibilityCustomActions = nil
        conditionButton.menu = nil
    }
}
