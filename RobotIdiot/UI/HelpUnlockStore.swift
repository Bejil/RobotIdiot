import Foundation

/// Mémorise l'indice / la solution déjà débloqués pour chaque niveau.
final class HelpUnlockStore {
    static let shared = HelpUnlockStore()

    private let defaults = UserDefaults.standard
    private let hintsKey = "robotidiot.help.hints"
    private let solutionsKey = "robotidiot.help.solutions"

    private var hints: [String: String] {
        didSet { defaults.set(hints, forKey: hintsKey) }
    }

    private var solutions: [String: String] {
        didSet { defaults.set(solutions, forKey: solutionsKey) }
    }

    private init() {
        hints = defaults.dictionary(forKey: hintsKey) as? [String: String] ?? [:]
        solutions = defaults.dictionary(forKey: solutionsKey) as? [String: String] ?? [:]
    }

    func hint(for levelID: String) -> String? {
        hints[levelID]
    }

    func solution(for levelID: String) -> String? {
        solutions[levelID]
    }

    func saveHint(_ text: String, for levelID: String) {
        hints[levelID] = text
    }

    func saveSolution(_ text: String, for levelID: String) {
        solutions[levelID] = text
        // La solution inclut l'aide : on peut aussi marquer un indice générique si absent.
        if hints[levelID] == nil {
            hints[levelID] = text
        }
    }
}
