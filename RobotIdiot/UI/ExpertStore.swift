import Foundation
import RobotIdiotCore

/// Persistance Mode Expert — namespace isolé de l’Aventure et des quotidiens.
final class ExpertStore {
    static let shared = ExpertStore()

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let tutorialKey = "robotIdiot.expert.tutorial.v1.completed"
    private let completedKey = "robotIdiot.expert.v1.completedIds"
    private let starsKey = "robotIdiot.expert.v1.bestStars"
    private let blocksKey = "robotIdiot.expert.v1.bestWrittenBlocks"
    private let programsKey = "robotIdiot.expert.v1.savedPrograms"
    private let microKey = "robotIdiot.expert.v1.microTutorialFlags"

    private(set) var tutorialCompleted: Bool {
        didSet { defaults.set(tutorialCompleted, forKey: tutorialKey) }
    }

    private var completedIds: Set<String> {
        didSet { defaults.set(Array(completedIds).sorted(), forKey: completedKey) }
    }

    private var bestStars: [String: Int] {
        didSet { defaults.set(bestStars, forKey: starsKey) }
    }

    private var bestWrittenBlocks: [String: Int] {
        didSet { defaults.set(bestWrittenBlocks, forKey: blocksKey) }
    }

    private var savedPrograms: [String: Data] {
        didSet { defaults.set(savedPrograms, forKey: programsKey) }
    }

    private var microFlags: Set<String> {
        didSet { defaults.set(Array(microFlags).sorted(), forKey: microKey) }
    }

    private init() {
        tutorialCompleted = defaults.bool(forKey: tutorialKey)
        completedIds = Set(defaults.stringArray(forKey: completedKey) ?? [])
        bestStars = (defaults.dictionary(forKey: starsKey) as? [String: Int]) ?? [:]
        bestWrittenBlocks = (defaults.dictionary(forKey: blocksKey) as? [String: Int]) ?? [:]
        savedPrograms = (defaults.dictionary(forKey: programsKey) as? [String: Data]) ?? [:]
        microFlags = Set(defaults.stringArray(forKey: microKey) ?? [])
    }

    var masteryCount: Int { completedIds.count }

    var masteryPercent: Int {
        Int(floor(100.0 * Double(masteryCount) / Double(ExpertCatalog.totalSimulations)))
    }

    func hasCompleted(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return completedIds.contains(id)
    }

    func bestStars(for id: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return bestStars[id] ?? 0
    }

    func bestBlocks(for id: String) -> Int? {
        lock.lock(); defer { lock.unlock() }
        return bestWrittenBlocks[id]
    }

    /// Prochaine simulation à jouer (première non réussie), ou la dernière si tout est fini.
    func resumeSimulation() -> ExpertSimulation {
        let ordered = ExpertCatalog.orderedSimulations
        if let next = ordered.first(where: { !completedIds.contains($0.id) }) {
            return next
        }
        return ordered.last ?? ordered[0]
    }

    func markTutorialCompleted() {
        lock.lock(); defer { lock.unlock() }
        tutorialCompleted = true
    }

    func hasSeenMicroTutorial(_ key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return microFlags.contains(key)
    }

    func markMicroTutorialSeen(_ key: String) {
        lock.lock(); defer { lock.unlock() }
        microFlags.insert(key)
    }

    @discardableResult
    func recordVictory(id: String, stars: Int, writtenBlocks: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let unlockedNext = !completedIds.contains(id)
        completedIds.insert(id)
        bestStars[id] = max(bestStars[id] ?? 0, stars)
        if let previous = bestWrittenBlocks[id] {
            bestWrittenBlocks[id] = min(previous, writtenBlocks)
        } else {
            bestWrittenBlocks[id] = writtenBlocks
        }
        return unlockedNext
    }

    func saveProgram(_ program: Program, for id: String) {
        lock.lock(); defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(program) {
            savedPrograms[id] = data
        }
    }

    func program(for id: String) -> Program? {
        lock.lock(); defer { lock.unlock() }
        guard let data = savedPrograms[id] else { return nil }
        return try? JSONDecoder().decode(Program.self, from: data)
    }

    func completedSimulations() -> [ExpertSimulation] {
        ExpertCatalog.orderedSimulations.filter { completedIds.contains($0.id) }
    }

    func resetForTests() {
        lock.lock()
        tutorialCompleted = false
        completedIds = []
        bestStars = [:]
        bestWrittenBlocks = [:]
        savedPrograms = [:]
        microFlags = []
        defaults.removeObject(forKey: tutorialKey)
        defaults.removeObject(forKey: completedKey)
        defaults.removeObject(forKey: starsKey)
        defaults.removeObject(forKey: blocksKey)
        defaults.removeObject(forKey: programsKey)
        defaults.removeObject(forKey: microKey)
        lock.unlock()
    }
}
