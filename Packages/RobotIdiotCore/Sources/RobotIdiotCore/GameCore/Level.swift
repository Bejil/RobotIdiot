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
    public var referenceNote: String

    public init(compactProgramMaxBlocks: Int?, efficientExecutionMaxSteps: Int?, referenceNote: String) {
        self.compactProgramMaxBlocks = compactProgramMaxBlocks
        self.efficientExecutionMaxSteps = efficientExecutionMaxSteps
        self.referenceNote = referenceNote
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
        rules: ScoringRules
    ) -> StarRating {
        guard succeeded else { return .none }
        let compact = rules.compactProgramMaxBlocks.map { blockCount <= $0 } ?? false
        let efficient = rules.efficientExecutionMaxSteps.map { executedInstructions <= $0 } ?? false
        return StarRating(completion: true, compactProgram: compact, efficientExecution: efficient)
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
        validation: ValidationMetadata
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
