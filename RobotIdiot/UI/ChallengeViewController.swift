import UIKit
import RobotIdiotCore

enum MechanicChoice: Int, CaseIterable, Hashable {
    case walks
    case loops
    case conditions
    case keys
    case switches
    case crates

    var title: String {
        switch self {
        case .walks: return "Déplacements"
        case .loops: return "Boucles"
        case .conditions: return "Conditions"
        case .keys: return "Clés"
        case .switches: return "Interrupteurs"
        case .crates: return "Caisses"
        }
    }

    var families: [PuzzleFamily] {
        switch self {
        case .walks: return [.openWalk, .obstacleWalk]
        case .loops: return [.infiniteCorridor]
        case .conditions: return [.wallFollow]
        case .keys: return [.keyDoor]
        case .switches: return [.switchDoor]
        case .crates: return [.cratePush]
        }
    }
}

final class ChallengeViewController: UITableViewController {
    private var selected: Set<MechanicChoice> = []
    private var favoritesOnly = false
    private var generating = false
    private var generationTicket = 0
    private let difficulties: [Double] = [0.2, 0.5, 0.8]
    private let difficultyControl = UISegmentedControl(items: ["Accessible", "Intermédiaire", "Exigeant"])
    private let seedField = UITextField()
    private let generateButton = AppTheme.filledButton(title: "Générer", systemImage: "dice.fill", prominent: true)
    private let generateFooter = UIView()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Défis"
        tableView.backgroundColor = AppTheme.cream
        tableView.keyboardDismissMode = .onDrag
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
        refreshFilterButton()

        difficultyControl.selectedSegmentIndex = 1
        difficultyControl.selectedSegmentTintColor = AppTheme.teal
        difficultyControl.setTitleTextAttributes([.font: AppTheme.font(13, .semibold, textStyle: .footnote)], for: .normal)
        difficultyControl.apportionsSegmentWidthsByContent = true

