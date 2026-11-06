import UIKit
import RobotIdiotCore

final class SettingsViewController: UITableViewController {
    private var backdrop: AmbientBackdropView!

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Réglages"
        tableView.backgroundColor = .clear
        let ambient = AmbientBackdropView(frame: .zero)
        ambient.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundView = ambient
        backdrop = ambient
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        if let navigation = navigationController {
            AppTheme.apply(to: navigation)
        }
        backdrop.start()
        tableView.reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3
        case 1: return 1
        case 2: return AdsConsentManager.shared.isPrivacyOptionsRequired ? 1 : 0
        default: return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Son"
        case 1: return "Tutoriel"
        case 2: return AdsConsentManager.shared.isPrivacyOptionsRequired ? "Confidentialité" : nil
        default: return "Progression"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 3 ? "Effacer oublie la progression de la campagne." : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return switchCell(title: "Sons", isOn: PlaySettings.sound, action: #selector(soundChanged(_:)))
        case (0, 1):
            return switchCell(title: "Musique", isOn: PlaySettings.music, action: #selector(musicChanged(_:)))
        case (0, 2):
            return switchCell(title: "Vibrations", isOn: PlaySettings.haptics, action: #selector(hapticsChanged(_:)))
        case (1, 0):
            return textCell(title: "Revoir le tutoriel", color: AppTheme.tealDark, accessory: .disclosureIndicator)
        case (2, 0):
            return textCell(title: "Options de confidentialité", color: AppTheme.tealDark, accessory: .disclosureIndicator)
        case (3, 0):
            return textCell(title: worldSummary(), color: AppTheme.ink, accessory: .none)
        default:
            return textCell(title: "Effacer la progression", color: AppTheme.coral, accessory: .none)
        }
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
            || indexPath.section == 2
            || (indexPath.section == 3 && indexPath.row == 1)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        Soundscape.shared.play("select")
        if indexPath.section == 1 {
            present(TutorialViewController(), animated: true)
            return
        }
        if indexPath.section == 2 {
            AdsConsentManager.shared.presentPrivacyOptions(from: self) { [weak self] _ in
                self?.tableView.reloadData()
            }
            return
        }
        guard indexPath.section == 3, indexPath.row == 1 else { return }
        ChartedConfirmAlertView.present(
            from: self,
            ribbon: "Attention",
            headline: "Effacer la progression ?",
            detail: "La progression de la campagne sera oubliée.",
            confirmTitle: "Effacer",
            accent: .destructive,
            confirmSystemImage: "trash"
        ) { [weak self] in
            CampaignStore.shared.reset()
            self?.tableView.reloadSections(IndexSet(integer: 3), with: .automatic)
        }
    }

    private func switchCell(title: String, isOn: Bool, action: Selector) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        cell.backgroundColor = AppTheme.card
        cell.textLabel?.text = title
        cell.textLabel?.font = AppTheme.font(17, .medium, textStyle: .body)
        cell.textLabel?.textColor = AppTheme.ink
        cell.textLabel?.numberOfLines = 0
        let toggle = UISwitch()
        toggle.onTintColor = AppTheme.teal
        toggle.isOn = isOn
        toggle.accessibilityLabel = title
        toggle.addTarget(self, action: action, for: .valueChanged)
        cell.accessoryView = toggle
        return cell
    }

    private func textCell(title: String, color: UIColor, accessory: UITableViewCell.AccessoryType) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = AppTheme.card
        cell.selectionStyle = accessory == .none && color == AppTheme.ink ? .none : .default
        cell.accessoryType = accessory
        cell.textLabel?.text = title
        cell.textLabel?.textColor = color
        cell.textLabel?.font = AppTheme.font(17, .medium, textStyle: .body)
        cell.textLabel?.numberOfLines = 0
        return cell
    }

    private func worldSummary() -> String {
        let progress = CampaignStore.shared.progress()
        let address = CampaignRules.continueAddress(in: progress, layout: CatalogCampaign.layout)
        if CatalogCampaign.level(at: address) == nil {
            return "Campagne terminée"
        }
        let world = min(
            CatalogCampaign.worldCount,
            CampaignRules.unlockedWorld(in: progress, layout: CatalogCampaign.layout)
        )
        return "Monde \(world) débloqué"
    }

    @objc private func soundChanged(_ sender: UISwitch) { PlaySettings.sound = sender.isOn }
    @objc private func musicChanged(_ sender: UISwitch) { PlaySettings.music = sender.isOn }
    @objc private func hapticsChanged(_ sender: UISwitch) { PlaySettings.haptics = sender.isOn }
}

/// Son, musique et vibrations, présenté depuis le bouton réglages du niveau.
final class SensorySettingsController: UIViewController, UIPopoverPresentationControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        let canvas = UIColor(hex: 0xF4F0FF)
        view.backgroundColor = canvas

        let title = UILabel()
        title.text = "Réglages"
        title.font = AppTheme.font(20, .heavy, textStyle: .title3)
        title.textColor = AppTheme.line
        title.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [
            title,
            settingRow(symbol: "speaker.wave.2.fill", tint: 0x7B3FF2, title: "Son", isOn: PlaySettings.sound, action: #selector(soundChanged(_:))),
            settingRow(symbol: "music.note", tint: 0x3EC6FF, title: "Musique", isOn: PlaySettings.music, action: #selector(musicChanged(_:))),
            settingRow(symbol: "iphone.radiowaves.left.and.right", tint: 0xFFB020, title: "Vibrations", isOn: PlaySettings.haptics, action: #selector(hapticsChanged(_:)))
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(14, after: title)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
        preferredContentSize = CGSize(width: 292, height: 262)
    }

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }

    private func settingRow(symbol: String, tint: UInt32, title: String, isOn: Bool, action: Selector) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous

        let badge = UIView()
        badge.backgroundColor = UIColor(hex: tint).withAlphaComponent(0.16)
        badge.layer.cornerRadius = 16
        badge.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
        icon.tintColor = UIColor(hex: tint)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(icon)

        let label = UILabel()
        label.text = title
        label.font = AppTheme.font(16, .heavy, textStyle: .body)
        label.textColor = AppTheme.line
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = PaletteSwitch()
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)
        toggle.accessibilityLabel = title
        toggle.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(badge)
        card.addSubview(label)
        card.addSubview(toggle)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 56),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 32),
            badge.heightAnchor.constraint(equalToConstant: 32),
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            label.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            toggle.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),
            toggle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            toggle.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        return card
    }

    @objc private func soundChanged(_ sender: PaletteSwitch) { PlaySettings.sound = sender.isOn }
    @objc private func musicChanged(_ sender: PaletteSwitch) { PlaySettings.music = sender.isOn }
    @objc private func hapticsChanged(_ sender: PaletteSwitch) { PlaySettings.haptics = sender.isOn }
}
