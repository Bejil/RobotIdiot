import Foundation

/// Sélection figée d'un jour civil (fuseau Europe/Paris).
public struct DailyFrozenSelection: Codable, Equatable, Sendable {
    public var civilDate: String
    public var tier: Int
    public var dayIndex: Int
    public var challengeId: String
    public var bugId: String
    public var challengeBoardRef: String
    public var bugBoardRef: String

    public init(
        civilDate: String,
        tier: Int,
        dayIndex: Int,
        challengeId: String,
        bugId: String,
        challengeBoardRef: String,
        bugBoardRef: String
    ) {
        self.civilDate = civilDate
        self.tier = tier
        self.dayIndex = dayIndex
        self.challengeId = challengeId
        self.bugId = bugId
        self.challengeBoardRef = challengeBoardRef
        self.bugBoardRef = bugBoardRef
    }
}

public enum DailySelection {
    public static let defaultTimezoneIdentifier = "Europe/Paris"
    public static let defaultEpochDate = "2026-11-04"
    public static let itemsPerTier = 10

    public static func calendar(timezoneIdentifier: String = defaultTimezoneIdentifier) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneIdentifier) ?? TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    public static func civilDateString(
        on date: Date,
        calendar: Calendar = calendar()
    ) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Jours civils écoulés depuis l'époque (Europe/Paris), sans division de timestamp.
    public static func dayIndex(
        on date: Date,
        epochDate: String = defaultEpochDate,
        calendar: Calendar = calendar()
    ) -> Int {
        guard let epoch = parseCivilDate(epochDate, calendar: calendar) else { return 0 }
        let start = calendar.startOfDay(for: epoch)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    public static func parseCivilDate(_ value: String, calendar: Calendar = calendar()) -> Date? {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12
        return calendar.date(from: components)
    }

    /// Formule du prompt : `(D + 3*T) % 10` et `(D + 3*T + 5) % 10`.
    public static func indices(dayIndex d: Int, tier t: Int) -> (challenge: Int, bug: Int) {
        let tier = max(1, min(t, 10))
        let challenge = positiveModulo(d + 3 * tier, itemsPerTier)
        let bug = positiveModulo(d + 3 * tier + 5, itemsPerTier)
        return (challenge, bug)
    }

    public static func challengeIndex(dayIndex: Int, tier: Int) -> Int {
        indices(dayIndex: dayIndex, tier: tier).challenge
    }

    public static func bugIndex(dayIndex: Int, tier: Int) -> Int {
        indices(dayIndex: dayIndex, tier: tier).bug
    }

    public static func select(
        tier: Int,
        on date: Date,
        challenges: [CatalogLevel],
        bugs: [DailyBug],
        config: DailyConfig = DailyCatalog.config
    ) -> DailyFrozenSelection {
        let calendar = calendar(timezoneIdentifier: config.timezone)
        let civil = civilDateString(on: date, calendar: calendar)
        let d = dayIndex(on: date, epochDate: config.epochDate, calendar: calendar)
        return select(
            tier: tier,
            civilDate: civil,
            dayIndex: d,
            challenges: challenges,
            bugs: bugs
        )
    }

    public static func select(
        tier: Int,
        civilDate: String,
        dayIndex d: Int,
        challenges: [CatalogLevel],
        bugs: [DailyBug]
    ) -> DailyFrozenSelection {
        let capped = max(1, min(tier, 10))
        let sortedChallenges = challenges.sorted { $0.worldLevel < $1.worldLevel }
        let challengeOrder = Dictionary(
            uniqueKeysWithValues: sortedChallenges.enumerated().map { ($0.element.id, $0.offset) }
        )
        let sortedBugs = bugs.sorted {
            (challengeOrder[$0.sourceDailyChallengeId] ?? Int.max)
                < (challengeOrder[$1.sourceDailyChallengeId] ?? Int.max)
        }
        let idx = indices(dayIndex: d, tier: capped)
        precondition(sortedChallenges.count == itemsPerTier)
        precondition(sortedBugs.count == itemsPerTier)
        let challenge = sortedChallenges[idx.challenge]
        let bug = sortedBugs[idx.bug]
        return DailyFrozenSelection(
            civilDate: civilDate,
            tier: capped,
            dayIndex: d,
            challengeId: challenge.id,
            bugId: bug.id,
            challengeBoardRef: challenge.id,
            bugBoardRef: bug.boardRef
        )
    }

    public static func currentTier(unlockedWorld: Int) -> Int {
        max(1, min(unlockedWorld, 10))
    }

    /// Remplace la primitive d'indice `index` (parcours préordre, hors conteneurs).
    public static func replacePrimitive(
        in program: [CatalogInstruction],
        at index: Int,
        with commandName: String
    ) -> [CatalogInstruction]? {
        guard let replacement = makeInstruction(named: commandName) else { return nil }
        var cursor = 0
        var didReplace = false
        func walk(_ nodes: [CatalogInstruction]) -> [CatalogInstruction] {
            nodes.map { node in
                switch node {
                case .repete(let body):
                    return .repete(walk(body))
                case .si(let condition, let body):
                    return .si(condition: condition, body: walk(body))
                default:
                    if cursor == index {
                        cursor += 1
                        didReplace = true
                        return replacement
                    }
                    cursor += 1
                    return node
                }
            }
        }
        let updated = walk(program)
        return didReplace ? updated : nil
    }

    public static func primitive(at index: Int, in program: [CatalogInstruction]) -> CatalogInstruction? {
        var cursor = 0
        func walk(_ nodes: [CatalogInstruction]) -> CatalogInstruction? {
            for node in nodes {
                switch node {
                case .repete(let body):
                    if let found = walk(body) { return found }
                case .si(_, let body):
                    if let found = walk(body) { return found }
                default:
                    if cursor == index { return node }
                    cursor += 1
                }
            }
            return nil
        }
        return walk(program)
    }

    private static func makeInstruction(named name: String) -> CatalogInstruction? {
        switch name {
        case "AVANCE": return .avance
        case "RECULE": return .recule
        case "TOURNE_GAUCHE": return .tourneGauche
        case "TOURNE_DROITE": return .tourneDroite
        case "RAMASSE": return .ramasse
        case "UTILISE": return .utilise
        case "POUSSE": return .pousse
        case "ACTIVE": return .active
        default: return nil
        }
    }

    private static func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let result = value % modulus
        return result >= 0 ? result : result + modulus
    }
}
