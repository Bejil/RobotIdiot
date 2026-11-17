import UIKit
import RobotIdiotCore

/// Liste des simulations réussies (réutilisable ; le hub affiche aussi l’historique inline).
final class ExpertHistoryViewController: UIViewController {
    private var backdrop: AmbientBackdropView!
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.cream
        navigationItem.title = "Historique"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal

        backdrop = AmbientBackdropView.install(in: view)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: guide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        backdrop.start()
        reload()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        backdrop.stop()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func reload() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let items = Array(ExpertStore.shared.completedSimulations().reversed())
        if items.isEmpty {
            let empty = UILabel()
            empty.text = "Aucune simulation réussie pour l’instant."
            empty.font = AppTheme.font(16, .medium, textStyle: .body)
            empty.textColor = AppTheme.inkSoft
            empty.numberOfLines = 0
            empty.textAlignment = .center
            empty.adjustsFontForContentSizeCategory = true
            stack.addArrangedSubview(empty)
            return
        }
        for simulation in items {
            let row = ExpertHistoryRowView()
            row.configure(
                sequence: simulation.sequence,
                title: simulation.name,
                stars: ExpertStore.shared.bestStars(for: simulation.id),
                themeWorld: simulation.visualThemeWorld
            )
            row.onTap = { [weak self] in
                let level = ExpertCatalog.playableLevel(for: simulation)
                let context = ExpertPlayContext(simulationId: simulation.id, simulationName: simulation.name)
                self?.navigationController?.pushViewController(
                    GameViewController(level: level, expert: context),
                    animated: true
                )
            }
            stack.addArrangedSubview(row)
        }
    }
}