        seedField.placeholder = "Aléatoire"
        seedField.keyboardType = .numberPad
        seedField.font = AppTheme.font(17, .medium, textStyle: .body)
        seedField.textColor = AppTheme.ink
        seedField.adjustsFontForContentSizeCategory = true
        let bar = UIToolbar()
        bar.sizeToFit()
        let close = UIBarButtonItem(title: "OK", style: .prominent, target: self, action: #selector(closeSeed))
        bar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), close]
        seedField.inputAccessoryView = bar

        generateButton.addTarget(self, action: #selector(generate), for: .touchUpInside)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateFooter.addSubview(generateButton)
        NSLayoutConstraint.activate([
            generateButton.leadingAnchor.constraint(equalTo: generateFooter.leadingAnchor, constant: 4),
            generateButton.trailingAnchor.constraint(equalTo: generateFooter.trailingAnchor, constant: -4),
            generateButton.topAnchor.constraint(equalTo: generateFooter.topAnchor, constant: 8),
            generateButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        generationTicket += 1
        generating = false
        generateButton.isEnabled = true
        updateGenerateTitle()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return MechanicChoice.allCases.count
        case 1: return 2
        default:
            let count = visibleEntries.count
            return count == 0 ? 1 : count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Mécaniques"
        case 1: return "Difficulté et graine"
        default: return "Gardés"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0 ? "Aucune sélection : le générateur choisit un parcours." : nil
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 1 ? 76 : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        section == 1 ? generateFooter : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return mechanicCell(at: indexPath.row)
        }
        if indexPath.section == 1 {
            return indexPath.row == 0 ? difficultyCell() : seedCell()
        }
        let entries = visibleEntries
        if entries.isEmpty {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.selectionStyle = .none
            cell.backgroundColor = AppTheme.card
            cell.textLabel?.text = "Aucun défi pour l'instant."
            cell.textLabel?.textColor = AppTheme.inkSoft
            cell.textLabel?.font = AppTheme.font(16, .medium, textStyle: .body)
            cell.textLabel?.numberOfLines = 0
            return cell
        }
        return historyCell(entries[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }
        Soundscape.shared.play("select")
        let entries = visibleEntries
        guard entries.indices.contains(indexPath.row) else { return }
        let entry = entries[indexPath.row]
        navigationController?.pushViewController(
            GameViewController(level: entry.level, challenge: entry.id),
            animated: true
        )
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 2 && !visibleEntries.isEmpty
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let entries = visibleEntries
        guard entries.indices.contains(indexPath.row) else { return nil }
        let entry = entries[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Supprimer") { [weak self] _, _, done in
            Soundscape.shared.play("ui")
            ChallengeStore.shared.delete(entry.id)
            self?.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    private var visibleEntries: [ChallengeEntry] {
        ChallengeStore.shared.entries(favoritesOnly: favoritesOnly)
    }

    private func mechanicCell(at index: Int) -> UITableViewCell {
        let choice = MechanicChoice.allCases[index]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = AppTheme.card
        cell.textLabel?.text = choice.title
        cell.textLabel?.font = AppTheme.font(17, .medium, textStyle: .body)
        cell.textLabel?.textColor = AppTheme.ink
        let toggle = UISwitch()
        toggle.onTintColor = AppTheme.teal
        toggle.isOn = selected.contains(choice)
        toggle.tag = choice.rawValue
        toggle.accessibilityLabel = choice.title
        toggle.addTarget(self, action: #selector(mechanicChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    private func difficultyCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = AppTheme.card
        if difficultyControl.superview !== cell.contentView {
            difficultyControl.removeFromSuperview()
            difficultyControl.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(difficultyControl)
            NSLayoutConstraint.activate([
                difficultyControl.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                difficultyControl.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                difficultyControl.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
                difficultyControl.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10)
            ])
        }
        return cell
    }

    private func seedCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = AppTheme.card
        if seedField.superview !== cell.contentView {
            seedField.removeFromSuperview()
            seedField.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(seedField)
            NSLayoutConstraint.activate([
                seedField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
                seedField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                seedField.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
                seedField.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
            ])
        }
        return cell
    }

    private func historyCell(_ entry: ChallengeEntry) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = AppTheme.card
        cell.textLabel?.text = PlayerCopy.challengeHeading(entry.recipe)
        cell.textLabel?.font = AppTheme.font(17, .semibold, textStyle: .body)
        cell.textLabel?.textColor = AppTheme.ink
        cell.textLabel?.numberOfLines = 0
        var detail = "\(PlayerCopy.difficultyTitle(entry.recipe.difficulty)) · graine \(entry.recipe.seed)"
        detail += " · \(Self.dateFormatter.string(from: entry.createdAt))"
        if let score = entry.score {
            detail += " · \(PlayerCopy.starCount(score.stars))"
        }
        cell.detailTextLabel?.text = detail
        cell.detailTextLabel?.textColor = AppTheme.inkSoft
        cell.detailTextLabel?.font = AppTheme.font(13, .medium, textStyle: .footnote)
        cell.detailTextLabel?.numberOfLines = 0
        let star = UIButton(type: .system)
        star.setImage(UIImage(systemName: entry.favorite ? "star.fill" : "star"), for: .normal)
        star.tintColor = entry.favorite ? AppTheme.gold : AppTheme.inkSoft
        star.accessibilityIdentifier = entry.id.uuidString
        star.accessibilityLabel = entry.favorite ? "Retirer des favoris" : "Ajouter aux favoris"
        star.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        star.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
        cell.accessoryView = star
        return cell
    }

    private func refreshFilterButton() {
        let item = UIBarButtonItem(
            title: favoritesOnly ? "Tous" : "Favoris",
            style: .plain,
            target: self,
            action: #selector(toggleFilter)
        )
        item.accessibilityLabel = favoritesOnly ? "Afficher tous les défis" : "Afficher les favoris"
        navigationItem.rightBarButtonItem = item
    }

    private func selectedFamilies() -> [PuzzleFamily] {
        var result: [PuzzleFamily] = []
        for choice in MechanicChoice.allCases where selected.contains(choice) {
            for family in choice.families where !result.contains(family) {
                result.append(family)
            }
        }
        return result
    }

    private func chosenSeed() -> UInt64 {
        let digits = seedField.text?.filter(\.isNumber) ?? ""
        if let value = UInt64(digits), value > 0 { return value }
        return UInt64.random(in: 1...UInt64.max)
    }

    private func updateGenerateTitle() {
        guard var configuration = generateButton.configuration else { return }
        configuration.title = generating ? "Préparation…" : "Générer"
        generateButton.configuration = configuration
        generateButton.accessibilityLabel = configuration.title
    }

    @objc private func mechanicChanged(_ sender: UISwitch) {
        guard let choice = MechanicChoice(rawValue: sender.tag) else { return }
        if sender.isOn {
            selected.insert(choice)
        } else {
            selected.remove(choice)
        }
    }

    @objc private func closeSeed() {
        seedField.resignFirstResponder()
    }

    @objc private func toggleFilter() {
        favoritesOnly.toggle()
        refreshFilterButton()
        tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
    }

    @objc private func starTapped(_ sender: UIButton) {
        guard let id = UUID(uuidString: sender.accessibilityIdentifier ?? ""),
              let entry = ChallengeStore.shared.entry(id) else { return }
        ChallengeStore.shared.setFavorite(id, !entry.favorite)
        tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
    }

    @objc private func generate() {
        guard !generating else { return }
        generating = true
        generateButton.isEnabled = false
        updateGenerateTitle()
        seedField.resignFirstResponder()
        let recipe = ChallengeRecipe(
            families: selectedFamilies(),
            difficulty: difficulties[max(0, difficultyControl.selectedSegmentIndex)],
            seed: chosenSeed()
        )
        generationTicket += 1
        let ticket = generationTicket
        GeneratedLevelFlow.produce(recipe.request()) { [weak self] generated in
            guard let self, ticket == self.generationTicket else { return }
            let entry = ChallengeStore.shared.append(level: generated.level, recipe: recipe)
            self.generating = false
            self.generateButton.isEnabled = true
            self.updateGenerateTitle()
            self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
            guard let navigation = self.navigationController, navigation.topViewController === self else { return }
            navigation.pushViewController(
                GameViewController(level: entry.level, challenge: entry.id),
                animated: true
            )
        }
    }
}
