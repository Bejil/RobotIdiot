import Foundation

public struct ThemeIdentifier: Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public static let laboratory = ThemeIdentifier(rawValue: "laboratory")
    public static let orchard = ThemeIdentifier(rawValue: "orchard")
    public static let night = ThemeIdentifier(rawValue: "night")
    public static let foundry = ThemeIdentifier(rawValue: "foundry")

    public static let campaign = [laboratory, orchard, night, foundry]
}

extension ThemeIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ProgramConstraints: Codable, Hashable, Sendable {
    public var maxBlocks: Int?
    public var maxNestingDepth: Int

    public init(maxBlocks: Int?, maxNestingDepth: Int) {
        self.maxBlocks = maxBlocks
        self.maxNestingDepth = maxNestingDepth
    }

    public static let flat = ProgramConstraints(maxBlocks: nil, maxNestingDepth: 1)
}

/// Seuils issus d'une solution de référence vérifiée.
/// Ils ne prétendent pas qu'une solution est optimale.
public struct ScoringRules: Codable, Hashable, Sendable {
    public var compactProgramMaxBlocks: Int?
    public var efficientExecutionMaxSteps: Int?
    /// Seuil 3★ si le bonus a été ramassé durant la tentative gagnante.
    public var efficientExecutionMaxStepsWithBonus: Int?
    public var referenceNote: String

    public init(
        compactProgramMaxBlocks: Int?,
        efficientExecutionMaxSteps: Int?,
        efficientExecutionMaxStepsWithBonus: Int? = nil,
        referenceNote: String
    ) {
        self.compactProgramMaxBlocks = compactProgramMaxBlocks
        self.efficientExecutionMaxSteps = efficientExecutionMaxSteps
        self.efficientExecutionMaxStepsWithBonus = efficientExecutionMaxStepsWithBonus
        self.referenceNote = referenceNote
    }

    public func efficientLimit(bonusCollected: Bool) -> Int? {
        if bonusCollected, let withBonus = efficientExecutionMaxStepsWithBonus {
            return withBonus
        }
        return efficientExecutionMaxSteps
    }
}

public struct StarRating: Codable, Hashable, Sendable {
    public var completion: Bool
    public var compactProgram: Bool
    public var efficientExecution: Bool

    public init(completion: Bool, compactProgram: Bool, efficientExecution: Bool) {
        self.completion = completion
        self.compactProgram = compactProgram
        self.efficientExecution = efficientExecution
    }

    public var count: Int {
        [completion, compactProgram, efficientExecution].filter { $0 }.count
    }

    public static let none = StarRating(completion: false, compactProgram: false, efficientExecution: false)
}

public enum ScoreEvaluator {
    public static func rating(
        succeeded: Bool,
        blockCount: Int,
        executedInstructions: Int,
        rules: ScoringRules,
        bonusCollected: Bool = false
    ) -> StarRating {
        guard succeeded else { return .none }
        let efficient = rules.efficientLimit(bonusCollected: bonusCollected).map { executedInstructions <= $0 } ?? false
        guard let compactLimit = rules.compactProgramMaxBlocks else {
            return StarRating(completion: true, compactProgram: efficient, efficientExecution: efficient)
        }
        return StarRating(
            completion: true,
            compactProgram: blockCount <= compactLimit,
            efficientExecution: efficient
        )
    }
}

public enum ValidationStatus: String, Codable, Hashable, Sendable {
    case handcrafted
    case accepted
    case rejected
}

public struct ValidationMetadata: Codable, Hashable, Sendable {
    public var status: ValidationStatus
    public var notes: [String]

    public init(status: ValidationStatus, notes: [String] = []) {
        self.status = status
        self.notes = notes
    }
}

/// Paire de portails jouable (coordonnées déjà dans le repère moteur).
public struct LevelPortalLink: Codable, Hashable, Sendable, Identifiable {
    public var id: String { linkId }
    public var linkId: String
    public var endpoints: [GridCoordinate]
    public var visualVariant: String

    public init(linkId: String, endpoints: [GridCoordinate], visualVariant: String) {
        self.linkId = linkId
        self.endpoints = endpoints
        self.visualVariant = visualVariant
    }

    public func partner(of coordinate: GridCoordinate) -> GridCoordinate? {
        guard endpoints.count == 2 else { return nil }
        if endpoints[0] == coordinate { return endpoints[1] }
        if endpoints[1] == coordinate { return endpoints[0] }
        return nil
    }
}

public struct Level: Codable, Hashable, Sendable {
    public var id: String
    public var version: Int
    public var seed: UInt64
    public var generatorVersion: Int
    public var worldNumber: Int
    public var levelNumber: Int
    public var difficulty: Double
    public var theme: ThemeIdentifier
    public var grid: Grid
    public var initialRobot: RobotState
    public var objectives: [Objective]
    public var allowedCommands: [CommandType]
    public var programConstraints: ProgramConstraints
    public var scoringRules: ScoringRules
    public var validation: ValidationMetadata
    /// Bonus facultatifs (ex. BoardBolt), affichés en overlay sans remplacer la tuile.
    public var collectibles: [LevelCollectible]
    /// Portails bidirectionnels (V13). Entrée sur une extrémité → sortie sur l'autre.
    public var portalLinks: [LevelPortalLink]

