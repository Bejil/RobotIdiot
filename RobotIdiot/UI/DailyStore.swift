import Foundation
import RobotIdiotCore

/// Persistance locale des défis / bugs du jour et de leurs récompenses.
final class DailyStore {
    static let shared = DailyStore()

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let frozenKey = "robotidiot.daily.frozen"
    private let challengeWinsKey = "robotidiot.daily.challengeWins"
    private let bugWinsKey = "robotidiot.daily.bugWins"

    private var frozen: DailyFrozenSelection? {
        didSet {
            if let frozen, let data = try? JSONEncoder().encode(frozen) {
                defaults.set(data, forKey: frozenKey)
            }
        }
    }

    private var challengeWins: Set<String> {
        didSet { defaults.set(Array(challengeWins).sorted(), forKey: challengeWinsKey) }
    }

    private var bugWins: Set<String> {
        didSet { defaults.set(Array(bugWins).sorted(), forKey: bugWinsKey) }
    }

    private init() {
        if let data = defaults.data(forKey: frozenKey),
           let decoded = try? JSONDecoder().decode(DailyFrozenSelection.self, from: data) {
            frozen = decoded
        } else {
            frozen = nil
        }
        challengeWins = Set(defaults.stringArray(forKey: challengeWinsKey) ?? [])
        bugWins = Set(defaults.stringArray(forKey: bugWinsKey) ?? [])
    }

    /// Fige `(date, palier, challenge, bug)` à la première ouverture du jour.
    @discardableResult
    func selection(
        now: Date = Date(),
        unlockedWorld: Int = CampaignRules.unlockedWorld(
            in: CampaignStore.shared.progress(),
            layout: CatalogCampaign.layout
        )
    ) -> DailyFrozenSelection {
        lock.lock()
        defer { lock.unlock() }
        let config = DailyCatalog.config
        let calendar = DailySelection.calendar(timezoneIdentifier: config.timezone)
        let civil = DailySelection.civilDateString(on: now, calendar: calendar)
        if let frozen, frozen.civilDate == civil {
            return frozen
        }
        let tier = DailySelection.currentTier(unlockedWorld: unlockedWorld)
        let challenges = DailyCatalog.challenges(forTier: tier)
        let bugs = DailyCatalog.bugs(forTier: tier)
        let next = DailySelection.select(
            tier: tier,
            on: now,
            challenges: challenges,
            bugs: bugs,
            config: config
        )
        frozen = next
        return next
    }

    func hasWonChallenge(on civilDate: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return challengeWins.contains(civilDate)
    }

    func hasWonBug(on civilDate: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return bugWins.contains(civilDate)
    }

    /// Crédite 2 écrous à la première victoire du défi du jour.
    @discardableResult
    func creditChallengeVictory(on civilDate: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard !challengeWins.contains(civilDate) else { return 0 }
        challengeWins.insert(civilDate)
        let amount = DailyCatalog.config.challengeRewardBolts
        BoltWallet.shared.credit(amount)
        return amount
    }

    /// Crédite 1 écrou à la première victoire du bug du jour.
    @discardableResult
    func creditBugVictory(on civilDate: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        guard !bugWins.contains(civilDate) else { return 0 }
        bugWins.insert(civilDate)
        let amount = DailyCatalog.config.bugRewardBolts
        BoltWallet.shared.credit(amount)
        return amount
    }

    func resetForTests() {
        lock.lock()
        frozen = nil
        challengeWins = []
        bugWins = []
        defaults.removeObject(forKey: frozenKey)
        defaults.removeObject(forKey: challengeWinsKey)
        defaults.removeObject(forKey: bugWinsKey)
        lock.unlock()
    }
}
