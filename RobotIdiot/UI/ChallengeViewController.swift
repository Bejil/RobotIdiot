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
    private var generating = false
    private var generationTicket = 0
    private let generateButton = AppTheme.filledButton(title: "Générer", systemImage: "dice.fill", prominent: true)
    private let generateFooter = UIView()

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
        navigationItem.backButtonDisplayMode = .minimal
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)

        let hint = UILabel()
        hint.text = "Aucune sélection : le générateur choisit un parcours."
        hint.font = AppTheme.font(13, .medium, textStyle: .footnote)
        hint.textColor = AppTheme.inkSoft
        hint.numberOfLines = 0

        generateButton.addTarget(self, action: #selector(generate), for: .touchUpInside)
        let column = UIStackView(arrangedSubviews: [hint, generateButton])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        generateFooter.addSubview(column)
        generateButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: generateFooter.leadingAnchor, constant: 4),
            column.trailingAnchor.constraint(equalTo: generateFooter.trailingAnchor, constant: -4),
            column.topAnchor.constraint(equalTo: generateFooter.topAnchor, constant: 8)
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

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        MechanicChoice.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Mécaniques"
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        128
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        generateFooter
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        mechanicCell(at: indexPath.row)
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

    private func selectedFamilies() -> [PuzzleFamily] {
        var result: [PuzzleFamily] = []
        for choice in MechanicChoice.allCases where selected.contains(choice) {
            for family in choice.families where !result.contains(family) {
                result.append(family)
            }
        }
        return result
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

    @objc private func generate() {
        guard !generating else { return }
        generating = true
        generateButton.isEnabled = false
        updateGenerateTitle()
        let seed = UInt64.random(in: 1...UInt64.max)
        let recipe = ChallengeRecipe(
            families: selectedFamilies(),
            difficulty: LevelGenerator.difficulty(forSeed: seed),
            seed: seed
        )
        generationTicket += 1
        let ticket = generationTicket
        GeneratedLevelFlow.produce(recipe.request()) { [weak self] generated in
            guard let self, ticket == self.generationTicket else { return }
            let entry = ChallengeStore.shared.append(level: generated.level, recipe: recipe)
            self.generating = false
            self.generateButton.isEnabled = true
            self.updateGenerateTitle()
            guard let navigation = self.navigationController, navigation.topViewController === self else { return }
            navigation.pushViewController(
                GameViewController(level: entry.level, challenge: entry.id),
                animated: true
            )
        }
    }
}
