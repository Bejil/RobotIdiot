import Foundation

/// Pack fixe des 100 défis du jour (10 par palier).
public struct DailyChallengePack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var game: String
    public var type: String
    public var count: Int
    public var levels: [CatalogLevel]
}

/// Entrée « bug du jour ».
public struct DailyBug: Codable, Equatable, Sendable {
    public var id: String
    public var sourceDailyChallengeId: String
    public var tier: Int
    public var world: Int
    public var availableCommands: [String]
    public var boardRef: String
    public var mode: String
    public var bugProgram: [CatalogInstruction]
    public var referenceProgram: [CatalogInstruction]
    public var visibleErrorMarker: Bool
    public var validation: Validation
    public var reward: Reward
    public var instructions: String
    /// Uniquement pour QA / tests — jamais affiché dans l'UI.
    public var intendedBugLineForQA: Int

    public struct Validation: Codable, Equatable, Sendable {
        public var badProgramFails: Bool
        public var badProgramFailureReason: String?
        public var badProgramActionsUntilStop: Int?
        public var replaceExactlyOneMarkedCommand: Bool?
        public var uniqueWinningReplacementAtEditableLine: Bool?
        public var winningReplacement: String
        public var originalIncorrectCommand: String?
        public var fixedProgramReplayed: Bool?
        public var authoringProofScope: String?
        public var playerMayEditAnyPrimitiveLine: Bool?
    }

    public struct Reward: Codable, Equatable, Sendable {
        public var currency: String
        public var amount: Int
        public var oncePerChallengeDate: Bool?
    }
}

public struct DailyBugPack: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var game: String
    public var type: String
    public var count: Int
    public var bugs: [DailyBug]
}

public struct DailyConfig: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var game: String
    public var type: String
    public var timezone: String
    public var epochDate: String
    public var challengeRewardBolts: Int
    public var bugRewardBolts: Int
    public var tiers: Int
    public var itemsPerTier: Int
}

public enum DailyCatalogError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)
    case unreadable(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .missingResource(let name): return "\(name) est absent du bundle."
        case .unreadable(let name): return "\(name) est illisible."
        case .invalid(let detail): return detail
        }
    }
}

public enum DailyCatalog {
    public static let challenges: DailyChallengePack = {
        do { return try loadChallengesBundled() }
        catch { fatalError("Pack défis du jour illisible : \(error)") }
    }()

    public static let bugs: DailyBugPack = {
        do { return try loadBugsBundled() }
        catch { fatalError("Pack bugs du jour illisible : \(error)") }
    }()

    public static let config: DailyConfig = {
        do { return try loadConfigBundled() }
        catch {
            return DailyConfig(
                schemaVersion: "1.0",
                game: "Robot Idiot",
                type: "dailyConfig",
                timezone: "Europe/Paris",
                epochDate: "2026-11-04",
                challengeRewardBolts: 2,
                bugRewardBolts: 1,
                tiers: 10,
                itemsPerTier: 10
            )
        }
    }()

    public static func loadChallengesBundled() throws -> DailyChallengePack {
        try load(name: "robot_idiot_daily_challenges_100", as: DailyChallengePack.self) { pack in
            guard pack.levels.count == 100 else {
                throw DailyCatalogError.invalid("Attendu 100 défis, trouvé \(pack.levels.count)")
            }
            let ids = pack.levels.map(\.id)
            guard Set(ids).count == ids.count else {
                throw DailyCatalogError.invalid("IDs de défis non uniques")
            }
        }
    }

    public static func loadBugsBundled() throws -> DailyBugPack {
        try load(name: "robot_idiot_daily_bugs_100", as: DailyBugPack.self) { pack in
            guard pack.bugs.count == 100 else {
                throw DailyCatalogError.invalid("Attendu 100 bugs, trouvé \(pack.bugs.count)")
            }
            let ids = pack.bugs.map(\.id)
            guard Set(ids).count == ids.count else {
                throw DailyCatalogError.invalid("IDs de bugs non uniques")
            }
        }
    }

    public static func loadConfigBundled() throws -> DailyConfig {
        try load(name: "robot_idiot_daily_config", as: DailyConfig.self) { _ in }
    }

    public static func challenges(forTier tier: Int) -> [CatalogLevel] {
        challenges.levels
            .filter { $0.world == tier }
            .sorted { $0.worldLevel < $1.worldLevel }
    }

    public static func bugs(forTier tier: Int) -> [DailyBug] {
        let challengeOrder = Dictionary(
            uniqueKeysWithValues: challenges(forTier: tier).enumerated().map { ($0.element.id, $0.offset) }
        )
        return bugs.bugs
            .filter { $0.tier == tier }
            .sorted {
                (challengeOrder[$0.sourceDailyChallengeId] ?? Int.max)
                    < (challengeOrder[$1.sourceDailyChallengeId] ?? Int.max)
            }
    }

    public static func catalogLevel(id: String) -> CatalogLevel? {
        challenges.levels.first { $0.id == id }
    }

    public static func playableLevel(id: String) -> Level? {
        catalogLevel(id: id).map(CatalogCampaign.playableLevel)
    }

    public static func program(from instructions: [CatalogInstruction]) -> Program {
        CatalogCampaign.program(from: instructions)
    }

    public static func commandTypes(from names: [String]) -> [CommandType] {
        names.compactMap(CatalogCampaign.commandType(named:))
    }

    private static func load<T: Decodable>(
        name: String,
        as type: T.Type,
        validate: (T) throws -> Void
    ) throws -> T {
        guard let url = resourceURL(name: name) else {
            throw DailyCatalogError.missingResource("\(name).json")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            try validate(decoded)
            return decoded
        } catch let error as DailyCatalogError {
            throw error
        } catch {
            throw DailyCatalogError.unreadable("\(name).json")
        }
    }

    private static func resourceURL(name: String) -> URL? {
        if let url = Bundle.module.url(forResource: name, withExtension: "json") {
            return url
        }
        if let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Resources") {
            return url
        }
        let bundles = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in bundles {
            if let url = bundle.url(forResource: name, withExtension: "json") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources") {
                return url
            }
        }
        return nil
    }
}
