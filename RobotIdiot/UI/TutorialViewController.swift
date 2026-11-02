import UIKit

final class TutorialViewController: UIViewController {
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
        titleLabel.text = "Comment jouer"
        titleLabel.font = AppTheme.font(28, .heavy, textStyle: .title1)
        titleLabel.textColor = AppTheme.ink
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        let body = UILabel()
        body.text = """
        Le robot fait exactement ce que tu écris. Il ne devine rien.

        La visière montre où il regarde. Avance suit cette direction.

        Répète tourne sans fin. Si ne s'exécute que lorsque la condition est vraie.
        """
        body.font = AppTheme.font(18, .medium, textStyle: .body)
        body.textColor = AppTheme.inkSoft
        body.numberOfLines = 0
        body.adjustsFontForContentSizeCategory = true

        let button = AppTheme.filledButton(title: "J'ai compris", systemImage: "checkmark", prominent: true)
        button.addTarget(self, action: #selector(close), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        let stack = UIStackView(arrangedSubviews: [robot, titleLabel, body, button])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        PlaySettings.tutorialSeen = true
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