    public init(
        id: String,
        version: Int,
        seed: UInt64,
        generatorVersion: Int,
        worldNumber: Int,
        levelNumber: Int,
        difficulty: Double,
        theme: ThemeIdentifier,
        grid: Grid,
        initialRobot: RobotState,
        objectives: [Objective],
        allowedCommands: [CommandType],
        programConstraints: ProgramConstraints,
        scoringRules: ScoringRules,
        validation: ValidationMetadata,
        collectibles: [LevelCollectible] = [],
        portalLinks: [LevelPortalLink] = []
    ) {
        self.id = id
        self.version = version
        self.seed = seed
        self.generatorVersion = generatorVersion
        self.worldNumber = worldNumber
        self.levelNumber = levelNumber
        self.difficulty = difficulty
        self.theme = theme
        self.grid = grid
        self.initialRobot = initialRobot
        self.objectives = objectives
        self.allowedCommands = allowedCommands
        self.programConstraints = programConstraints
        self.scoringRules = scoringRules
        self.validation = validation
        self.collectibles = collectibles
        self.portalLinks = portalLinks
    }

    public func portalPartner(of coordinate: GridCoordinate) -> GridCoordinate? {
        for link in portalLinks {
            if let partner = link.partner(of: coordinate) {
                return partner
            }
        }
        return nil
    }

    public func isPortal(_ coordinate: GridCoordinate) -> Bool {
        portalLinks.contains { $0.endpoints.contains(coordinate) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, version, seed, generatorVersion, worldNumber, levelNumber, difficulty
        case theme, grid, initialRobot, objectives, allowedCommands, programConstraints
        case scoringRules, validation, collectibles, portalLinks
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        version = try container.decode(Int.self, forKey: .version)
        seed = try container.decode(UInt64.self, forKey: .seed)
        generatorVersion = try container.decode(Int.self, forKey: .generatorVersion)
        worldNumber = try container.decode(Int.self, forKey: .worldNumber)
        levelNumber = try container.decode(Int.self, forKey: .levelNumber)
        difficulty = try container.decode(Double.self, forKey: .difficulty)
        theme = try container.decode(ThemeIdentifier.self, forKey: .theme)
        grid = try container.decode(Grid.self, forKey: .grid)
        initialRobot = try container.decode(RobotState.self, forKey: .initialRobot)
        objectives = try container.decode([Objective].self, forKey: .objectives)
        allowedCommands = try container.decode([CommandType].self, forKey: .allowedCommands)
        programConstraints = try container.decode(ProgramConstraints.self, forKey: .programConstraints)
        scoringRules = try container.decode(ScoringRules.self, forKey: .scoringRules)
        validation = try container.decode(ValidationMetadata.self, forKey: .validation)
        collectibles = try container.decodeIfPresent([LevelCollectible].self, forKey: .collectibles) ?? []
        portalLinks = try container.decodeIfPresent([LevelPortalLink].self, forKey: .portalLinks) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(version, forKey: .version)
        try container.encode(seed, forKey: .seed)
        try container.encode(generatorVersion, forKey: .generatorVersion)
        try container.encode(worldNumber, forKey: .worldNumber)
        try container.encode(levelNumber, forKey: .levelNumber)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(theme, forKey: .theme)
        try container.encode(grid, forKey: .grid)
        try container.encode(initialRobot, forKey: .initialRobot)
        try container.encode(objectives, forKey: .objectives)
        try container.encode(allowedCommands, forKey: .allowedCommands)
        try container.encode(programConstraints, forKey: .programConstraints)
        try container.encode(scoringRules, forKey: .scoringRules)
        try container.encode(validation, forKey: .validation)
        try container.encode(collectibles, forKey: .collectibles)
        try container.encode(portalLinks, forKey: .portalLinks)
    }

    public var placedObjects: [PlacedObject] {
        grid.cells.flatMap(\.objects)
    }

    public var placedMechanisms: [PlacedMechanism] {
        grid.cells.flatMap(\.mechanisms)
    }
}

public enum LevelIssue: Equatable, Sendable {
    case invalidDimensions
    case cellCountMismatch
    case robotOutside
    case robotBlocked
    case objectiveOutside(String)
    case objectiveBlocked(String)
    case duplicateObjectiveID(String)
    case alreadySolvedAtStart
    case noObjective
    case noAllowedCommand
}

public enum LevelIntegrity {
    public static func issues(in level: Level) -> [LevelIssue] {
        var found: [LevelIssue] = []
        if level.grid.width <= 0 || level.grid.height <= 0 {
            found.append(.invalidDimensions)
        }
        if level.grid.cells.count != level.grid.width * level.grid.height {
            found.append(.cellCountMismatch)
        }
        if level.grid.cell(at: level.initialRobot.position) == nil {
            found.append(.robotOutside)
        } else if level.grid.cell(at: level.initialRobot.position)?.allowsRobotEntry != true {
            found.append(.robotBlocked)
        }

        var seen = Set<String>()
        if level.objectives.isEmpty {
            found.append(.noObjective)
        }
        for objective in level.objectives {
            if !seen.insert(objective.id).inserted {
                found.append(.duplicateObjectiveID(objective.id))
            }
            guard let cell = level.grid.cell(at: objective.position) else {
                found.append(.objectiveOutside(objective.id))
                continue
            }
            if !cell.allowsRobotEntry {
                found.append(.objectiveBlocked(objective.id))
            }
        }

        let start = GameState.initial(from: level)
        if LevelRules.isSatisfied(start, level: level) {
            found.append(.alreadySolvedAtStart)
        }
        if level.allowedCommands.isEmpty {
            found.append(.noAllowedCommand)
        }
        return found
    }
}
