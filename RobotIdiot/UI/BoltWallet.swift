import Foundation
import RobotIdiotCore

/// Portefeuille d'écrous et crédits déjà obtenus (une fois par collectible).
final class BoltWallet {
    static let shared = BoltWallet()

    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let balanceKey = "robotidiot.bolts.balance"
    private let creditedKey = "robotidiot.bolts.credited"

    private(set) var balance: Int {
        didSet { defaults.set(balance, forKey: balanceKey) }
    }

    private var credited: Set<String> {
        didSet { defaults.set(Array(credited).sorted(), forKey: creditedKey) }
    }

    private init() {
        balance = defaults.object(forKey: balanceKey) as? Int ?? 0
        credited = Set(defaults.stringArray(forKey: creditedKey) ?? [])
    }

    static func creditKey(levelID: String, collectibleID: String) -> String {
        "\(levelID)|\(collectibleID)"
    }

    func hasCredited(levelID: String, collectibleID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return credited.contains(Self.creditKey(levelID: levelID, collectibleID: collectibleID))
    }

    /// Crédite les bonus ramassés pendant une victoire. Ignore ceux déjà obtenus.
    @discardableResult
    func creditVictory(levelID: String, collected: [LevelCollectible]) -> Int {
        lock.lock()
        defer { lock.unlock() }
        var gained = 0
        for item in collected {
            let key = Self.creditKey(levelID: levelID, collectibleID: item.id)
            guard !credited.contains(key) else { continue }
            credited.insert(key)
            let amount = max(0, item.amount)
            balance += amount
            gained += amount
        }
        return gained
    }

    /// Crédit libre (récompenses quotidiennes, etc.).
    func credit(_ amount: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard amount > 0 else { return }
        balance += amount
    }

    static func perfectWorldKey(_ world: Int) -> String {
        "worldPerfect|\(world)"
    }

    func hasCreditedPerfectWorld(_ world: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return credited.contains(Self.perfectWorldKey(world))
    }

    /// Bonus unique : tous les niveaux du monde à 3 étoiles.
    @discardableResult
    func creditPerfectWorld(_ world: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let key = Self.perfectWorldKey(world)
        guard world >= 1, !credited.contains(key) else { return 0 }
        let amount = RewardEconomy.perfectWorldBonusBolts
        guard amount > 0 else { return 0 }
        credited.insert(key)
        balance += amount
        return amount
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        return true
    }

    /// Dépense pour éviter une publicité de réessai. Ne remplace jamais un redémarrage gratuit.
    @discardableResult
    func spendForAdFreeRetry() -> Bool {
        spend(RewardEconomy.adFreeRetryCost)
    }

    @discardableResult
    func spendForHint() -> Bool {
        spend(RewardEconomy.hintCost)
    }

    @discardableResult
    func spendForFullSolution() -> Bool {
        spend(RewardEconomy.fullSolutionCost)
    }

    func reset() {
        lock.lock()
        balance = 0
        credited = []
        lock.unlock()
    }

#if DEBUG
    /// Remplace le solde (outil de debug uniquement).
    func debugSetBalance(_ value: Int) {
        lock.lock()
        defer { lock.unlock() }
        balance = max(0, value)
    }
#endif
}
